package com.example.reviewlinkgenerator.nfc.inspector

import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.nfc.tech.MifareUltralight

data class ChipProfile(
    val manufacturer: String,
    val chipName: String,
    val totalBytes: Int? = null,
    val pageCount: Int? = null,
    val pageSize: Int? = null,
    val sectorCount: Int? = null,
    val blockCount: Int? = null,
    val auth0Page: Int? = null,
    val accessPage: Int? = null,
    val supportsReadSig: Boolean = false
)

object NfcChipCatalog {

    private val MANUFACTURER_MAP = mapOf(
        0x01 to "Motorola",
        0x02 to "STMicroelectronics",
        0x03 to "Hitachi",
        0x04 to "NXP",
        0x05 to "Infineon",
        0x06 to "Cylink",
        0x07 to "Texas Instruments",
        0x08 to "Fujitsu",
        0x09 to "Matsushita",
        0x0A to "NEC",
        0x0B to "Oki Electric",
        0x0C to "Toshiba",
        0x0D to "Mitsubishi",
        0x0E to "Samsung",
        0x0F to "Hynix",
        0x10 to "LG",
        0x16 to "EM Microelectronic",
        0x1D to "Fudan Microelectronics",
        0x2B to "Broadcom",
        0x33 to "Sony",
        0x48 to "AMS",
        0x7A to "HuaHong"
    )

    fun lookupManufacturerByUid(uid: ByteArray): String {
        if (uid.isEmpty()) return ""
        val code = uid[0].toInt() and 0xFF
        return MANUFACTURER_MAP[code] ?: ""
    }

    fun lookupIso15693ManufacturerByUid(uid: ByteArray): String {
        // ISO 15693 UID (when reversed/little-endian in Android NfcV tag.id) has E0 at last byte, manufacturer at index 6
        if (uid.size >= 8 && (uid[7].toInt() and 0xFF) == 0xE0) {
            val code = uid[6].toInt() and 0xFF
            return MANUFACTURER_MAP[code] ?: ""
        }
        return lookupManufacturerByUid(uid)
    }

    /**
     * Parses NXP GET_VERSION (0x60) 8-byte response from NfcA tags (NTAG, Ultralight EV1/AES/Nano).
     */
    fun identifyFromNxpGetVersion(ver: ByteArray): ChipProfile? {
        if (ver.size < 8) return null
        val vendorId = ver[1].toInt() and 0xFF
        if (vendorId != 0x04) return null

        val prodType = ver[2].toInt() and 0xFF
        val prodSubtype = ver[3].toInt() and 0xFF
        val majorVer = ver[4].toInt() and 0xFF
        val storageSize = ver[6].toInt() and 0xFF
        val protocolType = ver[7].toInt() and 0xFF

        return identifyNxpFields(prodType, prodSubtype, majorVer, storageSize, protocolType)
    }

    /**
     * Parses NXP IsoDep wrapped GET_VERSION (90 60 00 00 00) 7-byte hardware info frame.
     */
    fun identifyFromIsoDepGetVersion(hwInfo: ByteArray): ChipProfile? {
        if (hwInfo.size < 7) return null
        val vendorId = hwInfo[0].toInt() and 0xFF
        if (vendorId != 0x04) return null

        val prodType = hwInfo[1].toInt() and 0xFF
        val prodSubtype = hwInfo[2].toInt() and 0xFF
        val majorVer = hwInfo[3].toInt() and 0xFF
        val storageSize = hwInfo[5].toInt() and 0xFF
        val protocolType = hwInfo[6].toInt() and 0xFF

        return identifyNxpFields(prodType, prodSubtype, majorVer, storageSize, protocolType)
    }

