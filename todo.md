# FeelsGoodUI TODO

Updated: 2026-11-06. Completed historical execution notes live in `history.md`; this file contains only runtime evidence that cannot be produced by static review.

## Retail 12.1.5 implementation status

- [x] Target Interface `120105` and release `0.0.47`.
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

## Required in-game validation

- [ ] Record `GetBuildInfo()` and confirm Interface `120105` on the tested client.
- [ ] Fresh login and `/reload` complete with zero repeating Lua errors.
- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.
- [ ] Start with UnitFrames and CenterBars disabled, log in, then enable them without `/reload`; frames initialize once, observers/events attach once, and live updates begin immediately.
- [ ] Disable and re-enable UnitFrames/CenterBars repeatedly; no duplicate event owner, stale unit watcher, duplicate frame, or false lifecycle state remains.
- [ ] Simulate a feature attach/apply failure; the module remains disabled, any new attachment is cleaned up, later feature families still enable, and the exact failure is logged.
- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors or opaque readback.
- [ ] Target aura filtering handles ordinary and inaccessible aura-source payloads without indexing denied tables or fields.
- [ ] Center bars handle ordinary and restricted power/rune values without duplicate producer calls, error loops, retained opaque samples, or stale text.
- [ ] Companion micro-menu/bag hooks coalesce repeated show/hide/layout requests instead of bypassing the queue; detach cancels both apply and micro-layout generations.
- [ ] Force a normal field apply handler to return `false`; profile value and its newly-created `Undo last` artifact both disappear, later keys do not execute, and previously applied owners restore.
- [ ] Force `Undo last` apply failure; the pre-undo profile and exact consumed undo entry return, and the panel refreshes after rollback.
- [ ] Force panel reset apply failure, including an actionbars+companion multi-key reset; defaults do not persist and only pre-reset history remains.
- [ ] Change UnitFrames settings during combat; the transaction remains pending until `PLAYER_REGEN_ENABLED` and commits only after the real runtime apply succeeds.
- [ ] Perform multi-key undo/reset where one key commits before another leaves combat; history finalizes only after the final required key succeeds, and a later failure restores each already-committed runtime owner.
- [ ] Make a newer successful field edit before an older deferred transaction fails; ownership-aware rollback preserves the newer value and table identity.
- [ ] Reset a section, then successfully edit another field before reset fails; rollback restores the old section while overlaying the newer committed edit.
- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.
- [ ] Rapid `Disable -> Enable` before queued callbacks fire does not execute an older lifecycle generation.
- [ ] Enter/leave combat with action bars, movers, Edit Mode, profile apply/import/reset, and module disable/enable; no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN`.
- [ ] Run every scenario in `docs/REGRESSION_MATRIX_1_25.md` with build/revision evidence.
