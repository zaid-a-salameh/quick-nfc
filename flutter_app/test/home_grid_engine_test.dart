import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/data/services/preferences_service.dart';
import 'package:review_link_generator/ui/features/home_grid/engine/home_grid_layout_engine.dart';
import 'package:review_link_generator/ui/features/home_grid/models/grid_tile_models.dart';
import 'package:review_link_generator/ui/features/home_grid/registry/tool_registry.dart';
import 'package:review_link_generator/ui/features/home_grid/view_models/home_grid_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolRegistry & default layout invariants', () {
    test('default layout matches agreed 3x4 hierarchy and invariants', () {
      final layout = ToolRegistry.defaultLayout();

      expect(layout.length, 7);
      expect(HomeGridLayoutEngine.columnCount, 3);
      expect(HomeGridLayoutEngine.totalRows(layout), 4);
      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);

      expect(
        layout.first,
        const HomeGridTile(
          id: HomeToolId.inspectCard,
          col: 0,
          row: 0,
          span: GridSpan.threeByOne,
        ),
      );
      expect(
        layout[1],
        const HomeGridTile(
          id: HomeToolId.cloneCard,
          col: 0,
          row: 1,
          span: GridSpan.oneByOne,
        ),
      );
      expect(
        layout[2],
        const HomeGridTile(
          id: HomeToolId.wifiCard,
          col: 1,
          row: 1,
          span: GridSpan.oneByOne,
        ),
      );
      expect(
        layout[3],
        const HomeGridTile(
          id: HomeToolId.pinLock,
          col: 0,
          row: 2,
          span: GridSpan.oneByOne,
        ),
      );
      expect(
        layout[4],
        const HomeGridTile(
          id: HomeToolId.eraseCard,
          col: 1,
          row: 2,
          span: GridSpan.oneByOne,
        ),
      );
      expect(
        layout[5],
        const HomeGridTile(
          id: HomeToolId.permLock,
          col: 2,
          row: 2,
          span: GridSpan.oneByOne,
        ),
      );
      expect(
        layout.last,
        const HomeGridTile(
          id: HomeToolId.toolsHub,
          col: 0,
          row: 3,
          span: GridSpan.threeByOne,
        ),
      );
    });

    test('preserves semantic keys, removability, and hub catalog filtering',
        () {
      expect(
        ToolRegistry.byId(HomeToolId.inspectCard).semanticKey,
        'btn_tool_inspect_card',
      );
      expect(
        ToolRegistry.byId(HomeToolId.cloneCard).semanticKey,
        'btn_tool_read_card',
      );
      expect(
        ToolRegistry.byId(HomeToolId.wifiCard).semanticKey,
        'btn_tool_wifi_card',
      );
      expect(
        ToolRegistry.byId(HomeToolId.pinLock).semanticKey,
        'btn_tool_pin_lock',
      );
      expect(
        ToolRegistry.byId(HomeToolId.eraseCard).semanticKey,
        'btn_tool_erase_card',
      );
      expect(
        ToolRegistry.byId(HomeToolId.permLock).semanticKey,
        'btn_tool_perm_lock',
      );
      expect(
        ToolRegistry.byId(HomeToolId.toolsHub).semanticKey,
        'btn_tool_hub',
      );

      expect(ToolRegistry.byId(HomeToolId.inspectCard).isRemovable, isTrue);
      expect(ToolRegistry.byId(HomeToolId.toolsHub).isRemovable, isFalse);
      expect(ToolRegistry.byId(HomeToolId.toolsHub).showInToolsHub, isFalse);

      final hubTools = ToolRegistry.hubTools;
      expect(hubTools.length, 6);
      expect(
        hubTools.any((tool) => tool.id == HomeToolId.toolsHub),
        isFalse,
      );
      expect(
        hubTools.any((tool) => tool.id == HomeToolId.inspectCard),
        isTrue,
      );
    });
  });

  group('GridSpan rules & resolveSpanFromDrag', () {
    test('permits 1x1, 2x1, 3x1, 2x2, and 3x2 spans', () {
      expect(
        GridSpan.allowedSpans,
        const <GridSpan>[
          GridSpan.oneByOne,
          GridSpan.twoByOne,
          GridSpan.threeByOne,
          GridSpan.twoByTwo,
          GridSpan.threeByTwo,
        ],
      );
      expect(GridSpan.isAllowed(1, 1), isTrue);
      expect(GridSpan.isAllowed(2, 1), isTrue);
      expect(GridSpan.isAllowed(3, 1), isTrue);
      expect(GridSpan.isAllowed(2, 2), isTrue);
      expect(GridSpan.isAllowed(3, 2), isTrue);

      for (final forbidden in const <(int, int)>[
        (1, 2),
        (0, 1),
        (1, 0),
        (4, 1),
        (2, 3),
        (-1, 1),
      ]) {
        expect(
          GridSpan.isAllowed(forbidden.$1, forbidden.$2),
          isFalse,
          reason: 'Expected ${forbidden.$1}x${forbidden.$2} to be disallowed',
        );
        expect(
          GridSpan.tryCreate(forbidden.$1, forbidden.$2),
          isNull,
        );
        expect(
          () => GridSpan(forbidden.$1, forbidden.$2),
          throwsArgumentError,
        );
      }

      expect(
        HomeGridTile.fromJson(const <String, dynamic>{
          'id': 'inspect_card',
          'col': 0,
          'row': 0,
          'colSpan': 1,
          'rowSpan': 2,
        }),
        isNull,
      );
      expect(
        HomeGridTile.fromJson(const <String, dynamic>{
          'id': 'non_existent',
          'col': 0,
          'row': 0,
          'colSpan': 1,
          'rowSpan': 1,
        }),
        isNull,
      );
    });

    test('resolveSpanFromDrag maps forbidden targets cleanly by intent', () {
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: 1,
          targetRowSpan: 2,
          currentSpan: GridSpan.oneByOne,
          activeEdge: ResizeEdge.bottom,
        ),
        GridSpan.twoByTwo,
      );
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: 1,
          targetRowSpan: 2,
          currentSpan: GridSpan.twoByTwo,
          activeEdge: ResizeEdge.right,
        ),
        GridSpan.oneByOne,
      );
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: 3,
          targetRowSpan: 2,
          currentSpan: GridSpan.threeByOne,
          activeEdge: ResizeEdge.bottom,
        ),
        GridSpan.threeByTwo,
      );
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: 3,
          targetRowSpan: 2,
          currentSpan: GridSpan.twoByTwo,
          activeEdge: ResizeEdge.left,
        ),
        GridSpan.threeByTwo,
      );
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: 9,
          targetRowSpan: 1,
          currentSpan: GridSpan.oneByOne,
        ),
        GridSpan.threeByOne,
      );
      expect(
        HomeGridLayoutEngine.resolveSpanFromDrag(
          targetColSpan: -2,
          targetRowSpan: 0,
        ),
        GridSpan.oneByOne,
      );
    });

    test('resolveAutoFillHalfSlots detects pure two-tile 1x1 rows only', () {
      const layout = <HomeGridTile>[
        // Row 0: adjacent 1x1 + 1x1 -> auto-fill 0 & 1
        HomeGridTile(id: HomeToolId.pinLock, col: 0, row: 0, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.eraseCard, col: 1, row: 0, span: GridSpan.oneByOne),
        // Row 1: gapped 1x1 (col 0) + 1x1 (col 2) -> auto-fill 0 & 1
        HomeGridTile(id: HomeToolId.permLock, col: 0, row: 1, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.cloneCard, col: 2, row: 1, span: GridSpan.oneByOne),
        // Row 2-3: 2x2 crosses both rows; row 2 has 1x1 beside 2x2 -> NOT auto-filled;
        // row 3 also crossed by 2x2 with single 1x1? wait let's put 2x1 on row 4 + 1x1
        HomeGridTile(id: HomeToolId.inspectCard, col: 0, row: 2, span: GridSpan.twoByTwo),
        HomeGridTile(id: HomeToolId.wifiCard, col: 2, row: 2, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.toolsHub, col: 0, row: 4, span: GridSpan.threeByOne),
      ];

      final slots = HomeGridLayoutEngine.resolveAutoFillHalfSlots(layout);
      expect(slots[HomeToolId.pinLock], 0);
      expect(slots[HomeToolId.eraseCard], 1);
      expect(slots[HomeToolId.permLock], 0);
      expect(slots[HomeToolId.cloneCard], 1);
      expect(slots.containsKey(HomeToolId.inspectCard), isFalse);
      expect(slots.containsKey(HomeToolId.wifiCard), isFalse);
      expect(slots.containsKey(HomeToolId.toolsHub), isFalse);

      // 3x(1x1) row, single 1x1 row, and 2x1 + 1x1 row must NOT auto-fill.
      const nonAutoRows = <HomeGridTile>[
        HomeGridTile(id: HomeToolId.pinLock, col: 0, row: 0, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.eraseCard, col: 1, row: 0, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.permLock, col: 2, row: 0, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.cloneCard, col: 0, row: 1, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.wifiCard, col: 1, row: 1, span: GridSpan.twoByOne),
        HomeGridTile(id: HomeToolId.inspectCard, col: 0, row: 2, span: GridSpan.oneByOne),
        HomeGridTile(id: HomeToolId.toolsHub, col: 0, row: 3, span: GridSpan.threeByOne),
      ];
      expect(HomeGridLayoutEngine.resolveAutoFillHalfSlots(nonAutoRows), isEmpty);
    });
  });

  group('Move, exact swap, collision reflow, and empty row collapse', () {
    test('swaps two tiles directly when target footprint matches exactly', () {
      final layout = ToolRegistry.defaultLayout();
      final swapped = HomeGridLayoutEngine.moveTile(
        layout,
        id: HomeToolId.permLock,
        targetCol: 0,
        targetRow: 2,
      );

      expect(HomeGridLayoutEngine.isValidLayout(swapped), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(swapped), isFalse);

      HomeGridTile find(HomeToolId id) =>
          swapped.firstWhere((tile) => tile.id == id);

      expect(find(HomeToolId.permLock).col, 0);
      expect(find(HomeToolId.permLock).row, 2);
      expect(find(HomeToolId.pinLock).col, 2);
      expect(find(HomeToolId.pinLock).row, 2);
      // Unrelated tiles preserve exact placement.
      expect(find(HomeToolId.eraseCard).col, 1);
      expect(find(HomeToolId.eraseCard).row, 2);
      expect(find(HomeToolId.inspectCard).row, 0);
      expect(find(HomeToolId.wifiCard).col, 1);
      expect(find(HomeToolId.wifiCard).row, 1);
    });

    test('reflows heterogeneous collisions cleanly without overlaps or gaps',
        () {
      final layout = ToolRegistry.defaultLayout();
      final moved = HomeGridLayoutEngine.moveTile(
        layout,
        id: HomeToolId.cloneCard,
        targetCol: 0,
        targetRow: 0,
      );

      expect(HomeGridLayoutEngine.isValidLayout(moved), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(moved), isFalse);
      expect(moved.length, layout.length);

      final clone = moved.firstWhere((t) => t.id == HomeToolId.cloneCard);
      expect(clone.col, 0);
      expect(clone.row, 0);
    });

    test('collapses empty middle rows when dropping far past grid end', () {
      final layout = ToolRegistry.defaultLayout();
      final dropped = HomeGridLayoutEngine.moveTile(
        layout,
        id: HomeToolId.inspectCard,
        targetCol: 0,
        targetRow: 99,
      );

      expect(HomeGridLayoutEngine.isValidLayout(dropped), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(dropped), isFalse);

      final inspect = dropped.firstWhere((t) => t.id == HomeToolId.inspectCard);
      expect(inspect.endRow, HomeGridLayoutEngine.totalRows(dropped));
    });

    test('preserves 2x2 rigid shape during moves and compaction', () {
      final withTwoByTwo = HomeGridLayoutEngine.resizeTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.wifiCard,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.bottom,
      );

      final moved = HomeGridLayoutEngine.moveTile(
        withTwoByTwo,
        id: HomeToolId.wifiCard,
        targetCol: 0,
        targetRow: 0,
      );

      expect(HomeGridLayoutEngine.isValidLayout(moved), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(moved), isFalse);
      final wifi = moved.firstWhere((t) => t.id == HomeToolId.wifiCard);
      expect(wifi.span, GridSpan.twoByTwo);
      expect(wifi.col, 0);
      expect(wifi.row, 0);
    });

    test('dragging 3rd tile out of a 3-tile row preserves remaining 2-tile auto-fill pair without sucking lower rows',
        () {
      final layout = HomeGridLayoutEngine.moveTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.permLock,
        targetCol: 0,
        targetRow: 4,
      );

      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);

      final pinLock = layout.firstWhere((t) => t.id == HomeToolId.pinLock);
      final eraseCard = layout.firstWhere((t) => t.id == HomeToolId.eraseCard);
      final permLock = layout.firstWhere((t) => t.id == HomeToolId.permLock);
      expect(pinLock.row, 2);
      expect(eraseCard.row, 2);
      expect(permLock.row, 4);

      final autoSlots = HomeGridLayoutEngine.resolveAutoFillHalfSlots(layout);
      expect(autoSlots[HomeToolId.pinLock], 0);
      expect(autoSlots[HomeToolId.eraseCard], 1);
    });

    test('shrinking 2x1 tile to 1x1 keeps row as a calm 2-tile auto-fill pair without sucking row-2 upward',
        () {
      final withTwoByOne = HomeGridLayoutEngine.resizeTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.wifiCard,
        newSpan: GridSpan.twoByOne,
        edge: ResizeEdge.right,
      );
      final shrunk = HomeGridLayoutEngine.resizeTile(
        withTwoByOne,
        id: HomeToolId.wifiCard,
        newSpan: GridSpan.oneByOne,
        edge: ResizeEdge.right,
      );

      expect(HomeGridLayoutEngine.isValidLayout(shrunk), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(shrunk), isFalse);

      final cloneCard = shrunk.firstWhere((t) => t.id == HomeToolId.cloneCard);
      final wifiCard = shrunk.firstWhere((t) => t.id == HomeToolId.wifiCard);
      final pinLock = shrunk.firstWhere((t) => t.id == HomeToolId.pinLock);
      final eraseCard = shrunk.firstWhere((t) => t.id == HomeToolId.eraseCard);
      final permLock = shrunk.firstWhere((t) => t.id == HomeToolId.permLock);
      expect(cloneCard.row, 1);
      expect(wifiCard.row, 1);
      expect(pinLock.row, 2);
      expect(eraseCard.row, 2);
      expect(permLock.row, 2);

      final autoSlots = HomeGridLayoutEngine.resolveAutoFillHalfSlots(shrunk);
      expect(autoSlots[HomeToolId.cloneCard], 0);
      expect(autoSlots[HomeToolId.wifiCard], 1);
    });

    test('dragging full-row inspectCard from row 0 to row 1 cleanly slides row 1 upward to row 0',
        () {
      final slid = HomeGridLayoutEngine.moveTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.inspectCard,
        targetCol: 0,
        targetRow: 1,
      );

      expect(HomeGridLayoutEngine.isValidLayout(slid), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(slid), isFalse);

      final cloneCard = slid.firstWhere((t) => t.id == HomeToolId.cloneCard);
      final wifiCard = slid.firstWhere((t) => t.id == HomeToolId.wifiCard);
      final inspectCard = slid.firstWhere((t) => t.id == HomeToolId.inspectCard);
      expect(cloneCard.row, 0);
      expect(wifiCard.row, 0);
      expect(inspectCard.row, 1);
    });
  });

  group('4-edge resizing and movable/resizable toolsHub', () {
    test('right edge resize keeps left edge anchored', () {
      final resized = HomeGridLayoutEngine.resizeTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.cloneCard,
        newSpan: GridSpan.twoByOne,
        edge: ResizeEdge.right,
      );

      expect(HomeGridLayoutEngine.isValidLayout(resized), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(resized), isFalse);
      final clone = resized.firstWhere((t) => t.id == HomeToolId.cloneCard);
      expect(clone.col, 0);
      expect(clone.row, 1);
      expect(clone.span, GridSpan.twoByOne);
    });

    test('left edge resize keeps right edge anchored', () {
      final resized = HomeGridLayoutEngine.resizeTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.permLock,
        newSpan: GridSpan.twoByOne,
        edge: ResizeEdge.left,
      );

      expect(HomeGridLayoutEngine.isValidLayout(resized), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(resized), isFalse);
      final perm = resized.firstWhere((t) => t.id == HomeToolId.permLock);
      expect(perm.col, 1);
      expect(perm.endCol, 3);
      expect(perm.row, 2);
      expect(perm.span, GridSpan.twoByOne);
    });

    test('bottom edge resize expands downward into 2x2 from top edge', () {
      final resized = HomeGridLayoutEngine.resizeTile(
        ToolRegistry.defaultLayout(),
        id: HomeToolId.wifiCard,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.bottom,
      );

      expect(HomeGridLayoutEngine.isValidLayout(resized), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(resized), isFalse);
      final wifi = resized.firstWhere((t) => t.id == HomeToolId.wifiCard);
      expect(wifi.col, 1);
      expect(wifi.row, 1);
      expect(wifi.span, GridSpan.twoByTwo);
    });

    test('top edge resize keeps bottom edge anchored while growing or shrinking',
        () {
      // Expand 2x1 tile upward from row 3 -> occupies rows 2..3 (endRow stays 4).
      final expandedUp = HomeGridLayoutEngine.resizeTile(
        HomeGridLayoutEngine.resizeTile(
          ToolRegistry.defaultLayout(),
          id: HomeToolId.toolsHub,
          newSpan: GridSpan.twoByOne,
          edge: ResizeEdge.right,
        ),
        id: HomeToolId.toolsHub,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.top,
      );

      expect(HomeGridLayoutEngine.isValidLayout(expandedUp), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(expandedUp), isFalse);
      final hubUp = expandedUp.firstWhere((t) => t.id == HomeToolId.toolsHub);
      expect(hubUp.span, GridSpan.twoByTwo);
      expect(hubUp.row, 2);
      expect(hubUp.endRow, 4);

      // Shrink that 2x2 tile via top edge back to 2x1 -> top drops to row 3.
      final shrunkDown = HomeGridLayoutEngine.resizeTile(
        expandedUp,
        id: HomeToolId.toolsHub,
        newSpan: GridSpan.twoByOne,
        edge: ResizeEdge.top,
      );

      expect(HomeGridLayoutEngine.isValidLayout(shrunkDown), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(shrunkDown), isFalse);
      final hubDown =
          shrunkDown.firstWhere((t) => t.id == HomeToolId.toolsHub);
      expect(hubDown.span, GridSpan.twoByOne);
      expect(hubDown.row, 3);
      expect(hubDown.endRow, 4);
    });

    test('clamps edge expansions near right/top boundaries gracefully', () {
      final layout = ToolRegistry.defaultLayout();
      // 1x1 at rightmost column (col 2) growing to 2x2 via right edge clamps col to 1.
      final rightClamped = HomeGridLayoutEngine.resizeTile(
        layout,
        id: HomeToolId.permLock,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.right,
      );
      expect(HomeGridLayoutEngine.isValidLayout(rightClamped), isTrue);
      final perm =
          rightClamped.firstWhere((t) => t.id == HomeToolId.permLock);
      expect(perm.col, 1);
      expect(perm.endCol, 3);

      // Move a 1x1 to row 0 and resize via top edge into 2x2 -> row clamps to 0.
      final atTop = HomeGridLayoutEngine.moveTile(
        layout,
        id: HomeToolId.cloneCard,
        targetCol: 0,
        targetRow: 0,
      );
      final topClamped = HomeGridLayoutEngine.resizeTile(
        atTop,
        id: HomeToolId.cloneCard,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.top,
      );
      expect(HomeGridLayoutEngine.isValidLayout(topClamped), isTrue);
      final clone = topClamped.firstWhere((t) => t.id == HomeToolId.cloneCard);
      expect(clone.row, 0);
      expect(clone.span, GridSpan.twoByTwo);
    });

    test('toolsHub can be freely moved and resized across all allowed spans',
        () {
      var layout = ToolRegistry.defaultLayout();

      for (final span in GridSpan.allowedSpans) {
        layout = HomeGridLayoutEngine.resizeTile(
          layout,
          id: HomeToolId.toolsHub,
          newSpan: span,
          edge: ResizeEdge.right,
        );
        expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
        expect(
          layout.firstWhere((t) => t.id == HomeToolId.toolsHub).span,
          span,
        );
      }

      layout = HomeGridLayoutEngine.resizeTile(
        layout,
        id: HomeToolId.toolsHub,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.right,
      );
      layout = HomeGridLayoutEngine.moveTile(
        layout,
        id: HomeToolId.toolsHub,
        targetCol: 1,
        targetRow: 0,
      );
      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);
      final hub = layout.firstWhere((t) => t.id == HomeToolId.toolsHub);
      expect(hub.col, 1);
      expect(hub.row, 0);
    });
  });

  group('Add, remove, and iOS-style upward compaction', () {
    test('removing inspectCard compacts all lower rows upward', () {
      final layout = HomeGridLayoutEngine.removeTool(
        ToolRegistry.defaultLayout(),
        HomeToolId.inspectCard,
      );

      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);
      expect(layout.any((t) => t.id == HomeToolId.inspectCard), isFalse);
      expect(HomeGridLayoutEngine.totalRows(layout), 3);
      expect(
        layout.firstWhere((t) => t.id == HomeToolId.toolsHub).row,
        2,
      );
    });

    test('removing wifiCard keeps row-2 1x1 tools in place without upward suction', () {
      final layout = HomeGridLayoutEngine.removeTool(
        ToolRegistry.defaultLayout(),
        HomeToolId.wifiCard,
      );

      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);

      final pinLock = layout.firstWhere((t) => t.id == HomeToolId.pinLock);
      final eraseCard = layout.firstWhere((t) => t.id == HomeToolId.eraseCard);
      final permLock = layout.firstWhere((t) => t.id == HomeToolId.permLock);
      expect(pinLock.row, 2);
      expect(pinLock.col, 0);
      expect(eraseCard.row, 2);
      expect(eraseCard.col, 1);
      expect(permLock.row, 2);
      expect(permLock.col, 2);
    });

    test('toolsHub cannot be removed', () {
      final initial = ToolRegistry.defaultLayout();
      final afterAttempt = HomeGridLayoutEngine.removeTool(
        initial,
        HomeToolId.toolsHub,
      );

      expect(afterAttempt, initial);
      expect(
        afterAttempt.any((t) => t.id == HomeToolId.toolsHub),
        isTrue,
      );
    });

    test('addTool keeps bottom-anchored toolsHub on the last row and fills gaps',
        () {
      // Remove permLock (1x1) -> cell (2,2) is free on row 2.
      // Remove wifiCard (1x1) -> cell (1,1) is free on row 1, row 2 stays intact.
      var layout = HomeGridLayoutEngine.removeTool(
        ToolRegistry.defaultLayout(),
        HomeToolId.wifiCard,
      );
      layout = HomeGridLayoutEngine.addTool(
        layout,
        HomeToolId.wifiCard,
      );

      expect(HomeGridLayoutEngine.isValidLayout(layout), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(layout), isFalse);

      final wifi = layout.firstWhere((t) => t.id == HomeToolId.wifiCard);
      final hub = layout.firstWhere((t) => t.id == HomeToolId.toolsHub);
      expect(wifi.col, 1);
      expect(wifi.row, 1);
      expect(hub.row, 3);

      // Adding a removed full-width inspectCard goes above bottom-anchored toolsHub.
      var withoutInspect = HomeGridLayoutEngine.removeTool(
        ToolRegistry.defaultLayout(),
        HomeToolId.inspectCard,
      );
      withoutInspect = HomeGridLayoutEngine.addTool(
        withoutInspect,
        HomeToolId.inspectCard,
      );
      expect(HomeGridLayoutEngine.isValidLayout(withoutInspect), isTrue);
      final reAddedInspect =
          withoutInspect.firstWhere((t) => t.id == HomeToolId.inspectCard);
      final keptBottomHub =
          withoutInspect.firstWhere((t) => t.id == HomeToolId.toolsHub);
      expect(reAddedInspect.row, lessThan(keptBottomHub.row));
      expect(keptBottomHub.endRow, HomeGridLayoutEngine.totalRows(withoutInspect));
    });

    test('addTool avoids duplicate pinning and handles unanchored toolsHub',
        () {
      final before = ToolRegistry.defaultLayout();
      final noDup = HomeGridLayoutEngine.addTool(before, HomeToolId.wifiCard);
      expect(noDup.length, before.length);

      // Move toolsHub to top (no longer anchored at bottom row), unpin & repin permLock.
      var movedHub = HomeGridLayoutEngine.resizeTile(
        before,
        id: HomeToolId.toolsHub,
        newSpan: GridSpan.oneByOne,
        edge: ResizeEdge.right,
      );
      movedHub = HomeGridLayoutEngine.moveTile(
        movedHub,
        id: HomeToolId.toolsHub,
        targetCol: 0,
        targetRow: 0,
      );
      movedHub = HomeGridLayoutEngine.removeTool(movedHub, HomeToolId.permLock);
      movedHub = HomeGridLayoutEngine.addTool(movedHub, HomeToolId.permLock);

      expect(HomeGridLayoutEngine.isValidLayout(movedHub), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(movedHub), isFalse);
      expect(movedHub.any((t) => t.id == HomeToolId.permLock), isTrue);
      expect(movedHub.any((t) => t.id == HomeToolId.toolsHub), isTrue);
    });
  });

  group('Persistence, recovery, and HomeGridViewModel lifecycle', () {
    Future<PreferencesService> createPrefs([
      Map<String, Object> initialValues = const <String, Object>{},
    ]) async {
      SharedPreferences.setMockInitialValues(initialValues);
      final prefs = await SharedPreferences.getInstance();
      return PreferencesService(prefs);
    }

    test('loads default layout initially and persists customizations across runs',
        () async {
      final prefsService = await createPrefs();
      final vm = HomeGridViewModel(preferencesService: prefsService);

      expect(vm.tiles, ToolRegistry.defaultLayout());
      expect(vm.displayTiles, vm.tiles);
      expect(vm.isPinned(HomeToolId.inspectCard), isTrue);

      await vm.unpinTool(HomeToolId.inspectCard);
      expect(vm.isPinned(HomeToolId.inspectCard), isFalse);

      await vm.pinTool(HomeToolId.inspectCard);
      expect(vm.isPinned(HomeToolId.inspectCard), isTrue);

      // Simulate cold restart reading back from the same SharedPreferences store.
      final reloadedPrefs = PreferencesService(
        await SharedPreferences.getInstance(),
      );
      final vm2 = HomeGridViewModel(preferencesService: reloadedPrefs);
      expect(vm2.tiles, vm.tiles);
      expect(HomeGridLayoutEngine.isValidLayout(vm2.tiles), isTrue);
    });

    test('recovers cleanly from corrupt JSON and missing toolsHub payloads',
        () async {
      for (final corruptPayload in const <String>[
        '{not valid json',
        '[]',
        '{"version": 1, "tiles": "oops"}',
        '{"version": 1, "tiles": []}',
        '{"version": 0, "tiles": []}',
      ]) {
        final prefs = await createPrefs(<String, Object>{
          'home_grid_layout_v1': corruptPayload,
        });
        final vm = HomeGridViewModel(preferencesService: prefs);
        expect(
          vm.tiles,
          ToolRegistry.defaultLayout(),
          reason: 'Expected fallback to default for payload: $corruptPayload',
        );
      }

      // Valid persisted subset missing non-removable toolsHub + containing
      // overlaps & duplicate IDs should sanitize & restore toolsHub.
      const incompletePayload = '''
      {
        "version": 1,
        "tiles": [
          {"id": "inspect_card", "col": 0, "row": 0, "colSpan": 3, "rowSpan": 1},
          {"id": "clone_card", "col": 0, "row": 0, "colSpan": 1, "rowSpan": 1},
          {"id": "clone_card", "col": 2, "row": 5, "colSpan": 1, "rowSpan": 1},
          {"id": "perm_lock", "col": 9, "row": -3, "colSpan": 1, "rowSpan": 2}
        ]
      }
      ''';

      final prefs = await createPrefs(<String, Object>{
        'home_grid_layout_v1': incompletePayload,
      });
      final vm = HomeGridViewModel(preferencesService: prefs);

      expect(HomeGridLayoutEngine.isValidLayout(vm.tiles), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(vm.tiles), isFalse);
      expect(vm.isPinned(HomeToolId.inspectCard), isTrue);
      expect(vm.isPinned(HomeToolId.cloneCard), isTrue);
      expect(vm.isPinned(HomeToolId.toolsHub), isTrue);
      // Invalid 1x2 entry for perm_lock was discarded rather than crashing.
      expect(vm.isPinned(HomeToolId.permLock), isFalse);

      // Also test sanitizeAndMigrate preserving existing valid tools while adding hub.
      final sanitized = HomeGridLayoutEngine.sanitizeAndMigrate(
        const <HomeGridTile>[
          HomeGridTile(
            id: HomeToolId.inspectCard,
            col: 0,
            row: 0,
            span: GridSpan.threeByOne,
          ),
          HomeGridTile(
            id: HomeToolId.cloneCard,
            col: 0,
            row: 1,
            span: GridSpan.oneByOne,
          ),
        ],
      );
      expect(sanitized.length, 3);
      expect(
        sanitized.any((t) => t.id == HomeToolId.toolsHub),
        isTrue,
      );
      expect(HomeGridLayoutEngine.isValidLayout(sanitized), isTrue);
      expect(HomeGridLayoutEngine.hasEmptyRows(sanitized), isFalse);
    });

    test('drag & resize preview/commit/cancel lifecycle and reset work properly',
        () async {
      final prefs = await createPrefs();
      final vm = HomeGridViewModel(preferencesService: prefs);
      var notifications = 0;
      vm.addListener(() => notifications++);

      final original = vm.tiles;

      // Drag preview -> cancel keeps committed unchanged & leaves prefs empty.
      vm.beginDrag(HomeToolId.permLock);
      expect(vm.isEditing, isTrue);
      expect(vm.draggingTileId, HomeToolId.permLock);
      vm.updateDragPreview(targetCol: 0, targetRow: 2);
      expect(vm.displayTiles, isNot(equals(original)));
      expect(vm.tiles, original);

      vm.cancelDrag();
      expect(vm.displayTiles, original);
      expect(vm.draggingTileId, isNull);
      expect(prefs.getSavedHomeGridLayoutJson(), isNull);

      // Drag preview -> commit persists changes.
      vm.beginDrag(HomeToolId.permLock);
      vm.updateDragPreview(targetCol: 0, targetRow: 2);
      await vm.commitDrag();
      expect(vm.tiles, vm.displayTiles);
      expect(
        vm.tileFor(HomeToolId.permLock)!.col,
        0,
      );
      expect(prefs.getSavedHomeGridLayoutJson(), isNotNull);

      // Resize preview -> cancel discards preview cleanly.
      final beforeResize = vm.tiles;
      vm.selectTileForEdit(HomeToolId.wifiCard);
      vm.updateResizePreview(
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.bottom,
      );
      expect(vm.resizingTileId, HomeToolId.wifiCard);
      expect(
        vm.displayTiles.firstWhere((t) => t.id == HomeToolId.wifiCard).span,
        GridSpan.twoByTwo,
      );
      expect(vm.tiles, beforeResize);

      vm.cancelResize();
      expect(vm.displayTiles, beforeResize);
      expect(vm.resizingTileId, isNull);

      // Resize preview -> commit persists & clearSelection closes edit state.
      vm.updateResizePreview(
        id: HomeToolId.wifiCard,
        newSpan: GridSpan.twoByTwo,
        edge: ResizeEdge.bottom,
      );
      await vm.commitResize();
      expect(
        vm.tileFor(HomeToolId.wifiCard)!.span,
        GridSpan.twoByTwo,
      );

      vm.clearSelection();
      expect(vm.isEditing, isFalse);

      // Refuses unpinning toolsHub.
      await vm.unpinTool(HomeToolId.toolsHub);
      expect(vm.isPinned(HomeToolId.toolsHub), isTrue);

      // Reset clears persisted JSON and restores default layout.
      await vm.resetToDefaultLayout();
      expect(vm.tiles, ToolRegistry.defaultLayout());
      expect(prefs.getSavedHomeGridLayoutJson(), isNull);
      expect(notifications, greaterThan(0));
    });
  });

  group('Deterministic randomized fuzz stress test (150 steps)', () {
    test('maintains all grid invariants across 150 pseudo-random operations',
        () {
      final rng = math.Random(0x51C4AFC);
      var layout = ToolRegistry.defaultLayout();
      const allIds = HomeToolId.values;
      const allEdges = ResizeEdge.values;
      const allSpans = GridSpan.allowedSpans;

      for (var step = 0; step < 150; step++) {
        final op = rng.nextInt(5);

        switch (op) {
          case 0: // moveTile
            final tile = layout[rng.nextInt(layout.length)];
            layout = HomeGridLayoutEngine.moveTile(
              layout,
              id: tile.id,
              targetCol: rng.nextInt(5) - 1,
              targetRow: rng.nextInt(12),
            );
          case 1: // resizeTile
            final tile = layout[rng.nextInt(layout.length)];
            final edge = allEdges[rng.nextInt(allEdges.length)];
            final rawCols = rng.nextInt(5);
            final rawRows = rng.nextInt(3) + 1;
            final resolvedSpan = HomeGridLayoutEngine.resolveSpanFromDrag(
              targetColSpan: rawCols,
              targetRowSpan: rawRows,
              currentSpan: tile.span,
              activeEdge: edge,
            );
            layout = HomeGridLayoutEngine.resizeTile(
              layout,
              id: tile.id,
              newSpan: resolvedSpan,
              edge: edge,
            );
          case 2: // addTool
            final id = allIds[rng.nextInt(allIds.length)];
            final span = allSpans[rng.nextInt(allSpans.length)];
            layout = HomeGridLayoutEngine.addTool(
              layout,
              id,
              preferredSpan: span,
            );
          case 3: // removeTool (including attempted toolsHub removal)
            final id = allIds[rng.nextInt(allIds.length)];
            layout = HomeGridLayoutEngine.removeTool(layout, id);
          default: // packCompact
            layout = HomeGridLayoutEngine.packCompact(layout);
        }

        expect(
          HomeGridLayoutEngine.isValidLayout(layout),
          isTrue,
          reason: 'Invalid layout at fuzz step $step: $layout',
        );
        expect(
          HomeGridLayoutEngine.hasEmptyRows(layout),
          isFalse,
          reason: 'Empty middle row at fuzz step $step: $layout',
        );
        expect(
          layout.any((t) => t.id == HomeToolId.toolsHub),
          isTrue,
          reason: 'toolsHub missing at fuzz step $step: $layout',
        );
        for (final tile in layout) {
          expect(
            GridSpan.isAllowed(tile.colSpan, tile.rowSpan),
            isTrue,
            reason: 'Disallowed span ${tile.span} at fuzz step $step',
          );
        }
        expect(
          layout.map((t) => t.id).toSet().length,
          layout.length,
          reason: 'Duplicate ID at fuzz step $step',
        );
      }
    });
  });
}