    private fun identifyNxpFields(
        prodType: Int,
        prodSubtype: Int,
        majorVer: Int,
        storageSize: Int,
        protocolType: Int
    ): ChipProfile? {
        return when (prodType) {
            0x04 -> when (storageSize) {
                0x0B -> ChipProfile("NXP", "NTAG210", 80, 20, 4, supportsReadSig = true)
                0x0E -> ChipProfile("NXP", "NTAG212", 164, 41, 4, supportsReadSig = true)
                0x0F -> {
                    val name = when (prodSubtype) {
                        0x04 -> "NTAG213F"
                        0x05 -> "NTAG213 TT"
                        else -> "NTAG213"
                    }
                    ChipProfile("NXP", name, 180, 45, 4, auth0Page = 41, accessPage = 42, supportsReadSig = true)
                }
                0x11 -> {
                    if (protocolType == 0x05) {
                        ChipProfile("NXP", "NTAG 424 DNA", 416)
                    } else {
                        ChipProfile("NXP", "NTAG215", 540, 135, 4, auth0Page = 131, accessPage = 132, supportsReadSig = true)
                    }
                }
                0x13 -> when (prodSubtype) {
                    0x05 -> ChipProfile("NXP", "NTAG I2C 1k", 1024, 256, 4, supportsReadSig = true)
                    0x04 -> ChipProfile("NXP", "NTAG216F", 924, 231, 4, auth0Page = 227, accessPage = 228, supportsReadSig = true)
                    else -> ChipProfile("NXP", "NTAG216", 924, 231, 4, auth0Page = 227, accessPage = 228, supportsReadSig = true)
                }
                0x15 -> ChipProfile("NXP", "NTAG I2C 2k", 2048, 512, 4, supportsReadSig = true)
                else -> ChipProfile("NXP", "NTAG Series")
            }

            0x03 -> when (storageSize) {
                0x0B -> {
                    if (majorVer == 0x02) {
                        ChipProfile("NXP", "MIFARE Ultralight Nano", 64, 16, 4)
                    } else {
                        ChipProfile(
                            "NXP",
                            "MIFARE Ultralight EV1 (MF0UL11)",
                            80,
                            20,
                            4,
                            auth0Page = 16,
                            accessPage = 17,
                            supportsReadSig = true
                        )
                    }
                }
                0x0E -> ChipProfile(
                    "NXP",
                    "MIFARE Ultralight EV1 (MF0UL21)",
                    164,
                    41,
                    4,
                    auth0Page = 37,
                    accessPage = 38,
                    supportsReadSig = true
                )
                0x0F -> ChipProfile("NXP", "MIFARE Ultralight AES", 224, 56, 4, supportsReadSig = true)
                else -> ChipProfile("NXP", "MIFARE Ultralight")
            }

            0x01 -> {
                val evLabel = when (majorVer) {
                    0x01 -> "EV1"
                    0x12 -> "EV2"
                    0x33 -> "EV3"
                    else -> ""
                }
                val sizeLabel = when (storageSize) {
                    0x16 -> Pair("2K", 2048)
                    0x18 -> Pair("4K", 4096)
                    0x1A -> Pair("8K", 8192)
                    0x1C -> Pair("16K", 16384)
                    0x1E -> Pair("32K", 32768)
                    else -> Pair("", null)
                }
                val parts = listOf("MIFARE DESFire", evLabel, sizeLabel.first).filter { it.isNotEmpty() }
                ChipProfile("NXP", parts.joinToString(" "), totalBytes = sizeLabel.second)
            }

            else -> null
        }
    }

