enum TagSignatureStatus {
  valid,
  invalid,
  notSupported;

  static TagSignatureStatus fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'VALID':
        return TagSignatureStatus.valid;
      case 'INVALID':
        return TagSignatureStatus.invalid;
      default:
        return TagSignatureStatus.notSupported;
    }
  }
}

enum TagPasswordStatus {
  protected,
  notProtected,
  unknown;

  static TagPasswordStatus fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'YES':
        return TagPasswordStatus.protected;
      case 'NO':
        return TagPasswordStatus.notProtected;
      default:
        return TagPasswordStatus.unknown;
    }
  }
}

enum InspectedRecordKind {
  uri,
  text,
  wifi,
  vcard,
  aar,
  mime,
  external,
  empty,
  unknown;

  static InspectedRecordKind fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'URI':
        return InspectedRecordKind.uri;
      case 'TEXT':
        return InspectedRecordKind.text;
      case 'WIFI':
        return InspectedRecordKind.wifi;
      case 'VCARD':
        return InspectedRecordKind.vcard;
      case 'AAR':
        return InspectedRecordKind.aar;
      case 'MIME':
        return InspectedRecordKind.mime;
      case 'EXTERNAL':
        return InspectedRecordKind.external;
      case 'EMPTY':
        return InspectedRecordKind.empty;
      default:
        return InspectedRecordKind.unknown;
    }
  }
}

class InspectedNdefRecord {
  const InspectedNdefRecord({
    required this.index,
    required this.tnf,
    required this.kind,
    required this.typeLabel,
    required this.displayValue,
    required this.fullValue,
    this.languageCode,
    this.mimeType,
    required this.payloadHex,
    required this.payloadSize,
    this.wifiSsid,
    this.wifiPassword,
    this.wifiEncryption,
  });

  final int index;
  final String tnf;
  final InspectedRecordKind kind;
  final String typeLabel;
  final String displayValue;
  final String fullValue;
  final String? languageCode;
  final String? mimeType;
  final String payloadHex;
  final int payloadSize;
  final String? wifiSsid;
  final String? wifiPassword;
  final String? wifiEncryption;

  bool get isHttpUrl {
    final lower = fullValue.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  bool get isOpenableUri {
    final lower = fullValue.trim().toLowerCase();
    return kind == InspectedRecordKind.uri &&
        (lower.startsWith('https://') ||
            lower.startsWith('http://') ||
            lower.startsWith('tel:') ||
            lower.startsWith('mailto:') ||
            lower.startsWith('geo:'));
  }

  static InspectedNdefRecord fromMap(Map<dynamic, dynamic> map) {
    return InspectedNdefRecord(
      index: _asInt(map['index']) ?? 1,
      tnf: map['tnf']?.toString() ?? 'Unknown',
      kind: InspectedRecordKind.fromCode(map['kind']?.toString()),
      typeLabel: map['typeLabel']?.toString() ?? 'Unknown',
      displayValue: map['displayValue']?.toString() ?? '',
      fullValue: map['fullValue']?.toString() ?? '',
      languageCode: _nonEmpty(map['languageCode']),
      mimeType: _nonEmpty(map['mimeType']),
      payloadHex: map['payloadHex']?.toString() ?? '',
      payloadSize: _asInt(map['payloadSize']) ?? 0,
      wifiSsid: _nonEmpty(map['wifiSsid']),
      wifiPassword: map['wifiPassword']?.toString(),
      wifiEncryption: _nonEmpty(map['wifiEncryption']),
    );
  }
}

class TagInspectionResult {
  const TagInspectionResult({
    required this.isoStandard,
    required this.manufacturer,
    required this.chipModel,
    required this.tagTypeLabel,
    required this.technologies,
    required this.serialNumber,
    this.atqa,
    this.sak,
    this.extraRfInfo = const <String, String>{},
    required this.signatureStatus,
    this.signatureHex,
    required this.passwordStatus,
    this.memoryTotalBytes,
    this.memoryPageCount,
    this.memoryPageSize,
    this.memorySectorCount,
    this.memoryBlockCount,
    required this.dataFormat,
    this.usedBytes,
    this.maxBytes,
    this.isWritable,
    this.canMakeReadOnly,
    this.records = const <InspectedNdefRecord>[],
  });

