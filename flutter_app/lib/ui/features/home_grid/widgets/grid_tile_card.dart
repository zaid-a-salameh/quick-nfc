/// Adaptive card widget rendering any tool tile across all allowed spans
/// (`1x1`, `2x1`, `3x1`, `2x2`, `3x2`) in both LTR and RTL orientations.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/lang_roll_text.dart';
import '../models/grid_tile_models.dart';
import 'bounded_adaptive_text.dart';
import 'tool_tile_visuals.dart';

/// Stateless responsive surface for a single [HomeGridTile].
///
/// Tap, long-press drag, and selection gestures are coordinated by the parent
/// grid so pointer transitions remain conflict-free inside the gesture arena.
class GridTileCard extends StatelessWidget {
  const GridTileCard({
    super.key,
    required this.tile,
    required this.presentation,
    required this.isRtl,
    this.showDescriptions = true,
    this.isSelected = false,
    this.isDragging = false,
    this.isResizing = false,
    this.isPressed = false,
  });

  /// Current tile placement and span.
  final HomeGridTile tile;

  /// Localized colors, gradient, and icon builder for this tool.
  final ToolTilePresentation presentation;

  /// Whether layout direction is right-to-left.
  final bool isRtl;

  /// Whether large tiles (`3x1`, `2x2`, `3x2`) display helper descriptions.
  final bool showDescriptions;

  /// Whether this tile is selected for resize/unpin editing.
  final bool isSelected;

  /// Whether this tile is actively floating during a drag gesture.
  final bool isDragging;

  /// Whether this tile is currently undergoing an interactive edge resize.
  final bool isResizing;

  /// Whether pointer press feedback should slightly scale the tile down.
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    final highlighted = isSelected || isDragging || isResizing;
    final borderColor =
        highlighted ? AppColors.primaryLight : presentation.borderColor;
    final borderWidth = highlighted ? 1.8 : 1.0;

    final scaleTarget = AppMotion.isReduced(context)
        ? 1.0
        : (isDragging ? 1.04 : (isPressed ? 0.97 : 1.0));

    final shadows = isDragging
        ? <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    return AnimatedScale(
      scale: scaleTarget,
      duration: AppMotion.duration(
        context,
        const Duration(milliseconds: 140),
      ),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: presentation.backgroundGradient == null
                  ? presentation.backgroundColor
                  : null,
              gradient: presentation.backgroundGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Match actual animated bounds so intermediate resize/move
                  // animation frames never trigger RenderFlex overflows.
                  if (tile.span == GridSpan.oneByOne ||
                      constraints.maxWidth < 126) {
                    return _buildOneByOne(
                      presentation,
                      isAutoFilledWide: constraints.maxWidth >= 126,
                    );
                  }
                  if (tile.span == GridSpan.threeByTwo &&
                      constraints.maxWidth >= 240 &&
                      constraints.maxHeight >= 140) {
                    return _buildThreeByTwo(presentation, isRtl);
                  }
                  if (tile.span == GridSpan.twoByTwo &&
                      constraints.maxHeight >= 140) {
                    return _buildTwoByTwo(presentation, isRtl);
                  }
                  if (tile.colSpan >= 3 && constraints.maxWidth >= 240) {
                    return _buildThreeByOne(presentation, isRtl);
                  }
                  return _buildTwoByOne(presentation);
                },
              ),
            ),
          ),
          if (isResizing)
            PositionedDirectional(
              top: 6,
              end: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tile.span.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOneByOne(
    ToolTilePresentation presentation, {
    required bool isAutoFilledWide,
  }) {
    final isDangerTone = presentation.accentColor == AppColors.pinkLock;
    final fontSize = isAutoFilledWide
        ? (isDangerTone ? 12.6 : 13.0)
        : (isDangerTone ? 11.8 : 12.4);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isAutoFilledWide ? 10 : 5,
        vertical: 6,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          presentation.iconBuilder(
            isAutoFilledWide ? 23 : 21,
            presentation.accentColor,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: LangRollText(
                  presentation.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoByOne(ToolTilePresentation presentation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          _IconBadge(
            size: 40,
            radius: 12,
            iconSize: 21,
            presentation: presentation,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: BoundedAdaptiveText(
              presentation.title,
              maxLines: 2,
              candidateSizes: const <double>[13.8, 13.0, 12.2, 11.5],
              baseStyle: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeByOne(ToolTilePresentation presentation, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: <Widget>[
          _IconBadge(
            size: 42,
            radius: 12,
            iconSize: 21,
            presentation: presentation,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    height: 1.18,
                  ),
                ),
                if (showDescriptions) ...<Widget>[
                  const SizedBox(height: 1),
                  Flexible(
                    child: BoundedAdaptiveText(
                      presentation.subtitle,
                      maxLines: 2,
                      candidateSizes: const <double>[11.6, 11.2, 10.8, 10.4],
                      baseStyle: TextStyle(
                        color: AppColors.textSub,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: presentation.accentColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTwoByTwo(ToolTilePresentation presentation, bool isRtl) {
    return _buildTallHero(
      presentation,
      isRtl,
      padding: 12,
      badgeSize: 42,
      badgeRadius: 12,
      iconSize: 22,
      titleSizes: const <double>[14.5, 13.5, 12.6],
      subtitleSizes: const <double>[11.6, 11.2, 10.8, 10.4],
    );
  }

  Widget _buildThreeByTwo(ToolTilePresentation presentation, bool isRtl) {
    return _buildTallHero(
      presentation,
      isRtl,
      padding: 14,
      badgeSize: 48,
      badgeRadius: 14,
      iconSize: 25,
      titleSizes: const <double>[16.0, 15.0, 14.0],
      subtitleSizes: const <double>[12.4, 11.8, 11.2, 10.6],
    );
  }

  Widget _buildTallHero(
    ToolTilePresentation presentation,
    bool isRtl, {
    required double padding,
    required double badgeSize,
    required double badgeRadius,
    required double iconSize,
    required List<double> titleSizes,
    required List<double> subtitleSizes,
  }) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconBadge(
                size: badgeSize,
                radius: badgeRadius,
                iconSize: iconSize,
                presentation: presentation,
              ),
              const Spacer(),
              Icon(
                isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: presentation.accentColor,
                size: 22,
              ),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BoundedAdaptiveText(
                  presentation.title,
                  maxLines: 2,
                  candidateSizes: titleSizes,
                  baseStyle: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                if (showDescriptions) ...<Widget>[
                  const SizedBox(height: 3),
                  Flexible(
                    child: BoundedAdaptiveText(
                      presentation.subtitle,
                      maxLines: 3,
                      candidateSizes: subtitleSizes,
                      baseStyle: TextStyle(
                        color: AppColors.textSub,
                        fontWeight: FontWeight.w500,
                        height: 1.16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.size,
    required this.radius,
    required this.iconSize,
    required this.presentation,
  });

  final double size;
  final double radius;
  final double iconSize;
  final ToolTilePresentation presentation;

  @override
  Widget build(BuildContext context) {
    final hasGradient = presentation.badgeGradient != null;
    final iconColor = presentation.badgeIconColor ?? presentation.accentColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasGradient ? null : presentation.badgeColor,
        gradient: presentation.badgeGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasGradient
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
        child: presentation.iconBuilder(iconSize, iconColor),
      ),
    );
  }
}
