# Agent guide: FeelsGoodUI

## Start here

Read [`FeelsGoodUI.toc`](FeelsGoodUI.toc) as the source of truth. It requires the external `oUF` addon and loads vendored LibStub/CallbackHandler/LibDataBroker/LibDBIcon/LibSharedMedia first. Core files then load in dependency order: namespace/bootstrap, logging/safety/schema/DB/settings/apply/theme/media/perf/events/lifecycle, feature registry and runtime-settings ownership, movers, minimap/options, QA/profile/commands, and `core/App.lua`; modules load last, followed by `FeelsGoodUI.lua`.

The executable entry points are `core/Bootstrap.lua:ns` and `core/Events.lua:OnEvent`. `core/App.lua:OnPlayerLogin` registers/enables feature modules and applies configuration. `FeelsGoodUI.lua` only marks the final entry file loaded; it is not the orchestrator.

## Runtime map

- `core/DB.lua:DB:Init` creates/migrates `FeelsGoodUIDB`, profiles, and sections. `core/Settings.lua` is the intended settings-write API; `core/Apply.lua` batches dirty apply keys, restores failed transactions, and defers combat-sensitive keys until `Apply:OnCombatEnd`. `core/PanelTransactions.lua` journals scalar writes plus panel undo/reset. `core/RuntimeSettings.lua` is the canonical apply owner for logging and the performance overlay.
- `core/FeatureRegistry.lua` is the contract table: feature order, apply order, panel order, module contracts, and theme consumers. `core/Lifecycle.lua:RegisterModule/Enable/Disable/EnableAll` supplies guarded module state and result-aware transitions.
- `core/App.lua:RegisterFeatureModules`, `EnableFeatureModules`, `RunStartupServices`, and `ApplyTheme` connect registry contracts to modules. `core/Events.lua` routes `ADDON_LOADED`, `PLAYER_LOGIN`, combat transitions, and blocked/forbidden action diagnostics.
- Unit frames: `modules/UnitFrames.lua` configures `UnitFramesPolicy`, `UnitFramesRender`, `UnitFramesRuntime`, `UnitFramesTarget`, and `UnitFramesText`, using external `oUF` frames. `UnitFramesRuntime`/`UnitFramesTarget` attach event observers for target/name/faction/level/auras.
- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. This is the most protected/taint-sensitive family.
- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. Companion and ExperienceBar are independent feature families registered through the same lifecycle.
- Options/minimap/commands are adapters over Settings/Apply. User mutations from the General panel and `/fgui debug|perf|aura|minimap` must never write both profile and runtime directly. `core/Commands.lua:Commands:Register` registers `SlashCmdList.FEELSGOODUI`.
- `/fgui` command groups are defined in `core/Commands.lua`: user (`unlock`, `lock`, `resetpos`, `config`, `export`, `import`, `minimap`, `reset`), transitional (`aura`), and diagnostic (`debug`, `perf`, `errors`, `clearerrors`, `qa`, `report`, `soak`).

## State and dependencies

`FeelsGoodUIDB` contains profile data, normalized feature sections, typography/media, mover positions, action-bar/unit-frame/center-bar/companion settings, and profile-transfer state. Runtime module state, caches, pending apply keys, undo journals, and observers are transient. Do not write directly to the global DB from a module or command; route persisted changes through `ns.Settings:Set/SetTx` and runtime effects through `ns.Apply:Request`.

`oUF` is required and external. The five support libraries are vendored in `libs/`; LibSharedMedia is used by `core/Media.lua`. `libs/LibDBIcon-1.0/lib.xml` is an inactive packaging descriptor in this snapshot because the root TOC loads `LibDBIcon-1.0.lua` directly. No in-house addon is a TOC dependency. The code may observe Blizzard UI and Edit Mode but must not assume those frames are loaded before the relevant `ADDON_LOADED`/login path.

## Change routing

- Add or migrate a setting: `core/DB.lua` defaults/migration, `core/Settings.lua` validation/normalization, then the relevant options panel; use `Settings:SetTx` and `Apply:Request`. Add an apply key to `core/FeatureRegistry.lua` only when a distinct runtime owner is required.
- Change general debug/performance runtime state: route through `core/RuntimeSettings.lua`; `Perf:SetEnabled` is runtime-only and must not persist configuration.
- Add a feature/module: define its contract in `core/FeatureRegistry.lua`, register it through `core/App.lua`, implement lifecycle methods in the module family, and preserve `Lifecycle` error/disable semantics.
- Change apply order or combat deferral: `core/FeatureRegistry.lua` apply order plus `core/Apply.lua`; do not patch a module to bypass the queue.
- Unit frame behavior: route layout/text/target/aura changes to `modules/UnitFrames*.lua`; keep `modules/UnitFrames.lua` as facade/configuration.
- Action bars: route secure holder/visibility to `ActionBarsState.lua`/`ActionBarsRuntime.lua`, Blizzard/Edit Mode synchronization to their dedicated files, and visual details to `ActionBarsVisuals.lua`.
- Options/movers/commands: modify the corresponding `core/Options*`, `Movers*`, or `Commands.lua` adapter and preserve Settings/Apply ownership.

## Invariants/risks

- `oUF` must exist before unit-frame startup; missing `oUF` is a hard functional dependency and is logged by `App:RunStartupServices`.
- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, and Blizzard shell visibility are protected boundaries. Defer mutations in combat and validate `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `MACRO_ACTION_FORBIDDEN` reports.
- Unit-frame/center-bar runtime handlers are event-driven hot paths. Preserve caches and narrow unit filters; avoid per-event allocations and unsafe arithmetic/comparisons on secret values (`core/Secret.lua`, `modules/UnitFramesText.lua`).
- Settings transaction rollback and apply-key ordering are correctness invariants: profile state, undo history, and runtime state must commit together or restore together.
- User-facing adapters must not update runtime optimistically after a profile write; the apply owner performs the runtime transition and reports failure back to the journal.
- `core/Bootstrap.lua` temporarily exposes a debug global; keep it removable through `HideDebugGlobal`.

## Verification

Static checks:

```powershell
Get-Content _Addons/FeelsGoodUI/FeelsGoodUI.toc
rg -n "RequiredDeps|FeelsGoodUIDB|RuntimeSettings|SetTx|Apply:Request|RegisterModule|Apply:OnCombatEnd|ADDON_ACTION_BLOCKED|SecureHandler|oUF" _Addons/FeelsGoodUI
```

In-game: test with and without `oUF`; reload/login; enable/disable every feature family; edit movers and reload; profile export/import/reset; Edit Mode and action-bar visibility; target/party/raid unit changes; resource/spec changes; enter/leave combat; `/fgui` command help and recent errors. Check command/UI parity for debug, perf, aura mode, and minimap state. Check the existing regression matrix in `docs/REGRESSION_MATRIX_1_25.md` and inspect BugGrabber for protected-action errors.

## Unknowns

Static evidence does not prove compatibility with every `oUF` revision or current Blizzard secure/Edit Mode implementation. Treat frame names, secret-value behavior, settings panel timing, and LibDBIcon drag persistence as target-client verification items.
