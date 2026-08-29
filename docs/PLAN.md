# FeelsGoodUI Plan (high-level)

Goal: minimal, fast full-UI replacement (action frames + player/target + castbar + settings), using Blizzard systems and Secret Value-safe handling.

1) Core: scheduler (staggered init), module Construct/Configure pattern, DB (profile vs private), diagnostics/perf
2) Action frames: robust Blizzard art/endcap hider + button skinning + layout/state/visibility + hotkey formatting
3) Unit frames: player/target health + reliable texts; optional target name/info + optional power bar; spec-colored resources
4) Auras: Secret-safe SimpleAuras + minimal filter UX
5) Castbar: player/target castbar with interrupt state, latency safezone, empowered pips (optional)
6) Settings: scroll panels, module options, profile tools, movers
7) Hardening: taint/combat lock policies, test matrix, perf/alloc pass
