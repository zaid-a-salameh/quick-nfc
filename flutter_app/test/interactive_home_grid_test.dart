import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/data/services/hardware_bridge_service.dart';
import 'package:review_link_generator/data/services/preferences_service.dart';
import 'package:review_link_generator/domain/models/nfc_models.dart';
import 'package:review_link_generator/main.dart';
import 'package:review_link_generator/ui/features/home/view_models/home_view_model.dart';
import 'package:review_link_generator/ui/features/home_grid/models/grid_tile_models.dart';
import 'package:review_link_generator/ui/features/home_grid/view_models/home_grid_view_model.dart';
import 'package:review_link_generator/ui/features/home_grid/widgets/interactive_home_grid.dart';
import 'package:review_link_generator/ui/features/nfc/view_models/nfc_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GridTestBridge extends HardwareBridgeService {
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
    _GridTestBridge bridge,
    HomeViewModel homeVm,
    NfcViewModel nfcVm,
    HomeGridViewModel gridVm,
  })> createHarness({
    String lang = 'en',
    ThemeMode themeMode = ThemeMode.dark,
    bool hintDismissed = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lang': lang,
      'app_theme_mode': themeMode.name,
      'review_link_flutter_onboarding_v1': true,
      if (hintDismissed) 'home_grid_customize_hint_dismissed_v1': true,
    });
    final prefs = await PreferencesService.create();
    final bridge = _GridTestBridge();
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
    _GridTestBridge bridge,
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

  Future<void> longPressHold(WidgetTester tester, Finder target) async {
    final center = tester.getCenter(target);
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> longPressAndDrag(
    WidgetTester tester,
    Finder target,
    Offset delta,
  ) async {
    final start = tester.getCenter(target);
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(start + delta * (i / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('InteractiveHomeGrid layout, themes, locales, and gestures', () {
    testWidgets(
      'renders default 3x4 geometry across EN LTR / AR RTL, Light / Dark, and 360x800 without overflow',
      (WidgetTester tester) async {
        final configs = <({String lang, ThemeMode theme, Size size})>[
          (lang: 'en', theme: ThemeMode.dark, size: const Size(430, 932)),
          (lang: 'ar', theme: ThemeMode.light, size: const Size(360, 800)),
        ];

        for (final cfg in configs) {
          await tester.binding.setSurfaceSize(cfg.size);
          final harness = await createHarness(
            lang: cfg.lang,
            themeMode: cfg.theme,
          );

          await tester.pumpWidget(buildApp(harness));
          await tester.pumpAndSettle();

          final inspect = find.byKey(const Key('btn_tool_inspect_card'));
          final clone = find.byKey(const Key('btn_tool_read_card'));
          final wifi = find.byKey(const Key('btn_tool_wifi_card'));
          final pin = find.byKey(const Key('btn_tool_pin_lock'));
          final erase = find.byKey(const Key('btn_tool_erase_card'));
          final perm = find.byKey(const Key('btn_tool_perm_lock'));
          final hub = find.byKey(const Key('btn_tool_hub'));
          final github = find.byKey(const Key('btn_github_project'));

          expect(find.byType(InteractiveHomeGrid), findsOneWidget);
          expect(inspect, findsOneWidget);
          expect(clone, findsOneWidget);
          expect(wifi, findsOneWidget);
          expect(pin, findsOneWidget);
          expect(erase, findsOneWidget);
          expect(perm, findsOneWidget);
          expect(hub, findsOneWidget);
          expect(github, findsOneWidget);

          final inspectRect = tester.getRect(inspect);
          final cloneRect = tester.getRect(clone);
          final wifiRect = tester.getRect(wifi);
          final pinRect = tester.getRect(pin);
          final eraseRect = tester.getRect(erase);
          final permRect = tester.getRect(perm);
          final hubRect = tester.getRect(hub);
          final githubRect = tester.getRect(github);

          // Vertical row ordering: inspect(0) < clone/wifi(1) < pin/erase/perm(2) < hub(3) < github
          expect(inspectRect.bottom, lessThan(cloneRect.top));
          expect(cloneRect.bottom, lessThan(pinRect.top));
          expect(pinRect.bottom, lessThan(hubRect.top));
          expect(hubRect.bottom, lessThan(githubRect.top));

          // Width proportions: 3x1 equals full width, Row 1 clone + wifi auto-fill equal 50%/50%
          final expectedHalfWidth =
              (hubRect.width - InteractiveHomeGrid.gridGap) / 2;
          expect((inspectRect.width - hubRect.width).abs(), lessThan(1.0));
          expect((wifiRect.width - expectedHalfWidth).abs(), lessThan(1.5));
          expect((cloneRect.width - expectedHalfWidth).abs(), lessThan(1.5));

          // RTL vs LTR horizontal mirroring on row 2
          if (cfg.lang == 'en') {
            expect(pinRect.right, lessThan(eraseRect.left));
            expect(eraseRect.right, lessThan(permRect.left));
            expect(cloneRect.right, lessThan(wifiRect.left));
          } else {
            expect(pinRect.left, greaterThan(eraseRect.right));
            expect(eraseRect.left, greaterThan(permRect.right));
            expect(cloneRect.left, greaterThan(wifiRect.right));
          }

          // Unmount the widget tree before disposing externally owned ViewModels.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          harness.gridVm.dispose();
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        }
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'normal taps invoke tools without entering edit mode and toolsHub opens ToolsHubScreen',
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

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        // Tap toolsHub -> stays out of edit mode and opens ToolsHubScreen.
        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        expect(harness.gridVm.isEditing, isFalse);
        expect(find.byKey(const Key('tools_hub_screen')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_tools_hub_back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tools_hub_screen')), findsNothing);

        await tester.ensureVisible(
          find.byKey(const Key('btn_tool_inspect_card')),
        );
        await tester.tap(find.byKey(const Key('btn_tool_inspect_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byKey(const Key('tag_inspector_screen')), findsOneWidget);
        expect(harness.bridge.inspectStartCalls, 1);
      },
    );

    testWidgets(
      'long-press opens edit mode with 4 resize dots and enforces non-removable toolsHub',
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

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        await longPressHold(tester, find.byKey(const Key('btn_tool_wifi_card')));

        expect(harness.gridVm.isEditing, isTrue);
        expect(harness.gridVm.selectedTileId, HomeToolId.wifiCard);
        expect(find.byKey(const Key('btn_grid_done')), findsOneWidget);
        expect(find.byKey(const Key('btn_grid_reset')), findsOneWidget);
        expect(find.byKey(const Key('btn_unpin_wifi_card')), findsOneWidget);

        for (final edge in ResizeEdge.values) {
          expect(
            find.byKey(Key('resize_handle_wifi_card_${edge.name}')),
            findsOneWidget,
          );
        }

        // Selecting toolsHub shows all 4 resize dots but NEVER an unpin button.
        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        expect(harness.gridVm.selectedTileId, HomeToolId.toolsHub);
        expect(find.byKey(const Key('btn_unpin_tools_hub')), findsNothing);
        for (final edge in ResizeEdge.values) {
          expect(
            find.byKey(Key('resize_handle_tools_hub_${edge.name}')),
            findsOneWidget,
          );
        }

        // Done button exits edit mode.
        await tester.tap(find.byKey(const Key('btn_grid_done')));
        await tester.pumpAndSettle();
        expect(harness.gridVm.isEditing, isFalse);
        expect(find.byKey(const Key('btn_grid_done')), findsNothing);

        // Long-press again, then tap outside header/margin to clear edit mode.
        await longPressHold(
          tester,
          find.byKey(const Key('btn_tool_inspect_card')),
        );
        expect(harness.gridVm.isEditing, isTrue);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(harness.gridVm.isEditing, isFalse);
      },
    );

    testWidgets(
      'long-press and drag reorders tiles in both LTR and RTL and persists across restart',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 1. LTR: drag permLock (rightmost col 2) onto pinLock (leftmost col 0) -> swap
        final ltrHarness = await createHarness(lang: 'en');
        await tester.pumpWidget(buildApp(ltrHarness));
        await tester.pumpAndSettle();

        final pinFinder = find.byKey(const Key('btn_tool_pin_lock'));
        final permFinder = find.byKey(const Key('btn_tool_perm_lock'));
        final ltrDelta = tester.getCenter(pinFinder) - tester.getCenter(permFinder);

        await longPressAndDrag(tester, permFinder, ltrDelta);

        expect(ltrHarness.gridVm.tileFor(HomeToolId.permLock)!.col, 0);
        expect(ltrHarness.gridVm.tileFor(HomeToolId.pinLock)!.col, 2);
        expect(
          tester.getRect(permFinder).right,
          lessThan(tester.getRect(pinFinder).left),
        );

        // Recreate HomeGridViewModel from persisted SharedPreferences to prove reload parity.
        final reloadedVm = HomeGridViewModel(
          preferencesService: ltrHarness.prefs,
          hardwareBridge: ltrHarness.bridge,
        );
        expect(reloadedVm.tileFor(HomeToolId.permLock)!.col, 0);
        expect(reloadedVm.tileFor(HomeToolId.pinLock)!.col, 2);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        reloadedVm.dispose();
        ltrHarness.gridVm.dispose();
        ltrHarness.nfcVm.dispose();
        ltrHarness.homeVm.dispose();
        ltrHarness.bridge.dispose();

        // 2. AR RTL: permLock starts on visual LEFT; dragging rightward onto pinLock moves it to col 0 (visual RIGHT).
        final rtlHarness = await createHarness(lang: 'ar');
        await tester.pumpWidget(buildApp(rtlHarness));
        await tester.pumpAndSettle();

        final rtlPinFinder = find.byKey(const Key('btn_tool_pin_lock'));
        final rtlPermFinder = find.byKey(const Key('btn_tool_perm_lock'));
        final rtlDelta =
            tester.getCenter(rtlPinFinder) - tester.getCenter(rtlPermFinder);

        expect(rtlDelta.dx, greaterThan(0));
        await longPressAndDrag(tester, rtlPermFinder, rtlDelta);

        expect(rtlHarness.gridVm.tileFor(HomeToolId.permLock)!.col, 0);
        expect(rtlHarness.gridVm.tileFor(HomeToolId.pinLock)!.col, 2);
        expect(
          tester.getRect(rtlPermFinder).left,
          greaterThan(tester.getRect(rtlPinFinder).right),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        rtlHarness.gridVm.dispose();
        rtlHarness.nfcVm.dispose();
        rtlHarness.homeVm.dispose();
        rtlHarness.bridge.dispose();
      },
    );

    testWidgets(
      '4-edge dot drag resizing enforces allowed spans and updates bounds live with persistence',
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

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        // 1. Expand wifiCard (2x1) via bottom dot -> 2x2
        await longPressHold(tester, find.byKey(const Key('btn_tool_wifi_card')));
        await tester.drag(
          find.byKey(const Key('resize_handle_wifi_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();

        final wifiTile = harness.gridVm.tileFor(HomeToolId.wifiCard)!;
        expect(wifiTile.span, GridSpan.twoByTwo);
        final wifiRect = tester.getRect(find.byKey(const Key('btn_tool_wifi_card')));
        expect(wifiRect.height, greaterThan(150));

        // Reset to clean state and verify 1x1 vertical bottom drag snaps forbidden 1x2 -> 2x2
        await tester.tap(find.byKey(const Key('btn_grid_reset')));
        await tester.pumpAndSettle();

        await longPressHold(tester, find.byKey(const Key('btn_tool_read_card')));
        await tester.drag(
          find.byKey(const Key('resize_handle_clone_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();
        expect(
          harness.gridVm.tileFor(HomeToolId.cloneCard)!.span,
          GridSpan.twoByTwo,
        );

        // Shrink toolsHub via right dot (3x1 -> 2x1)
        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();

        final hubRight = find.byKey(const Key('resize_handle_tools_hub_right'));
        await tester.ensureVisible(hubRight);
        await tester.drag(hubRight, const Offset(-120, 0));
        await tester.pumpAndSettle();

        expect(
          harness.gridVm.tileFor(HomeToolId.toolsHub)!.span,
          GridSpan.twoByOne,
        );

        // Reset and test left-edge anchor resize: permLock (col 2, 1x1) growing left -> col 1, 2x1
        await tester.ensureVisible(find.byKey(const Key('btn_grid_reset')));
        await tester.tap(find.byKey(const Key('btn_grid_reset')));
        await tester.pumpAndSettle();

        await longPressHold(tester, find.byKey(const Key('btn_tool_perm_lock')));
        final permLeft = find.byKey(const Key('resize_handle_perm_lock_left'));
        await tester.drag(permLeft, const Offset(-120, 0));
        await tester.pumpAndSettle();

        final resizedPerm = harness.gridVm.tileFor(HomeToolId.permLock)!;
        expect(resizedPerm.span, GridSpan.twoByOne);
        expect(resizedPerm.endCol, 3);

        // Verify persistence after resize.
        final reloaded = HomeGridViewModel(
          preferencesService: harness.prefs,
          hardwareBridge: harness.bridge,
        );
        expect(reloaded.tileFor(HomeToolId.permLock), resizedPerm);
        reloaded.dispose();
      },
    );

    testWidgets(
      'unpinning removable tile compacts lower tiles upward and reset restores all 7 tiles',
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

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        final initialCloneTop =
            tester.getRect(find.byKey(const Key('btn_tool_read_card'))).top;
        final initialHubTop =
            tester.getRect(find.byKey(const Key('btn_tool_hub'))).top;

        await longPressHold(
          tester,
          find.byKey(const Key('btn_tool_inspect_card')),
        );
        await tester.tap(find.byKey(const Key('btn_unpin_inspect_card')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_tool_inspect_card')), findsNothing);
        expect(harness.gridVm.isPinned(HomeToolId.inspectCard), isFalse);
        expect(harness.gridVm.totalRows, 3);

        final compactedCloneTop =
            tester.getRect(find.byKey(const Key('btn_tool_read_card'))).top;
        final compactedHubTop =
            tester.getRect(find.byKey(const Key('btn_tool_hub'))).top;
        expect(compactedCloneTop, lessThan(initialCloneTop));
        expect(compactedHubTop, lessThan(initialHubTop));

        // Reset restores all 7 default tiles cleanly.
        await longPressHold(tester, find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_grid_reset')));
        await tester.pumpAndSettle();

        expect(harness.gridVm.tiles.length, 7);
        expect(harness.gridVm.isPinned(HomeToolId.inspectCard), isTrue);
        expect(find.byKey(const Key('btn_tool_inspect_card')), findsOneWidget);
      },
    );

    testWidgets(
      'auto-fills two 1x1 tiles to 50%/50%, supports 3x2 resize, enlarges unpin button, and hides 2x1 subtitles',
      (WidgetTester tester) async {
        // 1. Check 2x1 subtitle hidden vs 3x1 subtitle visible & 3x2 resize + 42x42 unpin hit box
        await tester.binding.setSurfaceSize(const Size(430, 932));
        var harness = await createHarness(lang: 'en');
        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        // 3x1 inspectCard shows subtitle, 2x1 wifiCard hides subtitle.
        final inspectFinder = find.byKey(const Key('btn_tool_inspect_card'));
        final wifiFinder = find.byKey(const Key('btn_tool_wifi_card'));
        expect(
          find.descendant(
            of: inspectFinder,
            matching: find.text('Full chip info, signature & NDEF records'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: wifiFinder,
            matching: find.text('Write Wi-Fi credentials to NFC'),
          ),
          findsNothing,
        );

        // Select inspectCard -> enlarged unpin hit target >= 40x40
        await longPressHold(tester, inspectFinder);
        final unpinFinder = find.byKey(const Key('btn_unpin_inspect_card'));
        expect(unpinFinder, findsOneWidget);
        final unpinSize = tester.getSize(unpinFinder);
        expect(unpinSize.width, greaterThanOrEqualTo(40.0));
        expect(unpinSize.height, greaterThanOrEqualTo(40.0));

        // Resize inspectCard (3x1) downward via bottom dot -> 3x2 Hero (> 150px)
        await tester.drag(
          find.byKey(const Key('resize_handle_inspect_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();

        expect(
          harness.gridVm.tileFor(HomeToolId.inspectCard)!.span,
          GridSpan.threeByTwo,
        );
        final inspectHeroRect = tester.getRect(inspectFinder);
        expect(inspectHeroRect.height, greaterThan(150));
        expect(
          find.descendant(
            of: inspectFinder,
            matching: find.text('Full chip info, signature & NDEF records'),
          ),
          findsOneWidget,
        );

        // Resize toolsHub (3x1) to 2x1 to verify 2x1 hides subtitle while 3x1/2x2/3x2 show it.
        await tester.ensureVisible(find.byKey(const Key('btn_tool_hub')));
        await tester.tap(find.byKey(const Key('btn_tool_hub')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('resize_handle_tools_hub_right')),
        );
        await tester.drag(
          find.byKey(const Key('resize_handle_tools_hub_right')),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();
        expect(
          harness.gridVm.tileFor(HomeToolId.toolsHub)!.span,
          GridSpan.twoByOne,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('btn_tool_hub')),
            matching: find.text('Explore & pin tools to Home'),
          ),
          findsNothing,
        );

        // Check 2x2 subtitle visibility by resizing wifiCard (1x1 -> 2x2)
        await tester.ensureVisible(wifiFinder);
        await tester.tap(wifiFinder);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('resize_handle_wifi_card_bottom')),
        );
        await tester.drag(
          find.byKey(const Key('resize_handle_wifi_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();
        expect(
          harness.gridVm.tileFor(HomeToolId.wifiCard)!.span,
          GridSpan.twoByTwo,
        );
        expect(
          find.descendant(
            of: wifiFinder,
            matching: find.text('Write Wi-Fi credentials to NFC'),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        harness.gridVm.dispose();
        harness.nfcVm.dispose();
        harness.homeVm.dispose();
        harness.bridge.dispose();

        // 2. Test 50%/50% horizontal auto-fill when unpinning permLock leaves
        // two 1x1 tiles (pinLock & eraseCard) on the same row in EN LTR & AR RTL.
        for (final lang in const <String>['en', 'ar']) {
          harness = await createHarness(lang: lang);
          await tester.pumpWidget(buildApp(harness));
          await tester.pumpAndSettle();

          await longPressHold(tester, find.byKey(const Key('btn_tool_perm_lock')));
          await tester.tap(find.byKey(const Key('btn_unpin_perm_lock')));
          await tester.pumpAndSettle();

          final pinRect =
              tester.getRect(find.byKey(const Key('btn_tool_pin_lock')));
          final eraseRect =
              tester.getRect(find.byKey(const Key('btn_tool_erase_card')));
          final hubRect =
              tester.getRect(find.byKey(const Key('btn_tool_hub')));

          final expectedHalfWidth =
              (hubRect.width - InteractiveHomeGrid.gridGap) / 2;
          expect((pinRect.width - expectedHalfWidth).abs(), lessThan(1.5));
          expect((eraseRect.width - expectedHalfWidth).abs(), lessThan(1.5));

          if (lang == 'en') {
            expect(pinRect.right, lessThan(eraseRect.left));
            expect((pinRect.left - hubRect.left).abs(), lessThan(1.0));
            expect((eraseRect.right - hubRect.right).abs(), lessThan(1.0));
          } else {
            expect(pinRect.left, greaterThan(eraseRect.right));
            expect((pinRect.right - hubRect.right).abs(), lessThan(1.0));
            expect((eraseRect.left - hubRect.left).abs(), lessThan(1.0));
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          harness.gridVm.dispose();
          harness.nfcVm.dispose();
          harness.homeVm.dispose();
          harness.bridge.dispose();
        }
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'Settings grid card descriptions switch hides and restores subtitles on 3x1, 2x2, and 3x2 tiles',
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

        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        final inspectFinder = find.byKey(const Key('btn_tool_inspect_card'));
        final hubFinder = find.byKey(const Key('btn_tool_hub'));

        // Initially descriptions are visible on 3x1 tiles.
        expect(
          find.descendant(
            of: inspectFinder,
            matching: find.text('Full chip info, signature & NDEF records'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: hubFinder,
            matching: find.text('Explore & pin tools to Home'),
          ),
          findsOneWidget,
        );

        // Also prepare a 2x2 tile (wifiCard) and 3x2 tile (inspectCard).
        await longPressHold(tester, find.byKey(const Key('btn_tool_wifi_card')));
        await tester.drag(
          find.byKey(const Key('resize_handle_wifi_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();

        await longPressHold(tester, inspectFinder);
        await tester.drag(
          find.byKey(const Key('resize_handle_inspect_card_bottom')),
          const Offset(0, 86),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_grid_done')));
        await tester.pumpAndSettle();

        // Open Settings and toggle switch_grid_descriptions OFF.
        await tester.ensureVisible(find.byKey(const Key('btn_open_settings')));
        await tester.tap(find.byKey(const Key('btn_open_settings')));
        await tester.pumpAndSettle();

        final toggle = find.byKey(const Key('switch_grid_descriptions'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(harness.homeVm.showGridDescriptions, isFalse);

        // Return to Home -> subtitles hidden across 3x2, 2x2, and 3x1 tiles.
        await tester.tap(find.byKey(const Key('btn_settings_back')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: inspectFinder,
            matching: find.text('Full chip info, signature & NDEF records'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('btn_tool_wifi_card')),
            matching: find.text('Write Wi-Fi credentials to NFC'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: hubFinder,
            matching: find.text('Explore & pin tools to Home'),
          ),
          findsNothing,
        );

        // Toggle back ON in Settings -> descriptions restored on Home.
        await tester.ensureVisible(find.byKey(const Key('btn_open_settings')));
        await tester.tap(find.byKey(const Key('btn_open_settings')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(harness.homeVm.showGridDescriptions, isTrue);

        await tester.tap(find.byKey(const Key('btn_settings_back')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: inspectFinder,
            matching: find.text('Full chip info, signature & NDEF records'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('btn_tool_wifi_card')),
            matching: find.text('Write Wi-Fi credentials to NFC'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: hubFinder,
            matching: find.text('Explore & pin tools to Home'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows one-time grid customize coach hint initially and permanently dismisses on tap or first edit',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 1. Explicit X dismiss persists across reload.
        var harness = await createHarness(lang: 'en', hintDismissed: false);
        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('grid_customize_hint_banner')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('btn_dismiss_grid_hint')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('grid_customize_hint_banner')),
          findsNothing,
        );
        expect(harness.prefs.isGridCustomizeHintDismissed, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        harness.gridVm.dispose();
        harness.nfcVm.dispose();
        harness.homeVm.dispose();
        harness.bridge.dispose();

        // Reload with same prefs -> hint remains gone.
        final reloadedGridVm = HomeGridViewModel(
          preferencesService: harness.prefs,
          hardwareBridge: harness.bridge,
        );
        expect(reloadedGridVm.showCustomizeHint, isFalse);
        reloadedGridVm.dispose();

        // 2. First long-press to edit also consumes & persists hint dismissal.
        harness = await createHarness(lang: 'en', hintDismissed: false);
        await tester.pumpWidget(buildApp(harness));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('grid_customize_hint_banner')),
          findsOneWidget,
        );

        await longPressHold(tester, find.byKey(const Key('btn_tool_inspect_card')));
        await tester.tap(find.byKey(const Key('btn_grid_done')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('grid_customize_hint_banner')),
          findsNothing,
        );
        expect(harness.prefs.isGridCustomizeHintDismissed, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        harness.gridVm.dispose();
        harness.nfcVm.dispose();
        harness.homeVm.dispose();
        harness.bridge.dispose();
      },
    );
  });
}
