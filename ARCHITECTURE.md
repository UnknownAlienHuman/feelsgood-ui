# Architecture

`core/Bootstrap.lua` establishes the namespace and TOC-loaded core services. `core/App.lua` consumes `FeatureRegistry`, while `core/Lifecycle.lua` is the single feature-state owner: attach/apply results are checked, failed transitions clean up before state publication, reentrant transitions are rejected, and independent feature failures do not stop later families from loading.

`core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua`, and `core/PanelTransactions.lua` own `FeelsGoodUIDB`, migrations, validated writes, ordered apply, rollback, panel undo/reset history, and runtime restoration. Options and Movers are UI adapters around that state. `modules/` separates Unit Frames, Action Bars, Center Bars, Companion controls, and Experience Bar into public facades, runtime/event layers, renderers, and policy/state helpers.

Feature configuration is distinct from lifecycle ownership. A family may start configured off while its lifecycle registration remains valid; Unit Frames and Center Bars lazily initialize and acquire their event/observer owners when later enabled, without requiring `/reload`.

Risks are lifecycle teardown, partial apply, and combat-sensitive Blizzard UI hand-offs. Validate disabled-at-login enable paths, failure cleanup, enable/disable, reload, Edit Mode, profiles, and each enabled module in-game; the repository includes a regression matrix and Lua checker.
