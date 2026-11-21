/// Pure mathematical layout, collision, compaction, and resize engine for the
/// responsive 3-column home grid.
library;

import 'dart:math' as math;

import '../models/grid_tile_models.dart';
import '../registry/tool_registry.dart';

/// Stateless layout operations operating purely on immutable [HomeGridTile]
/// lists with zero Flutter UI dependencies.
abstract final class HomeGridLayoutEngine {
  /// Number of grid columns (`3`).
  static const int columnCount = ToolRegistry.columnCount;

  /// Total number of occupied rows required to render [tiles].
  static int totalRows(List<HomeGridTile> tiles) {
    var maxRow = 0;
    for (final tile in tiles) {
      if (tile.endRow > maxRow) {
        maxRow = tile.endRow;
      }
    }
    return maxRow;
  }

  /// Whether [tiles] contains any completely unoccupied row strictly above
  /// [totalRows].
  static bool hasEmptyRows(List<HomeGridTile> tiles) {
    final rows = totalRows(tiles);
    if (rows == 0) {
      return false;
    }
    for (var r = 0; r < rows; r++) {
      var occupied = false;
      for (final tile in tiles) {
        if (r >= tile.row && r < tile.endRow) {
          occupied = true;
          break;
        }
      }
      if (!occupied) {
        return true;
      }
    }
    return false;
  }

  /// Validates structural integrity of [tiles]: unique tool IDs, legal spans,
  /// in-bounds placement, and zero overlaps.
  static bool isValidLayout(List<HomeGridTile> tiles) {
    final seenIds = <HomeToolId>{};
    for (var i = 0; i < tiles.length; i++) {
      final a = tiles[i];
      if (!seenIds.add(a.id)) {
        return false;
      }
      if (!GridSpan.isAllowed(a.colSpan, a.rowSpan)) {
        return false;
      }
      if (a.col < 0 || a.row < 0 || a.endCol > columnCount) {
        return false;
      }
      for (var j = i + 1; j < tiles.length; j++) {
        if (a.overlaps(tiles[j])) {
          return false;
        }
      }
    }
    return true;
  }

  /// Maps raw drag target dimensions onto the nearest allowed [GridSpan].
  ///
  /// The only forbidden span within `[1..3] x [1..2]` (`1x2`) is resolved
  /// deterministically using [currentSpan] and the optional [activeEdge] so
  /// horizontal vs vertical intent behaves predictably:
  /// - Expanding height to `2` from a `1x1` tile resolves `1x2` to `2x2`.
  /// - Shrinking width of a `2x2` tile toward `1` resolves `1x2` to `1x1`.
  static GridSpan resolveSpanFromDrag({
    required int targetColSpan,
    required int targetRowSpan,
    GridSpan? currentSpan,
    ResizeEdge? activeEdge,
  }) {
    final clampedCols = targetColSpan.clamp(1, columnCount);
    final clampedRows = targetRowSpan.clamp(1, 2);

    final direct = GridSpan.tryCreate(clampedCols, clampedRows);
    if (direct != null) {
      return direct;
    }

    // Remaining forbidden case after clamping [1..3] x [1..2] is (1, 2).
    final isHorizontalChange =
        activeEdge == ResizeEdge.left || activeEdge == ResizeEdge.right;
    if (isHorizontalChange) {
      return GridSpan.oneByOne;
    }
    if (activeEdge == ResizeEdge.top || activeEdge == ResizeEdge.bottom) {
      return GridSpan.twoByTwo;
    }
    return currentSpan == GridSpan.twoByTwo
        ? GridSpan.oneByOne
        : GridSpan.twoByTwo;
  }

  /// Identifies rows occupied exclusively by two `1x1` tiles (with no other
  /// crossing `2x1`, `2x2`, or `3x2` tiles) and maps each tile's [HomeToolId]
  /// to its logical half-row slot (`0` for start half, `1` for end half).
  static Map<HomeToolId, int> resolveAutoFillHalfSlots(
    List<HomeGridTile> tiles,
  ) {
    final rows = totalRows(tiles);
    if (rows == 0) {
      return const <HomeToolId, int>{};
    }

    final byRow = List<List<HomeGridTile>>.generate(
      rows,
      (_) => <HomeGridTile>[],
    );
    for (final tile in tiles) {
      for (var r = tile.row; r < tile.endRow; r++) {
        if (r >= 0 && r < rows) {
          byRow[r].add(tile);
        }
      }
    }

    final result = <HomeToolId, int>{};
    for (final rowTiles in byRow) {
      if (rowTiles.length == 2 &&
          rowTiles[0].span == GridSpan.oneByOne &&
          rowTiles[1].span == GridSpan.oneByOne) {
        final sorted = List<HomeGridTile>.of(rowTiles)
          ..sort((HomeGridTile a, HomeGridTile b) => a.col.compareTo(b.col));
        result[sorted[0].id] = 0;
        result[sorted[1].id] = 1;
      }
    }
    return Map<HomeToolId, int>.unmodifiable(result);
  }

