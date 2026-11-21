package com.example.reviewlinkgenerator.nfc.inspector

import android.nfc.NdefMessage
import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.IsoDep
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.nfc.tech.NfcA
import android.nfc.tech.NfcB
import android.nfc.tech.NfcF
import android.nfc.tech.NfcV

object NfcTagInspector {

    private const val TECH_TIMEOUT_MS = 2500

    fun inspect(tag: Tag): Map<String, Any?> {
        val techNames = tag.techList.map { it.substringAfterLast('.') }
        val uid = tag.id ?: ByteArray(0)
        val serialNumber = uid.joinToString(":") { String.format("%02X", it.toInt() and 0xFF) }
        val isoStandard = NfcChipCatalog.resolveIsoStandard(techNames)
        val extraRfInfo = linkedMapOf<String, String>()

        // 1. Extract passive NDEF metadata first, then attempt a best-effort live read
        var ndefType: String? = null
        var maxBytes: Int? = null
        var usedBytes: Int? = null
        var isWritable: Boolean? = null
        var canMakeReadOnly: Boolean? = null
        var ndefMessage: NdefMessage? = null
        val isFormatable = NdefFormatable.get(tag) != null

        val ndef = Ndef.get(tag)
        if (ndef != null) {
            ndefType = ndef.type
            maxBytes = ndef.maxSize.takeIf { it > 0 }
            isWritable = ndef.isWritable
            canMakeReadOnly = try {
                ndef.canMakeReadOnly()
            } catch (_: Exception) {
                null
            }
            ndefMessage = try {
                ndef.cachedNdefMessage
            } catch (_: Exception) {
                null
            }

            try {
                ndef.connect()
                maxBytes = ndef.maxSize.takeIf { it > 0 } ?: maxBytes
                isWritable = ndef.isWritable
                canMakeReadOnly = try {
                    ndef.canMakeReadOnly()
                } catch (_: Exception) {
                    canMakeReadOnly
                }
                ndefMessage = try {
                    ndef.ndefMessage ?: ndefMessage
                } catch (_: Exception) {
                    ndefMessage
                }
            } catch (_: Exception) {
                // Best-effort live NDEF read; fall back to cached/passive properties
            } finally {
                try {
                    ndef.close()
                } catch (_: Exception) {
                }
            }

            if (ndefMessage != null) {
                usedBytes = ndefMessage.byteArrayLength
            } else if (maxBytes != null) {
                usedBytes = 0
            }
        }

        // 2. Collect NfcA metadata and run Type-2 low-level probes only on non-IsoDep/Classic tags
        var atqaStr: String? = null
        var sakStr: String? = null
        var atqaInt: Int? = null
        var sakInt: Int? = null

        var profile: ChipProfile? = null
        var signatureStatus = "NOT_SUPPORTED"
        var signatureHex: String? = null
        var passwordStatus = "UNKNOWN"

        val nfca = NfcA.get(tag)
        if (nfca != null) {
            val rawAtqa = nfca.atqa
            if (rawAtqa != null && rawAtqa.size >= 2) {
                val bHigh = rawAtqa[1].toInt() and 0xFF
                val bLow = rawAtqa[0].toInt() and 0xFF
                atqaInt = (bHigh shl 8) or bLow
                atqaStr = String.format("0x%02X%02X", bHigh, bLow)
            }
            sakInt = nfca.sak.toInt() and 0xFF
            sakStr = String.format("0x%02X", sakInt)

            if (!techNames.contains("MifareClassic") && !techNames.contains("IsoDep")) {
                try {
                    nfca.connect()
                    nfca.timeout = TECH_TIMEOUT_MS

                    // Probe 1: NXP GET_VERSION (0x60)
                    val verResp = transceiveRecoverOnNack(nfca, byteArrayOf(0x60.toByte()))
                    if (verResp != null && verResp.size >= 8) {
                        profile = NfcChipCatalog.identifyFromNxpGetVersion(verResp)
                    }

                    // Probe 2: NXP READ_SIG (0x3C, 0x00) — only when GET_VERSION confirmed EV1/NTAG
                    if (profile?.supportsReadSig == true) {
                        val sigResp = transceiveRecoverOnNack(nfca, byteArrayOf(0x3C.toByte(), 0x00.toByte()))
                        if (sigResp != null && sigResp.size >= 32) {
                            val sigBytes = sigResp.copyOfRange(0, 32)
                            signatureHex = sigBytes.joinToString(":") {
                                String.format("%02X", it.toInt() and 0xFF)
                            }
                            signatureStatus = if (NxpSignatureVerifier.verifyNxpOriginalitySignature(uid, sigBytes)) {
                                "VALID"
                            } else {
                                "INVALID"
                            }
                        } else {
                            signatureStatus = "NOT_SUPPORTED"
                        }
                    }

                    // Probe 3: NTAG / Ultralight EV1 Password Protection (AUTH0)
                    val confirmedProfile = profile
                    val auth0Page = confirmedProfile?.auth0Page
                    if (auth0Page != null) {
                        passwordStatus = probeAuth0PasswordStatus(
                            nfca = nfca,
                            auth0Page = auth0Page,
                            pageCount = confirmedProfile.pageCount
                        )
                    }
                } catch (_: Exception) {
                    // Best-effort low-level probing; preserve passive metadata on NACK or link drop
                } finally {
                    try {
                        nfca.close()
                    } catch (_: Exception) {
                    }
                }
            }
        }

        // 3. IsoDep passive metadata + best-effort DESFire GET_VERSION probe
        val isoDep = IsoDep.get(tag)
        if (isoDep != null) {
            isoDep.historicalBytes?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["ATS"] = formatHexPrefixed(it)
            }
            isoDep.hiLayerResponse?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["Hi-Layer Response"] = formatHexPrefixed(it)
            }
            if (profile == null) {
                try {
                    isoDep.connect()
                    isoDep.timeout = TECH_TIMEOUT_MS
                    val wrappedResp = try {
                        isoDep.transceive(byteArrayOf(0x90.toByte(), 0x60.toByte(), 0x00, 0x00, 0x00))
                    } catch (_: Exception) {
                        null
                    }
                    if (wrappedResp != null && wrappedResp.size >= 9) {
                        val sw1 = wrappedResp[wrappedResp.size - 2].toInt() and 0xFF
                        val sw2 = wrappedResp[wrappedResp.size - 1].toInt() and 0xFF
                        if (sw1 == 0x91 && (sw2 == 0xAF || sw2 == 0x00)) {
                            profile = NfcChipCatalog.identifyFromIsoDepGetVersion(
                                wrappedResp.copyOfRange(0, wrappedResp.size - 2)
                            )
                        }
                    }
                } catch (_: Exception) {
                    // Best-effort IsoDep probe; EMV/Bank/ID cards often reject non-EMV APDUs
                } finally {
                    try {
                        isoDep.close()
                    } catch (_: Exception) {
                    }
                }
            }
        }

        // 4. NfcB passive metadata
        val nfcb = NfcB.get(tag)
        if (nfcb != null) {
            nfcb.applicationData?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["Application Data"] = formatHexPrefixed(it)
            }
            nfcb.protocolInfo?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["Protocol Info"] = formatHexPrefixed(it)
            }
        }

        // 5. NfcF passive metadata
        val nfcf = NfcF.get(tag)
        if (nfcf != null) {
            nfcf.manufacturer?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["PMm / Manufacturer"] = formatHexPrefixed(it)
            }
            nfcf.systemCode?.takeIf { it.isNotEmpty() }?.let {
                extraRfInfo["System Code"] = formatHexPrefixed(it)
            }
        }

        // 6. NfcV (ISO 15693) passive metadata + best-effort GET SYSTEM INFORMATION
        var nfcvBlockCount: Int? = null
        var nfcvBlockSize: Int? = null
        val nfcv = NfcV.get(tag)
        if (nfcv != null) {
            extraRfInfo["DSFID"] = String.format("0x%02X", nfcv.dsfId.toInt() and 0xFF)
            extraRfInfo["Response Flags"] = String.format("0x%02X", nfcv.responseFlags.toInt() and 0xFF)
            try {
                nfcv.connect()
                val sysInfo = try {
                    nfcv.transceive(byteArrayOf(0x02.toByte(), 0x2B.toByte()))
                } catch (_: TagLostException) {
                    null
                } catch (_: Exception) {
                    val addressed = ByteArray(10)
                    addressed[0] = 0x22.toByte()
                    addressed[1] = 0x2B.toByte()
                    if (uid.size >= 8) {
                        System.arraycopy(uid, 0, addressed, 2, 8)
                        try {
                            nfcv.transceive(addressed)
                        } catch (_: Exception) {
                            null
                        }
                    } else {
                        null
                    }
                }
                if (sysInfo != null && sysInfo.size >= 12 && (sysInfo[0].toInt() and 0x01) == 0) {
                    val infoFlags = sysInfo[1].toInt() and 0xFF
                    var offset = 10 // flags(1) + infoFlags(1) + UID(8)
                    if ((infoFlags and 0x01) != 0) offset++ // DSFID
                    if ((infoFlags and 0x02) != 0) offset++ // AFI
                    if ((infoFlags and 0x04) != 0 && offset + 1 < sysInfo.size) {
                        nfcvBlockCount = (sysInfo[offset].toInt() and 0xFF) + 1
                        nfcvBlockSize = (sysInfo[offset + 1].toInt() and 0x1F) + 1
                    }
                }
            } catch (_: Exception) {
            } finally {
                try {
                    nfcv.close()
                } catch (_: Exception) {
                }
            }
        }

        // 7. Resolve final ChipProfile
        val finalProfile = profile ?: NfcChipCatalog.identifyFallback(
            tag = tag,
            techNames = techNames,
            atqaInt = atqaInt,
            sakInt = sakInt,
            ndefMaxSize = maxBytes,
            nfcvBlockCount = nfcvBlockCount,
            nfcvBlockSize = nfcvBlockSize
        )

        val mfr = finalProfile.manufacturer.trim()
        val chip = finalProfile.chipName.trim()
        val tagTypeLabel = if (mfr.isNotEmpty() && !chip.startsWith(mfr, ignoreCase = true)) {
            "$mfr - $chip"
        } else {
            chip
        }

        val dataFormat = NfcChipCatalog.formatDataFormat(ndefType, isFormatable)
        val parsedRecords = NdefRecordParser.parseMessage(ndefMessage)

        return mapOf(
            "event" to "tag_inspected",
            "isoStandard" to isoStandard,
            "manufacturer" to mfr,
            "chipModel" to chip,
            "tagTypeLabel" to tagTypeLabel,
            "technologies" to techNames,
            "serialNumber" to serialNumber,
            "atqa" to atqaStr,
            "sak" to sakStr,
            "extraRfInfo" to extraRfInfo,
            "signatureStatus" to signatureStatus,
            "signatureHex" to signatureHex,
            "passwordStatus" to passwordStatus,
            "memoryTotalBytes" to finalProfile.totalBytes,
            "memoryPageCount" to finalProfile.pageCount,
            "memoryPageSize" to finalProfile.pageSize,
            "memorySectorCount" to finalProfile.sectorCount,
            "memoryBlockCount" to finalProfile.blockCount,
            "dataFormat" to dataFormat,
            "usedBytes" to usedBytes,
            "maxBytes" to maxBytes,
            "isWritable" to isWritable,
            "canMakeReadOnly" to canMakeReadOnly,
            "records" to parsedRecords
        )
    }

    private fun transceiveRecoverOnNack(nfca: NfcA, command: ByteArray): ByteArray? {
        return try {
            nfca.transceive(command)
        } catch (_: TagLostException) {
            null
        } catch (_: Exception) {
            reconnectNfcA(nfca)
            null
        }
    }

    private fun reconnectNfcA(nfca: NfcA): Boolean {
        try {
            nfca.close()
        } catch (_: Exception) {
        }
        return try {
            nfca.connect()
            nfca.timeout = TECH_TIMEOUT_MS
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun probeAuth0PasswordStatus(
        nfca: NfcA,
        auth0Page: Int,
        pageCount: Int?
    ): String {
        return try {
            val resp = nfca.transceive(byteArrayOf(0x30.toByte(), auth0Page.toByte()))
            if (resp != null && resp.size >= 4) {
                val auth0 = resp[3].toInt() and 0xFF
                val limit = pageCount ?: 0xFF
                if (auth0 != 0xFF && auth0 < limit) "YES" else "NO"
            } else {
                "UNKNOWN"
            }
        } catch (_: TagLostException) {
            "UNKNOWN"
        } catch (_: Exception) {
            // Reconnect and check if page 0 is readable while config page failed (indicates read-protection)
            try {
                if (!reconnectNfcA(nfca)) return "UNKNOWN"
                val p0 = nfca.transceive(byteArrayOf(0x30.toByte(), 0x00.toByte()))
                if (p0 != null && p0.size >= 4) "YES" else "UNKNOWN"
            } catch (_: Exception) {
                "UNKNOWN"
            }
        }
    }

    private fun formatHexPrefixed(bytes: ByteArray): String {
        return "0x" + bytes.joinToString("") { String.format("%02X", it.toInt() and 0xFF) }
    }
}