    fun identifyFallback(
        tag: Tag,
        techNames: List<String>,
        atqaInt: Int?,
        sakInt: Int?,
        ndefMaxSize: Int?,
        nfcvBlockCount: Int? = null,
        nfcvBlockSize: Int? = null
    ): ChipProfile {
        val uid = tag.id ?: ByteArray(0)
        val uidMfr = if (techNames.contains("NfcV")) {
            lookupIso15693ManufacturerByUid(uid)
        } else {
            lookupManufacturerByUid(uid)
        }

        // Topaz / Jewel (Type 1)
        if (atqaInt == 0x0C00) {
            return ChipProfile(uidMfr, "Topaz / Jewel (Type 1)", totalBytes = 120, blockCount = 15)
        }

        // MIFARE Classic
        if (techNames.contains("MifareClassic")) {
            val mc = try {
                MifareClassic.get(tag)
            } catch (_: Exception) {
                null
            }
            if (mc != null) {
                val isPlus = sakInt == 0x10 || sakInt == 0x11 || sakInt == 0x20 || mc.type == MifareClassic.TYPE_PLUS
                val sizeLabel = when (mc.size) {
                    MifareClassic.SIZE_MINI -> "Mini"
                    MifareClassic.SIZE_1K -> "1K"
                    MifareClassic.SIZE_2K -> "2K"
                    MifareClassic.SIZE_4K -> "4K"
                    else -> "${mc.size}B"
                }
                val chipName = if (isPlus) {
                    "MIFARE Plus $sizeLabel"
                } else {
                    "MIFARE Classic $sizeLabel"
                }
                return ChipProfile(
                    manufacturer = uidMfr.ifEmpty { "NXP" },
                    chipName = chipName,
                    totalBytes = mc.size,
                    sectorCount = mc.sectorCount,
                    blockCount = mc.blockCount
                )
            }
        }

        // MIFARE Ultralight fallback (when GET_VERSION failed or is unsupported)
        if (techNames.contains("MifareUltralight")) {
            val ul = try {
                MifareUltralight.get(tag)
            } catch (_: Exception) {
                null
            }
            return if (ul?.type == MifareUltralight.TYPE_ULTRALIGHT_C) {
                ChipProfile(uidMfr.ifEmpty { "NXP" }, "Mifare Ultralight C (Ultralight C)")
            } else {
                ChipProfile(uidMfr.ifEmpty { "NXP" }, "Mifare Ultralight (Ultralight)")
            }
        }

        // IsoDep (ISO 14443-4 Bank / ID / Transit / Smart Cards)
        if (techNames.contains("IsoDep")) {
            return when {
                sakInt == 0x20 && atqaInt == 0x0044 -> ChipProfile("NXP", "Mifare Plus")
                sakInt == 0x20 && atqaInt == 0x0344 -> ChipProfile("NXP", "Mifare DESFire")
                sakInt == 0x20 && atqaInt == 0x0004 -> ChipProfile("NXP", "SmartMX / Mifare Plus")
                sakInt == 0x28 -> ChipProfile("NXP", "JCOP / SmartMX (Mifare 1K)")
                sakInt == 0x38 -> ChipProfile("NXP", "JCOP / SmartMX (Mifare 4K)")
                else -> ChipProfile(uidMfr, "ISO 14443-4 Smart Card")
            }
        }

        // NfcV (ISO 15693)
        if (techNames.contains("NfcV")) {
            val totalBytes = if (nfcvBlockCount != null && nfcvBlockSize != null) {
                nfcvBlockCount * nfcvBlockSize
            } else {
                null
            }
            val chipName = when {
                uid.size >= 8 && (uid[6].toInt() and 0xFF) == 0x04 -> when (totalBytes) {
                    112 -> "ICODE SLIX"
                    320 -> "ICODE SLIX2"
                    else -> "ICODE SLI / SLIX"
                }
                uid.size >= 8 && (uid[6].toInt() and 0xFF) == 0x02 -> "ST25TV (ISO 15693)"
                uid.size >= 8 && (uid[6].toInt() and 0xFF) == 0x07 -> "Tag-it HF-I"
                else -> "ISO 15693 Tag"
            }
            return ChipProfile(
                manufacturer = uidMfr,
                chipName = chipName,
                totalBytes = totalBytes,
                blockCount = nfcvBlockCount,
                pageSize = nfcvBlockSize
            )
        }

        // NfcF (FeliCa)
        if (techNames.contains("NfcF")) {
            return ChipProfile("Sony", "FeliCa / FeliCa Lite-S")
        }

        // NfcB
        if (techNames.contains("NfcB")) {
            return ChipProfile(uidMfr, "ISO 14443-3B Tag")
        }

        // NfcA generic SAK lookup
        if (techNames.contains("NfcA")) {
            val genericName = when (sakInt) {
                0x00 -> "Ultralight / NTAG Type 2"
                0x08 -> "MIFARE Classic 1K Compatible"
                0x09 -> "MIFARE Mini Compatible"
                0x18 -> "MIFARE Classic 4K Compatible"
                else -> "ISO 14443-3A Tag"
            }
            return ChipProfile(uidMfr, genericName)
        }

        return ChipProfile(uidMfr, "Unknown NFC Tag")
    }

    fun formatDataFormat(ndefType: String?, isFormatable: Boolean): String {
        return when (ndefType) {
            "org.nfcforum.ndef.type1" -> "NFC Forum Type 1"
            "org.nfcforum.ndef.type2" -> "NFC Forum Type 2"
            "org.nfcforum.ndef.type3" -> "NFC Forum Type 3"
            "org.nfcforum.ndef.type4" -> "NFC Forum Type 4"
            "org.nfcforum.ndef.type5" -> "NFC Forum Type 5"
            "com.nxp.ndef.mifareclassic" -> "MIFARE Classic"
            null -> if (isFormatable) "NDEF Formatable" else "Not NDEF formatted"
            else -> ndefType
        }
    }

    fun resolveIsoStandard(techNames: List<String>): String {
        return when {
            techNames.contains("IsoDep") -> "ISO 14443-4"
            techNames.contains("NfcA") -> "ISO 14443-3A"
            techNames.contains("NfcB") -> "ISO 14443-3B"
            techNames.contains("NfcV") -> "ISO 15693"
            techNames.contains("NfcF") -> "JIS X 6319-4 (FeliCa)"
            else -> "Unknown"
        }
    }
}
