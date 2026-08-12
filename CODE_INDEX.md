# Code index

| Path | Responsibility |
| --- | --- |
| `FeelsGoodUI.toc` | Metadata, dependency, and load order. |
| `FeelsGoodUI.lua` | Final addon entry file. |
| `core/Bootstrap.lua`, `core/Events.lua`, `core/Lifecycle.lua`, `core/App.lua` | Namespace, lifecycle, event handling, and feature orchestration. |
| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, setting writes, and configuration application. |
| `core/Options*.lua`, `core/Movers*.lua` | Settings pages and frame editing/movement UI. |
| `core/FeatureRegistry.lua` | Feature definitions and apply order. |
| `modules/UnitFrames*.lua` | Unit-frame runtime, render, policy, target, and text behavior. |
| `modules/ActionBars*.lua` | Action-bar runtime, visual, state, Edit Mode, and Blizzard shell handling. |
| `modules/CenterBars*.lua`, `modules/Companion*.lua`, `modules/ExperienceBar.lua` | Other feature families. |
| `docs/` | Plans, archived work, architecture ledger, and regression material. |
