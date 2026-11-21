/// Dedicated Deep Tools Hub screen surfacing all registered catalog tools
/// in full-width 3x1 rows with instant quick-launch and one-tap pinning.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/toast_message.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_glow_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../home_grid/models/grid_tile_models.dart';
import '../../home_grid/registry/tool_registry.dart';
import '../../home_grid/view_models/home_grid_view_model.dart';
import '../../home_grid/widgets/tool_tile_visuals.dart';
import 'tools_hub_row_card.dart';

/// Displays all cataloged tools eligible for quick launch or pinning onto the
/// customizable home screen grid.
class ToolsHubScreen extends StatelessWidget {
  const ToolsHubScreen({
    super.key,
    required this.gridViewModel,
    required this.onShowToast,
    required this.onLaunchTool,
    this.isArabic = false,
  });

  /// Reactive grid coordinator checked live to toggle `+` / `-` pin badges.
  final HomeGridViewModel gridViewModel;

  /// Callback used to present user feedback when a tool is pinned/unpinned.
  final void Function(String message, {ToastType type}) onShowToast;

  /// Launches a tool cleanly on top of this screen without dismissing it.
  final Future<void> Function(BuildContext hubContext, HomeToolId toolId)
      onLaunchTool;

  /// Whether Arabic display font should style header typography.
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final hubTools = ToolRegistry.hubTools;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.currentOverlayStyle,
      child: AmbientGlowScaffold(
        key: const Key('tools_hub_screen'),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: <Widget>[
                  _buildTopBar(context, l10n, isRtl),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: gridViewModel,
                      builder: (BuildContext context, _) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              GlassCard(
                                padding: const EdgeInsets.all(14),
                                margin: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    for (var i = 0;
                                        i < hubTools.length;
                                        i++) ...<Widget>[
                                      if (i > 0) const SizedBox(height: 10),
                                      _buildRow(
                                        context: context,
                                        definition: hubTools[i],
                                        l10n: l10n,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                key: const Key('tools_hub_coming_soon_footer'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 16,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        l10n.toolsHubComingSoon,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12.2,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required HomeToolDefinition definition,
    required AppLocalizations l10n,
  }) {
    final isPinned = gridViewModel.isPinned(definition.id);
    final presentation = ToolTileVisuals.resolve(definition.id, l10n);

    return ToolsHubRowCard(
      definition: definition,
      presentation: presentation,
      isPinned: isPinned,
      onLaunch: () => unawaited(onLaunchTool(context, definition.id)),
      onPin: () {
        unawaited(() async {
          await gridViewModel.pinTool(definition.id);
          onShowToast(l10n.toolsHubPinAdded, type: ToastType.success);
        }());
      },
      onUnpin: () {
        unawaited(() async {
          await gridViewModel.unpinTool(definition.id);
          onShowToast(l10n.toolsHubPinRemoved, type: ToastType.info);
        }());
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppLocalizations l10n,
    bool isRtl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: <Widget>[
          PressableScale(
            key: const Key('btn_tools_hub_back'),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.topBarButtonBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: isRtl ? 0.5 : 0.0,
                  duration: AppMotion.duration(
                    context,
                    const Duration(milliseconds: 260),
                  ),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.lblToolsHub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Inter',
                    color: AppColors.textPrimary,
                    fontSize: 19.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.lblToolsHubSub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
