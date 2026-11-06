# FeelsGoodUI Retail 12.1.5 Regression Matrix

Target contract: Retail `12.1.5`, Interface `120105`  
Execution rule: every run records the exact client build, addon revision, result, and evidence. Static review is not a substitute for these scenarios.

## Result codes

- `PASS` — expected behavior confirmed with evidence.
- `FAIL` — reproducible mismatch; include the first error and exact steps.
- `PARTIAL` — only part of the scenario was exercised.
- `BLOCKED` — test could not run; state the missing prerequisite.

## Run header

- Tester:
- Date:
- `GetBuildInfo()` version/build/TOC:
- FeelsGoodUI revision/version:
- oUF version/revision:
- Character/class/spec:
- Instance/restriction context:
- Resolution/UI scale:

## Matrix

| # | Scenario | Expected result | Result | Evidence / notes |
|---|---|---|---|---|
| 1 | Fresh login with FeelsGoodUI and oUF enabled | Addon loads once; no dependency, TOC, or repeating Lua errors |  |  |
| 2 | `/reload` after default initialization | `FeelsGoodUIDB` remains valid; no duplicate registrations or frames |  |  |
| 3 | `/fgui qa` and `/fgui report` | Commands finish without schema, legacy-field, or serialization errors |  |  |
| 4 | Open every settings category repeatedly | Navigation, resize, scrolling, and reopen remain stable |  |  |
| 5 | Change settings, apply, undo, reset, and force one apply failure | The logical batch commits atomically or restores profile, runtime owners, and exact undo history |  |  |
| 6 | Export/import a valid profile | Round trip preserves supported settings and positions |  |  |
| 7 | Import malformed, oversized, or wrong-schema data | Import fails cleanly without modifying the active profile |  |  |
| 8 | Unlock/lock movers; drag, nudge, and reset near every screen edge | Preview is smooth; one terminal commit persists; clamping, undo, reset, and reload remain coherent |  |  |
| 9 | Resize/scale every supported mover through wheel, handle, and inspector | Preview does not write/apply per frame; terminal action produces one normalized transaction and one feature apply |  |  |
| 10 | Force `movers` apply failure after position/editor-state change | Position, overlay/grid/lock state, profile, and exact undo artifact restore together |  |  |
| 11 | Change mover/Edit Mode state during combat | Work remains pending; one post-combat apply commits without blocked/forbidden actions |  |  |
| 12 | Login with UnitFrames/CenterBars disabled, then enable; repeat disable/re-enable | Frames initialize once; observers/events attach once; live updates start without reload or stale owner state |  |  |
| 13 | Player health in ordinary world context | Value, percent, low-health glow, and color update correctly |  |  |
| 14 | Target/focus/targettarget ordinary values | Name, level, class, classification, reaction color, and target-of-target update |  |  |
| 15 | Restricted/Secret health or identity context | No Lua operation error; opaque text uses native display or unavailable state |  |  |
| 16 | Target aura mode `MINI` and `CLASSIC` | Ownership filter, layout, and header anchoring update without stale icons |  |  |
| 17 | Enter/leave combat with combat timer enabled | Timer starts once, stops once, and leaves no ticker after disable |  |  |
| 18 | Center power with ordinary values | Min/max, fill, threshold color/spark, and text update correctly |  |  |
| 19 | Center power with restricted values | StatusBar receives opaque values directly; no format/readback/error loop |  |  |
| 20 | Death Knight runes, including restriction transition | Ordinary cooldowns animate; restricted state is explicit; timer tears down |  |  |
| 21 | Point resources across supported classes/specs | Segment count/fill/color follows current max and caps safely |  |  |
| 22 | Configure action bars out of combat | Geometry, visibility, bindings, and Blizzard shell handoff apply once |  |  |
| 23 | Change action-bar settings during combat | Protected work defers and coalesces; applies once after combat |  |  |
| 24 | Disable/re-enable action bars and reload | Blizzard-owned bars restore; no detached delayed callback re-enters |  |  |
| 25 | Companion micro menu, bags, and pet bar lifecycle | Controls attach, update, restore, and detach without duplicate ownership |  |  |
| 26 | Experience/reputation/honor states | Correct bar is shown; capped/unsupported states hide cleanly |  |  |
| 27 | Theme/media/minimap icon/profile switch | Fonts, textures, colors, icon actions, and profile refresh remain coherent |  |  |
| 28 | Full combat smoke with taint logging enabled | No `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, or repeating errors |  |  |
| 29 | Inject one feature attach/apply failure while other families are valid | Failed feature cleans up and remains disabled; later families still enable; exact owner/error is reported |  |  |

## Required smoke order

1. Capture the run header, then fresh login.
2. Run `/fgui qa` and `/fgui report`.
3. Exercise settings, profile round trip, and mover preview/commit/rollback out of combat.
4. Exercise mover combat deferral, then disabled-at-login enable paths and ordinary/restricted unit data.
5. Enter/leave combat while changing action-bar settings.
6. Disable/re-enable every feature family.
7. `/reload`, confirm persistence, and inspect the first error/taint event if any.

## Failure record

- Matrix item:
- Build/revision:
- Reproduction steps:
- Expected:
- Actual:
- First error/taint event:
- Evidence:
- Suspected owner/lifecycle boundary:
