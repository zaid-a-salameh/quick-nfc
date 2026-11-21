import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/data/services/hardware_bridge_service.dart';
import 'package:review_link_generator/data/services/preferences_service.dart';
import 'package:review_link_generator/domain/models/nfc_models.dart';
import 'package:review_link_generator/domain/models/tag_inspection_models.dart';
import 'package:review_link_generator/main.dart';
import 'package:review_link_generator/ui/features/home/view_models/home_view_model.dart';
import 'package:review_link_generator/ui/features/home/widgets/main_input_card.dart';
import 'package:review_link_generator/ui/features/home_grid/widgets/interactive_home_grid.dart';
import 'package:review_link_generator/ui/features/nfc/view_models/nfc_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InspectorFakeHardwareBridge extends HardwareBridgeService {
  int startInspectCalls = 0;
  int startPermLockCalls = 0;
  int startPinLockCalls = 0;
  int cancelCalls = 0;
  bool allowInspectStart = true;

  final StreamController<NfcHardwareEvent> _controller =
      StreamController<NfcHardwareEvent>.broadcast();

  @override
  Stream<NfcHardwareEvent> get nfcEvents => _controller.stream;

  void emitEvent(NfcHardwareEvent event) {
    _controller.add(event);
  }

  @override
  Future<String> getNfcStatus() async => 'READY';

  @override
  Future<bool> isNetworkConnected() async => true;

  @override
  Future<String> getAppVersion() async => '2.2.0';

  @override
  Future<void> triggerLightHaptic() async {}

  @override
  Future<void> triggerSuccessHaptic() async {}

  @override
  Future<void> triggerErrorHaptic() async {}

  @override
  Future<bool> startNfcInspect() async {
    startInspectCalls++;
    return allowInspectStart;
  }

  @override
  Future<bool> startNfcPermanentLock() async {
    startPermLockCalls++;
    return true;
  }

  @override
  Future<bool> startNfcPasswordLock(String pin) async {
    startPinLockCalls++;
    return true;
  }

  @override
  Future<void> cancelNfcSession() async {
    cancelCalls++;
  }

  void dispose() {
    _controller.close();
  }
}

