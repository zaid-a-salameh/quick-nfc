import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/data/services/hardware_bridge_service.dart';
import 'package:review_link_generator/data/services/preferences_service.dart';
import 'package:review_link_generator/domain/models/nfc_models.dart';
import 'package:review_link_generator/main.dart';
import 'package:review_link_generator/ui/features/home/view_models/home_view_model.dart';
import 'package:review_link_generator/ui/features/home_grid/models/grid_tile_models.dart';
import 'package:review_link_generator/ui/features/home_grid/registry/tool_registry.dart';
import 'package:review_link_generator/ui/features/home_grid/view_models/home_grid_view_model.dart';
import 'package:review_link_generator/ui/features/nfc/view_models/nfc_view_model.dart';
import 'package:review_link_generator/ui/features/nfc/widgets/nfc_modal_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ToolsHubTestBridge extends HardwareBridgeService {
  int inspectStartCalls = 0;
  int cancelCalls = 0;

  final StreamController<NfcHardwareEvent> _controller =
      StreamController<NfcHardwareEvent>.broadcast();

  @override
  Stream<NfcHardwareEvent> get nfcEvents => _controller.stream;

  @override
  Future<String> getNfcStatus() async => 'ENABLED';

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
    inspectStartCalls++;
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

  Future<({
    PreferencesService prefs,
    _ToolsHubTestBridge bridge,
    HomeViewModel homeVm,
    NfcViewModel nfcVm,
    HomeGridViewModel gridVm,
  })> createHarness({
    String lang = 'en',
    ThemeMode themeMode = ThemeMode.dark,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lang': lang,
      'app_theme_mode': themeMode.name,
      'review_link_flutter_onboarding_v1': true,
    });
    final prefs = await PreferencesService.create();
    final bridge = _ToolsHubTestBridge();
    final homeVm = HomeViewModel(
      preferencesService: prefs,
      hardwareBridge: bridge,
    );
    final nfcVm = NfcViewModel(
      hardwareBridge: bridge,
      isSequentialWriteEnabled: () => homeVm.sequentialWriteEnabled,
    );
    final gridVm = HomeGridViewModel(
      preferencesService: prefs,
      hardwareBridge: bridge,
    );
    return (
      prefs: prefs,
      bridge: bridge,
      homeVm: homeVm,
      nfcVm: nfcVm,
      gridVm: gridVm,
    );
  }

  Widget buildApp(({
    PreferencesService prefs,
    _ToolsHubTestBridge bridge,
    HomeViewModel homeVm,
    NfcViewModel nfcVm,
    HomeGridViewModel gridVm,
  }) harness) {
    return ReviewLinkGeneratorApp(
      preferencesService: harness.prefs,
      hardwareBridge: harness.bridge,
      homeViewModel: harness.homeVm,
      nfcViewModel: harness.nfcVm,
      homeGridViewModel: harness.gridVm,
      enableAutoOnboarding: false,
      enableStartupUpdateCheck: false,
    );
  }

  group('ToolsHubScreen Deep Tools Catalog', () {
    testWidgets(
      'lists all 6 catalog tools as full-width 3x1 rows, hides plus buttons when pinned, and mirrors layout cleanly in Arabic RTL',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 1. Default pinned state in EN LTR: all 6 tools show '-' unpin button, 0 '+' buttons, plus coming-soon footer.
        final enHarness = await createHarness(lang: 'en');
        await tester.pumpWidget(buildApp(enHarness));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tools_hub_screen')), findsOneWidget);
        expect(find.byKey(const Key('btn_hub_launch_tools_hub')), findsNothing);
        expect(find.byKey(const Key('btn_hub_pin_tools_hub')), findsNothing);
        expect(
          find.byKey(const Key('tools_hub_coming_soon_footer')),
          findsOneWidget,
        );

        for (final tool in ToolRegistry.hubTools) {
          final launchKey = Key('btn_hub_launch_${tool.id.storageKey}');
          final pinKey = Key('btn_hub_pin_${tool.id.storageKey}');
          final unpinKey = Key('btn_hub_unpin_${tool.id.storageKey}');
          expect(find.byKey(launchKey), findsOneWidget);
          expect(find.byKey(pinKey), findsNothing);
          expect(find.byKey(unpinKey), findsOneWidget);
          expect(tester.getRect(find.byKey(launchKey)).width, greaterThan(340));
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        enHarness.gridVm.dispose();
        enHarness.nfcVm.dispose();
        enHarness.homeVm.dispose();
        enHarness.bridge.dispose();

        // 2. Arabic RTL with unpinned wifi_card: icon is on the right, '+' is on the far left.
        final arHarness = await createHarness(
          lang: 'ar',
          themeMode: ThemeMode.light,
        );
        await arHarness.gridVm.unpinTool(HomeToolId.wifiCard);

        await tester.pumpWidget(buildApp(arHarness));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        final rowFinder = find.byKey(const Key('btn_hub_launch_wifi_card'));
        final pinFinder = find.byKey(const Key('btn_hub_pin_wifi_card'));
        expect(rowFinder, findsOneWidget);
        expect(pinFinder, findsOneWidget);

        final rowRect = tester.getRect(rowFinder);
        final pinRect = tester.getRect(pinFinder);
        final titleRect = tester.getRect(
          find.descendant(
            of: rowFinder,
            matching: find.text('كرت Wi-Fi'),
          ),
        );

        // In RTL, '+' sits toward the far left and title/icon are to its right.
        expect(pinRect.right, lessThan(titleRect.left));
        expect(titleRect.right, lessThan(rowRect.right - 40));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        arHarness.gridVm.dispose();
        arHarness.nfcVm.dispose();
        arHarness.homeVm.dispose();
        arHarness.bridge.dispose();
      },
    );

    testWidgets(
      'shows plus only on unpinned tools, pins tool on tap, keeps row without plus, shows toast, and restores on Home',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.gridVm.dispose();
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await harness.gridVm.unpinTool(HomeToolId.inspectCard);
        await harness.gridVm.unpinTool(HomeToolId.wifiCard);

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_tool_wifi_card')), findsNothing);
        expect(find.byKey(const Key('btn_tool_inspect_card')), findsNothing);

        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        // Only unpinned tools show '+', pinned tools show '-'
        expect(find.byKey(const Key('btn_hub_pin_inspect_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_hub_pin_wifi_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_hub_pin_clone_card')), findsNothing);
        expect(find.byKey(const Key('btn_hub_unpin_clone_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_hub_pin_pin_lock')), findsNothing);
        expect(find.byKey(const Key('btn_hub_unpin_pin_lock')), findsOneWidget);

        // Tap '+' on wifiCard -> pins and flips button to '-'
        await tester.tap(find.byKey(const Key('btn_hub_pin_wifi_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.byKey(const Key('btn_hub_launch_wifi_card')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_hub_pin_wifi_card')), findsNothing);
        expect(find.byKey(const Key('btn_hub_unpin_wifi_card')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_hub_pin_inspect_card')),
          findsOneWidget,
        );
        expect(find.text('Added to Home screen'), findsOneWidget);
        expect(harness.gridVm.isPinned(HomeToolId.wifiCard), isTrue);

        // Tap '-' on cloneCard -> unpins from Home and flips button to '+'
        await tester.tap(find.byKey(const Key('btn_hub_unpin_clone_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Removed from Home screen'), findsOneWidget);
        expect(find.byKey(const Key('btn_hub_pin_clone_card')), findsOneWidget);
        expect(harness.gridVm.isPinned(HomeToolId.cloneCard), isFalse);

        // Return to Home and verify wifiCard is restored while inspectCard & cloneCard stay unpinned
        await tester.tap(find.byKey(const Key('btn_tools_hub_back')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tools_hub_screen')), findsNothing);
        expect(find.byKey(const Key('btn_tool_wifi_card')), findsOneWidget);
        expect(find.byKey(const Key('btn_tool_inspect_card')), findsNothing);
        expect(find.byKey(const Key('btn_tool_read_card')), findsNothing);

        // Wait out toast auto-dismiss timer cleanly.
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'quick launch from ToolsHubScreen opens tool over hub and keeps user on ToolsHubScreen after closing',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final harness = await createHarness(lang: 'en');
        addTearDown(() {
          harness.gridVm.dispose();
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        });

        await harness.gridVm.unpinTool(HomeToolId.wifiCard);

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        // Quick-launch unpinned Wi-Fi Card -> opens Wi-Fi Wizard modal OVER ToolsHub (without pinning it).
        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_hub_launch_wifi_card')));
        await tester.pumpAndSettle();

        expect(find.byType(NfcModalDialog), findsOneWidget);
        expect(find.text('Network Name'), findsOneWidget);
        expect(harness.gridVm.isPinned(HomeToolId.wifiCard), isFalse);

        // Dismiss Wi-Fi modal -> user stays on ToolsHubScreen!
        await tester.tap(find.byKey(const Key('btn_close_wifi_modal')));
        await tester.pumpAndSettle();
        expect(find.byType(NfcModalDialog), findsNothing);
        expect(find.byKey(const Key('tools_hub_screen')), findsOneWidget);

        // Quick-launch pinned Inspect Card directly from ToolsHub -> pushes TagInspectorScreen on top.
        await tester.tap(find.byKey(const Key('btn_hub_launch_inspect_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('tag_inspector_screen')), findsOneWidget);
        expect(harness.bridge.inspectStartCalls, 1);

        // Closing TagInspectorScreen returns directly to ToolsHubScreen.
        await tester.tap(find.byKey(const Key('btn_inspector_back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tag_inspector_screen')), findsNothing);
        expect(find.byKey(const Key('tools_hub_screen')), findsOneWidget);

        // Tapping Hub Back returns to HomeScreen cleanly.
        await tester.tap(find.byKey(const Key('btn_tools_hub_back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tools_hub_screen')), findsNothing);
        expect(find.byKey(const Key('btn_tool_hub')), findsOneWidget);
      },
    );
  });
}