  /// Compacts [tiles] upward and left-to-right (iOS-style gravity), eliminating
  /// all gaps while preserving reading order.
  static List<HomeGridTile> packCompact(List<HomeGridTile> tiles) {
    final sorted = List<HomeGridTile>.of(tiles)..sort(_readingOrderCompare);
    final placed = <HomeGridTile>[];
    final occupancy = _GridOccupancy();

    for (final tile in sorted) {
      final slot = occupancy.findFirstFit(tile.span);
      final settled = tile.copyWith(col: slot.col, row: slot.row);
      occupancy.mark(settled);
      placed.add(settled);
    }

    placed.sort(_readingOrderCompare);
    return List<HomeGridTile>.unmodifiable(placed);
  }

  /// Moves the tile identified by [id] to ([targetCol], [targetRow]).
  ///
  /// When the target rectangle overlaps exactly one tile with an identical
  /// `(col, row, colSpan, rowSpan)` footprint, performs a direct 1-to-1 swap.
  /// Otherwise anchors the moved tile at the clamped coordinates, reflows
  /// remaining tiles around it, and collapses any completely empty rows.
  static List<HomeGridTile> moveTile(
    List<HomeGridTile> tiles, {
    required HomeToolId id,
    required int targetCol,
    required int targetRow,
  }) {
    final index = tiles.indexWhere((t) => t.id == id);
    if (index < 0) {
      return packCompact(tiles);
    }

    final moving = tiles[index];
    final clampedCol = targetCol.clamp(0, columnCount - moving.colSpan);
    final clampedRow = math.max(0, targetRow);

    final overlapping = tiles
        .where(
          (other) =>
              other.id != id &&
              other.overlapsRect(clampedCol, clampedRow, moving.span),
        )
        .toList(growable: false);

    if (overlapping.length == 1) {
      final partner = overlapping.single;
      if (partner.col == clampedCol &&
          partner.row == clampedRow &&
          partner.span == moving.span) {
        final swapped = tiles
            .map((tile) {
              if (tile.id == moving.id) {
                return tile.copyWith(col: partner.col, row: partner.row);
              }
              if (tile.id == partner.id) {
                return tile.copyWith(col: moving.col, row: moving.row);
              }
              return tile;
            })
            .toList(growable: false);
        return _finalize(_collapseEmptyRows(swapped));
      }
    }

    var others = tiles
        .where((other) => other.id != id)
        .toList(growable: false);
    if (moving.row < clampedRow) {
      final vacatedBand = !others.any(
        (HomeGridTile t) => t.row < moving.endRow && t.endRow > moving.row,
      );
      if (vacatedBand) {
        others = others
            .map((HomeGridTile tile) {
              if (tile.row >= moving.endRow && tile.row <= clampedRow) {
                return tile.copyWith(
                  row: math.max(0, tile.row - moving.rowSpan),
                );
              }
              return tile;
            })
            .toList(growable: false);
      }
    }
    final anchored = moving.copyWith(col: clampedCol, row: clampedRow);
    return _placeAnchoredAndReflow(others, anchored);
  }

  /// Resizes the tile identified by [id] to [newSpan], preserving the opposite
  /// edge from [edge], then reflowing colliding tiles and collapsing gaps.
  static List<HomeGridTile> resizeTile(
    List<HomeGridTile> tiles, {
    required HomeToolId id,
    required GridSpan newSpan,
    ResizeEdge edge = ResizeEdge.right,
  }) {
    final index = tiles.indexWhere((t) => t.id == id);
    if (index < 0) {
      return packCompact(tiles);
    }

    final target = tiles[index];
    if (target.span == newSpan) {
      return _finalize(tiles);
    }

    var newCol = switch (edge) {
      ResizeEdge.left => target.endCol - newSpan.colSpan,
      ResizeEdge.right || ResizeEdge.top || ResizeEdge.bottom => target.col,
    };
    var newRow = switch (edge) {
      ResizeEdge.top => target.endRow - newSpan.rowSpan,
      ResizeEdge.left || ResizeEdge.right || ResizeEdge.bottom => target.row,
    };

    newCol = newCol.clamp(0, columnCount - newSpan.colSpan);
    if (newRow < 0) {
      newRow = 0;
    }

    final others = tiles
        .where((other) => other.id != id)
        .toList(growable: false);
    final anchored = target.copyWith(col: newCol, row: newRow, span: newSpan);
    return _placeAnchoredAndReflow(others, anchored);
  }