  final String isoStandard;
  final String manufacturer;
  final String chipModel;
  final String tagTypeLabel;
  final List<String> technologies;
  final String serialNumber;
  final String? atqa;
  final String? sak;
  final Map<String, String> extraRfInfo;
  final TagSignatureStatus signatureStatus;
  final String? signatureHex;
  final TagPasswordStatus passwordStatus;
  final int? memoryTotalBytes;
  final int? memoryPageCount;
  final int? memoryPageSize;
  final int? memorySectorCount;
  final int? memoryBlockCount;
  final String dataFormat;
  final int? usedBytes;
  final int? maxBytes;
  final bool? isWritable;
  final bool? canMakeReadOnly;
  final List<InspectedNdefRecord> records;

  bool get hasMemoryPages =>
      memoryTotalBytes != null &&
      memoryPageCount != null &&
      memoryPageSize != null;

  bool get hasMemorySectors =>
      memoryTotalBytes != null &&
      memorySectorCount != null &&
      memoryBlockCount != null;

  bool get hasMemoryBlocksOnly =>
      !hasMemoryPages &&
      !hasMemorySectors &&
      memoryTotalBytes != null &&
      memoryBlockCount != null;

  double? get usageRatio {
    final used = usedBytes;
    final max = maxBytes;
    if (used == null || max == null || max <= 0) return null;
    return (used / max).clamp(0.0, 1.0);
  }

  String get technologiesFormatted => technologies.join(', ');

  static TagInspectionResult fromMap(Map<dynamic, dynamic> map) {
    final rawTechs = map['technologies'];
    final techs = rawTechs is List
        ? rawTechs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final rawExtra = map['extraRfInfo'];
    final extra = <String, String>{};
    if (rawExtra is Map) {
      rawExtra.forEach((k, v) {
        final keyStr = k?.toString() ?? '';
        final valStr = v?.toString() ?? '';
        if (keyStr.isNotEmpty && valStr.isNotEmpty) {
          extra[keyStr] = valStr;
        }
      });
    }

    final rawRecords = map['records'];
    final parsedRecords = rawRecords is List
        ? rawRecords
            .whereType<Map<dynamic, dynamic>>()
            .map(InspectedNdefRecord.fromMap)
            .toList()
        : const <InspectedNdefRecord>[];

    return TagInspectionResult(
      isoStandard: map['isoStandard']?.toString() ?? 'Unknown',
      manufacturer: map['manufacturer']?.toString() ?? '',
      chipModel: map['chipModel']?.toString() ?? 'Unknown NFC Tag',
      tagTypeLabel: map['tagTypeLabel']?.toString() ??
          map['chipModel']?.toString() ??
          'Unknown NFC Tag',
      technologies: techs,
      serialNumber: map['serialNumber']?.toString() ?? '',
      atqa: _nonEmpty(map['atqa']),
      sak: _nonEmpty(map['sak']),
      extraRfInfo: extra,
      signatureStatus:
          TagSignatureStatus.fromCode(map['signatureStatus']?.toString()),
      signatureHex: _nonEmpty(map['signatureHex']),
      passwordStatus:
          TagPasswordStatus.fromCode(map['passwordStatus']?.toString()),
      memoryTotalBytes: _asInt(map['memoryTotalBytes']),
      memoryPageCount: _asInt(map['memoryPageCount']),
      memoryPageSize: _asInt(map['memoryPageSize']),
      memorySectorCount: _asInt(map['memorySectorCount']),
      memoryBlockCount: _asInt(map['memoryBlockCount']),
      dataFormat: map['dataFormat']?.toString() ?? 'Not NDEF formatted',
      usedBytes: _asInt(map['usedBytes']),
      maxBytes: _asInt(map['maxBytes']),
      isWritable: _asBool(map['isWritable']),
      canMakeReadOnly: _asBool(map['canMakeReadOnly']),
      records: parsedRecords,
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return null;
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
