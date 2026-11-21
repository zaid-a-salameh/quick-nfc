package com.example.reviewlinkgenerator.nfc.locker

import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.Ndef
import android.nfc.tech.NfcA
import com.example.reviewlinkgenerator.nfc.NfcTagCapabilities
import com.example.reviewlinkgenerator.nfc.Ntag21xProfile
import com.example.reviewlinkgenerator.nfc.NtagPasswordState
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

sealed class PermLockResult {
    data object Success : PermLockResult()
    data class Error(val code: String) : PermLockResult()
}

/**
 * Performs safe permanent read-only locking.
 *
 * Uses pre-flight password/CC validation and direct silicon page writes only on
 * hardware-confirmed NXP NTAG213/215/216 tags to avoid Android libnfc-nci
 * RW_T2tSetTagReadOnly deadlocks, and guards non-NTAG fallback calls with a
 * hard close watchdog timeout.
 */
object NfcPermanentLocker {

    private const val NFCA_TIMEOUT_MS = 2000
    private const val FALLBACK_WATCHDOG_TIMEOUT_MS = 3500L

    fun lockPermanently(tag: Tag): PermLockResult {
        val ndef = Ndef.get(tag) ?: return PermLockResult.Error("UNSUPPORTED")

        var isWritable = false
        var canMakeReadOnly = false
        try {
            ndef.connect()
            isWritable = ndef.isWritable
            canMakeReadOnly = try {
                ndef.canMakeReadOnly()
            } catch (_: Exception) {
                false
            }
        } catch (e: Exception) {
            return if (NfcTagCapabilities.isTagLost(e)) {
                PermLockResult.Error("TAG_LOST")
            } else {
                PermLockResult.Error("LOCK_FAILED")
            }
        } finally {
            try {
                ndef.close()
            } catch (_: Exception) {
            }
        }

        if (!isWritable) {
            return PermLockResult.Error("CANNOT_LOCK")
        }

        // Direct silicon lock only for pure Type-2 NfcA tags confirmed via GET_VERSION
        if (NfcTagCapabilities.isType2NfcACandidate(tag)) {
            val nfca = NfcA.get(tag)
            if (nfca != null) {
                val directResult = tryDirectNtagLock(nfca)
                if (directResult != null) {
                    return directResult
                }
            }
        }

        // Watchdog-guarded fallback for IsoDep / Classic / non-confirmed NDEF tags
        if (!canMakeReadOnly) {
            return PermLockResult.Error("CANNOT_LOCK")
        }

        return executeWatchdogMakeReadOnly(ndef)
    }

