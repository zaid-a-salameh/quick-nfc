import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/data/services/hardware_bridge_service.dart';
import 'package:review_link_generator/data/services/preferences_service.dart';
import 'package:review_link_generator/domain/models/nfc_models.dart';
import 'package:review_link_generator/domain/models/toast_message.dart';
import 'package:review_link_generator/l10n/app_localizations.dart';
import 'package:review_link_generator/main.dart';
import 'package:review_link_generator/ui/core/theme/app_colors.dart';
import 'package:review_link_generator/ui/core/theme/app_motion.dart';
import 'package:review_link_generator/ui/core/widgets/ambient_glow_scaffold.dart';
import 'package:review_link_generator/ui/features/home/view_models/home_view_model.dart';
import 'package:review_link_generator/ui/features/home/widgets/home_screen.dart';
import 'package:review_link_generator/ui/features/nfc/view_models/nfc_view_model.dart';
import 'package:review_link_generator/ui/features/nfc/widgets/nfc_sensor_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubHardwareBridgeService extends HardwareBridgeService {
  int startWriteCalls = 0;
  int startWifiWriteCalls = 0;
  int startEraseCalls = 0;
  int cancelCalls = 0;

  final StreamController<NfcHardwareEvent> _controller =
      StreamController<NfcHardwareEvent>.broadcast();

  @override
  Stream<NfcHardwareEvent> get nfcEvents => _controller.stream;

  void emitEvent(NfcHardwareEvent event) {
    _controller.add(event);
  }

  @override
  Future<String> getNfcStatus() async => 'ENABLED';

  @override
  Future<bool> isNetworkConnected() async => true;

  @override
  Future<String> getAppVersion() async => '2.0.0';

  @override
  Future<void> triggerLightHaptic() async {}

  @override
  Future<void> triggerSuccessHaptic() async {}

  @override
  Future<void> triggerErrorHaptic() async {}

  @override
  Future<bool> startNfcWrite(String url) async {
    startWriteCalls++;
    return true;
  }

  @override
  Future<bool> startNfcWifiWrite({
    required String ssid,
    required String password,
    required String encType,
  }) async {
    startWifiWriteCalls++;
    return true;
  }

  @override
  Future<bool> startNfcErase() async {
    startEraseCalls++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Preferences & Settings Persistence', () {
    test('persists animationsEnabled (default true) and sequentialWriteEnabled (default false)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await PreferencesService.create();
      final bridge = _StubHardwareBridgeService();
      addTearDown(bridge.dispose);

      final vm = HomeViewModel(
        preferencesService: prefs,
        hardwareBridge: bridge,
      );
      addTearDown(vm.dispose);

      expect(vm.animationsEnabled, isTrue);
      expect(vm.sequentialWriteEnabled, isFalse);

      await vm.setAnimationsEnabled(false);
      await vm.setSequentialWriteEnabled(true);

      final reloadedPrefs = await PreferencesService.create();
      expect(reloadedPrefs.isAnimationsEnabled, isFalse);
      expect(reloadedPrefs.isSequentialWriteEnabled, isTrue);
    });
  });

  group('Sequential Card Writing Mode', () {
    testWidgets(
      'auto-rearms URL write after 1500ms, hides Write Another button, and cancels cleanly on Done',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'app_lang': 'en',
          'review_link_flutter_onboarding_v1': true,
        });
        final prefs = await PreferencesService.create();
        await prefs.setSequentialWriteEnabled(true);

        final bridge = _StubHardwareBridgeService();
        final homeVm = HomeViewModel(
          preferencesService: prefs,
          hardwareBridge: bridge,
        );
        final nfcVm = NfcViewModel(
          hardwareBridge: bridge,
          isSequentialWriteEnabled: () => homeVm.sequentialWriteEnabled,
        );
        addTearDown(() {
          nfcVm.dispose();
          homeVm.dispose();
          bridge.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ListenableBuilder(
                listenable: nfcVm,
                builder: (_, _) => NfcSensorView(
                  viewModel: nfcVm,
                  hardwareBridge: bridge,
                  onShowToast: (_, {ToastType type = ToastType.info}) {},
                  onRequestCloseModal: () {},
                ),
              ),
            ),
          ),
        );

        await nfcVm.prepareWriteUrl('https://example.com');
        await tester.pump();
        expect(bridge.startWriteCalls, equals(1));
        expect(nfcVm.sensorState, equals(NfcSensorState.ready));

        bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.writeSuccess,
            count: 1,
          ),
        );
        await tester.pump();

        expect(nfcVm.sensorState, equals(NfcSensorState.success));
        expect(nfcVm.isSequentialAutoRearming, isTrue);
        expect(find.byKey(const Key('btn_write_another')), findsNothing);
        expect(find.byKey(const Key('btn_nfc_cancel')), findsOneWidget);

        // Before 1500ms elapses, still on success state
        await tester.pump(const Duration(milliseconds: 1400));
        expect(nfcVm.sensorState, equals(NfcSensorState.success));
        expect(bridge.startWriteCalls, equals(1));

        // Cross 1500ms -> returns straight to ready-to-write mode
        await tester.pump(const Duration(milliseconds: 150));
        expect(nfcVm.sensorState, equals(NfcSensorState.ready));
        expect(bridge.startWriteCalls, equals(2));

        // Second success cancelled early before 1500ms
        bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.writeSuccess,
            count: 2,
          ),
        );
        await tester.pump();
        expect(nfcVm.sensorState, equals(NfcSensorState.success));

        await tester.pump(const Duration(milliseconds: 400));
        await nfcVm.closeAndResetSession();
        await tester.pump(const Duration(milliseconds: 2000));
        expect(bridge.startWriteCalls, equals(2));
      },
    );

    testWidgets(
      'auto-rearms Wi-Fi write after 1500ms and hides btn_wifi_write_another',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'app_lang': 'en',
          'review_link_flutter_onboarding_v1': true,
        });
        final prefs = await PreferencesService.create();
        await prefs.setSequentialWriteEnabled(true);

        final bridge = _StubHardwareBridgeService();
        final homeVm = HomeViewModel(
          preferencesService: prefs,
          hardwareBridge: bridge,
        );
        final nfcVm = NfcViewModel(
          hardwareBridge: bridge,
          isSequentialWriteEnabled: () => homeVm.sequentialWriteEnabled,
        );
        addTearDown(() {
          nfcVm.dispose();
          homeVm.dispose();
          bridge.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ListenableBuilder(
                listenable: nfcVm,
                builder: (_, _) => NfcSensorView(
                  viewModel: nfcVm,
                  hardwareBridge: bridge,
                  onShowToast: (_, {ToastType type = ToastType.info}) {},
                  onRequestCloseModal: () {},
                ),
              ),
            ),
          ),
        );

        nfcVm.prepareWifiWizard();
        nfcVm.wifiSsidController.text = 'CafeGuest';
        nfcVm.wifiPasswordController.text = '12345678';
        await nfcVm.startWifiNfcWriteFromWizard();
        await tester.pump();

        expect(bridge.startWifiWriteCalls, equals(1));
        expect(nfcVm.sensorState, equals(NfcSensorState.wifiReady));

        bridge.emitEvent(
          const NfcHardwareEvent(
            type: NfcHardwareEventType.writeSuccess,
            count: 1,
            operationCode: 'WRITE_WIFI',
          ),
        );
        await tester.pump();

        expect(nfcVm.sensorState, equals(NfcSensorState.success));
        expect(nfcVm.isSequentialAutoRearming, isTrue);
        expect(find.byKey(const Key('btn_wifi_write_another')), findsNothing);
        expect(find.byKey(const Key('btn_wifi_success_done')), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1550));
        expect(nfcVm.sensorState, equals(NfcSensorState.wifiReady));
        expect(bridge.startWifiWriteCalls, equals(2));

        await nfcVm.closeAndResetSession();
      },
    );

    test('does not mark erase as sequential auto-rearming even when enabled', () {
      final bridge = _StubHardwareBridgeService();
      final nfcVm = NfcViewModel(
        hardwareBridge: bridge,
        isSequentialWriteEnabled: () => true,
      );
      addTearDown(() {
        nfcVm.dispose();
        bridge.dispose();
      });

      nfcVm.prepareEraseConfirm();
      expect(nfcVm.isSequentialAutoRearming, isFalse);
    });
  });

  group('Settings Switches & Instant Theme Background Fix', () {
    testWidgets(
      'toggles Animations and Sequential Write in Settings, and snaps Home background immediately on theme switch',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        SharedPreferences.setMockInitialValues(<String, Object>{
          'app_lang': 'en',
          'app_theme_mode': 'light',
          'review_link_flutter_onboarding_v1': true,
        });
        final prefs = await PreferencesService.create();
        final bridge = _StubHardwareBridgeService();
        final homeVm = HomeViewModel(
          preferencesService: prefs,
          hardwareBridge: bridge,
        );
        final nfcVm = NfcViewModel(
          hardwareBridge: bridge,
          isSequentialWriteEnabled: () => homeVm.sequentialWriteEnabled,
        );
        addTearDown(() {
          nfcVm.dispose();
          homeVm.dispose();
          bridge.dispose();
        });

        await tester.pumpWidget(
          ReviewLinkGeneratorApp(
            preferencesService: prefs,
            hardwareBridge: bridge,
            homeViewModel: homeVm,
            nfcViewModel: nfcVm,
            enableAutoOnboarding: false,
            enableStartupUpdateCheck: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(AppColors.isLight, isTrue);
        expect(
          AppMotion.isReduced(
            tester.element(find.byType(AmbientGlowScaffold)),
          ),
          isFalse,
        );

        // Open SettingsScreen
        await tester.tap(find.byKey(const Key('btn_open_settings')));
        await tester.pumpAndSettle();

        // Toggle Animations OFF
        final animSwitch = find.byKey(const Key('switch_animations'));
        await tester.ensureVisible(animSwitch);
        await tester.tap(animSwitch);
        await tester.pumpAndSettle();

        expect(homeVm.animationsEnabled, isFalse);
        expect(
          AppMotion.isReduced(
            tester.element(find.byType(AmbientGlowScaffold)),
          ),
          isTrue,
        );

        // Toggle Sequential Write ON
        final seqSwitch = find.byKey(const Key('switch_sequential_write'));
        await tester.ensureVisible(seqSwitch);
        await tester.tap(seqSwitch);
        await tester.pumpAndSettle();

        expect(homeVm.sequentialWriteEnabled, isTrue);

        // Switch Light -> Dark inside SettingsScreen, re-enable animations so
        // AmbientGlowScaffold's routeDuration (not just disableAnimations) is verified.
        await tester.tap(animSwitch);
        await tester.pumpAndSettle();
        expect(homeVm.animationsEnabled, isTrue);

        final darkBtn = find.byKey(const Key('btn_theme_dark'));
        await tester.ensureVisible(darkBtn);
        await tester.tap(darkBtn);
        await tester.pumpAndSettle();

        expect(AppColors.isLight, isFalse);

        // Navigate back to HomeScreen and check rendered background color immediately
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        final homeScaffoldFinder = find.descendant(
          of: find.byType(HomeScreen, skipOffstage: false),
          matching: find.byType(AmbientGlowScaffold, skipOffstage: false),
        );
        expect(homeScaffoldFinder, findsOneWidget);
        final renderedContainer = tester.widget<Container>(
          find
              .descendant(
                of: homeScaffoldFinder,
                matching: find.byType(Container, skipOffstage: false),
              )
              .first,
        );
        final decoration = renderedContainer.decoration as BoxDecoration?;
        expect(decoration?.color, equals(AppColors.bg));

        await tester.pumpAndSettle();
      },
    );
  });
}
