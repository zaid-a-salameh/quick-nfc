package com.example.reviewlinkgenerator.nfc.inspector

import android.nfc.NdefMessage
import android.nfc.NdefRecord
import java.nio.charset.Charset

object NdefRecordParser {

    private val URI_PREFIX_TABLE = arrayOf(
        "",                           // 0x00
        "http://www.",                // 0x01
        "https://www.",               // 0x02
        "http://",                    // 0x03
        "https://",                   // 0x04
        "tel:",                       // 0x05
        "mailto:",                    // 0x06
        "ftp://anonymous:anonymous@", // 0x07
        "ftp://ftp.",                 // 0x08
        "ftps://",                    // 0x09
        "sftp://",                    // 0x0A
        "smb://",                     // 0x0B
        "nfs://",                     // 0x0C
        "ftp://",                     // 0x0D
        "dav://",                     // 0x0E
        "news:",                      // 0x0F
        "telnet://",                  // 0x10
        "imap:",                      // 0x11
        "rtsp://",                    // 0x12
        "urn:",                       // 0x13
        "pop:",                       // 0x14
        "sip:",                       // 0x15
        "sips:",                      // 0x16
        "tftp:",                      // 0x17
        "btspp://",                   // 0x18
        "btl2cap://",                 // 0x19
        "btgoep://",                  // 0x1A
        "tcpobex://",                 // 0x1B
        "irdaobex://",                // 0x1C
        "file://",                    // 0x1D
        "urn:epc:id:",                // 0x1E
        "urn:epc:tag:",               // 0x1F
        "urn:epc:pat:",               // 0x20
        "urn:epc:raw:",               // 0x21
        "urn:epc:",                   // 0x22
        "urn:nfc:"                    // 0x23
    )

    private const val MAX_HEX_DISPLAY_BYTES = 1024

    fun parseMessage(message: NdefMessage?): List<Map<String, Any?>> {
        if (message == null || message.records.isEmpty()) return emptyList()
        return message.records.mapIndexed { idx, record ->
            parseSingleRecord(idx + 1, record)
        }
    }

