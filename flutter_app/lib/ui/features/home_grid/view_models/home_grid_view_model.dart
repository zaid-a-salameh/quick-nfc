/// Stateful coordinator bridging the pure [HomeGridLayoutEngine] with
/// [PreferencesService] persistence, transient drag/resize previews, and haptics.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../data/services/hardware_bridge_service.dart';
import '../../../../data/services/preferences_service.dart';
import '../engine/home_grid_layout_engine.dart';
import '../models/grid_tile_models.dart';
import '../registry/tool_registry.dart';

/// ChangeNotifier managing the user's customizable 3-column home tool grid.
class HomeGridViewModel extends ChangeNotifier {
  /// Creates a [HomeGridViewModel] and immediately loads & sanitizes any
  /// persisted grid layout from [preferencesService].
  HomeGridViewModel({
    required this._preferencesService,
    this._hardwareBridge,
  })  : _showCustomizeHint =
            !_preferencesService.isGridCustomizeHintDismissed {
    _committedTiles = _loadInitialLayout();
  }

  /// Current JSON persistence schema version.
  static const int schemaVersion = 1;

  final PreferencesService _preferencesService;
  final HardwareBridgeService? _hardwareBridge;

  late List<HomeGridTile> _committedTiles;
  List<HomeGridTile>? _previewTiles;
  HomeToolId? _selectedTileId;
  HomeToolId? _draggingTileId;
  HomeToolId? _resizingTileId;
  bool _showCustomizeHint;

  /// Persisted layout tiles outside of transient gesture previews.
  List<HomeGridTile> get tiles => _committedTiles;

  /// Active tiles to render (transient drag/resize preview when active,
  /// otherwise [tiles]).
  List<HomeGridTile> get displayTiles => _previewTiles ?? _committedTiles;

  /// Total rows required by [displayTiles].
  int get totalRows => HomeGridLayoutEngine.totalRows(displayTiles);

  /// Whether the one-time grid customization tip should be shown above the grid.
  bool get showCustomizeHint => _showCustomizeHint && !isEditing;

  /// Tile currently selected for editing (e.g., resize dots & unpin action).
  HomeToolId? get selectedTileId => _selectedTileId;

  /// Tile currently being dragged across the grid, if any.
  HomeToolId? get draggingTileId => _draggingTileId;

  /// Tile currently being resized via an edge handle, if any.
  HomeToolId? get resizingTileId => _resizingTileId;

  /// Whether edit mode, drag preview, or resize preview is currently active.
  bool get isEditing =>
      _selectedTileId != null ||
      _draggingTileId != null ||
      _resizingTileId != null;

  /// Whether [id] is currently pinned in the committed home grid layout.
  bool isPinned(HomeToolId id) => _committedTiles.any((tile) => tile.id == id);

  /// Returns the committed tile for [id], or `null` if not pinned.
  HomeGridTile? tileFor(HomeToolId id) {
    for (final tile in _committedTiles) {
      if (tile.id == id) {
        return tile;
      }
    }
    return null;
  }

  /// Dismisses the one-time grid customization tip permanently.
  Future<void> dismissCustomizeHint() async {
    if (!_showCustomizeHint) {
      return;
    }
    _showCustomizeHint = false;
    notifyListeners();
    await _preferencesService.markGridCustomizeHintDismissed();
  }

  void _consumeCustomizeHintSilently() {
    if (!_showCustomizeHint) {
      return;
    }
    _showCustomizeHint = false;
    unawaited(_preferencesService.markGridCustomizeHintDismissed());
  }

  /// Selects [id] to display resize handles and edit controls.
  void selectTileForEdit(HomeToolId id) {
    if (!isPinned(id)) {
      return;
    }
    if (_selectedTileId == id) {
      return;
    }
    _consumeCustomizeHintSilently();
    _selectedTileId = id;
    unawaited(_safeHaptic());
    notifyListeners();
  }

  /// Exits tile edit selection without altering the committed layout.
  void clearSelection() {
    if (_selectedTileId == null &&
        _draggingTileId == null &&
        _resizingTileId == null &&
        _previewTiles == null) {
      return;
    }
    _selectedTileId = null;
    _draggingTileId = null;
    _resizingTileId = null;
    _previewTiles = null;
    notifyListeners();
  }

  /// Begins an interactive drag gesture for [id].
  void beginDrag(HomeToolId id) {
    if (!isPinned(id)) {
      return;
    }
    _consumeCustomizeHintSilently();
    _draggingTileId = id;
    _resizingTileId = null;
    _selectedTileId = id;
    _previewTiles = _committedTiles;
    unawaited(_safeHaptic());
    notifyListeners();
  }

  /// Updates the transient reflow preview while dragging a tile to
  /// ([targetCol], [targetRow]).
  void updateDragPreview({
    required int targetCol,
    required int targetRow,
    HomeToolId? id,
  }) {
    final activeId = id ?? _draggingTileId;
    if (activeId == null || !isPinned(activeId)) {
      return;
    }

    final nextPreview = HomeGridLayoutEngine.moveTile(
      _committedTiles,
      id: activeId,
      targetCol: targetCol,
      targetRow: targetRow,
    );

    if (listEquals(nextPreview, _previewTiles)) {
      return;
    }

    _draggingTileId = activeId;
    _previewTiles = nextPreview;
    notifyListeners();
  }

  /// Commits the active drag preview layout and persists it to preferences.
  Future<void> commitDrag() async {
    if (_draggingTileId == null) {
      return;
    }
    final next = _previewTiles ?? _committedTiles;
    final changed = !listEquals(next, _committedTiles);
    _committedTiles = next;
    _previewTiles = null;
    _draggingTileId = null;
    notifyListeners();
    if (changed) {
      await _persist(_committedTiles);
    }
  }

