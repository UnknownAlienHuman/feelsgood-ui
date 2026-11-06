# FeelsGoodUI TODO

Updated: 2026-11-06. Completed historical execution notes live in `history.md`; this file contains only runtime evidence that cannot be produced by static review.

## Retail 12.1.5 implementation status

- [x] Target Interface `120105` and release `0.0.41`.
- [x] Gate Secret/Restricted Values before Lua inspection, conversion, comparison, or formatting.
- [x] Route inaccessible Unit Frame and Center Bar values through narrow 12.1.5 adapters.
- [x] Keep opaque power/text on exact native sinks where available; otherwise render an explicit unavailable state.
- [x] Replace exception-based arithmetic/string probes in shared helpers.
- [x] Make the static checker fail on syntax, TOC, duplicate, missing-file, and load-order errors; expose `npm test`.
- [x] Replace the stale 12.0.1/removed-feature regression matrix with current 12.1.5 coverage.

## Required in-game validation

- [ ] Record `GetBuildInfo()` and confirm Interface `120105` on the tested client.
- [ ] Fresh login and `/reload` complete with zero repeating Lua errors.
- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.
- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors.
- [ ] Center bars handle ordinary and restricted power/rune values without error loops or stale text.
- [ ] Enter/leave combat with action bars, movers, Edit Mode, profile apply/import/reset, and module disable/enable; no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN`.
- [ ] Run every scenario in `docs/REGRESSION_MATRIX_1_25.md` with build/revision evidence.
