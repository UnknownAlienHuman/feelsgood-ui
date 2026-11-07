# FeelsGoodUI

Minimalist Retail UI addon with oUF unit frames, secure action bars, center resources, companion controls, movers, settings, and profile transfer.

## Requirements

- World of Warcraft Retail `12.1.5`
- Interface `120105`
- FeelsGoodUI `0.0.55`
- External required dependency: `oUF`
- Saved variables: `FeelsGoodUIDB`

Copy the `FeelsGoodUI` directory into `World of Warcraft/_retail_/Interface/AddOns/`, install `oUF`, and restart the client or run `/reload`.

## Runtime policy

Restricted/Secret Values are gated before Lua inspection. Unit Frames and Center Bars own those gates directly in their render paths. Configuration access has an explicit read/write boundary: `DB:ReadSection` never creates or repairs SavedVariables, while `DB:EnsureSection` is reserved for Settings, migrations, and other validated write owners. Core presentation services and every feature runtime use the pure reader. UnitFrames runtime/render paths are read-only consumers of normalized configuration: missing sections, sizes, and scales resolve through local immutable fallbacks and are repaired only by DB/Settings/schema owners, never while frames are being created or refreshed. Each restricted-value producer is queried once: each producer is queried once, ordinary data stays on the normal path, and inaccessible health, power, classification, aura-source, and rune values go only to documented native presentation sinks or an explicit unavailable state. Protected action-bar and Blizzard-frame mutations remain deferred outside combat. ExperienceBar suppresses native status tracking through captured alpha/mouse ownership only: it never hides or unconditionally shows foreign frames, reasserts suppression after Blizzard refreshes, and restores only properties that still carry its owned values. ActionBars snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach; a compact per-character recovery marker preserves that baseline across `/reload` or interruption and is restored on `PLAYER_LOGIN` before ActionBars reattaches. Native sidebar state is never imported by mutating the addon profile, and unchanged toggle sets are not rewritten. Detach invalidates queued action-bar work, disables permanent hook side effects, and performs a narrow post-combat Blizzard-shell restore when teardown occurs during combat. Shared debounce requests treat an existing keyed timer as a successful coalesced request; cancellation always invalidates its generation before lifecycle teardown. Apply handlers propagate explicit failure: settings commit only after every key in the batch succeeds, while a `false` result or exception rolls back the batch and restores already-applied runtime owners. Panel undo/reset operations participate in the same transaction: history is consumed or invalidated only after every required apply key commits, and failed or partially deferred batches restore both profile sections and the exact undo stack. Feature lifecycle transitions are result-aware and reentrancy-guarded: failed attach/apply paths clean up without publishing `enabled=true`, independent modules continue loading, and Unit Frames or Center Bars that start disabled can later initialize and acquire their event owners normally. Minimap drag uses a detached LibDBIcon runtime proxy: per-frame movement never touches SavedVariables, mouse-up creates one validated `Settings:SetTx` transaction, and failed apply/cancel restores the persisted position. The dead addon `radius` field is removed because LibDBIcon radius is library-global rather than per button. General commands and options never write runtime settings directly: debug, performance overlay, target-aura mode, and minimap state all flow through `Settings:SetTx` and the shared apply/rollback journal; `RuntimeSettings` is the single apply owner for debug and performance presentation. Mover state follows the same ownership rule: continuous move/resize is runtime-only preview, while mouse-up, wheel, inspector, lock state, editor settings and position resets commit validated writes once through `MoversTransactions`; failed commits reapply the persisted owner state. Profile import is staged on a detached snapshot and replaces the live profile through one profile-wide transaction; success is published only after every immediate and combat-deferred runtime owner commits, while a late failure restores the prior profile and history. A temporary SavedVariables recovery record restores any import interrupted by `/reload`, logout, or client termination before terminal commit and overlays newer edits onto the recovered profile.

## Validation

Run the deterministic static check from the addon root:

```bash
npm ci
npm test
```

The checker parses first-party Lua, validates TOC paths and duplicates, and enforces critical load-order constraints. Static checks do not replace client validation; record each tested build and result in [`docs/REGRESSION_MATRIX_1_25.md`](docs/REGRESSION_MATRIX_1_25.md).

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [Active runtime checks](todo.md)

## License

Licensed under the [MIT License](LICENSE). Bundled third-party components retain their own notices.
