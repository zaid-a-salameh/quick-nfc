/// Interactive 3-column launcher-style home tool grid supporting long-press
/// reordering, 4-edge dot resizing, removable tile unpinning, and RTL symmetry.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/glass_card.dart';
import '../engine/home_grid_layout_engine.dart';
import '../models/grid_tile_models.dart';
import '../registry/tool_registry.dart';
import '../view_models/home_grid_view_model.dart';
import 'grid_tile_card.dart';
import 'tile_resize_overlay.dart';
import 'tool_tile_visuals.dart';

/// Responsive 3-column grid replacing the static tool card container.
class InteractiveHomeGrid extends StatefulWidget {
  const InteractiveHomeGrid({
    super.key,
    required this.viewModel,
    required this.onInvokeTool,
    this.showDescriptions = true,
  });

  /// Grid state, editing selection, drag/resize preview, and persistence store.
  final HomeGridViewModel viewModel;

  /// Invoked when the user taps a tile while not in edit mode.
  final ValueChanged<HomeToolId> onInvokeTool;

  /// Whether large tiles (`3x1`, `2x2`, `3x2`) render helper descriptions.
  final bool showDescriptions;

  /// Horizontal and vertical spacing between grid cells in logical pixels.
  static const double gridGap = 10.0;

  /// Hit-test gutter inside the grid [Stack] so edge dots and unpin badges
  /// along the outer perimeter remain strictly inside [Stack] hit-test bounds.
  static const double _stackGutter = 14.0;

  /// Single-row height matching the app's resting button proportions.
  static const double cellHeight = 76.0;

  @override
  State<InteractiveHomeGrid> createState() => _InteractiveHomeGridState();
}

class _InteractiveHomeGridState extends State<InteractiveHomeGrid> {
  HomeToolId? _pressedDownTileId;
  HomeToolId? _pressTileId;
  Offset? _dragStartGlobal;
  Rect? _dragOriginRect;
  Offset _dragOffset = Offset.zero;
  bool _hasMovedPastDragThreshold = false;

  HomeGridTile? _resizeStartTile;
  Offset? _resizeStartGlobal;
  ResizeEdge? _activeVisualResizeEdge;
  int? _lastDragTargetCol;
  int? _lastDragTargetRow;

  Rect _rectForTile(
    HomeGridTile tile, {
    required double colWidth,
    required double innerWidth,
    required Map<HomeToolId, int> autoFillSlots,
    required bool isRtl,
  }) {
    final pitchY = InteractiveHomeGrid.cellHeight + InteractiveHomeGrid.gridGap;
    final halfSlot = autoFillSlots[tile.id];
    if (halfSlot != null) {
      final halfWidth = (innerWidth - InteractiveHomeGrid.gridGap) / 2;
      final visualHalfSlot = isRtl ? (1 - halfSlot) : halfSlot;
      return Rect.fromLTWH(
        InteractiveHomeGrid._stackGutter +
            visualHalfSlot * (halfWidth + InteractiveHomeGrid.gridGap),
        InteractiveHomeGrid._stackGutter + tile.row * pitchY,
        halfWidth,
        InteractiveHomeGrid.cellHeight,
      );
    }

    final pitchX = colWidth + InteractiveHomeGrid.gridGap;
    final visualStartCol =
        isRtl ? (HomeGridLayoutEngine.columnCount - tile.endCol) : tile.col;

    return Rect.fromLTWH(
      InteractiveHomeGrid._stackGutter + visualStartCol * pitchX,
      InteractiveHomeGrid._stackGutter + tile.row * pitchY,
      tile.colSpan * colWidth +
          (tile.colSpan - 1) * InteractiveHomeGrid.gridGap,
      tile.rowSpan * InteractiveHomeGrid.cellHeight +
          (tile.rowSpan - 1) * InteractiveHomeGrid.gridGap,
    );
  }