  /// Discards any in-flight drag preview and restores the committed layout.
  void cancelDrag() {
    if (_draggingTileId == null && _previewTiles == null) {
      return;
    }
    _previewTiles = null;
    _draggingTileId = null;
    notifyListeners();
  }

  /// Updates the transient resize preview for [id] (or the currently active
  /// selected/resizing tile) to [newSpan] anchored opposite [edge].
  void updateResizePreview({
    required GridSpan newSpan,
    ResizeEdge edge = ResizeEdge.right,
    HomeToolId? id,
  }) {
    final activeId = id ?? _resizingTileId ?? _selectedTileId;
    if (activeId == null || !isPinned(activeId)) {
      return;
    }

    final nextPreview = HomeGridLayoutEngine.resizeTile(
      _committedTiles,
      id: activeId,
      newSpan: newSpan,
      edge: edge,
    );

    if (_resizingTileId == activeId && listEquals(nextPreview, _previewTiles)) {
      return;
    }

    _resizingTileId = activeId;
    _selectedTileId = activeId;
    _previewTiles = nextPreview;
    unawaited(_safeHaptic());
    notifyListeners();
  }

  /// Commits the active resize preview layout and persists it to preferences.
  Future<void> commitResize() async {
    if (_resizingTileId == null && _previewTiles == null) {
      return;
    }
    final next = _previewTiles ?? _committedTiles;
    final changed = !listEquals(next, _committedTiles);
    _committedTiles = next;
    _previewTiles = null;
    _resizingTileId = null;
    notifyListeners();
    if (changed) {
      await _persist(_committedTiles);
    }
  }

  /// Discards any in-flight resize preview and restores the committed layout.
  void cancelResize() {
    if (_resizingTileId == null && _previewTiles == null) {
      return;
    }
    _previewTiles = null;
    _resizingTileId = null;
    notifyListeners();
  }

  /// Pins [id] onto the grid and persists the updated layout.
  Future<void> pinTool(
    HomeToolId id, {
    GridSpan? preferredSpan,
  }) async {
    if (isPinned(id)) {
      return;
    }
    _previewTiles = null;
    _draggingTileId = null;
    _resizingTileId = null;
    _committedTiles = HomeGridLayoutEngine.addTool(
      _committedTiles,
      id,
      preferredSpan: preferredSpan,
    );
    notifyListeners();
    await _persist(_committedTiles);
  }

  /// Unpins [id] from the grid if allowed by [ToolRegistry], compacting gaps
  /// and persisting the result.
  Future<void> unpinTool(HomeToolId id) async {
    if (!ToolRegistry.byId(id).isRemovable || !isPinned(id)) {
      return;
    }
    _previewTiles = null;
    _draggingTileId = null;
    _resizingTileId = null;
    _committedTiles = HomeGridLayoutEngine.removeTool(_committedTiles, id);
    if (_selectedTileId == id) {
      _selectedTileId = null;
    }
    notifyListeners();
    await _persist(_committedTiles);
  }

  /// Restores the factory default home grid layout and clears saved state.
  Future<void> resetToDefaultLayout() async {
    _previewTiles = null;
    _selectedTileId = null;
    _draggingTileId = null;
    _resizingTileId = null;
    _committedTiles = List<HomeGridTile>.unmodifiable(
      ToolRegistry.defaultLayout(),
    );
    notifyListeners();
    await _preferencesService.clearHomeGridLayout();
  }

  /// Encodes a layout into its versioned JSON string representation.
  static String encodeLayoutJson(List<HomeGridTile> tiles) =>
      jsonEncode(<String, dynamic>{
        'version': schemaVersion,
        'tiles': tiles.map((tile) => tile.toJson()).toList(growable: false),
      });

  List<HomeGridTile> _loadInitialLayout() {
    final raw = _preferencesService.getSavedHomeGridLayoutJson();
    if (raw == null || raw.trim().isEmpty) {
      return List<HomeGridTile>.unmodifiable(ToolRegistry.defaultLayout());
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return List<HomeGridTile>.unmodifiable(ToolRegistry.defaultLayout());
      }
      final version = decoded['version'];
      final rawTiles = decoded['tiles'];
      if (version is! int || version < 1 || rawTiles is! List) {
        return List<HomeGridTile>.unmodifiable(ToolRegistry.defaultLayout());
      }

      final parsed = <HomeGridTile>[];
      for (final entry in rawTiles) {
        if (entry is! Map) {
          continue;
        }
        final tile = HomeGridTile.fromJson(Map<String, dynamic>.from(entry));
        if (tile != null) {
          parsed.add(tile);
        }
      }

      if (parsed.isEmpty) {
        return List<HomeGridTile>.unmodifiable(ToolRegistry.defaultLayout());
      }

      return HomeGridLayoutEngine.sanitizeAndMigrate(parsed);
    } catch (_) {
      return List<HomeGridTile>.unmodifiable(ToolRegistry.defaultLayout());
    }
  }

  Future<void> _persist(List<HomeGridTile> tiles) async {
    await _preferencesService.setHomeGridLayoutJson(encodeLayoutJson(tiles));
  }

  Future<void> _safeHaptic() async {
    final bridge = _hardwareBridge;
    if (bridge == null) {
      return;
    }
    try {
      await bridge.triggerLightHaptic();
    } catch (_) {
      // Haptics are optional and safely ignored in headless test environments.
    }
  }
}
