/// Pure Dart domain models for the customizable 3-column home grid.
library;

/// Canonical identifiers for tools that can appear on the home grid or in the
/// Deep Tools Hub.
enum HomeToolId {
  inspectCard('inspect_card'),
  cloneCard('clone_card'),
  wifiCard('wifi_card'),
  pinLock('pin_lock'),
  eraseCard('erase_card'),
  permLock('perm_lock'),
  toolsHub('tools_hub');

  const HomeToolId(this.storageKey);

  /// Stable persistence key stored in user preferences.
  final String storageKey;

  /// Resolves a [HomeToolId] from its persisted [storageKey], or returns `null`
  /// if [key] is unrecognized.
  static HomeToolId? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final value in values) {
      if (value.storageKey == key) {
        return value;
      }
    }
    return null;
  }
}

/// High-level functional grouping for home tools.
enum ToolCategory {
  inspection,
  data,
  security,
  navigation,
}

/// Semantic visual emphasis for a tool tile, decoupled from Flutter UI colors.
enum ToolVisualTone {
  primary,
  standard,
  warning,
  danger,
  hub,
}

/// Edge handle along which a tile resize gesture operates.
enum ResizeEdge {
  left,
  right,
  top,
  bottom,
}

/// Allowed tile dimensions inside the 3-column home grid.
///
/// Only `1x1`, `2x1`, `3x1`, `2x2`, and `3x2` are permitted; `1x2` is
/// strictly disallowed by product design.
final class GridSpan {
  const GridSpan._(this.colSpan, this.rowSpan);

  /// Single cell (`1x1`).
  static const GridSpan oneByOne = GridSpan._(1, 1);

  /// Half/wide two-column strip (`2x1`).
  static const GridSpan twoByOne = GridSpan._(2, 1);

  /// Full-width banner strip (`3x1`).
  static const GridSpan threeByOne = GridSpan._(3, 1);

  /// Featured square block (`2x2`).
  static const GridSpan twoByTwo = GridSpan._(2, 2);

  /// Full-width double-height hero block (`3x2`).
  static const GridSpan threeByTwo = GridSpan._(3, 2);

  /// All spans permitted by the grid specification.
  static const List<GridSpan> allowedSpans = <GridSpan>[
    oneByOne,
    twoByOne,
    threeByOne,
    twoByTwo,
    threeByTwo,
  ];

  /// Returns a validated [GridSpan] for [colSpan] and [rowSpan], throwing an
  /// [ArgumentError] if the combination is not allowed.
  factory GridSpan(int colSpan, int rowSpan) {
    final resolved = tryCreate(colSpan, rowSpan);
    if (resolved == null) {
      throw ArgumentError(
        'Disallowed grid span ${colSpan}x$rowSpan. '
        'Only 1x1, 2x1, 3x1, 2x2, and 3x2 are permitted.',
      );
    }
    return resolved;
  }

  /// Width of the tile in grid columns.
  final int colSpan;

  /// Height of the tile in grid rows.
  final int rowSpan;

  /// Whether ([colSpan], [rowSpan]) matches one of the allowed sizes.
  static bool isAllowed(int colSpan, int rowSpan) =>
      tryCreate(colSpan, rowSpan) != null;

  /// Returns the canonical [GridSpan] for ([colSpan], [rowSpan]), or `null` if
  /// the combination is forbidden.
  static GridSpan? tryCreate(int colSpan, int rowSpan) {
    return switch ((colSpan, rowSpan)) {
      (1, 1) => oneByOne,
      (2, 1) => twoByOne,
      (3, 1) => threeByOne,
      (2, 2) => twoByTwo,
      (3, 2) => threeByTwo,
      _ => null,
    };
  }

  /// Total number of grid cells occupied by this span.
  int get area => colSpan * rowSpan;

  /// Human-readable `WxH` notation.
  String get label => '${colSpan}x$rowSpan';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridSpan &&
          other.colSpan == colSpan &&
          other.rowSpan == rowSpan;

  @override
  int get hashCode => Object.hash(colSpan, rowSpan);

  @override
  String toString() => 'GridSpan($label)';
}

/// Immutable placement of a single tool tile within the 3-column grid.
final class HomeGridTile {
  const HomeGridTile({
    required this.id,
    required this.col,
    required this.row,
    required this.span,
  });

  /// Identifier of the tool represented by this tile.
  final HomeToolId id;

  /// Zero-based starting column index (`0..2`).
  final int col;

  /// Zero-based starting row index (`>= 0`).
  final int row;

  /// Validated tile span (`1x1`, `2x1`, `3x1`, or `2x2`).
  final GridSpan span;

  /// Width in grid columns.
  int get colSpan => span.colSpan;

  /// Height in grid rows.
  int get rowSpan => span.rowSpan;

  /// Exclusive right column boundary.
  int get endCol => col + span.colSpan;

  /// Exclusive bottom row boundary.
  int get endRow => row + span.rowSpan;

  /// Whether this tile covers cell ([cellCol], [cellRow]).
  bool containsCell(int cellCol, int cellRow) =>
      cellCol >= col &&
      cellCol < endCol &&
      cellRow >= row &&
      cellRow < endRow;

  /// Whether this tile intersects another rectangular footprint.
  bool overlapsRect(int otherCol, int otherRow, GridSpan otherSpan) =>
      col < otherCol + otherSpan.colSpan &&
      endCol > otherCol &&
      row < otherRow + otherSpan.rowSpan &&
      endRow > otherRow;

  /// Whether this tile intersects [other].
  bool overlaps(HomeGridTile other) =>
      overlapsRect(other.col, other.row, other.span);

  /// Returns a copy of this tile with the specified fields updated.
  HomeGridTile copyWith({
    HomeToolId? id,
    int? col,
    int? row,
    GridSpan? span,
  }) {
    return HomeGridTile(
      id: id ?? this.id,
      col: col ?? this.col,
      row: row ?? this.row,
      span: span ?? this.span,
    );
  }

  /// Serializes this tile to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.storageKey,
        'col': col,
        'row': row,
        'colSpan': span.colSpan,
        'rowSpan': span.rowSpan,
      };

  /// Reconstructs a tile from JSON, returning `null` if fields are malformed or
  /// the encoded span is forbidden.
  static HomeGridTile? fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawCol = json['col'];
    final rawRow = json['row'];
    final rawColSpan = json['colSpan'];
    final rawRowSpan = json['rowSpan'];

    if (rawId is! String ||
        rawCol is! int ||
        rawRow is! int ||
        rawColSpan is! int ||
        rawRowSpan is! int) {
      return null;
    }

    final id = HomeToolId.fromStorageKey(rawId);
    final span = GridSpan.tryCreate(rawColSpan, rawRowSpan);
    if (id == null || span == null) {
      return null;
    }

    return HomeGridTile(
      id: id,
      col: rawCol,
      row: rawRow,
      span: span,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeGridTile &&
          other.id == id &&
          other.col == col &&
          other.row == row &&
          other.span == span;

  @override
  int get hashCode => Object.hash(id, col, row, span);

  @override
  String toString() =>
      'HomeGridTile(id: ${id.storageKey}, col: $col, row: $row, span: ${span.label})';
}
