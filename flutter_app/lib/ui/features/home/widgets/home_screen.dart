import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/toast_message.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_glow_scaffold.dart';
import '../../home_grid/models/grid_tile_models.dart';
import '../../home_grid/view_models/home_grid_view_model.dart';
import '../../home_grid/widgets/interactive_home_grid.dart';
import '../../nfc/view_models/nfc_view_model.dart';
import '../../nfc/widgets/nfc_modal_dialog.dart';
import '../../onboarding/onboarding_modal_dialog.dart';
import '../../qr/qr_modal_dialog.dart';
import '../../settings/widgets/settings_screen.dart';
import '../../tag_inspector/widgets/tag_inspector_screen.dart';
import '../../tools_hub/widgets/tools_hub_screen.dart';
import '../../updater/update_modal_dialog.dart';
import '../view_models/home_view_model.dart';
import 'github_dock_button.dart';
import 'header_widget.dart';
import 'main_input_card.dart';
import 'result_card.dart';
import 'top_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.homeViewModel,
    required this.nfcViewModel,
    required this.homeGridViewModel,
    this.enableAutoOnboarding = true,
    this.enableStartupUpdateCheck = true,
  });

  final HomeViewModel homeViewModel;
  final NfcViewModel nfcViewModel;
  final HomeGridViewModel homeGridViewModel;
  final bool enableAutoOnboarding;
  final bool enableStartupUpdateCheck;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  final GlobalKey _resultCardAnchorKey = GlobalKey();
  Timer? _onboardingTimer;
  int _lastResultRevealTick = 0;
  bool _wasGridEditing = false;
  bool _wasGridScrollLocked = false;

  bool get _gridScrollLocked =>
      widget.homeGridViewModel.draggingTileId != null ||
      widget.homeGridViewModel.resizingTileId != null;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    _lastResultRevealTick = widget.homeViewModel.resultRevealTick;
    _wasGridEditing = widget.homeGridViewModel.isEditing;
    _wasGridScrollLocked = _gridScrollLocked;
    widget.homeViewModel.addListener(_handleHomeViewModelChanged);
    widget.homeGridViewModel.addListener(_handleHomeGridChanged);

    if (widget.enableAutoOnboarding &&
        widget.homeViewModel.shouldAutoShowOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onboardingTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (widget.homeViewModel.shouldAutoShowOnboarding) {
            _openOnboardingTour();
          }
        });
      });
    }

    if (widget.enableStartupUpdateCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.homeViewModel.initializeStartupChecks();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.homeViewModel.removeListener(_handleHomeViewModelChanged);
    widget.homeGridViewModel.removeListener(_handleHomeGridChanged);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _onboardingTimer?.cancel();
    super.dispose();
  }

  void _handleHomeViewModelChanged() {
    final tick = widget.homeViewModel.resultRevealTick;
    if (tick == _lastResultRevealTick) return;
    _lastResultRevealTick = tick;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetCtx = _resultCardAnchorKey.currentContext;
      if (targetCtx == null || !targetCtx.mounted) return;
      Scrollable.ensureVisible(
        targetCtx,
        alignment: 0.12,
        duration: AppMotion.duration(
          context,
          const Duration(milliseconds: 420),
        ),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleHomeGridChanged() {
    final editing = widget.homeGridViewModel.isEditing;
    final locked = _gridScrollLocked;
    if (editing != _wasGridEditing || locked != _wasGridScrollLocked) {
      _wasGridEditing = editing;
      _wasGridScrollLocked = locked;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      setState(() {});
    }
  }

  void _unfocusAll() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (widget.homeGridViewModel.isEditing) {
      widget.homeGridViewModel.clearSelection();
    }
  }

  Future<void> _handleCheckUpdate() async {
    _unfocusAll();
    final l10n = AppLocalizations.of(context)!;
    final update = widget.homeViewModel.availableUpdate;

    if (update != null) {
      await showAppUpdateModal(
        context: context,
        release: update,
        currentVersion: widget.homeViewModel.currentAppVersion,
        onInstall: () => widget.homeViewModel.startUpdateDownload(l10n),
        onDismiss: () {},
      );
      if (mounted) _unfocusAll();
      return;
    }

    final newRelease = await widget.homeViewModel.checkForUpdatesManual(l10n);
    if (newRelease != null && mounted) {
      await showAppUpdateModal(
        context: context,
        release: newRelease,
        currentVersion: widget.homeViewModel.currentAppVersion,
        onInstall: () => widget.homeViewModel.startUpdateDownload(l10n),
        onDismiss: () {},
      );
      if (mounted) _unfocusAll();
    }
  }

  Future<void> _openOnboardingTour() async {
    _unfocusAll();
    await showOnboardingTourModal(
      context: context,
      onCompleted: widget.homeViewModel.markOnboardingSeen,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _openSettings() async {
    _unfocusAll();
    final reduced = AppMotion.isReduced(context);
    await Navigator.of(context).push(
      reduced
          ? PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, _, _) =>
                  SettingsScreen(viewModel: widget.homeViewModel),
            )
          : MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(viewModel: widget.homeViewModel),
            ),
    );
    if (mounted) {
      _unfocusAll();
      setState(() {});
    }
  }

  Future<void> _handleWriteNfc(AppLocalizations l10n) async {
    _unfocusAll();
    final url = widget.homeViewModel.activeGeneratedUrl;
    if (url == null || url.isEmpty) {
      widget.homeViewModel.showToast(
        l10n.toastPasteFirst,
        type: ToastType.warn,
      );
      return;
    }
    widget.nfcViewModel.prepareWriteUrl(url);
    await showNfcOperationModal(
      context: context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _openTagInspector({BuildContext? launchContext}) async {
    final activeContext = launchContext ?? context;
    _unfocusAll();
    final l10n = AppLocalizations.of(context)!;
    final reduced = AppMotion.isReduced(activeContext);
    Widget buildInspector(BuildContext _) => TagInspectorScreen(
          hardwareBridge: widget.homeViewModel.hardwareBridge,
          onShowToast: widget.homeViewModel.showToast,
          isArabic: widget.homeViewModel.isArabic,
          onUseUrl: (String url) async {
            await widget.homeViewModel.importUrlFromNfcTag(url, l10n);
          },
        );

    await Navigator.of(activeContext).push(
      reduced
          ? PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (ctx, _, _) => buildInspector(ctx),
            )
          : MaterialPageRoute<void>(builder: buildInspector),
    );
    if (mounted) {
      _unfocusAll();
      setState(() {});
    }
  }

  Future<void> _handleReadNfc({BuildContext? launchContext}) async {
    _unfocusAll();
    widget.nfcViewModel.prepareReadCard();
    await showNfcOperationModal(
      context: launchContext ?? context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _handleOpenWifiWizard({BuildContext? launchContext}) async {
    _unfocusAll();
    widget.nfcViewModel.prepareWifiWizard();
    await showNfcOperationModal(
      context: launchContext ?? context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _handleOpenPinModal({BuildContext? launchContext}) async {
    _unfocusAll();
    widget.nfcViewModel.preparePinProtection();
    await showNfcOperationModal(
      context: launchContext ?? context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _handleOpenPermLockModal({BuildContext? launchContext}) async {
    _unfocusAll();
    widget.nfcViewModel.preparePermLockConfirm();
    await showNfcOperationModal(
      context: launchContext ?? context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  Future<void> _handleOpenEraseModal({BuildContext? launchContext}) async {
    _unfocusAll();
    widget.nfcViewModel.prepareEraseConfirm();
    await showNfcOperationModal(
      context: launchContext ?? context,
      viewModel: widget.nfcViewModel,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  void _handleSupportTapped(AppLocalizations l10n) {
    _unfocusAll();
    widget.homeViewModel.openSupportPage();
  }

  Future<void> _openToolsHub(AppLocalizations l10n) async {
    _unfocusAll();
    final reduced = AppMotion.isReduced(context);
    Widget buildHub(BuildContext _) => ToolsHubScreen(
          gridViewModel: widget.homeGridViewModel,
          onShowToast: widget.homeViewModel.showToast,
          isArabic: widget.homeViewModel.isArabic,
          onLaunchTool: (BuildContext hubCtx, HomeToolId toolId) =>
              _handleGridToolInvocation(
            toolId,
            l10n,
            launchContext: hubCtx,
          ),
        );

    await Navigator.of(context).push<void>(
      reduced
          ? PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (ctx, _, _) => buildHub(ctx),
            )
          : MaterialPageRoute<void>(builder: buildHub),
    );
    if (!mounted) return;
    _unfocusAll();
    setState(() {});
  }

  Future<void> _handleGridToolInvocation(
    HomeToolId toolId,
    AppLocalizations l10n, {
    BuildContext? launchContext,
  }) async {
    switch (toolId) {
      case HomeToolId.inspectCard:
        await _openTagInspector(launchContext: launchContext);
      case HomeToolId.cloneCard:
        await _handleReadNfc(launchContext: launchContext);
      case HomeToolId.wifiCard:
        await _handleOpenWifiWizard(launchContext: launchContext);
      case HomeToolId.pinLock:
        await _handleOpenPinModal(launchContext: launchContext);
      case HomeToolId.eraseCard:
        await _handleOpenEraseModal(launchContext: launchContext);
      case HomeToolId.permLock:
        await _handleOpenPermLockModal(launchContext: launchContext);
      case HomeToolId.toolsHub:
        await _openToolsHub(l10n);
    }
  }

  Future<void> _handleOpenQrModal(AppLocalizations l10n) async {
    _unfocusAll();
    final url = widget.homeViewModel.activeGeneratedUrl;
    if (url == null || url.isEmpty) {
      widget.homeViewModel.showToast(
        l10n.toastPasteFirst,
        type: ToastType.warn,
      );
      return;
    }
    await showQrCodeModal(
      context: context,
      data: url,
      hardwareBridge: widget.homeViewModel.hardwareBridge,
      onShowToast: widget.homeViewModel.showToast,
    );
    if (mounted) _unfocusAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    return ListenableBuilder(
      listenable: widget.homeViewModel,
      builder: (BuildContext context, _) {
        final vm = widget.homeViewModel;
        final themeMode = vm.themeMode;
        final isLight = themeMode == ThemeMode.light ||
            (themeMode == ThemeMode.system &&
                platformBrightness == Brightness.light);
        AppColors.isLight = isLight;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.currentOverlayStyle,
          child: PopScope(
            canPop: !vm.isDropdownOpen && !widget.homeGridViewModel.isEditing,
            onPopInvokedWithResult: (bool didPop, dynamic _) {
              if (!didPop) {
                if (widget.homeGridViewModel.isEditing) {
                  widget.homeGridViewModel.clearSelection();
                } else if (vm.isDropdownOpen) {
                  vm.hideDropdown();
                }
              }
            },
            child: AmbientGlowScaffold(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _unfocusAll,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: _gridScrollLocked
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TopBarWidget(
                              key: ValueKey<String>('top_bar_$isLight'),
                              currentVersion: vm.currentAppVersion,
                              hasUpdate: vm.availableUpdate != null,
                              isCheckingUpdate: vm.isCheckingUpdate,
                              onCheckUpdate: _handleCheckUpdate,
                              onOpenGuide: _openOnboardingTour,
                              onOpenSettings: _openSettings,
                            ),
                            HeaderWidget(
                              key: ValueKey<String>('header_$isLight'),
                            ),
                            MainInputCard(viewModel: vm),
                            KeyedSubtree(
                              key: _resultCardAnchorKey,
                              child: AnimatedSize(
                                duration: AppMotion.duration(
                                  context,
                                  const Duration(milliseconds: 320),
                                ),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedSwitcher(
                                  duration: AppMotion.duration(
                                    context,
                                    const Duration(milliseconds: 280),
                                  ),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (
                                    Widget child,
                                    Animation<double> animation,
                                  ) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, -0.06),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: (vm.currentResult.isResultActive &&
                                          (vm.activeGeneratedUrl?.isNotEmpty ??
                                              false))
                                      ? ResultCard(
                                          key: ValueKey<String>(
                                            'result_card_active_$isLight',
                                          ),
                                          viewModel: vm,
                                          onWriteNfc: () =>
                                              _handleWriteNfc(l10n),
                                          onOpenQr: () =>
                                              _handleOpenQrModal(l10n),
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey<String>(
                                            'result_card_empty',
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            InteractiveHomeGrid(
                              key: ValueKey<String>('tools_grid_$isLight'),
                              viewModel: widget.homeGridViewModel,
                              showDescriptions: vm.showGridDescriptions,
                              onInvokeTool: (HomeToolId id) =>
                                  _handleGridToolInvocation(id, l10n),
                            ),
                            if (!keyboardOpen)
                              GithubDockButton(
                                key: ValueKey<String>('github_dock_$isLight'),
                                onTapProject: vm.openGithubRepository,
                                onTapSupport: () => _handleSupportTapped(l10n),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
