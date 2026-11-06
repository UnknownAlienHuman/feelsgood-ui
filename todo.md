# FeelsGoodUI TODO

Updated: 2026-11-06. Completed historical execution notes live in `history.md`; this file contains only the active pass and runtime checks.

## Retail 12.1.5 safety pass

- [ ] Target Interface `120105` and bump the addon release version.
- [ ] Replace exception-based Secret Value probing with explicit secrecy/access gates before Lua inspection, conversion, comparison, or formatting.
- [ ] Keep restricted health/power values on direct visual sinks instead of trying to abbreviate or format them.
- [ ] Make the Lua checker fail its process on syntax/walk errors and expose one deterministic `npm test` command.
- [ ] Replace the stale 12.0.1 regression matrix and removed-feature scenarios with current 12.1.5 coverage.
- [ ] Run syntax, TOC-path, targeted secret-boundary, and diff validation; record the completed slice in `history.md`.

## Required in-game validation

- [ ] Record `GetBuildInfo()` and confirm Interface `120105` on the tested client.
- [ ] Fresh login and `/reload` complete with zero repeating Lua errors.
- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.
- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors.
- [ ] Center bars handle ordinary and restricted power values without error loops or stale text.
- [ ] Enter/leave combat with action bars, movers, Edit Mode, profile apply/import/reset, and module disable/enable; no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN`.
- [ ] Run every current scenario in `docs/REGRESSION_MATRIX_1_25.md` with build/revision evidence.
