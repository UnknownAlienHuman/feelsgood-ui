# Architecture

`core/Bootstrap.lua` establishes the namespace and TOC-loaded core services. The lifecycle/event layer initializes persisted schema and settings, then `core/App.lua` consumes `FeatureRegistry` to apply enabled feature modules.

`core/DB.lua`, `core/Schema.lua`, and `core/Settings.lua` own `FeelsGoodUIDB`, migrations, profile operations, and setting application. Options and Movers are UI adapters around that state. `modules/` separates Unit Frames, Action Bars, Center Bars, Companion controls, and Experience Bar into public facades, runtime/event layers, renderers, and policy/state helpers.

Risks are lifecycle teardown and combat-sensitive Blizzard UI hand-offs. Validate enable/disable, reload, Edit Mode, profiles, and each enabled module in-game; the repository includes a regression matrix and Lua checker.
