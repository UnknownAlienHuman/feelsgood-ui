# FeelsGoodUI

Minimalist Retail UI addon with oUF unit frames, secure action bars, center resources, companion controls, movers, settings, and profile transfer.

## Requirements

- World of Warcraft Retail `12.1.5`
- Interface `120105`
- FeelsGoodUI `0.0.44`
- External required dependency: `oUF`
- Saved variables: `FeelsGoodUIDB`

Copy the `FeelsGoodUI` directory into `World of Warcraft/_retail_/Interface/AddOns/`, install `oUF`, and restart the client or run `/reload`.

## Runtime policy

Restricted/Secret Values are gated before Lua inspection. Unit Frames and Center Bars own those gates directly in their render paths: each producer is queried once, ordinary data stays on the normal path, and inaccessible health, power, classification, aura-source, and rune values go only to documented native presentation sinks or an explicit unavailable state. Protected action-bar and Blizzard-frame mutations remain deferred outside combat. Detach invalidates queued action-bar work, disables permanent hook side effects, and performs a narrow post-combat Blizzard-shell restore when teardown occurs during combat. Shared debounce requests treat an existing keyed timer as a successful coalesced request; cancellation always invalidates its generation before lifecycle teardown.

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
