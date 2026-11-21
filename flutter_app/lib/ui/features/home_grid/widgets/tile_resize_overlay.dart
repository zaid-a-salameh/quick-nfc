/// Selection overlay rendering 4-edge dot resize handles and an unpin badge
/// directly inside the home grid [Stack] around the selected tile.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../models/grid_tile_models.dart';

/// Builds positioned overlay controls (4 edge resize dots + optional unpin
/// badge) for the currently selected [tile] at [tileRect].
///
/// Returned [Positioned] widgets are placed directly in the parent grid
/// [Stack] so only the small handle hit targets intercept pointer events.
List<Widget> buildTileResizeOverlayWidgets({
  required BuildContext context,
  required Rect tileRect,
  required HomeGridTile tile,
  required bool isRemovable,
  required bool isRtl,
  required bool isResizing,
  required ResizeEdge? activeVisualEdge,
  required void Function(ResizeEdge visualEdge, Offset globalPosition)
      onResizeStart,
  required void Function(ResizeEdge visualEdge, Offset globalPosition)
      onResizeUpdate,
  required VoidCallback onResizeEnd,
  required VoidCallback onResizeCancel,
  required VoidCallback onUnpin,
}) {
  const handleHitSize = 34.0;
  const halfHit = handleHitSize / 2;

  Widget positionedDot({
    required ResizeEdge visualEdge,
    required Offset center,
  }) {
    return Positioned(
      left: center.dx - halfHit,
      top: center.dy - halfHit,
      width: handleHitSize,
      height: handleHitSize,
      child: _ResizeEdgeDot(
        key: ValueKey<String>(
          'resize_handle_${tile.id.storageKey}_${visualEdge.name}',
        ),
        visualEdge: visualEdge,
        isActive: activeVisualEdge == visualEdge,
        onResizeStart: onResizeStart,
        onResizeUpdate: onResizeUpdate,
        onResizeEnd: onResizeEnd,
        onResizeCancel: onResizeCancel,
      ),
    );
  }

  final widgets = <Widget>[
    positionedDot(
      visualEdge: ResizeEdge.top,
      center: Offset(tileRect.center.dx, tileRect.top),
    ),
    positionedDot(
      visualEdge: ResizeEdge.bottom,
      center: Offset(tileRect.center.dx, tileRect.bottom),
    ),
    positionedDot(
      visualEdge: ResizeEdge.left,
      center: Offset(tileRect.left, tileRect.center.dy),
    ),
    positionedDot(
      visualEdge: ResizeEdge.right,
      center: Offset(tileRect.right, tileRect.center.dy),
    ),
  ];

  if (isRemovable && !isResizing) {
    const unpinHitSize = 42.0;
    const halfUnpinHit = unpinHitSize / 2;
    final centerX = isRtl ? tileRect.left + 7.0 : tileRect.right - 7.0;
    final centerY = tileRect.top + 7.0;

    widgets.add(
      Positioned(
        left: centerX - halfUnpinHit,
        top: centerY - halfUnpinHit,
        width: unpinHitSize,
        height: unpinHitSize,
        child: GestureDetector(
          key: Key('btn_unpin_${tile.id.storageKey}'),
          behavior: HitTestBehavior.opaque,
          onTap: onUnpin,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.pinkLockDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.isLight ? Colors.white : AppColors.bg,
                  width: 2.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.pinkLockDark.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  return widgets;
}

class _ResizeEdgeDot extends StatelessWidget {
  const _ResizeEdgeDot({
    super.key,
    required this.visualEdge,
    required this.isActive,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final ResizeEdge visualEdge;
  final bool isActive;
  final void Function(ResizeEdge visualEdge, Offset globalPosition)
      onResizeStart;
  final void Function(ResizeEdge visualEdge, Offset globalPosition)
      onResizeUpdate;
  final VoidCallback onResizeEnd;
  final VoidCallback onResizeCancel;

  bool get _isVertical =>
      visualEdge == ResizeEdge.top || visualEdge == ResizeEdge.bottom;

  @override
  Widget build(BuildContext context) {
    final dotSize = isActive ? 15.0 : 12.0;

    final dotVisual = Center(
      child: AnimatedContainer(
        duration: AppMotion.duration(
          context,
          const Duration(milliseconds: 120),
        ),
        curve: Curves.easeOutCubic,
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : AppColors.primaryLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.white,
            width: isActive ? 2.4 : 2.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (isActive ? AppColors.primary : Colors.black)
                  .withValues(alpha: isActive ? 0.45 : 0.28),
              blurRadius: isActive ? 8 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );

    // Axis-specific drag recognizers match Scrollable's kTouchSlop (18px) so
    // vertical edge handles reliably win against the parent SingleChildScrollView.
    return _isVertical
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTap: () {},
            onVerticalDragStart: (DragStartDetails details) =>
                onResizeStart(visualEdge, details.globalPosition),
            onVerticalDragUpdate: (DragUpdateDetails details) =>
                onResizeUpdate(visualEdge, details.globalPosition),
            onVerticalDragEnd: (_) => onResizeEnd(),
            onVerticalDragCancel: onResizeCancel,
            child: dotVisual,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTap: () {},
            onHorizontalDragStart: (DragStartDetails details) =>
                onResizeStart(visualEdge, details.globalPosition),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                onResizeUpdate(visualEdge, details.globalPosition),
            onHorizontalDragEnd: (_) => onResizeEnd(),
            onHorizontalDragCancel: onResizeCancel,
            child: dotVisual,
          );
  }
}
