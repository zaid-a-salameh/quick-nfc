/// Open-closed pure Dart catalog of tools available to the home grid and hub.
library;

import '../models/grid_tile_models.dart';

/// Immutable metadata descriptor for a single registered home tool.
final class HomeToolDefinition {
  const HomeToolDefinition({
    required this.id,
    required this.semanticKey,
    required this.category,
    required this.visualTone,
    required this.defaultSpan,
    this.isRemovable = true,
    this.showInToolsHub = true,
  });

  /// Canonical tool identifier.
  final HomeToolId id;

  /// Stable UI automation/widget key preserved for test & accessibility parity.
  final String semanticKey;

  /// Functional group used for filtering or grouping in the Tools Hub.
  final ToolCategory category;

  /// Visual accent role resolved by the UI theme layer.
  final ToolVisualTone visualTone;

  /// Default span used when resetting or pinning the tool onto the home grid.
  final GridSpan defaultSpan;

  /// Whether the user can unpin/remove this tool from the home grid.
  final bool isRemovable;

  /// Whether this tool appears as an entry inside the Tools Hub catalog.
  final bool showInToolsHub;
}

/// Central registry defining grid dimensions, registered tools, and default
/// home screen placement.
abstract final class ToolRegistry {
  /// Fixed number of columns on the responsive home grid.
  static const int columnCount = 3;

  /// All registered tool definitions in display catalog order.
  static const List<HomeToolDefinition> allTools = <HomeToolDefinition>[
    HomeToolDefinition(
      id: HomeToolId.inspectCard,
      semanticKey: 'btn_tool_inspect_card',
      category: ToolCategory.inspection,
      visualTone: ToolVisualTone.primary,
      defaultSpan: GridSpan.threeByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.cloneCard,
      semanticKey: 'btn_tool_read_card',
      category: ToolCategory.data,
      visualTone: ToolVisualTone.standard,
      defaultSpan: GridSpan.oneByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.wifiCard,
      semanticKey: 'btn_tool_wifi_card',
      category: ToolCategory.data,
      visualTone: ToolVisualTone.standard,
      defaultSpan: GridSpan.oneByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.pinLock,
      semanticKey: 'btn_tool_pin_lock',
      category: ToolCategory.security,
      visualTone: ToolVisualTone.warning,
      defaultSpan: GridSpan.oneByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.eraseCard,
      semanticKey: 'btn_tool_erase_card',
      category: ToolCategory.data,
      visualTone: ToolVisualTone.standard,
      defaultSpan: GridSpan.oneByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.permLock,
      semanticKey: 'btn_tool_perm_lock',
      category: ToolCategory.security,
      visualTone: ToolVisualTone.danger,
      defaultSpan: GridSpan.oneByOne,
      isRemovable: true,
      showInToolsHub: true,
    ),
    HomeToolDefinition(
      id: HomeToolId.toolsHub,
      semanticKey: 'btn_tool_hub',
      category: ToolCategory.navigation,
      visualTone: ToolVisualTone.hub,
      defaultSpan: GridSpan.threeByOne,
      isRemovable: false,
      showInToolsHub: false,
    ),
  ];

  static final Map<HomeToolId, HomeToolDefinition> _definitionsById =
      <HomeToolId, HomeToolDefinition>{
    for (final tool in allTools) tool.id: tool,
  };

  /// Looks up the registered [HomeToolDefinition] for [id].
  static HomeToolDefinition byId(HomeToolId id) => _definitionsById[id]!;

  /// Tools surfaced inside the Deep Tools Hub catalog.
  static List<HomeToolDefinition> get hubTools =>
      allTools.where((tool) => tool.showInToolsHub).toList(growable: false);

  /// Initial home screen layout used on first launch and layout reset.
  static List<HomeGridTile> defaultLayout() => <HomeGridTile>[
        const HomeGridTile(
          id: HomeToolId.inspectCard,
          col: 0,
          row: 0,
          span: GridSpan.threeByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.cloneCard,
          col: 0,
          row: 1,
          span: GridSpan.oneByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.wifiCard,
          col: 1,
          row: 1,
          span: GridSpan.oneByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.pinLock,
          col: 0,
          row: 2,
          span: GridSpan.oneByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.eraseCard,
          col: 1,
          row: 2,
          span: GridSpan.oneByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.permLock,
          col: 2,
          row: 2,
          span: GridSpan.oneByOne,
        ),
        const HomeGridTile(
          id: HomeToolId.toolsHub,
          col: 0,
          row: 3,
          span: GridSpan.threeByOne,
        ),
      ];
}
