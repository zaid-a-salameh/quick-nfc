/// Full-width 3x1 list row card representing a single tool in the Tools Hub.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../home_grid/registry/tool_registry.dart';
import '../../home_grid/widgets/bounded_adaptive_text.dart';
import '../../home_grid/widgets/tool_tile_visuals.dart';

/// Displays a [HomeToolDefinition] as a full-width 3x1 row with quick launch on
/// tap and a trailing `+` / `-` pin toggle action.
class ToolsHubRowCard extends StatelessWidget {
  const ToolsHubRowCard({
    super.key,
    required this.definition,
    required this.presentation,
    required this.isPinned,
    required this.onLaunch,
    required this.onPin,
    required this.onUnpin,
  });

  /// Registered tool metadata.
  final HomeToolDefinition definition;

  /// Localized colors, gradient, and icon builder shared with the home grid.
  final ToolTilePresentation presentation;

  /// Whether this tool is currently pinned on the home grid.
  final bool isPinned;

  /// Invoked when the user taps the card body to immediately launch the tool.
  final VoidCallback onLaunch;

  /// Invoked when the user taps `+` to pin the tool to Home.
  final VoidCallback onPin;

  /// Invoked when the user taps `-` to unpin the tool from Home.
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final hasBadgeGradient = presentation.badgeGradient != null;
    final badgeIconColor =
        presentation.badgeIconColor ?? presentation.accentColor;

    return PressableScale(
      key: Key('btn_hub_launch_${definition.id.storageKey}'),
      onTap: onLaunch,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: presentation.backgroundGradient == null
              ? presentation.backgroundColor
              : null,
          gradient: presentation.backgroundGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: presentation.borderColor, width: 1.1),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasBadgeGradient ? null : presentation.badgeColor,
                gradient: presentation.badgeGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: hasBadgeGradient
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: presentation.iconBuilder(23, badgeIconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  BoundedAdaptiveText(
                    presentation.title,
                    maxLines: 1,
                    candidateSizes: const <double>[14.5, 13.6, 12.8],
                    baseStyle: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  BoundedAdaptiveText(
                    presentation.subtitle,
                    maxLines: 2,
                    candidateSizes: const <double>[11.8, 11.4, 11.0, 10.5],
                    baseStyle: TextStyle(
                      color: AppColors.textSub,
                      fontWeight: FontWeight.w500,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
            if (!isPinned) ...<Widget>[
              const SizedBox(width: 10),
              GestureDetector(
                key: Key('btn_hub_pin_${definition.id.storageKey}'),
                behavior: HitTestBehavior.opaque,
                onTap: onPin,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ] else if (definition.isRemovable) ...<Widget>[
              const SizedBox(width: 10),
              GestureDetector(
                key: Key('btn_hub_unpin_${definition.id.storageKey}'),
                behavior: HitTestBehavior.opaque,
                onTap: onUnpin,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.pinkLock.withValues(
                      alpha: AppColors.isLight ? 0.12 : 0.18,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.pinkLock.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.remove_rounded,
                    color: AppColors.pinkLock,
                    size: 22,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
