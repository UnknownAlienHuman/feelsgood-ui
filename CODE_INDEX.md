# Code index

| Path | Responsibility |
| --- | --- |
| `FeelsGoodUI.toc` | Metadata, dependency, and load order. |
| `FeelsGoodUI.lua` | Final addon entry file. |
| `core/Bootstrap.lua`, `core/Events.lua`, `core/Lifecycle.lua`, `core/App.lua` | Namespace, lifecycle, event handling, and feature orchestration. |
| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, validated setting writes, apply ordering, and runtime restoration. |
| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |
| `core/PanelTransactions.lua` | Ordered `SetTx`/undo/reset journal, ownership-aware rollback, multi-key commit tracking, undo-history repair, and panel refresh callbacks. |
| `core/MoversShared.lua`, `core/MoversInspector.lua`, `core/MoversEditor.lua`, `core/Movers.lua` | Mover geometry, preview-only input, normalized terminal commits, transactional scale/size adapters, and the `movers` apply owner. |
| `core/Options*.lua`, `core/Commands.lua` | Settings pages and command adapters over Settings/Apply. |
| `core/FeatureRegistry.lua` | Feature, apply, panel, combat-deferral, and mover-owner contracts. |
| `modules/UnitFrames*.lua` | Unit-frame runtime, render, policy, target, and text behavior. |
| `modules/ActionBars*.lua` | Action-bar runtime, visual, state, Edit Mode, and Blizzard shell handling. |
| `modules/CenterBars*.lua`, `modules/Companion*.lua`, `modules/ExperienceBar.lua` | Other feature families. |
| `docs/` | Plans, archived work, architecture ledger, and regression material. |