    private fun parseSingleRecord(index: Int, record: NdefRecord): Map<String, Any?> {
        val payload = record.payload ?: ByteArray(0)
        val payloadHex = formatHex(payload)
        val tnfName = tnfLabel(record.tnf)
        val typeStr = try {
            String(record.type, Charsets.US_ASCII)
        } catch (_: Exception) {
            ""
        }
        val mimeType = try {
            record.toMimeType()
        } catch (_: Exception) {
            null
        }

        // 1. Empty record
        if (record.tnf == NdefRecord.TNF_EMPTY) {
            return buildRecordMap(
                index = index,
                tnf = tnfName,
                kind = "EMPTY",
                typeLabel = "Empty",
                displayValue = "",
                fullValue = "",
                mimeType = mimeType,
                payloadHex = payloadHex,
                payloadSize = payload.size
            )
        }

        // 2. Well-Known RTD_URI
        if (record.tnf == NdefRecord.TNF_WELL_KNOWN && record.type.contentEquals(NdefRecord.RTD_URI)) {
            if (payload.isNotEmpty()) {
                val prefixCode = payload[0].toInt() and 0xFF
                val prefix = if (prefixCode < URI_PREFIX_TABLE.size) URI_PREFIX_TABLE[prefixCode] else ""
                val suffix = String(payload, 1, payload.size - 1, Charsets.UTF_8)
                val fullUri = prefix + suffix
                if (fullUri.startsWith("WIFI:", ignoreCase = true)) {
                    val wifi = parseWifiUriString(fullUri)
                    if (wifi != null) {
                        return buildRecordMap(
                            index = index,
                            tnf = tnfName,
                            kind = "WIFI",
                            typeLabel = "Wi-Fi",
                            displayValue = "${wifi.ssid} (${wifi.encType})",
                            fullValue = wifi.ssid,
                            mimeType = mimeType,
                            payloadHex = payloadHex,
                            payloadSize = payload.size,
                            wifiSsid = wifi.ssid,
                            wifiPassword = wifi.password,
                            wifiEncryption = wifi.encType
                        )
                    }
                }
                return buildRecordMap(
                    index = index,
                    tnf = tnfName,
                    kind = "URI",
                    typeLabel = prefix.ifEmpty { "URI" },
                    displayValue = if (prefix.isNotEmpty()) suffix else fullUri,
                    fullValue = fullUri,
                    mimeType = mimeType,
                    payloadHex = payloadHex,
                    payloadSize = payload.size
                )
            }
        }

        // 3. Absolute URI
        if (record.tnf == NdefRecord.TNF_ABSOLUTE_URI) {
            val fullUri = try {
                record.toUri()?.toString() ?: String(record.type, Charsets.UTF_8)
            } catch (_: Exception) {
                String(record.type, Charsets.UTF_8)
            }
            return buildRecordMap(
                index = index,
                tnf = tnfName,
                kind = "URI",
                typeLabel = "URI",
                displayValue = fullUri,
                fullValue = fullUri,
                mimeType = mimeType,
                payloadHex = payloadHex,
                payloadSize = payload.size
            )
        }

        // 4. Well-Known RTD_TEXT
        if (record.tnf == NdefRecord.TNF_WELL_KNOWN && record.type.contentEquals(NdefRecord.RTD_TEXT)) {
            if (payload.isNotEmpty()) {
                val status = payload[0].toInt() and 0xFF
                val isUtf16 = (status and 0x80) != 0
                val langLen = (status and 0x3F).coerceAtMost((payload.size - 1).coerceAtLeast(0))
                val langCode = if (langLen > 0) {
                    String(payload, 1, langLen, Charsets.US_ASCII)
                } else {
                    ""
                }
                val textStart = 1 + langLen
                val charset: Charset = if (isUtf16) Charsets.UTF_16 else Charsets.UTF_8
                val textValue = if (textStart <= payload.size) {
                    String(payload, textStart, payload.size - textStart, charset)
                } else {
                    ""
                }
                if (textValue.trimStart().startsWith("WIFI:", ignoreCase = true)) {
                    val wifi = parseWifiUriString(textValue.trim())
                    if (wifi != null) {
                        return buildRecordMap(
                            index = index,
                            tnf = tnfName,
                            kind = "WIFI",
                            typeLabel = "Wi-Fi",
                            displayValue = "${wifi.ssid} (${wifi.encType})",
                            fullValue = wifi.ssid,
                            languageCode = langCode.ifEmpty { null },
                            mimeType = mimeType,
                            payloadHex = payloadHex,
                            payloadSize = payload.size,
                            wifiSsid = wifi.ssid,
                            wifiPassword = wifi.password,
                            wifiEncryption = wifi.encType
                        )
                    }
                }
                return buildRecordMap(
                    index = index,
                    tnf = tnfName,
                    kind = "TEXT",
                    typeLabel = "Text",
                    displayValue = textValue,
                    fullValue = textValue,
                    languageCode = langCode.ifEmpty { null },
                    mimeType = mimeType,
                    payloadHex = payloadHex,
                    payloadSize = payload.size
                )
            }
        }

        // 5. Well-Known RTD_SMART_POSTER
        if (record.tnf == NdefRecord.TNF_WELL_KNOWN && record.type.contentEquals(NdefRecord.RTD_SMART_POSTER)) {
            try {
                val nested = NdefMessage(payload)
                val nestedRecords = parseMessage(nested)
                val uriRec = nestedRecords.firstOrNull { it["kind"] == "URI" }
                val titleRec = nestedRecords.firstOrNull { it["kind"] == "TEXT" }
                val uriVal = uriRec?.get("fullValue") as? String ?: ""
                val titleVal = titleRec?.get("fullValue") as? String ?: ""
                val display = listOf(titleVal, uriVal).filter { it.isNotEmpty() }.joinToString("\n")
                return buildRecordMap(
                    index = index,
                    tnf = tnfName,
                    kind = "URI",
                    typeLabel = "Smart Poster",
                    displayValue = display.ifEmpty { payloadHex },
                    fullValue = uriVal.ifEmpty { display },
                    mimeType = mimeType,
                    payloadHex = payloadHex,
                    payloadSize = payload.size
                )
            } catch (_: Exception) {
                // fall through
            }
        }

        // 6. Wi-Fi WSC MIME record
        if ("application/vnd.wfa.wsc".equals(mimeType, ignoreCase = true) ||
            "application/vnd.wfa.wsc".equals(typeStr, ignoreCase = true)
        ) {
            val wifi = parseWscPayload(payload)
            if (wifi != null) {
                return buildRecordMap(
                    index = index,
                    tnf = tnfName,
                    kind = "WIFI",
                    typeLabel = "Wi-Fi",
                    displayValue = "${wifi.ssid} (${wifi.encType})",
                    fullValue = wifi.ssid,
                    mimeType = mimeType ?: "application/vnd.wfa.wsc",
                    payloadHex = payloadHex,
                    payloadSize = payload.size,
                    wifiSsid = wifi.ssid,
                    wifiPassword = wifi.password,
                    wifiEncryption = wifi.encType
                )
            }
        }

        // 7. vCard MIME
        if ("text/vcard".equals(mimeType, ignoreCase = true) ||
            "text/x-vcard".equals(mimeType, ignoreCase = true)
        ) {
            val vcardText = String(payload, Charsets.UTF_8).trim()
            return buildRecordMap(
                index = index,
                tnf = tnfName,
                kind = "VCARD",
                typeLabel = "vCard",
                displayValue = vcardText,
                fullValue = vcardText,
                mimeType = mimeType,
                payloadHex = payloadHex,
                payloadSize = payload.size
            )
        }

        // 8. Android Application Record (AAR)
        if (record.tnf == NdefRecord.TNF_EXTERNAL_TYPE && "android.com:pkg".equals(typeStr, ignoreCase = true)) {
            val pkg = String(payload, Charsets.UTF_8).trim()
            return buildRecordMap(
                index = index,
                tnf = tnfName,
                kind = "AAR",
                typeLabel = "Android App",
                displayValue = pkg,
                fullValue = pkg,
                mimeType = mimeType,
                payloadHex = payloadHex,
                payloadSize = payload.size
            )
        }

        // 9. Generic MIME / External / Unknown
        val printableText = decodePrintableUtf8(payload)
        val kind = when (record.tnf) {
            NdefRecord.TNF_MIME_MEDIA -> "MIME"
            NdefRecord.TNF_EXTERNAL_TYPE -> "EXTERNAL"
            else -> "UNKNOWN"
        }
        val label = mimeType?.takeIf { it.isNotEmpty() }
            ?: typeStr.takeIf { it.isNotEmpty() }
            ?: tnfName

        return buildRecordMap(
            index = index,
            tnf = tnfName,
            kind = kind,
            typeLabel = label,
            displayValue = printableText ?: payloadHex,
            fullValue = printableText ?: payloadHex,
            mimeType = mimeType,
            payloadHex = payloadHex,
            payloadSize = payload.size
        )
    }

