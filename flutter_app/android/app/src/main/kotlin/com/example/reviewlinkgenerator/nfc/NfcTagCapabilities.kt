package com.example.reviewlinkgenerator.nfc

import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.NfcA

/**
 * Hardware-confirmed profile and memory map for genuine NXP NTAG21x chips.
 */
data class Ntag21xProfile(
    val typeName: String,
    val pageCount: Int,
    val dynamicLockPage: Int,
    val dynB0: Byte,
    val dynB1: Byte,
    val dynB2: Byte,
    val auth0Page: Int,
    val accessPage: Int,
    val pwdPage: Int,
    val packPage: Int
)

enum class NtagPasswordState {
    UNPROTECTED,
    PROTECTED,
    INDETERMINATE
}

/**
 * Shared low-level hardware capability checks ensuring raw Type-2 / NTAG21x
 * commands are never sent blindly to IsoDep (Bank/ID/Bus) or MIFARE Classic cards,
 * and chip capabilities are verified strictly via silicon responses rather than heuristics.
 */
object NfcTagCapabilities {

    val NTAG213 = Ntag21xProfile(
        typeName = "NTAG213",
        pageCount = 45,
        dynamicLockPage = 40,
        dynB0 = 0xFF.toByte(),
        dynB1 = 0x0F.toByte(),
        dynB2 = 0x3F.toByte(),
        auth0Page = 41,
        accessPage = 42,
        pwdPage = 43,
        packPage = 44
    )

    val NTAG215 = Ntag21xProfile(
        typeName = "NTAG215",
        pageCount = 135,
        dynamicLockPage = 130,
        dynB0 = 0xFF.toByte(),
        dynB1 = 0x00.toByte(),
        dynB2 = 0x0F.toByte(),
        auth0Page = 131,
        accessPage = 132,
        pwdPage = 133,
        packPage = 134
    )

    val NTAG216 = Ntag21xProfile(
        typeName = "NTAG216",
        pageCount = 231,
        dynamicLockPage = 226,
        dynB0 = 0xFF.toByte(),
        dynB1 = 0x3F.toByte(),
        dynB2 = 0x7F.toByte(),
        auth0Page = 227,
        accessPage = 228,
        pwdPage = 229,
        packPage = 230
    )

    /**
     * Returns true strictly when [tag] exposes NfcA + MifareUltralight and does NOT
     * expose IsoDep or MifareClassic (preventing Type-2 commands on Bank/ID/Bus cards).
     */
    fun isType2NfcACandidate(tag: Tag): Boolean {
        val techNames = tag.techList.map { it.substringAfterLast('.') }
        return techNames.contains("NfcA") &&
            techNames.contains("MifareUltralight") &&
            !techNames.contains("IsoDep") &&
            !techNames.contains("MifareClassic")
    }

    /**
     * Checks whether the decoded AUTH0 configuration byte actively protects tag memory.
     */
    fun isAuth0Protected(auth0Byte: Int, pageCount: Int): Boolean {
        return auth0Byte != 0xFF && auth0Byte < pageCount
    }