  ResizeEdge _toLogicalEdge(ResizeEdge visualEdge, bool isRtl) {
    if (!isRtl) {
      return visualEdge;
    }
    return switch (visualEdge) {
      ResizeEdge.left => ResizeEdge.right,
      ResizeEdge.right => ResizeEdge.left,
      ResizeEdge.top => ResizeEdge.top,
      ResizeEdge.bottom => ResizeEdge.bottom,
    };
  }

  void _handleTileTap(HomeToolId tileId) {
    final vm = widget.viewModel;
    if (!vm.isEditing) {
      widget.onInvokeTool(tileId);
      return;
    }
    if (vm.selectedTileId == tileId) {
      vm.clearSelection();
    } else {
      vm.selectTileForEdit(tileId);
    }
  }

  void _handleLongPressStart(
    HomeGridTile tile,
    LongPressStartDetails details, {
    required double colWidth,
    required double innerWidth,
    required Map<HomeToolId, int> autoFillSlots,
    required bool isRtl,
  }) {
    setState(() {
      _pressedDownTileId = null;
      _pressTileId = tile.id;
      _dragStartGlobal = details.globalPosition;
      _dragOriginRect = _rectForTile(
        tile,
        colWidth: colWidth,
        innerWidth: innerWidth,
        autoFillSlots: autoFillSlots,
        isRtl: isRtl,
      );
      _dragOffset = Offset.zero;
      _hasMovedPastDragThreshold = false;
      _lastDragTargetCol = null;
      _lastDragTargetRow = null;
    });
    widget.viewModel.selectTileForEdit(tile.id);
  }

  void _handleLongPressMoveUpdate(
    HomeGridTile tile,
    LongPressMoveUpdateDetails details, {
    required double colWidth,
    required bool isRtl,
  }) {
    if (_pressTileId != tile.id ||
        _dragStartGlobal == null ||
        _dragOriginRect == null) {
      return;
    }

    final delta = details.globalPosition - _dragStartGlobal!;
    if (!_hasMovedPastDragThreshold && delta.distance < 8.0) {
      return;
    }

    final enteredDragNow = !_hasMovedPastDragThreshold;
    setState(() {
      _hasMovedPastDragThreshold = true;
      _dragOffset = delta;
    });

    final vm = widget.viewModel;
    if (enteredDragNow) {
      vm.beginDrag(tile.id);
    }

    final pitchX = colWidth + InteractiveHomeGrid.gridGap;
    final pitchY = InteractiveHomeGrid.cellHeight + InteractiveHomeGrid.gridGap;
    final floatingLeft =
        _dragOriginRect!.left + delta.dx - InteractiveHomeGrid._stackGutter;
    final floatingTop =
        _dragOriginRect!.top + delta.dy - InteractiveHomeGrid._stackGutter;

    final maxVisualCol = HomeGridLayoutEngine.columnCount - tile.colSpan;
    final visualCol = (floatingLeft / pitchX).round().clamp(0, maxVisualCol);
    final targetCol = isRtl ? (maxVisualCol - visualCol) : visualCol;
    final maxTargetRow = HomeGridLayoutEngine.totalRows(vm.tiles);
    final targetRow = (floatingTop / pitchY).round().clamp(0, maxTargetRow);

    if (enteredDragNow ||
        targetCol != _lastDragTargetCol ||
        targetRow != _lastDragTargetRow) {
      _lastDragTargetCol = targetCol;
      _lastDragTargetRow = targetRow;
      vm.updateDragPreview(
        id: tile.id,
        targetCol: targetCol,
        targetRow: targetRow,
      );
    }
  }

  void _handleLongPressEnd(HomeToolId tileId) {
    final wasDragging = _hasMovedPastDragThreshold && _pressTileId == tileId;
    setState(() {
      _pressTileId = null;
      _dragStartGlobal = null;
      _dragOriginRect = null;
      _dragOffset = Offset.zero;
      _hasMovedPastDragThreshold = false;
      _lastDragTargetCol = null;
      _lastDragTargetRow = null;
    });
    if (wasDragging) {
      unawaited(widget.viewModel.commitDrag());
    }
  }