    private fun buildRecordMap(
        index: Int,
        tnf: String,
        kind: String,
        typeLabel: String,
        displayValue: String,
        fullValue: String,
        languageCode: String? = null,
        mimeType: String? = null,
        payloadHex: String,
        payloadSize: Int,
        wifiSsid: String? = null,
        wifiPassword: String? = null,
        wifiEncryption: String? = null
    ): Map<String, Any?> {
        return mapOf(
            "index" to index,
            "tnf" to tnf,
            "kind" to kind,
            "typeLabel" to typeLabel,
            "displayValue" to displayValue,
            "fullValue" to fullValue,
            "languageCode" to languageCode,
            "mimeType" to mimeType,
            "payloadHex" to payloadHex,
            "payloadSize" to payloadSize,
            "wifiSsid" to wifiSsid,
            "wifiPassword" to wifiPassword,
            "wifiEncryption" to wifiEncryption
        )
    }

    private fun tnfLabel(tnf: Short): String {
        return when (tnf) {
            NdefRecord.TNF_EMPTY -> "Empty"
            NdefRecord.TNF_WELL_KNOWN -> "Well Known"
            NdefRecord.TNF_MIME_MEDIA -> "MIME Media"
            NdefRecord.TNF_ABSOLUTE_URI -> "Absolute URI"
            NdefRecord.TNF_EXTERNAL_TYPE -> "External"
            NdefRecord.TNF_UNKNOWN -> "Unknown"
            NdefRecord.TNF_UNCHANGED -> "Unchanged"
            else -> "TNF $tnf"
        }
    }

    private fun formatHex(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        val limit = bytes.size.coerceAtMost(MAX_HEX_DISPLAY_BYTES)
        val sb = StringBuilder(limit * 3)
        for (i in 0 until limit) {
            if (i > 0) sb.append(':')
            sb.append(String.format("%02X", bytes[i].toInt() and 0xFF))
        }
        if (bytes.size > MAX_HEX_DISPLAY_BYTES) {
            sb.append("...")
        }
        return sb.toString()
    }

    private fun decodePrintableUtf8(bytes: ByteArray): String? {
        if (bytes.isEmpty()) return null
        return try {
            val text = String(bytes, Charsets.UTF_8)
            var controlCount = 0
            for (ch in text) {
                if (ch == '\uFFFD') return null
                if (ch.code < 0x20 && ch != '\n' && ch != '\r' && ch != '\t') {
                    controlCount++
                }
            }
            if (controlCount > 0) null else text.trim()
        } catch (_: Exception) {
            null
        }
    }