    /**
     * Sends NXP GET_VERSION (0x60) over an already-connected [nfca] handle and returns
     * the confirmed [Ntag21xProfile], or `null` if rejected or unrecognized.
     *
     * Never falls back to NDEF size heuristics.
     */
    fun probeConfirmedNtag21x(
        nfca: NfcA,
        timeoutMs: Int,
        rethrowTagLost: Boolean = false
    ): Ntag21xProfile? {
        return try {
            val verResp = nfca.transceive(byteArrayOf(0x60.toByte()))
            if (verResp != null && verResp.size >= 8) {
                val vendorId = verResp[1].toInt() and 0xFF
                val prodType = verResp[2].toInt() and 0xFF
                val storageSize = verResp[6].toInt() and 0xFF
                val protocolType = verResp[7].toInt() and 0xFF
                if (vendorId == 0x04 && prodType == 0x04 && protocolType != 0x05) {
                    when (storageSize) {
                        0x0F -> NTAG213
                        0x11 -> NTAG215
                        0x13 -> NTAG216
                        else -> null
                    }
                } else {
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            if (rethrowTagLost && isTagLost(e)) {
                throw e
            }
            if (!isTagLost(e)) {
                reconnectNfcA(nfca, timeoutMs)
            }
            null
        }
    }

    /**
     * Reads Capability Container (Page 03) on an already-connected Type-2 [nfca] handle
     * and returns true if the low access nibble is permanently locked read-only (`0x0F`).
     */
    fun isCapabilityContainerReadOnly(
        nfca: NfcA,
        rethrowTagLost: Boolean = false
    ): Boolean {
        return try {
            val cc = nfca.transceive(byteArrayOf(0x30.toByte(), 0x03.toByte()))
            cc != null && cc.size >= 4 && (cc[3].toInt() and 0x0F) == 0x0F
        } catch (e: Exception) {
            if (rethrowTagLost && isTagLost(e)) {
                throw e
            }
            false
        }
    }

    /**
     * Probes AUTH0 on an already-connected [nfca] handle for a confirmed [profile].
     *
     * Handles both PROT = 0 (AUTH0 readable) and PROT = 1 (AUTH0 NACKed because reads
     * are also password-protected, verified by reconnecting and reading always-readable Page 00).
     */
    fun probeAuth0ProtectionState(
        nfca: NfcA,
        profile: Ntag21xProfile,
        timeoutMs: Int,
        rethrowTagLost: Boolean = false
    ): NtagPasswordState {
        return try {
            val resp = nfca.transceive(byteArrayOf(0x30.toByte(), profile.auth0Page.toByte()))
            if (resp != null && resp.size >= 4) {
                val auth0 = resp[3].toInt() and 0xFF
                if (isAuth0Protected(auth0, profile.pageCount)) {
                    NtagPasswordState.PROTECTED
                } else {
                    NtagPasswordState.UNPROTECTED
                }
            } else {
                NtagPasswordState.INDETERMINATE
            }
        } catch (e: Exception) {
            if (isTagLost(e)) {
                if (rethrowTagLost) throw e
                return NtagPasswordState.INDETERMINATE
            }
            if (!reconnectNfcA(nfca, timeoutMs)) {
                return NtagPasswordState.INDETERMINATE
            }
            try {
                val page0 = nfca.transceive(byteArrayOf(0x30.toByte(), 0x00.toByte()))
                if (page0 != null && page0.size >= 4) {
                    NtagPasswordState.PROTECTED
                } else {
                    NtagPasswordState.INDETERMINATE
                }
            } catch (page0Ex: Exception) {
                if (rethrowTagLost && isTagLost(page0Ex)) {
                    throw page0Ex
                }
                NtagPasswordState.INDETERMINATE
            }
        }
    }

    /**
     * Safely checks whether [tag] is a confirmed NTAG21x chip with active password
     * protection (either PROT = 0 write protection or PROT = 1 read+write protection).
     */
    fun isTagPasswordProtected(tag: Tag, timeoutMs: Int = 2000): Boolean {
        if (!isType2NfcACandidate(tag)) return false
        val nfca = try {
            NfcA.get(tag)
        } catch (_: Exception) {
            null
        } ?: return false

        return try {
            nfca.connect()
            nfca.timeout = timeoutMs
            val profile = probeConfirmedNtag21x(nfca, timeoutMs) ?: return false
            probeAuth0ProtectionState(nfca, profile, timeoutMs, rethrowTagLost = false) ==
                NtagPasswordState.PROTECTED
        } catch (_: Exception) {
            false
        } finally {
            try {
                nfca.close()
            } catch (_: Exception) {
            }
        }
    }

    fun isTagLost(e: Exception): Boolean {
        if (e is TagLostException) return true
        val msg = e.message?.lowercase() ?: ""
        return msg.contains("tag was lost") ||
            msg.contains("tag lost") ||
            msg.contains("connection lost") ||
            msg.contains("broken pipe")
    }

    fun reconnectNfcA(nfca: NfcA, timeoutMs: Int): Boolean {
        try {
            nfca.close()
        } catch (_: Exception) {
        }
        return try {
            nfca.connect()
            nfca.timeout = timeoutMs
            true
        } catch (_: Exception) {
            false
        }
    }
}