    private fun tryDirectNtagLock(nfca: NfcA): PermLockResult? {
        try {
            nfca.connect()
            nfca.timeout = NFCA_TIMEOUT_MS

            val profile = NfcTagCapabilities.probeConfirmedNtag21x(
                nfca = nfca,
                timeoutMs = NFCA_TIMEOUT_MS,
                rethrowTagLost = true
            ) ?: return null

            // Pre-flight A: Check AUTH0 password protection
            val pwdState = checkAuth0Protected(nfca, profile)
            if (pwdState != null) {
                return PermLockResult.Error(pwdState)
            }

            // Pre-flight B: Read Capability Container (Page 03)
            val cc = readPageSafe(nfca, 0x03) ?: return PermLockResult.Error("LOCK_FAILED")
            if (cc.size < 4) return PermLockResult.Error("LOCK_FAILED")
            if ((cc[3].toInt() and 0x0F) == 0x0F) {
                return PermLockResult.Error("CANNOT_LOCK")
            }

            // Pre-flight C: Read Static Lock Page (Page 02) to preserve manufacturing bytes
            val p2 = readPageSafe(nfca, 0x02) ?: return PermLockResult.Error("LOCK_FAILED")
            if (p2.size < 4) return PermLockResult.Error("LOCK_FAILED")
            val p2b0 = p2[0]
            val p2b1 = p2[1]

            // Step A: Write Dynamic Lock Page (RFUI bits cleared to 0, Byte 3 = 0x00)
            if (!writePageSafe(
                    nfca,
                    profile.dynamicLockPage,
                    profile.dynB0,
                    profile.dynB1,
                    profile.dynB2,
                    0x00
                )
            ) {
                return PermLockResult.Error("LOCK_FAILED")
            }

            // Step B: Set CC access nibble in Page 03 to permanent read-only (0x0F)
            if (!writePageSafe(
                    nfca,
                    0x03,
                    cc[0],
                    cc[1],
                    cc[2],
                    (cc[3].toInt() or 0x0F).toByte()
                )
            ) {
                return PermLockResult.Error("LOCK_FAILED")
            }

            // Step C: Lock static pages via Page 02 bytes 2..3 = 0xFF 0xFF
            if (!writePageSafe(
                    nfca,
                    0x02,
                    p2b0,
                    p2b1,
                    0xFF.toByte(),
                    0xFF.toByte()
                )
            ) {
                return PermLockResult.Error("LOCK_FAILED")
            }

            // Step D: Verify Capability Container read-back reflects read-only
            val verifyCc = readPageSafe(nfca, 0x03) ?: return PermLockResult.Error("LOCK_FAILED")
            return if (verifyCc.size >= 4 && (verifyCc[3].toInt() and 0x0F) == 0x0F) {
                PermLockResult.Success
            } else {
                PermLockResult.Error("LOCK_FAILED")
            }
        } catch (e: Exception) {
            return if (NfcTagCapabilities.isTagLost(e)) {
                PermLockResult.Error("TAG_LOST")
            } else {
                PermLockResult.Error("LOCK_FAILED")
            }
        } finally {
            try {
                nfca.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun checkAuth0Protected(nfca: NfcA, profile: Ntag21xProfile): String? {
        return when (
            NfcTagCapabilities.probeAuth0ProtectionState(
                nfca = nfca,
                profile = profile,
                timeoutMs = NFCA_TIMEOUT_MS,
                rethrowTagLost = true
            )
        ) {
            NtagPasswordState.PROTECTED -> "LOCKED"
            NtagPasswordState.UNPROTECTED -> null
            NtagPasswordState.INDETERMINATE -> "LOCK_FAILED"
        }
    }

    private fun readPageSafe(nfca: NfcA, page: Int): ByteArray? {
        return try {
            nfca.transceive(byteArrayOf(0x30.toByte(), page.toByte()))
        } catch (e: TagLostException) {
            throw e
        } catch (e: Exception) {
            if (NfcTagCapabilities.isTagLost(e)) throw e
            null
        }
    }

    private fun writePageSafe(
        nfca: NfcA,
        page: Int,
        b0: Byte,
        b1: Byte,
        b2: Byte,
        b3: Byte
    ): Boolean {
        return try {
            val cmd = byteArrayOf(0xA2.toByte(), page.toByte(), b0, b1, b2, b3)
            val resp = nfca.transceive(cmd)
            resp != null && (resp.isEmpty() || (resp[0].toInt() and 0x0F) == 0x0A)
        } catch (e: TagLostException) {
            throw e
        } catch (e: Exception) {
            if (NfcTagCapabilities.isTagLost(e)) throw e
            false
        }
    }

    private fun executeWatchdogMakeReadOnly(ndef: Ndef): PermLockResult {
        val timedOut = AtomicBoolean(false)
        val watchdog = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "QuickNfc-LockWatchdog").apply { isDaemon = true }
        }
        var watchdogFuture: ScheduledFuture<*>? = null

        return try {
            watchdogFuture = watchdog.schedule(
                {
                    timedOut.set(true)
                    try {
                        ndef.close()
                    } catch (_: Exception) {
                    }
                },
                FALLBACK_WATCHDOG_TIMEOUT_MS,
                TimeUnit.MILLISECONDS
            )

            ndef.connect()
            val success = ndef.makeReadOnly()
            watchdogFuture.cancel(false)

            when {
                timedOut.get() -> PermLockResult.Error("LOCK_FAILED")
                success -> PermLockResult.Success
                else -> PermLockResult.Error("LOCK_FAILED")
            }
        } catch (e: Exception) {
            if (timedOut.get()) {
                PermLockResult.Error("LOCK_FAILED")
            } else if (NfcTagCapabilities.isTagLost(e)) {
                PermLockResult.Error("TAG_LOST")
            } else {
                PermLockResult.Error("LOCK_FAILED")
            }
        } finally {
            try {
                watchdogFuture?.cancel(true)
            } catch (_: Exception) {
            }
            try {
                watchdog.shutdownNow()
            } catch (_: Exception) {
            }
            try {
                ndef.close()
            } catch (_: Exception) {
            }
        }
    }
}
