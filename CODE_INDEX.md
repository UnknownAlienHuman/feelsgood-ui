# Code index

| Path | Responsibility |
| --- | --- |
| `FeelsGoodUI.toc` | Metadata, dependency, and load order. |
| `FeelsGoodUI.lua` | Final addon entry file. |
| `core/Bootstrap.lua`, `core/Events.lua`, `core/Lifecycle.lua`, `core/App.lua` | Namespace, lifecycle, event handling, and feature orchestration, including pre-enable recovery of interrupted native ActionBars takeover. |
| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, pure `ReadSection` vs explicit `EnsureSection`, validated setting writes, apply ordering, and runtime restoration. |
| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |
| `core/Animate.lua`, `core/Utils.lua` | Weak-key fade/timer ownership and stateless shared helpers without caller-object cache fields. |
| `core/Media.lua` | Media lookup, icon crop/font helpers, and weak-key border ownership without foreign-frame metadata. |
| `core/MoversTransactions.lua` | Pure mover write builders, runtime-only position/geometry preview, one-shot Settings commits, and preview restoration after failure/cancel. |
| `core/PanelTransactions.lua` | Ordered `SetTx`/undo/reset/profile-replacement journal, ownership-aware rollback, multi-key commit tracking, history repair, and terminal callbacks. |
| `core/ProfileImport.lua`, `core/ProfileTransfer.lua` | Bounded decode/export UI, detached normalization, profile-wide atomic commit/rollback, and durable recovery for interrupted imports. |
| `core/MinimapIcon.lua` | LibDBIcon runtime proxy, weak-key button-hook ownership, exact active-drag owner, terminal position transaction, and rollback reconciliation. |
| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |
| `core/FeatureRegistry.lua` | Feature definitions and apply order. |
| `modules/UnitFramesPolicy.lua` | Read-only UnitFrames configuration/cache policy, immutable fallbacks, and transactional mover write builders. |
| `modules/UnitFramesRuntime.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesText.lua`, `modules/UnitFrames.lua` | Unit-frame lifecycle, rendering, target/aura observers, text safety, weak-key oUF runtime ownership, and result-bearing unit-watch transitions without persisted configuration repair. |
| `modules/ActionBarsBlizzardShell.lua` | Reversible Blizzard shell/native-toggle takeover, per-character recovery across reload/interruption, exact detach restore, and managed-position synchronization. |
| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, and mover integration without direct profile mutation. |
| `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua` | Weak-key ActionButton/region runtime registries, custom state layers, typography/cooldown caches, empty-slot and hotkey presentation. |
| `modules/CenterBars*.lua` | Center-resource rendering/runtime plus reversible, conflict-aware Blizzard class-resource alpha/mouse ownership. |
| `modules/CompanionRuntime.lua` | Result-bearing Companion lifecycle/apply coordinator and partial-layer cleanup. |
| `modules/CompanionPetState.lua` | Exact original/managed PetActionButton and native PetActionBar snapshot journal with conflict-aware restore. |
| `modules/CompanionMicroBags.lua`, `modules/CompanionPetBar.lua`, `modules/CompanionShared.lua` | Owner-local hook/cache state plus pet-bar, micro-menu, and bag presentation layers. |
| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, single lifecycle apply owner, and reversible Blizzard status-tracking alpha/mouse suppression. |
| `docs/` | Plans, archived work, architecture ledger, and regression material. |