  void _handleLongPressCancel(HomeToolId tileId) {
    final wasDragging = _hasMovedPastDragThreshold && _pressTileId == tileId;
    setState(() {
      _pressTileId = null;
      _dragStartGlobal = null;
      _dragOriginRect = null;
      _dragOffset = Offset.zero;
      _hasMovedPastDragThreshold = false;
      _lastDragTargetCol = null;
      _lastDragTargetRow = null;
    });
    if (wasDragging) {
      widget.viewModel.cancelDrag();
    }
  }

  void _handleResizeStart(ResizeEdge visualEdge, Offset globalPosition) {
    final selectedId = widget.viewModel.selectedTileId;
    final startTile =
        selectedId == null ? null : widget.viewModel.tileFor(selectedId);
    if (startTile == null) {
      return;
    }
    setState(() {
      _resizeStartTile = startTile;
      _resizeStartGlobal = globalPosition;
      _activeVisualResizeEdge = visualEdge;
    });
  }

  void _handleResizeUpdate(
    ResizeEdge visualEdge,
    Offset globalPosition, {
    required double colWidth,
    required bool isRtl,
  }) {
    final startTile = _resizeStartTile;
    final startGlobal = _resizeStartGlobal;
    if (startTile == null || startGlobal == null) {
      return;
    }

    final pitchX = colWidth + InteractiveHomeGrid.gridGap;
    final pitchY = InteractiveHomeGrid.cellHeight + InteractiveHomeGrid.gridGap;
    final delta = globalPosition - startGlobal;
    final logicalEdge = _toLogicalEdge(visualEdge, isRtl);

    final colSteps = (delta.dx / pitchX).round();
    final rowSteps = (delta.dy / pitchY).round();

    var targetColSpan = startTile.colSpan;
    var targetRowSpan = startTile.rowSpan;

    switch (visualEdge) {
      case ResizeEdge.right:
        targetColSpan = startTile.colSpan + colSteps;
      case ResizeEdge.left:
        targetColSpan = startTile.colSpan - colSteps;
      case ResizeEdge.bottom:
        targetRowSpan = startTile.rowSpan + rowSteps;
      case ResizeEdge.top:
        targetRowSpan = startTile.rowSpan - rowSteps;
    }

    final resolvedSpan = HomeGridLayoutEngine.resolveSpanFromDrag(
      targetColSpan: targetColSpan,
      targetRowSpan: targetRowSpan,
      currentSpan: startTile.span,
      activeEdge: logicalEdge,
    );

    widget.viewModel.updateResizePreview(
      id: startTile.id,
      newSpan: resolvedSpan,
      edge: logicalEdge,
    );
  }

  void _handleResizeEnd() {
    setState(() {
      _resizeStartTile = null;
      _resizeStartGlobal = null;
      _activeVisualResizeEdge = null;
    });
    unawaited(widget.viewModel.commitResize());
  }

  void _handleResizeCancel() {
    setState(() {
      _resizeStartTile = null;
      _resizeStartGlobal = null;
      _activeVisualResizeEdge = null;
    });
    widget.viewModel.cancelResize();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        final vm = widget.viewModel;
        final displayTiles = vm.displayTiles;
        final isEditing = vm.isEditing;
        final rows = math.max(1, HomeGridLayoutEngine.totalRows(displayTiles));
        final gridHeight = rows * InteractiveHomeGrid.cellHeight +
            (rows - 1) * InteractiveHomeGrid.gridGap;

        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedSize(
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 180),
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isEditing
                    ? _EditModeBanner(
                        hint: l10n.gridEditModeHint,
                        doneLabel: l10n.gridEditDone,
                        resetTooltip: l10n.gridResetTooltip,
                        onReset: () => unawaited(vm.resetToDefaultLayout()),
                        onDone: vm.clearSelection,
                      )
                    : (vm.showCustomizeHint
                        ? _CustomizeHintBanner(
                            hint: l10n.gridCustomizeHint,
                            onDismiss: () => unawaited(vm.dismissCustomizeHint()),
                          )
                        : const SizedBox(width: double.infinity, height: 0)),
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final innerWidth = constraints.maxWidth -
                      2 * InteractiveHomeGrid._stackGutter;
                  final colWidth = (innerWidth -
                          (HomeGridLayoutEngine.columnCount - 1) *
                              InteractiveHomeGrid.gridGap) /
                      HomeGridLayoutEngine.columnCount;

                  final selectedId = vm.selectedTileId;
                  final airborneId =
                      _hasMovedPastDragThreshold ? _pressTileId : null;
                  final autoFillSlots =
                      HomeGridLayoutEngine.resolveAutoFillHalfSlots(
                    displayTiles,
                  );

                  // Keep deterministic Stack order while placing the selected
                  // and airborne tiles last so they elevate cleanly on top
                  // without changing wrapper widget types or keys.
                  final orderedTiles = List<HomeGridTile>.of(displayTiles)
                    ..sort((HomeGridTile a, HomeGridTile b) {
                      final aAir = a.id == airborneId ? 1 : 0;
                      final bAir = b.id == airborneId ? 1 : 0;
                      if (aAir != bAir) return aAir.compareTo(bAir);

                      final aSel = a.id == selectedId ? 1 : 0;
                      final bSel = b.id == selectedId ? 1 : 0;
                      if (aSel != bSel) return aSel.compareTo(bSel);

                      return a.id.index.compareTo(b.id.index);
                    });

                  HomeGridTile? airborneTargetTile;
                  HomeGridTile? selectedTile;
                  for (final tile in orderedTiles) {
                    if (tile.id == airborneId) {
                      airborneTargetTile = tile;
                    }
                    if (tile.id == selectedId) {
                      selectedTile = tile;
                    }
                  }

                  final animDuration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 220),
                  );

                  final stackChildren = <Widget>[
                    if (airborneTargetTile != null)
                      _buildDropZoneHighlight(
                        context: context,
                        rect: _rectForTile(
                          airborneTargetTile,
                          colWidth: colWidth,
                          innerWidth: innerWidth,
                          autoFillSlots: autoFillSlots,
                          isRtl: isRtl,
                        ),
                      ),
                    for (final tile in orderedTiles)
                      _buildGridTile(
                        context: context,
                        tile: tile,
                        colWidth: colWidth,
                        innerWidth: innerWidth,
                        autoFillSlots: autoFillSlots,
                        isRtl: isRtl,
                        l10n: l10n,
                        animDuration: animDuration,
                        isSelected: tile.id == selectedId,
                        isAirborne: tile.id == airborneId,
                        isResizing: tile.id == vm.resizingTileId,
                      ),
                    if (selectedTile != null && airborneId == null)
                      ...buildTileResizeOverlayWidgets(
                        context: context,
                        tileRect: _rectForTile(
                          selectedTile,
                          colWidth: colWidth,
                          innerWidth: innerWidth,
                          autoFillSlots: autoFillSlots,
                          isRtl: isRtl,
                        ),
                        tile: selectedTile,
                        isRemovable:
                            ToolRegistry.byId(selectedTile.id).isRemovable,
                        isRtl: isRtl,
                        isResizing: vm.resizingTileId == selectedTile.id,
                        activeVisualEdge: _activeVisualResizeEdge,
                        onResizeStart: _handleResizeStart,
                        onResizeUpdate: (
                          ResizeEdge visualEdge,
                          Offset globalPos,
                        ) =>
                            _handleResizeUpdate(
                          visualEdge,
                          globalPos,
                          colWidth: colWidth,
                          isRtl: isRtl,
                        ),
                        onResizeEnd: _handleResizeEnd,
                        onResizeCancel: _handleResizeCancel,
                        onUnpin: () => unawaited(
                          vm.unpinTool(selectedTile!.id),
                        ),
                      ),
                  ];

                  return AnimatedContainer(
                    duration: AppMotion.duration(
                      context,
                      const Duration(milliseconds: 220),
                    ),
                    curve: Curves.easeOutCubic,
                    height: gridHeight + 2 * InteractiveHomeGrid._stackGutter,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: stackChildren,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropZoneHighlight({
    required BuildContext context,
    required Rect rect,
  }) {
    return AnimatedPositioned(
      key: const ValueKey<String>('grid_drop_zone_preview'),
      duration: AppMotion.duration(
        context,
        const Duration(milliseconds: 160),
      ),
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(
              alpha: AppColors.isLight ? 0.12 : 0.18,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.65),
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile({
    required BuildContext context,
    required HomeGridTile tile,
    required double colWidth,
    required double innerWidth,
    required Map<HomeToolId, int> autoFillSlots,
    required bool isRtl,
    required AppLocalizations l10n,
    required Duration animDuration,
    required bool isSelected,
    required bool isAirborne,
    required bool isResizing,
  }) {
    final definition = ToolRegistry.byId(tile.id);
    final presentation = ToolTileVisuals.resolve(tile.id, l10n);

    final rect = isAirborne && _dragOriginRect != null
        ? _dragOriginRect!.shift(_dragOffset)
        : _rectForTile(
            tile,
            colWidth: colWidth,
            innerWidth: innerWidth,
            autoFillSlots: autoFillSlots,
            isRtl: isRtl,
          );

    return AnimatedPositioned(
      key: ValueKey<HomeToolId>(tile.id),
      duration: isAirborne ? Duration.zero : animDuration,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        key: Key(definition.semanticKey),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (_pressedDownTileId != tile.id) {
            setState(() => _pressedDownTileId = tile.id);
          }
        },
        onTapUp: (_) {
          if (_pressedDownTileId != null) {
            setState(() => _pressedDownTileId = null);
          }
        },
        onTapCancel: () {
          if (_pressedDownTileId != null) {
            setState(() => _pressedDownTileId = null);
          }
        },
        onTap: () => _handleTileTap(tile.id),
        onLongPressStart: (LongPressStartDetails details) =>
            _handleLongPressStart(
          tile,
          details,
          colWidth: colWidth,
          innerWidth: innerWidth,
          autoFillSlots: autoFillSlots,
          isRtl: isRtl,
        ),
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) =>
            _handleLongPressMoveUpdate(
          tile,
          details,
          colWidth: colWidth,
          isRtl: isRtl,
        ),
        onLongPressEnd: (_) => _handleLongPressEnd(tile.id),
        onLongPressCancel: () => _handleLongPressCancel(tile.id),
        child: GridTileCard(
          tile: tile,
          presentation: presentation,
          isRtl: isRtl,
          showDescriptions: widget.showDescriptions,
          isSelected: isSelected,
          isDragging: isAirborne,
          isResizing: isResizing,
          isPressed: _pressedDownTileId == tile.id && !isAirborne,
        ),
      ),
    );
  }
}

class _EditModeBanner extends StatelessWidget {
  const _EditModeBanner({
    required this.hint,
    required this.doneLabel,
    required this.resetTooltip,
    required this.onReset,
    required this.onDone,
  });

  final String hint;
  final String doneLabel;
  final String resetTooltip;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: AppColors.isLight ? 0.10 : 0.16,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.tune_rounded,
            size: 16,
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: resetTooltip,
            child: GestureDetector(
              key: const Key('btn_grid_reset'),
              behavior: HitTestBehavior.opaque,
              onTap: onReset,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.subtleButtonBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.restart_alt_rounded,
                  size: 17,
                  color: AppColors.textSub,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: const Key('btn_grid_done'),
            behavior: HitTestBehavior.opaque,
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                doneLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizeHintBanner extends StatelessWidget {
  const _CustomizeHintBanner({
    required this.hint,
    required this.onDismiss,
  });

  final String hint;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('grid_customize_hint_banner'),
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: AppColors.isLight ? 0.07 : 0.12,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.touch_app_rounded,
            size: 16,
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSub,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: const Key('btn_dismiss_grid_hint'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.subtleButtonBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
