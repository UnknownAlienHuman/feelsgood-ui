# FeelsGoodUI TODO

Updated: 2026-11-06. Completed historical execution notes live in `history.md`; this file contains only runtime evidence that cannot be produced by static review.

## Retail 12.1.5 implementation status

- [x] Target Interface `120105` and release `0.0.67`.
- [x] Gate Secret/Restricted Values before Lua inspection, conversion, comparison, or formatting.
- [x] Integrate restricted Unit Frame and Center Bar handling into the canonical render/target owners; remove late method overrides and duplicate producer calls.
- [x] Keep opaque power/text on exact native sinks where available; otherwise render an explicit unavailable state.
- [x] Never format or read back opaque health-percent text; never retain opaque rune samples for a later refresh.
- [x] Replace exception-based arithmetic/string probes in shared helpers.
- [x] Make the static checker fail on syntax, TOC, duplicate, missing-file, and load-order errors; expose `npm test`.
- [x] Replace the stale 12.0.1/removed-feature regression matrix with current 12.1.5 coverage.
- [x] Invalidate queued ActionBars apply/hide/auto-hide work on detach, silence permanent hooks while detached, and defer Blizzard-shell restoration through one post-combat watcher.
- [x] Define one shared debounce contract: an existing keyed timer is a successful coalesced request, callers never inspect `Safety._timers`, and teardown cancellation invalidates generations before restore.
- [x] Propagate explicit apply-handler failures through FeatureRegistry/App/Apply, roll back the entire settings batch, restore already-applied runtime owners, and centrally defer UnitFrames transactions during combat.
- [x] Journal scalar writes, panel undo, and panel reset in one operation order; failed/deferred batches repair exact undo artifacts, preserve newer owners, and restore every runtime key that had already committed.
- [x] Make lifecycle enable/disable result-aware and reentrancy-safe; failed attach/apply never publishes an enabled state, independent features continue loading, and disabled-at-login UnitFrames/CenterBars can acquire their runtime owners later.
- [x] Route debug/perf/aura/minimap command and General-panel mutations through `Settings:SetTx -> Apply`; remove duplicate direct runtime writes and make `RuntimeSettings` the single owner of logging/perf application.
- [x] Separate mover geometry preview from persistence: drag/resize hot paths mutate runtime frames only, terminal input creates one validated transaction, and failed/cancelled commits restore the persisted runtime owner.
- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, restore the prior profile on any late failure, and persist a recovery record for interrupted imports.
- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into addon profile data, persist a per-character recovery vector across reload/interruption, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach vector after out-of-combat or deferred detach.
- [x] Make UnitFrames runtime configuration read-only: remove render/apply-time size/scale normalizers, stop getters from creating profile sections, and resolve missing values through local immutable fallbacks while DB/Settings/schema remain the only repair owners.
- [x] Enforce one DB read/write boundary across core and feature families: `ReadSection` is pure, `EnsureSection` is explicit mutation, the compatibility `GetSection` no longer creates data, and static checks reject first-party runtime use of it.
- [x] Isolate LibDBIcon from SavedVariables: use a detached minimap proxy during drag, commit one normalized position on drag stop, restore persisted state on failure/cancel, and remove the dead per-addon radius field.
- [x] Make ExperienceBar native takeover narrow and reversible: capture alpha/mouse state without hiding foreign frames, keep one lifecycle apply owner, re-suppress after Blizzard refreshes, and restore only properties still carrying addon-owned values.
- [x] Make CenterBars class-resource takeover narrow and reversible: keep snapshots/hooks on the owner, never stamp or Hide/Show/Setup foreign frames, handle native frame replacement, and preserve newer conflicting alpha/mouse changes on release.
- [x] Move border ownership out of target frames: `Media` now keeps weak-key records, exposes explicit lookup/color APIs, and static validation rejects `__fguiBorder*` metadata anywhere in first-party Lua.
- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply result-aware; failed layers clean partial presentation, while transient PetActionButton creation queues an event-driven retry instead of disabling Companion.
- [x] Make Companion permanent hooks replacement-aware and retryable: weak-key records publish each edge only after successful HookScript/hooksecurefunc/EventRegistry registration, partial failures retry only missing edges, and stale source/button callbacks are inert.
- [x] Journal PetActionButton takeover in `CompanionPetState`: separate structural layout from dynamic visibility ownership, reopen snapshots on component replacement, journal mover preview, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.
- [x] Move ActionBars runtime metadata off Blizzard ActionButton/FontString/Cooldown objects into weak-key button/region registries; hooks resolve current owner/layers through the registry and no callback/style cache is stored on foreign frames.
- [x] Remove generic caller-object metadata: Animate fade/timer state and Minimap LibDBIcon hook state live in weak registries, active drag is button-specific, and the unused arbitrary cooldown-frame cache helper is deleted.
- [x] Move Options adaptive-width, numeric-sync, wheel-proxy, and Edit Mode mover-listener ownership into weak registries; publish each hook edge only after successful registration and retry partial failures without widget/panel markers.
- [x] Make ActionBars holder/button auto-hide and state-layer hooks result-bearing: weak registries own state, callbacks resolve current owners, partial failures retry only missing edges, and visual/apply callers propagate failure.
- [x] Make ActionBars permanent state, EndCaps, SettingsPanel and action-change hooks result-bearing: weak target/method registries prevent duplicates, init/callback flags publish after success, owner replacement is dynamic, and detach releases owners/handles.
- [x] Move UnitFrames target observers, aura roles, header-hook state, low-health cache and unit-watch ownership off oUF frames/elements into weak registries; remove target-aura runtime persistence writes and propagate native watch failures.
- [x] Make ExperienceBar native takeover a verified property journal: refuse unreadable channels, read back every write, retain unresolved restore state for retry, reopen hooks on manager replacement, preserve newer conflicts, and propagate exact hook/suppress/restore failures.

