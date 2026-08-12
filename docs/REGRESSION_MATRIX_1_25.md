# FeelsGoodUI Regression Matrix (Items 1-25)

Build target: `12.0.1.65867`  
Addon branch state: `todo canonical 2026-03-02`  
Execution rule: every run must record evidence (screenshot/video/log snippet), not only PASS/FAIL.

## Result Codes
- `PASS` - behavior matches expected result with evidence
- `FAIL` - behavior does not match expected result; add repro steps
- `PARTIAL` - only part of expected behavior confirmed
- `BLOCKED` - cannot validate in current environment (state why)

## Run Header
- Tester:
- Date (YYYY-MM-DD):
- Character/Class/Spec:
- Resolution/UI scale:
- In combat checks performed: `yes/no`
- `/reload` checks performed: `yes/no`

## Matrix

| # | Scenario | Expected Result | Result | Evidence | Notes |
|---|---|---|---|---|---|
| 1 | Objective Tracker with default config | Tracker remains under Blizzard Edit Mode ownership; no forced docking by addon |  |  |  |
| 2 | Drag edge bars (`actionbar4/5`) to right edge + resize + `/reload` | Bars stay edge-attached without gap drift |  |  |  |
| 3 | Open mover inspector near each screen edge | Inspector stays under cursor and clamped to screen |  |  |  |
| 4 | Inspector controls alignment at different scales | All controls stay inside inspector frame; no overlap/out-of-bounds |  |  |  |
| 5 | Change Bar1 settings then check Bar2..Bar7 | Per-bar settings remain isolated (no cross-bar mutation) |  |  |  |
| 6 | Macro/trinket/proc highlight states on action buttons | No oversized/incorrect green highlight frame artifacts |  |  |  |
| 7 | Open each options panel at 1080p and 1440p | Controls remain usable with scroll; no hard overflow breakage |  |  |  |
| 8 | Verify geometry controls in ActionBars panel | Main bar geometry is not duplicated outside Edit Mode |  |  |  |
| 9 | Compare castbar settings by unit (target vs targettarget) | Per-unit castbar config applies independently |  |  |  |
| 10 | Action bars with empty slots | Empty slots are hidden/clean; no placeholder square noise |  |  |  |
| 11 | Target with and without buffs | Target name auto-reanchors to avoid aura overlap |  |  |  |
| 12 | Health/power percent text | Integer percentages only; no long decimal output |  |  |  |
| 13 | Cooldown viewer custom mode vs blizzard-skin mode | Expected mode behavior and refresh lifecycle without stale icons |  |  |  |
| 14 | Combat timer mover | Timer has independent frame/mover and persists position |  |  |  |
| 15 | Static code architecture check | No new monolith growth for changed features |  |  |  |
| 16 | Pattern quality check vs reference standards | Implementations favor reusable contracts over one-off hacks |  |  |  |
| 17 | Modernization check | New code uses normalized data contracts and safe event paths |  |  |  |
| 18 | Blizzard integration safety check | No new fragile ownership hooks introduced without justification |  |  |  |
| 19 | Toggle \"show my buffs\" over player frame | Toggle works and applies immediately |  |  |  |
| 20 | Short numbers uppercase suffix option | `K/M/B` uppercase mode works where enabled |  |  |  |
| 21 | EXP bar behavior | EXP bar displays/hides correctly by character state |  |  |  |
| 22 | Create/remove many custom bars (0..256) | Creation/removal stable; movers created for active bars |  |  |  |
| 23 | Switch custom bar shape `bar <-> circle` | Shape changes correctly with proper fill rendering |  |  |  |
| 24 | Trigger mode checks: combat/health/power/spell cooldown/spell cooldown threshold/unit-aura/unit-aura-stacks | Trigger bars react correctly; `hideWhenInactive` works; no event spam artifacts |  |  |  |
| 25 | Full historical complaint sweep | All prior complaint scenarios re-checked and recorded |  |  |  |

## Critical Smoke Order (required per run)
1. `/reload`, then `/fgui qa` (baseline)
2. Edit Mode drag/resize sweep (`actionbar1..7`, `custombar1`)
3. Combat enter/leave cycle (check taint/protected warnings)
4. Trigger mode sweep (item 24) for all trigger types
5. `/reload` again and re-validate persistence

## Trigger Mode Sub-Checklist (Item 24)
- `combat` trigger with unit `player`: bar state flips on `PLAYER_REGEN_*`
- `unit-health` trigger with `below/above` threshold: updates on `UNIT_HEALTH/MAXHEALTH`
- `unit-power` trigger with explicit `powerType` and `AUTO`: updates on `UNIT_POWER_UPDATE/MAXPOWER/DISPLAYPOWER`
- `spell-cooldown` trigger:
  - valid spell ID countdown uses correct modRate behavior
  - charges spell uses charge cooldown behavior
  - `spellMode`: `active`, `ready`, `always` each verified
  - `hideWhenInactive` hides/shows without stale state
- `spell-cooldown-threshold` trigger:
  - active state follows threshold comparator (`below` / `above`) against remaining cooldown seconds
  - threshold UI/range is in seconds (`0..600`), not percent
- `unit-aura` trigger:
  - aura lookup by `spellID` works for player/target/focus/targettarget/pet
  - `spellMode`: `active`(aura present), `ready`(aura missing), `always`
  - selective `UNIT_AURA` filtering does not miss tracked aura add/update/remove
- `unit-aura-stacks` trigger:
  - active state follows comparator (`below` / `above`) against current aura stacks
  - threshold UI/range is stacks (`1..100`)

## Failure Reporting Template
- Item:
- Build:
- Repro steps:
- Expected:
- Actual:
- Evidence:
- Suspected root cause:
- Fix candidate:
