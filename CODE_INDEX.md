# Code index

| Path | Responsibility |
| --- | --- |
| `FeelsGoodUI.toc` | Metadata, dependency, and load order. |
| `FeelsGoodUI.lua` | Final addon entry file. |
| `core/Bootstrap.lua`, `core/Events.lua`, `core/Lifecycle.lua`, `core/App.lua` | Namespace, lifecycle, event handling, and feature orchestration, including pre-enable recovery of interrupted native ActionBars takeover. |
| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, pure `ReadSection` vs explicit `EnsureSection`, validated setting writes, apply ordering, and runtime restoration. |
| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |
| `core/MoversTransactions.lua` | Pure mover write builders, runtime-only position/geometry preview, one-shot Settings commits, and preview restoration after failure/cancel. |
| `core/PanelTransactions.lua` | Ordered `SetTx`/undo/reset/profile-replacement journal, ownership-aware rollback, multi-key commit tracking, history repair, and terminal callbacks. |
| `core/ProfileImport.lua`, `core/ProfileTransfer.lua` | Bounded decode/export UI, detached normalization, profile-wide atomic commit/rollback, and durable recovery for interrupted imports. |
| `core/MinimapIcon.lua` | LibDBIcon runtime proxy, terminal drag-position transaction, visibility apply owner, and rollback reconciliation. |
| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |
| `core/FeatureRegistry.lua` | Feature definitions and apply order. |
| `modules/UnitFramesPolicy.lua` | Read-only UnitFrames configuration/cache policy, immutable fallbacks, and transactional mover write builders. |
| `modules/UnitFramesRuntime.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesText.lua`, `modules/UnitFrames.lua` | Unit-frame lifecycle, rendering, target/aura observers, text safety, and facade wiring without persisted configuration repair. |
| `modules/ActionBarsBlizzardShell.lua` | Reversible Blizzard shell/native-toggle takeover, per-character recovery across reload/interruption, exact detach restore, and managed-position synchronization. |
| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, state, visuals, and mover integration without direct profile mutation. |
| `modules/CenterBars*.lua`, `modules/Companion*.lua` | Center-resource and companion feature families. |
| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, single lifecycle apply owner, and reversible Blizzard status-tracking alpha/mouse suppression. |
| `docs/` | Plans, archived work, architecture ledger, and regression material. |
