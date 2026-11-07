# Code index

| Path | Responsibility |
| --- | --- |
| `FeelsGoodUI.toc` | Metadata, dependency, and load order. |
| `FeelsGoodUI.lua` | Final addon entry file. |
| `core/Bootstrap.lua`, `core/Events.lua`, `core/Lifecycle.lua`, `core/App.lua` | Namespace, lifecycle, event handling, and feature orchestration. |
| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, validated setting writes, apply ordering, and runtime restoration. |
| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |
| `core/MoversTransactions.lua` | Pure mover write builders, runtime-only position/geometry preview, one-shot Settings commits, and preview restoration after failure/cancel. |
| `core/PanelTransactions.lua` | Ordered `SetTx`/undo/reset/profile-replacement journal, ownership-aware rollback, multi-key commit tracking, history repair, and terminal callbacks. |
| `core/ProfileImport.lua`, `core/ProfileTransfer.lua` | Bounded decode/export UI, detached normalization, profile-wide atomic commit/rollback, and durable recovery for interrupted imports. |
| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |
| `core/FeatureRegistry.lua` | Feature definitions and apply order. |
| `modules/UnitFrames*.lua` | Unit-frame runtime, render, policy, target, and text behavior. |
| `modules/ActionBars*.lua` | Action-bar runtime, visual, state, Edit Mode, and Blizzard shell handling. |
| `modules/CenterBars*.lua`, `modules/Companion*.lua`, `modules/ExperienceBar.lua` | Other feature families. |
| `docs/` | Plans, archived work, architecture ledger, and regression material. |
