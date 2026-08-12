# FeelsGoodUI Architecture Pattern Ledger

Purpose: track the patterns that are actually live in the addon tree, not abandoned branches or archived experiments.

## Module Lifecycle Contract
- Contract: `Attach -> Enable -> Disable -> Detach` with idempotent guards.
- Implemented:
  - `modules/UnitFrames.lua`
  - `modules/CenterBars.lua`
  - `modules/Companion.lua`
  - `modules/ExperienceBar.lua`
- Bootstrap path:
  - `core/App.lua` owns feature registration, enable order, and apply order.

## Panel Ownership Contract
- Pattern: panel metadata (`panelKey`, apply routing, reset sections, refresh context) lives in one shared registry instead of being duplicated in each page builder.
- Implemented:
  - `core/FeatureRegistry.lua`
  - `core/OptionsShared.lua`
  - `core/OptionsFieldBuilders.lua`
  - `core/OptionsSharedHelpers.lua`
  - `core/OptionsPanel*.lua`

## Apply Pipeline
- Pattern: settings writes are transactional and flow through one ordered apply graph rather than ad-hoc `ApplyAll`.
- Implemented:
  - `core/App.lua`
  - `core/Apply.lua`
  - `core/Settings.lua`

## Data Contract Normalization
- Pattern: normalize profile values once at DB/settings boundaries, not ad-hoc in render paths.
- Implemented:
  - `core/DB.lua`
  - `core/Settings.lua`
  - `modules/ExperienceBar.lua` keeps only runtime fallback clamps; DB remains the source of truth.

## Mover Spec Contract
- Pattern: each movable owner declares `applyKeys`, `positionKey`, and optional size/scale hooks through one spec object.
- Implemented:
  - `modules/ActionBarsEditMode.lua`
  - `modules/CenterBars.lua`
  - `modules/CompanionPetBar.lua`
  - `modules/ExperienceBar.lua`
  - `modules/UnitFramesPolicy.lua`

## Runtime Route Narrowing
- Pattern: runtime event layers should call one narrow feature-side coordinator instead of fanning out through several coarse owner proxy methods.
- Implemented:
  - `modules/CenterBarsRuntime.lua` -> `modules/CenterBarsRender.lua`
  - `modules/UnitFramesRuntime.lua` -> `modules/UnitFramesTarget.lua`
