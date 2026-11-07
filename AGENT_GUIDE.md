# Agent guide: FeelsGoodUI

## Start here

Read [`FeelsGoodUI.toc`](FeelsGoodUI.toc) as the source of truth. It requires the external `oUF` addon and loads vendored LibStub/CallbackHandler/LibDataBroker/LibDBIcon/LibSharedMedia first. Core files then load in dependency order: namespace/bootstrap, logging/safety/schema/DB/settings/apply/theme/media/perf/events/lifecycle, feature registry and runtime-settings ownership, movers, minimap/options, QA/profile/commands, and `core/App.lua`; modules load last, followed by `FeelsGoodUI.lua`.

The executable entry points are `core/Bootstrap.lua:ns` and `core/Events.lua:OnEvent`. `core/App.lua:OnPlayerLogin` registers/enables feature modules and applies configuration. `FeelsGoodUI.lua` only marks the final entry file loaded; it is not the orchestrator.

## Runtime map

- `core/DB.lua:DB:Init` creates/migrates `FeelsGoodUIDB`, profiles, and sections. `DB:ReadSection` is the non-mutating runtime reader; `DB:EnsureSection` is the explicit section-creation boundary and `DB:GetSection` is compatibility-only. `core/Settings.lua` is the intended settings-write API; `core/Apply.lua` batches dirty apply keys, restores failed transactions, and defers combat-sensitive keys until `Apply:OnCombatEnd`. `core/PanelTransactions.lua` journals scalar writes, panel undo/reset, and profile-wide replacement. `core/RuntimeSettings.lua` owns logging/performance presentation; `core/MoversTransactions.lua` owns mover preview-to-commit transitions; `core/ProfileImport.lua` owns detached normalization, terminal import commit/rollback, and interrupted-import recovery.
- `core/FeatureRegistry.lua` is the contract table: feature order, apply order, panel order, module contracts, and theme consumers. `core/Lifecycle.lua:RegisterModule/Enable/Disable/EnableAll` supplies guarded module state and result-aware transitions.
- `core/App.lua:RegisterFeatureModules`, `EnableFeatureModules`, `RunStartupServices`, and `ApplyTheme` connect registry contracts to modules. Interrupted profile-import recovery runs before `DB.Init`; `core/Events.lua` routes `ADDON_LOADED`, `PLAYER_LOGIN`, combat transitions, and blocked/forbidden action diagnostics.
- Unit frames: `modules/UnitFrames.lua` configures `UnitFramesPolicy`, `UnitFramesRender`, `UnitFramesRuntime`, `UnitFramesTarget`, and `UnitFramesText`, using external `oUF` frames. Policy getters are read-only and resolve missing sections/size/scale data locally; only DB/Settings/schema may repair persisted UnitFrames configuration. `UnitFramesRuntime`/`UnitFramesTarget` attach event observers for target/name/faction/level/auras.
- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. `ActionBarsBlizzardShell` snapshots native multi-bar toggles before takeover, persists a per-character recovery vector across reload/interruption, restores that vector on `PLAYER_LOGIN` before feature enable, and restores the exact snapshot on detach; it must never infer or persist addon profile configuration from Blizzard toggles. This is the most protected/taint-sensitive family.
- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns reversible alpha/mouse suppression of Blizzard class-resource frames through owner-local records and permanent gated OnShow hooks; it never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.
- Companion: `CompanionRuntime` coordinates PetBar and MicroBags as result-bearing layers; hook registries, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. `CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties, treats structural layout and dynamic visibility as separate ownership groups, reopens snapshots when component objects are replaced, and refuses unreadable mutable state. A failed layer restores partial presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.
- ExperienceBar owns one lifecycle apply path and the same narrow reversible policy for Blizzard status-tracking frames.
- Media: `core/Media.lua` owns borders through a weak-key registry keyed by target frame; consumers use `CreateBorder`, `GetBorder`, and `SetBorderColor` and never stamp addon metadata onto Blizzard/third-party frames.
- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, hooks drag start/stop, and commits only the terminal position through Settings/Apply; never pass the live `profile.minimap` table to third-party code.
- Options/minimap/commands are adapters over Settings/Apply. User mutations from the General panel and `/fgui debug|perf|aura|minimap` must never write both profile and runtime directly. `core/Commands.lua:Commands:Register` registers `SlashCmdList.FEELSGOODUI`.
- `/fgui` command groups are defined in `core/Commands.lua`: user (`unlock`, `lock`, `resetpos`, `config`, `export`, `import`, `minimap`, `reset`), transitional (`aura`), and diagnostic (`debug`, `perf`, `errors`, `clearerrors`, `qa`, `report`, `soak`).

## State and dependencies

`FeelsGoodUIDB` contains profile data, normalized feature sections, typography/media, mover positions, action-bar/unit-frame/center-bar/companion settings, and profile-transfer state. Runtime module state, caches, pending apply keys, undo journals, and observers are transient. While an import is waiting for terminal apply, the root may contain temporary `_profileImportRecovery` data with the previous and expected profiles; it must be removed on commit/rollback or consumed before `DB.Init` after an interrupted session. Do not write directly to the global DB from a module or command; route persisted changes through `ns.Settings:Set/SetTx` and runtime effects through `ns.Apply:Request`.

`oUF` is required and external. The five support libraries are vendored in `libs/`; LibSharedMedia is used by `core/Media.lua`. `libs/LibDBIcon-1.0/lib.xml` is an inactive packaging descriptor in this snapshot because the root TOC loads `LibDBIcon-1.0.lua` directly. No in-house addon is a TOC dependency. The code may observe Blizzard UI and Edit Mode but must not assume those frames are loaded before the relevant `ADDON_LOADED`/login path.

## Change routing

- Add or migrate a setting: `core/DB.lua` defaults/migration, `core/Settings.lua` validation/normalization, then the relevant options panel; use `Settings:SetTx` and `Apply:Request`. Runtime/core readers use `DB:ReadSection`; only validated write owners may call `DB:EnsureSection`. Add an apply key to `core/FeatureRegistry.lua` only when a distinct runtime owner is required.
- Change general debug/performance runtime state: route through `core/RuntimeSettings.lua`; `Perf:SetEnabled` is runtime-only and must not persist configuration.
- Change profile import/export: keep decode/bounds/schema compatibility in `core/ProfileTransfer.lua`; keep detached normalization, full apply-order transaction ownership, terminal callbacks, and durable recovery in `core/ProfileImport.lua`. Never call individual runtime owners or invalidate history directly from the UI adapter.
- Add a feature/module: define its contract in `core/FeatureRegistry.lua`, register it through `core/App.lua`, implement lifecycle methods in the module family, and preserve `Lifecycle` error/disable semantics.
- Change apply order or combat deferral: `core/FeatureRegistry.lua` apply order plus `core/Apply.lua`; do not patch a module to bypass the queue.
- Unit frame behavior: route layout/text/target/aura changes to `modules/UnitFrames*.lua`; keep `modules/UnitFrames.lua` as facade/configuration.
- Action bars: route secure holder/visibility to `ActionBarsState.lua`/`ActionBarsRuntime.lua`, Blizzard/Edit Mode synchronization to their dedicated files, and visual details to `ActionBarsVisuals.lua`.
- Options/movers/commands: modify the corresponding adapter and preserve Settings/Apply ownership. Continuous mover input may preview runtime frames only; build validated writes in the feature mover spec and commit through `MoversTransactions` once at the terminal input event.

## Invariants/risks

- `oUF` must exist before unit-frame startup; missing `oUF` is a hard functional dependency and is logged by `App:RunStartupServices`.
- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, Blizzard shell visibility, and native action-bar toggles are protected ownership boundaries. Defer mutations in combat, snapshot before takeover, restore exactly on detach, avoid redundant native writes, and validate `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `MACRO_ACTION_FORBIDDEN` reports.
- Unit-frame/center-bar runtime handlers are event-driven hot paths. Preserve caches and narrow unit filters; avoid per-event allocations, persisted profile repair, and unsafe arithmetic/comparisons on secret values (`core/Secret.lua`, `modules/UnitFramesText.lua`).
- Foreign Blizzard-frame takeover must mutate the narrowest properties, capture them before first write, avoid duplicate lifecycle owners, restore only values still owned by the addon, and keep all ownership metadata on addon-owned registries rather than foreign frame fields.
- Third-party runtime adapters must not receive live SavedVariables tables when they can mutate them; use detached proxies and translate terminal changes into validated Settings transactions.
- Read paths must never create SavedVariables sections: `DB:GetSection` is not used by first-party runtime code, `DB:ReadSection` returns nil for missing/non-table sections, and repair is explicit through `DB:EnsureSection`/Settings/Schema.
- Settings transaction rollback and apply-key ordering are correctness invariants: profile state, undo history, and runtime state must commit together or restore together. A mover resize that changes both feature geometry and anchor position is one multi-owner transaction, not independent writes.
- Profile import is not successful until every immediate and combat-deferred apply owner commits. `/reload`, logout, or termination while pending must recover the previous profile before DB initialization and overlay only changes made after the import began.
- User-facing adapters must not update runtime optimistically after a profile write; the apply owner performs the runtime transition and reports failure back to the journal.
- `core/Bootstrap.lua` temporarily exposes a debug global; keep it removable through `HideDebugGlobal`.

## Verification

Static checks:

```powershell
Get-Content _Addons/FeelsGoodUI/FeelsGoodUI.toc
rg -n "RequiredDeps|FeelsGoodUIDB|ProfileImport|_profileImportRecovery|RuntimeSettings|MoversTransactions|SetTx|Apply:Request|RegisterModule|Apply:OnCombatEnd|ADDON_ACTION_BLOCKED|SecureHandler|oUF" _Addons/FeelsGoodUI
```

In-game: test with and without `oUF`; reload/login; enable/disable every feature family; edit movers and reload; profile export/import/reset; import during combat and force a late owner failure; reload or log out while an import is pending and confirm recovery; Edit Mode and action-bar visibility; target/party/raid unit changes; resource/spec changes; enter/leave combat; `/fgui` command help and recent errors. Check command/UI parity for debug, perf, aura mode, and minimap state. Check the existing regression matrix in `docs/REGRESSION_MATRIX_1_25.md` and inspect BugGrabber for protected-action errors.

## Unknowns

Static evidence does not prove compatibility with every `oUF` revision, current Blizzard secure/Edit Mode implementation, or actual SavedVariables write timing. Treat frame names, secret-value behavior, settings panel timing, LibDBIcon drag persistence, and interrupted-import recovery in the target client as runtime verification items.
