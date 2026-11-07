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
| 8 | Unlock/lock movers; drag near every screen edge | Inspector and frames remain clamped; positions persist after reload |  |  |
| 9 | Login with UnitFrames/CenterBars disabled, then enable; repeat disable/re-enable | Frames initialize once; observers/events attach once; live updates start without reload or stale owner state |  |  |
| 10 | Player health in ordinary world context | Value, percent, low-health glow, and color update correctly |  |  |
| 11 | Target/focus/targettarget ordinary values | Name, level, class, classification, reaction color, and target-of-target update |  |  |
| 12 | Restricted/Secret health or identity context | No Lua operation error; opaque text uses native display or unavailable state |  |  |
| 13 | Target aura mode `MINI` and `CLASSIC` | Ownership filter, layout, and header anchoring update without stale icons |  |  |
| 13a | Remove a UnitFrames section/size/scale field after DB initialization, then create and apply frames | Runtime resolves immutable defaults without recreating or mutating the missing persisted field; explicit DB/schema normalization remains the only repair owner |  |  |
| 14 | Enter/leave combat with combat timer enabled | Timer starts once, stops once, and leaves no ticker after disable |  |  |
| 15 | Center power with ordinary values | Min/max, fill, threshold color/spark, and text update correctly |  |  |
| 16 | Center power with restricted values | StatusBar receives opaque values directly; no format/readback/error loop |  |  |
| 17 | Death Knight runes, including restriction transition | Ordinary cooldowns animate; restricted state is explicit; timer tears down |  |  |
| 18 | Point resources across supported classes/specs | Segment count/fill/color follows current max and caps safely |  |  |
| 18a | Native class-resource takeover across supported classes, including OnShow, frame replacement, combat-deferred toggle, and conflicting external changes | No addon `Hide`/`Show`/`Setup` or foreign markers; owner-local alpha/mouse suppression restores exact still-owned values and preserves newer conflicts |  |  |
| 19 | Configure action bars out of combat | Geometry, visibility, bindings, and Blizzard shell handoff apply once |  |  |
| 20 | Change action-bar settings during combat | Protected work defers and coalesces; applies once after combat |  |  |
| 21 | Disable/re-enable action bars and reload after setting a distinctive native multi-bar toggle vector | Exact pre-attach Blizzard toggles and shell state restore after reload or detach; recovery marker clears after restore; addon profile bars do not change; no detached delayed callback re-enters |  |  |
| 22 | Companion micro menu, bags, and pet bar lifecycle, including repeated border restyling | Controls attach, update, restore, and detach without duplicate ownership; border objects are reused and target Blizzard frames receive no `__fguiBorder*` metadata |  |  |
| 23 | Experience/reputation/honor states plus repeated enable/disable and native manager refresh | Correct custom bar is shown; native status frames retain visibility ownership, receive no addon `Hide`/`Show`, and restore captured alpha/mouse state without overwriting newer conflicting changes |  |  |
| 24 | Theme/media/minimap icon/profile switch; drag icon and force one minimap apply failure | Fonts/textures/colors remain coherent; drag preview writes only the proxy, mouse-up commits once, no-op drag creates no transaction, and failure restores the persisted position |  |  |
| 25 | Full combat smoke with taint logging enabled | No `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, or repeating errors |  |  |
| 26 | Inject one feature attach/apply failure while other families are valid | Failed feature cleans up and remains disabled; later families still enable; exact owner/error is reported |  |  |
| 27 | Delete one core/feature section after DB initialization, then exercise all runtime readers and settings pages | No read path recreates SavedVariables data; explicit `EnsureSection`/Settings normalization repairs the section once |  |  |

## Required smoke order

1. Capture the run header, then fresh login.
2. Run `/fgui qa` and `/fgui report`.
3. Exercise settings, profile round trip, and movers out of combat.
4. Exercise disabled-at-login enable paths, then ordinary and restricted unit/center data.
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