  /// Pins tool [id] onto [tiles] if not already present.
  ///
  /// When `toolsHub` currently spans the bottom full row (`col == 0`, `3x1`,
  /// ending at [totalRows]), places the new tool into the earliest gap above
  /// `toolsHub` (or directly before it) while keeping `toolsHub` anchored on
  /// the last row. Otherwise appends via earliest available fit and collapses
  /// empty rows.
  static List<HomeGridTile> addTool(
    List<HomeGridTile> tiles,
    HomeToolId id, {
    GridSpan? preferredSpan,
  }) {
    if (tiles.any((t) => t.id == id)) {
      return _finalize(_collapseEmptyRows(tiles));
    }

    final span = preferredSpan ?? ToolRegistry.byId(id).defaultSpan;
    final currentRows = totalRows(tiles);
    final hubIndex = tiles.indexWhere((t) => t.id == HomeToolId.toolsHub);

    if (hubIndex >= 0 && id != HomeToolId.toolsHub) {
      final hub = tiles[hubIndex];
      final isHubAnchoredAtBottom = hub.endRow == currentRows &&
          hub.col == 0 &&
          hub.colSpan == columnCount;

      if (isHubAnchoredAtBottom) {
        final nonHub = tiles
            .where((t) => t.id != HomeToolId.toolsHub)
            .toList(growable: false);
        final occupancy = _GridOccupancy.fromTiles(nonHub);
        final slot = occupancy.findFirstFit(span);
        final added = HomeGridTile(
          id: id,
          col: slot.col,
          row: slot.row,
          span: span,
        );
        final updatedNonHub = <HomeGridTile>[...nonHub, added];
        final newHubRow = totalRows(updatedNonHub);
        final updatedHub = hub.copyWith(col: 0, row: newHubRow);
        return _finalize(
          _collapseEmptyRows(<HomeGridTile>[...updatedNonHub, updatedHub]),
        );
      }
    }

    final occupancy = _GridOccupancy.fromTiles(tiles);
    final slot = occupancy.findFirstFit(span);
    final added = HomeGridTile(
      id: id,
      col: slot.col,
      row: slot.row,
      span: span,
    );
    return _finalize(_collapseEmptyRows(<HomeGridTile>[...tiles, added]));
  }

  /// Unpins [id] from [tiles] and collapses any completely empty rows without
  /// pulling lower tiles into remaining partial rows.
  ///
  /// Non-removable tools (such as [HomeToolId.toolsHub]) are preserved even if
  /// requested for removal.
  static List<HomeGridTile> removeTool(
    List<HomeGridTile> tiles,
    HomeToolId id,
  ) {
    final definition = ToolRegistry.byId(id);
    if (!definition.isRemovable) {
      return _finalize(_collapseEmptyRows(tiles));
    }
    final remaining = tiles
        .where((tile) => tile.id != id)
        .toList(growable: false);
    return _finalize(_collapseEmptyRows(remaining));
  }

  /// Repairs arbitrary, duplicate, overlapping, or incomplete tile lists into a
  /// valid packed layout and ensures every non-removable tool is present.
  static List<HomeGridTile> sanitizeAndMigrate(List<HomeGridTile> rawTiles) {
    final deduplicated = <HomeToolId, HomeGridTile>{};

    for (final tile in rawTiles) {
      if (deduplicated.containsKey(tile.id)) {
        continue;
      }
      final validSpan = GridSpan.tryCreate(tile.colSpan, tile.rowSpan) ??
          ToolRegistry.byId(tile.id).defaultSpan;
      final clampedCol = tile.col.clamp(0, columnCount - validSpan.colSpan);
      final clampedRow = math.max(0, tile.row);
      deduplicated[tile.id] = HomeGridTile(
        id: tile.id,
        col: clampedCol,
        row: clampedRow,
        span: validSpan,
      );
    }

    final candidates = deduplicated.values.toList(growable: false)
      ..sort(_readingOrderCompare);

    final occupancy = _GridOccupancy();
    final settled = <HomeGridTile>[];

    for (final candidate in candidates) {
      if (occupancy.fitsAt(candidate.col, candidate.row, candidate.span)) {
        occupancy.mark(candidate);
        settled.add(candidate);
      } else {
        final slot = occupancy.findFirstFit(candidate.span);
        final relocated = candidate.copyWith(col: slot.col, row: slot.row);
        occupancy.mark(relocated);
        settled.add(relocated);
      }
    }

    var result = _collapseEmptyRows(settled);

    for (final definition in ToolRegistry.allTools) {
      if (!definition.isRemovable &&
          !result.any((tile) => tile.id == definition.id)) {
        final nextRow = totalRows(result);
        final injected = HomeGridTile(
          id: definition.id,
          col: 0,
          row: nextRow,
          span: definition.defaultSpan,
        );
        result = _finalize(<HomeGridTile>[...result, injected]);
      }
    }

    return _finalize(result);
  }