    private data class ParsedWifi(val ssid: String, val password: String, val encType: String)

    private fun parseWscPayload(payload: ByteArray): ParsedWifi? {
        var ssid: String? = null
        var password = ""
        var authTypeVal: Int? = null
        var encrTypeVal: Int? = null

        fun parseTlvs(bytes: ByteArray, startOffset: Int, endOffset: Int) {
            var i = startOffset
            while (i + 4 <= endOffset) {
                val type = ((bytes[i].toInt() and 0xFF) shl 8) or (bytes[i + 1].toInt() and 0xFF)
                val len = ((bytes[i + 2].toInt() and 0xFF) shl 8) or (bytes[i + 3].toInt() and 0xFF)
                i += 4
                if (i + len > endOffset) break
                when (type) {
                    0x100E -> parseTlvs(bytes, i, i + len)
                    0x1045 -> ssid = String(bytes, i, len, Charsets.UTF_8).trim()
                    0x1027 -> password = String(bytes, i, len, Charsets.UTF_8)
                    0x1003 -> if (len >= 2) {
                        authTypeVal = ((bytes[i].toInt() and 0xFF) shl 8) or (bytes[i + 1].toInt() and 0xFF)
                    }
                    0x100F -> if (len >= 2) {
                        encrTypeVal = ((bytes[i].toInt() and 0xFF) shl 8) or (bytes[i + 1].toInt() and 0xFF)
                    }
                }
                i += len
            }
        }

        try {
            parseTlvs(payload, 0, payload.size)
        } catch (_: Exception) {
            return null
        }

        val resolvedSsid = ssid
        if (resolvedSsid.isNullOrEmpty()) return null
        val finalEnc = when {
            encrTypeVal == 0x0002 || authTypeVal == 0x0004 -> "WEP"
            authTypeVal == 0x0001 && (encrTypeVal == null || encrTypeVal == 0x0001) -> "OPEN"
            authTypeVal != null || encrTypeVal != null -> "WPA"
            password.isNotEmpty() -> "WPA"
            else -> "OPEN"
        }
        return ParsedWifi(resolvedSsid, password, finalEnc)
    }

    private fun parseWifiUriString(raw: String): ParsedWifi? {
        var ssid: String? = null
        var password = ""
        var encType: String? = null

        val content = if (raw.startsWith("WIFI:", ignoreCase = true)) raw.substring(5) else raw
        val parts = splitUnescapedSemicolons(content)
        for (part in parts) {
            val trimmed = part.trim()
            when {
                trimmed.startsWith("S:", ignoreCase = true) -> ssid = unescapeWifiValue(trimmed.substring(2))
                trimmed.startsWith("P:", ignoreCase = true) -> password = unescapeWifiValue(trimmed.substring(2))
                trimmed.startsWith("T:", ignoreCase = true) -> {
                    encType = when (trimmed.substring(2).uppercase()) {
                        "WEP" -> "WEP"
                        "NOPASS", "NONE", "OPEN" -> "OPEN"
                        else -> "WPA"
                    }
                }
            }
        }
        val resolvedSsid = ssid
        if (resolvedSsid.isNullOrEmpty()) return null
        val finalEnc = encType ?: if (password.isNotEmpty()) "WPA" else "OPEN"
        return ParsedWifi(resolvedSsid, password, finalEnc)
    }

    private fun splitUnescapedSemicolons(input: String): List<String> {
        val tokens = mutableListOf<String>()
        val sb = StringBuilder()
        var escaped = false
        for (ch in input) {
            if (escaped) {
                sb.append('\\').append(ch)
                escaped = false
            } else if (ch == '\\') {
                escaped = true
            } else if (ch == ';') {
                tokens.add(sb.toString())
                sb.setLength(0)
            } else {
                sb.append(ch)
            }
        }
        if (escaped) sb.append('\\')
        tokens.add(sb.toString())
        return tokens
    }

    private fun unescapeWifiValue(value: String): String {
        val sb = StringBuilder()
        var escaped = false
        for (ch in value) {
            if (escaped) {
                sb.append(ch)
                escaped = false
            } else if (ch == '\\') {
                escaped = true
            } else {
                sb.append(ch)
            }
        }
        if (escaped) sb.append('\\')
        return sb.toString()
    }
}
