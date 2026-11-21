# Quick NFC Architectural Rules

## Core Principle: Concept-Based Modular Architecture (Prevent Accumulative Coupling)

1. **Cohesion Over Line Counts**
   - Never split or forbid files based on arbitrary line-count thresholds.
   - Split modules strictly by *conceptual responsibility* and *reason to change*.
   - A cohesive protocol catalog, state machine, or data table may legitimately be long; a short file mixing unrelated concerns (such as hardware I/O, UI rendering, and persistence) must be decomposed.

2. **Feature-First Vertical Slices**
   - Never bolt new capabilities onto existing multi-purpose files (such as `MainActivity.kt`, `HomeScreen`, or monolithic ViewModels).
   - Build every distinct capability in its own dedicated feature or module directory (`models/`, `engine/` or `services/`, `view_models/`, `widgets/`) and connect it to entry points through minimal, thin wiring.

3. **Thin Coordinators & Explicit Data Contracts**
   - Host activities, platform channels, root screens, and routers should only bind lifecycle, dispatch, and delegate to dedicated units via immutable, typed contracts.

4. **Open-Closed Extensibility**
   - Repeating or extensible surfaces (tool catalogs, widget grids, NFC chip profiles, NDEF record parsers) must be registry- or strategy-driven so adding future capabilities requires zero edits to core layout, gesture, or routing infrastructure.

5. **Pure Testable Core**
   - Decouple algorithms, cryptography, layout math, and protocol parsing from UI and framework APIs so they are unit-testable in isolation and free from UI side effects.

6. **Leave Existing Monoliths Untangled**
   - When working near an already-large legacy file, extract new logic into dedicated cohesive modules rather than expanding the monolith.

## Quick NFC Vertical Slice Map
- **Shared NFC Hardware Capabilities**: `flutter_app/android/app/src/main/kotlin/com/example/reviewlinkgenerator/nfc/NfcTagCapabilities.kt`
- **Native NFC Inspection Engine**: `flutter_app/android/app/src/main/kotlin/com/example/reviewlinkgenerator/nfc/inspector/`
- **Native NFC Permanent Locker**: `flutter_app/android/app/src/main/kotlin/com/example/reviewlinkgenerator/nfc/locker/`
- **Tag Inspector Feature**: `flutter_app/lib/ui/features/tag_inspector/`
- **Interactive Home Grid**: `flutter_app/lib/ui/features/home_grid/`
- **Tools Hub**: `flutter_app/lib/ui/features/tools_hub/`
