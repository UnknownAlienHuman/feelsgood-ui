# FeelsGoodUI

Minimalist unit frames with custom action bars, center bars, companion controls, movers, settings, and profile support.

## Installation

Copy the `FeelsGoodUI` directory into `World of Warcraft/_retail_/Interface/AddOns/`. Install the required `oUF` addon separately, then restart the client or use `/reload`. Supporting libraries listed in the TOC are vendored.

## Compatibility and data

- Interface: `120001`, `120005`
- Version: `0.0.40`
- Required dependency: `oUF`
- Saved variables: `FeelsGoodUIDB`

## Usage

Configuration, Edit Mode, minimap actions, and slash commands are implemented by the core settings, movers, options, and commands modules. Start with the in-game addon settings; see the source index for the corresponding modules.

## Development status

The tracked code execution blocks are marked implemented. Remaining work is in-game QA, including scenarios that validate partial architectural areas; those checks are not proven by static review. See [todo.md](todo.md) and [docs/REGRESSION_MATRIX_1_25.md](docs/REGRESSION_MATRIX_1_25.md).

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)

## License

Licensed under the [MIT License](LICENSE). Bundled third-party components remain under their own notices.