## Required in-game validation

- [ ] Record `GetBuildInfo()` and confirm Interface `120105` on the tested client.
- [ ] Fresh login and `/reload` complete with zero repeating Lua errors.
- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.
- [ ] Rebuild/show/resize every Options page while injecting one failure into owner/widget `HookScript` and mover-listener registration; successful edges remain single, only missing edges retry, widgets/panels receive no `_fgui*` markers, wheel forwarding fires once, and stale rebuilt-panel listeners are collectible/inert.
- [ ] Remove a core/feature section after DB initialization, then open Theme, Safety, Minimap, QA, Movers, ActionBars, CenterBars, Companion and their settings panels; readers must not recreate the section, while one explicit `EnsureSection`/Settings normalization repairs it.
- [ ] Toggle debug and perf from both General settings and slash commands; profile, runtime state, and `Undo last` stay identical after success and rollback.
- [ ] Run `/fgui aura mini|classic`; UnitFrames apply executes through the normal queue and a forced failure restores the prior mode/history.
- [ ] Show/hide/reset and drag the minimap icon from settings and slash commands; OnUpdate performs zero SavedVariables writes, each LibDBIcon button is hooked once without foreign metadata, stale-button stop events are inert, drag stop creates one undoable transaction, and failed apply/cancel restores the persisted position.
- [ ] Exercise repeated ExperienceBar fades and keyed timer replacement/cancellation; frame/owner tables receive no `_fguiAnimate*` fields, animation groups are reused, stale callbacks remain invalidated, and terminal alpha/visibility is exact.
- [ ] Import a valid profile both in and out of combat; the UI reports queued status until all apply owners finish, old history is removed only after commit, and a forced late failure restores the previous profile while preserving newer edits.
- [ ] Attempt import while another settings transaction or import is pending; the live profile, runtime state, and undo history remain untouched.
- [ ] Start an import that remains combat-deferred, then `/reload` or log out before commit; next startup restores the previous profile and overlays any newer post-import edits, then removes the recovery record.
- [ ] Hold a long mover drag/resize and verify zero SavedVariables writes, zero apply requests, and zero undo entries before the terminal input event.
- [ ] Resize/scale ActionBars, UnitFrames, CenterBars, Companion PetBar, and ExperienceBar; each terminal action produces one undo entry and one owner apply.
- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states; inject unreadable alpha/mouse, stubborn setters, hook failure, manager replacement and restore failure; ExperienceBar must never mutate unreadable channels, must report exact failures, retain retryable unresolved records, avoid duplicate hooks/writes, restore exact still-owned values, and preserve newer conflicts without foreign `Hide`/`Show`.
- [ ] Repeatedly skin and restore Blizzard pet/micro/bag buttons; border frames are reused through `Media` without any `__fguiBorder*` fields on the target buttons, and transparent release is reversed by the next theme/style apply.
- [ ] Force HookScript, hooksecurefunc, EventRegistry registration, missing pet buttons, and MicroBags layer failures; Companion publishes no false hook flags, retries only missing edges, replacement makes stale callbacks inert, partial layers restore, and the exact failure reaches Lifecycle/Apply.
- [ ] Give each PetActionButton and PetActionBar distinctive parent/points/size/hit-rect/visibility/alpha/texture/mask/name/cooldown/hotkey state, apply twice, replace one button, make one conflicting external change, then detach; exact still-owned state restores without guessed defaults or overwriting the conflict.
- [ ] Force mover position/scale/size apply failure; profile, exact undo artifact, and visible frame geometry return to the persisted state.
- [ ] Lock Edit Mode while resize preview is active; preview state is discarded and the persisted geometry is restored without a stale commit.
- [ ] Start with UnitFrames and CenterBars disabled, log in, then enable them without `/reload`; frames initialize once, observers/events attach once, and live updates begin immediately.
- [ ] Disable and re-enable UnitFrames/CenterBars repeatedly; no duplicate event owner, stale unit watcher, duplicate frame, or false lifecycle state remains.
- [ ] Simulate a feature attach/apply failure; the module remains disabled, any new attachment is cleaned up, later feature families still enable, and the exact failure is logged.
- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors or opaque readback.
- [ ] Remove a UnitFrames section/size/scale field in a test profile after DB initialization, then create/apply frames; runtime must use defaults without recreating or mutating the missing persisted field, while the next explicit DB/schema normalization repairs it.
- [ ] Target aura filtering handles ordinary and inaccessible aura-source payloads without indexing denied tables or fields; aura containers and oUF frames receive no `_fgui*` metadata, repeated attach installs no duplicate hooks/observers, and detach makes permanent header hooks inert.
- [ ] Force `RegisterUnitWatch` and `UnregisterUnitWatch` failures for focus/targettarget/pet; no false registry state is published, Apply/Lifecycle receives the exact failure, successful retry is idempotent, and detach clears every successfully owned watch.
- [ ] Center bars handle ordinary and restricted power/rune values without duplicate producer calls, error loops, retained opaque samples, or stale text.
- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, give native class-resource frames distinctive alpha/mouse/visibility states, trigger OnShow, replace a named frame, toggle suppression in combat, and verify zero addon Hide/Show/Setup calls, exact owned-property restore, and preservation of newer conflicting changes.
- [ ] Companion micro-menu/bag hooks coalesce repeated show/hide/layout requests instead of bypassing the queue; detach cancels both apply and micro-layout generations.
- [ ] Force a normal field apply handler to return `false`; profile value and its newly-created `Undo last` artifact both disappear, later keys do not execute, and previously applied owners restore.
- [ ] Force `Undo last` apply failure; the pre-undo profile and exact consumed undo entry return, and the panel refreshes after rollback.
- [ ] Force panel reset apply failure, including an actionbars+companion multi-key reset; defaults do not persist and only pre-reset history remains.
- [ ] Change UnitFrames settings during combat; the transaction remains pending until `PLAYER_REGEN_ENABLED` and commits only after the real runtime apply succeeds.
- [ ] Perform multi-key undo/reset where one key commits before another leaves combat; history finalizes only after the final required key succeeds, and a later failure restores each already-committed runtime owner.
- [ ] Make a newer successful field edit before an older deferred transaction fails; ownership-aware rollback preserves the newer value and table identity.
- [ ] Reset a section, then successfully edit another field before reset fails; rollback restores the old section while overlaying the newer committed edit.
- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.
- [ ] Repeatedly skin, refresh, detach and re-enable all five ActionBars while injecting one holder/button `HookScript` failure; successful edges and textures remain single, only missing edges retry, callbacks follow the current module, no holder `_fguiAutoHidden`/`_fguiAutoHideHooks` fields appear, and the exact failure reaches Apply.
- [ ] Before enabling ActionBars, set a distinctive Blizzard multi-bar toggle combination; addon apply must not alter `profile.actionbars.bars[4/5].enabled`, repeated identical applies must not rewrite native toggles, `/reload` must retain the original recovery vector, and detach must restore the exact original vector and remove its recovery record.
- [ ] Rapid `Disable -> Enable` before queued callbacks fire does not execute an older lifecycle generation.
- [ ] Inject one failure into each permanent ActionBars `hooksecurefunc`, SettingsPanel `HookScript`, callback-container creation/registration, and detach `Unregister`; successful edges remain single, only missing edges retry, `_initDone`/callback flags never publish early, callbacks follow the current owner, and detach releases owner references.
- [ ] Enter/leave combat with action bars, movers, Edit Mode, profile apply/import/reset, and module disable/enable; no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN`.
- [ ] Run every scenario in `docs/REGRESSION_MATRIX_1_25.md` with build/revision evidence.