Map<String, dynamic> _buildNtag215Payload() {
  return <String, dynamic>{
    'event': 'tag_inspected',
    'isoStandard': 'ISO 14443-3A',
    'manufacturer': 'NXP',
    'chipModel': 'NTAG215',
    'tagTypeLabel': 'NXP - NTAG215',
    'technologies': <String>['NfcA', 'MifareUltralight', 'Ndef'],
    'serialNumber': '04:D5:81:52:CB:2A:81',
    'atqa': '0x0044',
    'sak': '0x00',
    'extraRfInfo': <String, String>{},
    'signatureStatus': 'INVALID',
    'signatureHex': 'AA:BB:CC:DD',
    'passwordStatus': 'YES',
    'memoryTotalBytes': 540,
    'memoryPageCount': 135,
    'memoryPageSize': 4,
    'dataFormat': 'NFC Forum Type 2',
    'usedBytes': 90,
    'maxBytes': 492,
    'isWritable': true,
    'canMakeReadOnly': true,
    'records': <Map<String, dynamic>>[
      <String, dynamic>{
        'index': 1,
        'tnf': 'Well Known',
        'kind': 'URI',
        'typeLabel': 'https://www.',
        'displayValue': 'google.com/maps/place/?q=place_id:ChIJN1t_tDeuEmsRUsoyG83frY4',
        'fullValue': 'https://www.google.com/maps/place/?q=place_id:ChIJN1t_tDeuEmsRUsoyG83frY4',
        'payloadHex': '02:67:6F:6F:67:6C:65',
        'payloadSize': 65,
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({
    PreferencesService prefs,
    _InspectorFakeHardwareBridge bridge,
    HomeViewModel homeVm,
    NfcViewModel nfcVm,
  })> createHarness({String lang = 'en'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lang': lang,
      'review_link_flutter_onboarding_v1': true,
    });
    final prefs = await PreferencesService.create();
    final bridge = _InspectorFakeHardwareBridge();
    final homeVm = HomeViewModel(
      preferencesService: prefs,
      hardwareBridge: bridge,
    );
    final nfcVm = NfcViewModel(hardwareBridge: bridge);
    return (prefs: prefs, bridge: bridge, homeVm: homeVm, nfcVm: nfcVm);
  }

  group('TagInspectionResult Unit Tests', () {
    test('parses full NTAG215 payload matching NFC Tools metadata and URI record', () {
      final result = TagInspectionResult.fromMap(_buildNtag215Payload());

      expect(result.isoStandard, equals('ISO 14443-3A'));
      expect(result.manufacturer, equals('NXP'));
      expect(result.chipModel, equals('NTAG215'));
      expect(result.tagTypeLabel, equals('NXP - NTAG215'));
      expect(
        result.technologies,
        equals(<String>['NfcA', 'MifareUltralight', 'Ndef']),
      );
      expect(result.serialNumber, equals('04:D5:81:52:CB:2A:81'));
      expect(result.atqa, equals('0x0044'));
      expect(result.sak, equals('0x00'));
      expect(result.signatureStatus, equals(TagSignatureStatus.invalid));
      expect(result.passwordStatus, equals(TagPasswordStatus.protected));
      expect(result.hasMemoryPages, isTrue);
      expect(result.memoryTotalBytes, equals(540));
      expect(result.memoryPageCount, equals(135));
      expect(result.memoryPageSize, equals(4));
      expect(result.dataFormat, equals('NFC Forum Type 2'));
      expect(result.usedBytes, equals(90));
      expect(result.maxBytes, equals(492));
      expect(result.usageRatio, closeTo(90 / 492, 0.001));
      expect(result.isWritable, isTrue);
      expect(result.canMakeReadOnly, isTrue);
      expect(result.records, hasLength(1));

      final rec = result.records.first;
      expect(rec.index, equals(1));
      expect(rec.kind, equals(InspectedRecordKind.uri));
      expect(rec.typeLabel, equals('https://www.'));
      expect(rec.isHttpUrl, isTrue);
      expect(rec.isOpenableUri, isTrue);
    });

    test('parses MIFARE Classic 1K sectors payload, valid signature, Wi-Fi, Text, and AAR records', () {
      final result = TagInspectionResult.fromMap(<String, dynamic>{
        'isoStandard': 'ISO 14443-3A',
        'manufacturer': 'NXP',
        'chipModel': 'MIFARE Classic 1K',
        'tagTypeLabel': 'NXP - MIFARE Classic 1K',
        'technologies': <String>['NfcA', 'MifareClassic', 'Ndef'],
        'serialNumber': 'A1:B2:C3:D4',
        'atqa': '0x0004',
        'sak': '0x08',
        'signatureStatus': 'VALID',
        'passwordStatus': 'NO',
        'memoryTotalBytes': 1024,
        'memorySectorCount': 16,
        'memoryBlockCount': 64,
        'dataFormat': 'MIFARE Classic',
        'usedBytes': 128,
        'maxBytes': 716,
        'isWritable': true,
        'canMakeReadOnly': false,
        'records': <Map<String, dynamic>>[
          <String, dynamic>{
            'index': 1,
            'tnf': 'MIME Media',
            'kind': 'WIFI',
            'typeLabel': 'Wi-Fi',
            'displayValue': 'CafeNet (WPA)',
            'fullValue': 'CafeNet',
            'mimeType': 'application/vnd.wfa.wsc',
            'payloadHex': '10:0E',
            'payloadSize': 42,
            'wifiSsid': 'CafeNet',
            'wifiPassword': 'secret123',
            'wifiEncryption': 'WPA',
          },
          <String, dynamic>{
            'index': 2,
            'tnf': 'Well Known',
            'kind': 'TEXT',
            'typeLabel': 'Text',
            'displayValue': 'Hello NFC',
            'fullValue': 'Hello NFC',
            'languageCode': 'en',
            'payloadHex': '02:65:6E:48',
            'payloadSize': 12,
          },
          <String, dynamic>{
            'index': 3,
            'tnf': 'External',
            'kind': 'AAR',
            'typeLabel': 'Android App',
            'displayValue': 'com.example.app',
            'fullValue': 'com.example.app',
            'payloadHex': '63:6F:6D',
            'payloadSize': 15,
          },
        ],
      });

      expect(result.signatureStatus, equals(TagSignatureStatus.valid));
      expect(result.passwordStatus, equals(TagPasswordStatus.notProtected));
      expect(result.hasMemorySectors, isTrue);
      expect(result.hasMemoryPages, isFalse);
      expect(result.memorySectorCount, equals(16));
      expect(result.memoryBlockCount, equals(64));
      expect(result.records, hasLength(3));
      expect(result.records[0].kind, equals(InspectedRecordKind.wifi));
      expect(result.records[0].wifiSsid, equals('CafeNet'));
      expect(result.records[0].wifiPassword, equals('secret123'));
      expect(result.records[0].wifiEncryption, equals('WPA'));
      expect(result.records[1].kind, equals(InspectedRecordKind.text));
      expect(result.records[1].languageCode, equals('en'));
      expect(result.records[2].kind, equals(InspectedRecordKind.aar));
      expect(result.records[2].isHttpUrl, isFalse);
    });

    test('parses empty and unformatted tag payload safely', () {
      final result = TagInspectionResult.fromMap(<String, dynamic>{
        'isoStandard': 'ISO 14443-3B',
        'chipModel': 'ISO 14443-3B Tag',
        'technologies': <String>['NfcB'],
        'serialNumber': '11:22:33:44',
        'signatureStatus': 'NOT_SUPPORTED',
        'passwordStatus': 'UNKNOWN',
        'dataFormat': 'Not NDEF formatted',
        'records': <Map<String, dynamic>>[],
      });

      expect(result.signatureStatus, equals(TagSignatureStatus.notSupported));
      expect(result.passwordStatus, equals(TagPasswordStatus.unknown));
      expect(result.usageRatio, isNull);
      expect(result.records, isEmpty);
      expect(result.isWritable, isNull);
    });
  });

  group('TagInspectorScreen & ResultCard Widget Tests', () {
    testWidgets(
      'Inspect hero tile opens TagInspectorScreen, renders live tag details, refreshes on second scan, imports URL, and cancels session on exit',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        // Inspect Card hero tile must be first and wider than Clone Card tile
        final inspectBtn = find.byKey(const Key('btn_tool_inspect_card'));
        final cloneBtn = find.byKey(const Key('btn_tool_read_card'));
        expect(inspectBtn, findsOneWidget);
        expect(cloneBtn, findsOneWidget);
        expect(find.text('Inspect Card'), findsOneWidget);
        expect(find.text('Clone Card'), findsOneWidget);

        final inspectRect = tester.getRect(inspectBtn);
        final cloneRect = tester.getRect(cloneBtn);
        expect(inspectRect.bottom, lessThan(cloneRect.top));
        expect(inspectRect.width, greaterThan(cloneRect.width));

        // Open Inspector Screen
        await tester.tap(inspectBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byKey(const Key('tag_inspector_screen')), findsOneWidget);
        expect(find.byKey(const Key('inspector_waiting_card')), findsOneWidget);
        expect(harness.bridge.startInspectCalls, equals(1));

        // Emit first tag_inspected event (NTAG215)
        final firstEvent = NfcHardwareEvent.fromMap(_buildNtag215Payload());
        expect(firstEvent, isNotNull);
        harness.bridge.emitEvent(firstEvent!);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inspector_waiting_card')), findsNothing);
        expect(find.byKey(const Key('inspector_chip_name')), findsOneWidget);
        expect(find.text('NXP - NTAG215'), findsOneWidget);
        expect(find.text('04:D5:81:52:CB:2A:81'), findsOneWidget);
        expect(find.text('0x0044'), findsOneWidget);
        expect(find.text('0x00'), findsOneWidget);
        expect(find.text('Signature'), findsOneWidget);
        expect(find.text('Invalid'), findsOneWidget);
        expect(find.text('Protected by password'), findsOneWidget);
        expect(find.text('Memory information'), findsOneWidget);
        expect(find.text('540 bytes : 135 pages (4 bytes each)'), findsOneWidget);
        expect(find.text('Data format'), findsOneWidget);
        expect(find.text('NFC Forum Type 2'), findsOneWidget);
        expect(find.text('90 / 492 Bytes'), findsOneWidget);
        expect(find.text('Writable'), findsOneWidget);
        expect(find.text('Can be made Read-Only'), findsOneWidget);
        expect(find.text('Record 1 - https://www.'), findsOneWidget);

        // Emit a second tag_inspected event live without leaving screen
        final secondPayload = Map<String, dynamic>.from(_buildNtag215Payload())
          ..['chipModel'] = 'NTAG216'
          ..['tagTypeLabel'] = 'NXP - NTAG216'
          ..['signatureStatus'] = 'VALID'
          ..['passwordStatus'] = 'NO'
          ..['memoryTotalBytes'] = 924
          ..['memoryPageCount'] = 231;
        harness.bridge.emitEvent(NfcHardwareEvent.fromMap(secondPayload)!);
        await tester.pumpAndSettle();

        expect(find.text('NXP - NTAG216'), findsWidgets);
        expect(find.text('Valid (Original NXP)'), findsOneWidget);
        expect(
          find.text('924 bytes : 231 pages (4 bytes each)'),
          findsOneWidget,
        );

        // Tap "Use in Quick NFC" -> returns to Home and populates ResultCard
        final useUrlBtn = find.byKey(const Key('btn_inspector_use_url_1'));
        await tester.ensureVisible(useUrlBtn);
        await tester.tap(useUrlBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tag_inspector_screen')), findsNothing);
        expect(find.byKey(const Key('result_card')), findsOneWidget);
        expect(harness.bridge.cancelCalls, greaterThanOrEqualTo(1));

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'TagInspectorScreen renders properly in Arabic RTL while keeping Serial Number LTR, and cancels on Back',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'ar');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('فحص البطاقة'), findsOneWidget);
        expect(find.text('نسخ البطاقة'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_tool_inspect_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          Directionality.of(
            tester.element(find.byKey(const Key('tag_inspector_screen'))),
          ),
          equals(TextDirection.rtl),
        );

        harness.bridge.emitEvent(
          NfcHardwareEvent.fromMap(_buildNtag215Payload())!,
        );
        await tester.pumpAndSettle();

        expect(
          Directionality.of(tester.element(find.text('04:D5:81:52:CB:2A:81'))),
          equals(TextDirection.ltr),
        );

        await tester.tap(find.byKey(const Key('btn_inspector_back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tag_inspector_screen')), findsNothing);
        expect(harness.bridge.cancelCalls, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'ResultCard appears directly below MainInputCard (above InteractiveHomeGrid) and toggles collapse/expand cleanly',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        const sampleUrl =
            'https://www.google.com/maps/place/?q=place_id:ChIJN1t_tDeuEmsRUsoyG83frY4';
        await tester.enterText(
          find.byKey(const Key('input_direct_url')),
          sampleUrl,
        );
        await tester.tap(find.byKey(const Key('btn_convert_link')));
        await tester.pumpAndSettle();

        final inputRect = tester.getRect(find.byType(MainInputCard));
        final resultRect = tester.getRect(find.byKey(const Key('result_card')));
        final toolsRect = tester.getRect(find.byType(InteractiveHomeGrid));

        // ResultCard must sit strictly between MainInputCard and InteractiveHomeGrid
        expect(resultRect.top, greaterThanOrEqualTo(inputRect.bottom - 1));
        expect(resultRect.bottom, lessThanOrEqualTo(toolsRect.top + 1));

        // Expanded by default
        expect(find.byKey(const Key('btn_write_nfc')), findsOneWidget);

        // Collapse ResultCard
        final toggleBtn = find.byKey(const Key('btn_toggle_result_expand'));
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('result_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_write_nfc')), findsNothing);

        // Expand ResultCard again
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_write_nfc')), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Permanent Lock reports Card Is Protected and Retry recovers cleanly when native returns LOCKED',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_tool_perm_lock')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_perm_lock_confirm')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(harness.bridge.startPermLockCalls, equals(1));

        // Simulate native pre-flight rejecting password-protected tag with LOCKED
        harness.bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.error,
            errorCode: 'LOCKED',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Card Is Protected'), findsOneWidget);
        expect(
          find.text('Card is password-protected or read-only. Unlock it first.'),
          findsOneWidget,
        );
        final retryBtn = find.byKey(const Key('btn_nfc_retry'));
        expect(retryBtn, findsOneWidget);

        await tester.tap(retryBtn);
        await tester.pump(const Duration(milliseconds: 350));
        expect(harness.bridge.startPermLockCalls, equals(2));

        await tester.tap(find.byKey(const Key('btn_nfc_cancel')));
        await tester.pumpAndSettle();
        expect(harness.bridge.cancelCalls, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'ISO 14443-4 Bank / Smart Card (IsoDep, NfcA) renders ATS & chip metadata directly while hiding NDEF/memory rows',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_tool_inspect_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        harness.bridge.emitEvent(
          NfcHardwareEvent.fromMap(<String, dynamic>{
            'event': 'tag_inspected',
            'isoStandard': 'ISO 14443-4',
            'manufacturer': 'NXP',
            'chipModel': 'Mifare Plus',
            'tagTypeLabel': 'NXP - Mifare Plus',
            'technologies': <String>['IsoDep', 'NfcA'],
            'serialNumber': '02:44:80:E8:44:40:00',
            'atqa': '0x0044',
            'sak': '0x20',
            'extraRfInfo': <String, String>{
              'ATS': '0x80318066B1840C016E0183009000',
            },
            'signatureStatus': 'NOT_SUPPORTED',
            'passwordStatus': 'UNKNOWN',
            'dataFormat': 'Not NDEF formatted',
            'records': <Map<String, dynamic>>[],
          })!,
        );
        await tester.pumpAndSettle();

        expect(find.text('Tag type : ISO 14443-4'), findsOneWidget);
        expect(find.byKey(const Key('inspector_chip_name')), findsOneWidget);
        expect(find.text('NXP - Mifare Plus'), findsOneWidget);
        expect(find.text('IsoDep, NfcA'), findsOneWidget);
        expect(find.text('02:44:80:E8:44:40:00'), findsOneWidget);
        expect(find.text('0x0044'), findsOneWidget);
        expect(find.text('0x20'), findsOneWidget);
        expect(find.text('ATS'), findsOneWidget);
        expect(find.text('0x80318066B1840C016E0183009000'), findsOneWidget);

        expect(find.text('Signature'), findsNothing);
        expect(find.text('Protected by password'), findsNothing);
        expect(find.text('Memory information'), findsNothing);
        expect(find.text('Data format'), findsNothing);
        expect(find.text('NDEF Records (0)'), findsNothing);
        expect(find.text('No NDEF records found on this tag'), findsNothing);
        expect(find.text('Live Scan'), findsNothing);
      },
    );

    testWidgets(
      'Mifare Ultralight fallback with Empty NDEF record hides unsupported signature/password/memory and omits dash box',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_tool_inspect_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        harness.bridge.emitEvent(
          NfcHardwareEvent.fromMap(<String, dynamic>{
            'event': 'tag_inspected',
            'isoStandard': 'ISO 14443-3A',
            'manufacturer': 'NXP',
            'chipModel': 'Mifare Ultralight (Ultralight)',
            'tagTypeLabel': 'NXP - Mifare Ultralight (Ultralight)',
            'technologies': <String>['NfcA', 'MifareUltralight', 'Ndef'],
            'serialNumber': '04:4E:AB:52:CB:2A:81',
            'atqa': '0x0044',
            'sak': '0x00',
            'signatureStatus': 'NOT_SUPPORTED',
            'passwordStatus': 'UNKNOWN',
            'dataFormat': 'NFC Forum Type 2',
            'usedBytes': 4,
            'maxBytes': 492,
            'isWritable': true,
            'canMakeReadOnly': true,
            'records': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 1,
                'tnf': 'Empty',
                'kind': 'EMPTY',
                'typeLabel': 'Empty',
                'displayValue': '',
                'fullValue': '',
                'payloadHex': '',
                'payloadSize': 0,
              },
            ],
          })!,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('NXP - Mifare Ultralight (Ultralight)'),
          findsOneWidget,
        );
        expect(find.text('04:4E:AB:52:CB:2A:81'), findsOneWidget);
        expect(find.text('0x0044'), findsOneWidget);
        expect(find.text('0x00'), findsOneWidget);
        expect(find.text('NFC Forum Type 2'), findsOneWidget);
        expect(find.text('4 / 492 Bytes'), findsOneWidget);
        expect(find.text('Record 1 - Empty'), findsOneWidget);

        expect(find.text('Signature'), findsNothing);
        expect(find.text('Protected by password'), findsNothing);
        expect(find.text('Memory information'), findsNothing);

        final emptyRecordFinder = find.byKey(const Key('inspector_record_1'));
        expect(emptyRecordFinder, findsOneWidget);
        expect(
          find.descendant(of: emptyRecordFinder, matching: find.text('-')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'PIN Lock and Permanent Lock show Unsupported Card title and clear reason on PWD_UNSUPPORTED / UNSUPPORTED',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        // 1. PIN Lock -> PWD_UNSUPPORTED
        await tester.tap(find.byKey(const Key('btn_tool_pin_lock')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('input_nfc_pin')), '1234');
        await tester.tap(find.byKey(const Key('btn_pin_submit')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(harness.bridge.startPinLockCalls, equals(1));

        harness.bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.error,
            errorCode: 'PWD_UNSUPPORTED',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unsupported Card'), findsOneWidget);
        expect(
          find.text('PIN protection is not supported on this card'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_nfc_cancel')));
        await tester.pumpAndSettle();
        if (find.byKey(const Key('btn_pin_cancel')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('btn_pin_cancel')));
          await tester.pumpAndSettle();
        }

        // 2. Permanent Lock -> UNSUPPORTED
        await tester.tap(find.byKey(const Key('btn_tool_perm_lock')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_perm_lock_confirm')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(harness.bridge.startPermLockCalls, equals(1));

        harness.bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.error,
            errorCode: 'UNSUPPORTED',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unsupported Card'), findsOneWidget);
        expect(
          find.text('This card type is not supported.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_nfc_cancel')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ResultCard animates into view and auto-scrolls smoothly when converting a link',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: harness.prefs,
            hardwareBridge: harness.bridge,
            homeViewModel: harness.homeVm,
            nfcViewModel: harness.nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('result_card')), findsNothing);
        expect(harness.homeVm.resultRevealTick, equals(0));

        await tester.enterText(
          find.byKey(const Key('input_direct_url')),
          'https://zaid-a-salameh.github.io',
        );
        await tester.tap(find.byKey(const Key('btn_convert_link')));
        await tester.pumpAndSettle();

        expect(harness.homeVm.resultRevealTick, equals(1));
        expect(find.byKey(const Key('result_card')), findsOneWidget);

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first,
        );
        expect(scrollView.controller!.offset, greaterThan(0.0));

        final resultRect = tester.getRect(find.byKey(const Key('result_card')));
        expect(resultRect.top, greaterThanOrEqualTo(0.0));
        expect(resultRect.top, lessThan(420.0));
      },
    );
  });
}