  static List<HomeGridTile> _placeAnchoredAndReflow(
    List<HomeGridTile> others,
    HomeGridTile anchored,
  ) {
    final occupancy = _GridOccupancy()..mark(anchored);
    final sortedOthers = List<HomeGridTile>.of(others)
      ..sort(_readingOrderCompare);
    final placed = <HomeGridTile>[anchored];

    for (final tile in sortedOthers) {
      if (occupancy.fitsAt(tile.col, tile.row, tile.span)) {
        occupancy.mark(tile);
        placed.add(tile);
      } else {
        final slot = occupancy.findFirstFitFromRow(
          tile.span,
          startRow: tile.row,
        );
        final relocated = tile.copyWith(col: slot.col, row: slot.row);
        occupancy.mark(relocated);
        placed.add(relocated);
      }
    }

    return _finalize(_collapseEmptyRows(placed));
  }

  static List<HomeGridTile> _collapseEmptyRows(List<HomeGridTile> tiles) {
    final maxRow = totalRows(tiles);
    if (maxRow == 0) {
      return tiles;
    }

    final emptyRows = <int>{};
    for (var r = 0; r < maxRow; r++) {
      var occupied = false;
      for (final tile in tiles) {
        if (r >= tile.row && r < tile.endRow) {
          occupied = true;
          break;
        }
      }
      if (!occupied) {
        emptyRows.add(r);
      }
    }

    if (emptyRows.isEmpty) {
      return tiles;
    }

    return tiles
        .map((tile) {
          var shiftUp = 0;
          for (final emptyRow in emptyRows) {
            if (emptyRow < tile.row) {
              shiftUp++;
            }
          }
          return shiftUp == 0
              ? tile
              : tile.copyWith(row: tile.row - shiftUp);
        })
        .toList(growable: false);
  }

  static List<HomeGridTile> _finalize(List<HomeGridTile> tiles) {
    final sorted = List<HomeGridTile>.of(tiles)..sort(_readingOrderCompare);
    return List<HomeGridTile>.unmodifiable(sorted);
  }

  static int _readingOrderCompare(HomeGridTile a, HomeGridTile b) {
    final rowCmp = a.row.compareTo(b.row);
    if (rowCmp != 0) {
      return rowCmp;
    }
    final colCmp = a.col.compareTo(b.col);
    if (colCmp != 0) {
      return colCmp;
    }
    return a.id.index.compareTo(b.id.index);
  }
}

final class _GridOccupancy {
  _GridOccupancy();

  factory _GridOccupancy.fromTiles(List<HomeGridTile> tiles) {
    final occupancy = _GridOccupancy();
    for (final tile in tiles) {
      occupancy.mark(tile);
    }
    return occupancy;
  }

  final List<List<bool>> _rows = <List<bool>>[];

  void _ensureRow(int row) {
    while (_rows.length <= row) {
      _rows.add(List<bool>.filled(HomeGridLayoutEngine.columnCount, false));
    }
  }

  bool fitsAt(int col, int row, GridSpan span) {
    if (col < 0 ||
        row < 0 ||
        col + span.colSpan > HomeGridLayoutEngine.columnCount) {
      return false;
    }
    for (var r = row; r < row + span.rowSpan; r++) {
      if (r >= _rows.length) {
        continue;
      }
      for (var c = col; c < col + span.colSpan; c++) {
        if (_rows[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  void mark(HomeGridTile tile) {
    for (var r = tile.row; r < tile.endRow; r++) {
      _ensureRow(r);
      for (var c = tile.col; c < tile.endCol; c++) {
        _rows[r][c] = true;
      }
    }
  }

  ({int col, int row}) findFirstFit(GridSpan span) =>
      findFirstFitFromRow(span, startRow: 0);

  ({int col, int row}) findFirstFitFromRow(
    GridSpan span, {
    int startRow = 0,
  }) {
    final initialRow = math.max(0, startRow);
    for (var row = initialRow; ; row++) {
      for (var col = 0;
          col <= HomeGridLayoutEngine.columnCount - span.colSpan;
          col++) {
        if (fitsAt(col, row, span)) {
          return (col: col, row: row);
        }
      }
    }
  }
}
