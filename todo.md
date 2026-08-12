# FeelsGoodUI TODO

Актуальный backlog после аудита 2026-03-14.

Подтверждено закрытое и старые execution blocks вынесены в `history.md`.
Здесь оставлено только:
- реально не сделанное;
- сделанное частично;
- места, где реализация все еще плохая или слишком сцепленная;
- обязательная in-game проверка, которую нельзя подтвердить чтением кода.

## Итог после проверки (2026-03-17)
- [x] Кодовые execution blocks в живом дереве сведены: все блоки до раздела `9` закрыты как реализованные, новых `TODO/FIXME` в `.lua` не найдено.
- [ ] Остаются только сценарии, которые можно закрыть только через in-game QA (см. раздел `9. Обязательная in-game validation`).
- [ ] После in-game подтверждений разделы `1..8` с тегом `PARTIAL` можно преобразовать в `DONE`, потому что сейчас это архитектурные заметки о местах контроля/возможного дополучения проверки, а не кодовые незавершенности.

## Execution block — 2026-03-17
- [x] Route `UnitFrames` master-scale through one panel undo batch so `Undo last` reverts the logical multi-write action instead of only restoring the last unit scale entry.
- [x] Wire `OptionsPanelUnitFrames.lua` to the existing shared `Settings` batch-undo contract and close the missing `ctx.Settings` binding / batch-cleanup gap that surfaced in editor diagnostics.
- [x] Re-run static validation (`npx --yes luaparse`; `node check_lua.js`; `git diff --check`; targeted diff review), update todo/history state, and commit the UnitFrames batch-undo slice.

## Execution block — 2026-03-17
- [x] Add explicit `CompanionPetBar:RestoreDefaultLayout()` so lifecycle detach returns pet buttons to Blizzard button containers, clears the addon holder visibility driver, and refreshes Blizzard `PetActionBar` instead of only hiding the addon anchor.
- [x] Re-arm the reused pet-bar holder on attach/apply so `Disable -> Enable` cannot leave `Companion` with a hidden secure holder after teardown.
- [x] Re-run static validation (`npx --yes luaparse`; `node check_lua.js`; `git diff --check`; targeted Blizzard/EditMode source comparison), update todo/history state, and commit the pet-bar teardown slice.

## Execution block — 2026-03-17
- [x] Guard `ActionBars` delayed initial-apply path against detached modules so queued `C_Timer.After(...)` callbacks cannot re-enter `ApplyConfig()` after lifecycle disable.
- [x] Re-run static validation (`npx --yes luaparse`; `git diff --check`; targeted diff review), update todo/history state, and commit the actionbars detached-apply guard slice.

## Execution block — 2026-03-17
- [x] Make `UnitFramesRuntime:Detach()` reuse the existing disabled-state hide contract instead of leaving spawned unit frames/combat timer live after lifecycle disable.
- [x] Make `CenterBarsRuntime:Detach()` hide the owner frame in addition to stopping rune/default-resource side effects, so detach matches the already-shipped disabled apply path.
- [x] Re-run static validation (`npx --yes luaparse`; `git diff --check`; targeted diff review), update todo/history state, and commit the runtime-detach-visibility slice.

## Execution block — 2026-03-17
- [x] Guard `Companion` apply/repair paths behind explicit detached-state checks so source-widget hooks and debounced retries cannot re-take over micro menu/bags after `Detach()`.
- [x] Restore default micro/bags layout on `Companion` teardown when safe, and defer that restore to `PLAYER_REGEN_ENABLED` instead of dropping it on the floor if detach happens in combat.
- [x] Re-run static validation (`npx --yes luaparse`; `git diff --check`; targeted diff review), update todo/history state, and commit the companion teardown-guard slice.

## Execution block — 2026-03-17
- [x] Clamp the `Movers` numeric inspector to visible screen bounds so overlays near the right/bottom edges cannot open an unreachable editor.
- [x] Add an explicit `Movers -> Edit Mode panel` unlock-state refresh hook so `Esc` / `/fgui lock` / `/fgui unlock` cannot leave the open panel checkbox stale.
- [x] Re-run static validation (`npx --yes luaparse`; `git diff --check`; targeted diff review), update todo/history state, and commit the movers inspector/state-sync slice.

## Execution block — 2026-03-17
- [x] Extend shared `Options` layout builder so complex pages can declare `color swatch` / custom grouped sections through the same data-first layout contract used by simple pages.
- [x] Migrate `OptionsPanelCenterBars.lua`, `OptionsPanelUnitFrames.lua`, and `OptionsPanelActionBars.lua` to `BuildLayout` specs while preserving existing descriptor bindings and apply/runtime behavior.
- [x] Re-run static validation (`npx --yes luaparse`; `git diff --check`; targeted grep/diff checks), update todo/history state, and commit the complex-settings-layout slice.

## Execution block — 2026-03-17
- [x] Gate `Movers:ResetPositions()` out of combat so `/fgui resetpos` and the Edit Mode reset button cannot move frames through the only remaining unsafe bulk-reset path.
- [x] Keep the guard at the user-facing reset entrypoint instead of broad-gating `Movers:Apply()`, so normal runtime holder setup still works.
- [x] Re-run static validation (`npx --yes luaparse`; targeted grep/diff checks), update todo/history state, and commit the movers reset-safety slice.

## Execution block — 2026-03-17
- [x] Add an explicit schema compatibility gate for profile import so non-current payloads are rejected instead of being silently replaced by `DB:Init()`.
- [x] Tighten schema QA/purge checks to report version incompatibility clearly and keep removed `customBars` / `weakBars` scopes out of the live profile tree.
- [x] Re-run static validation (`npx --yes luaparse`; targeted grep/diff checks), update todo/history state, and commit the profile-import compatibility slice.

## Execution block — 2026-03-17
- [x] Extract repeated `ActionBars` settings bar-section assembly behind one shared section factory so the page feeds specs instead of hand-building Bar1..Bar5 widgets.
- [x] Keep descriptor bindings generated from the same bar-spec data so layout and saved-value wiring stop drifting apart.
- [x] Re-run static validation (`npx luaparse`; `git diff --check`), update todo/history state, and commit the ActionBars settings-factory slice.

## Execution block — 2026-03-17
- [x] Stop `UnitFramesRuntime` / `CenterBarsRuntime` from force-writing `enabled=true` back into the live profile during apply.
- [x] Make both runtimes respect persisted disabled state by hiding/restoring their frames instead of mutating schema state.
- [x] Re-run static validation (`npx luaparse`; `git diff --check`; targeted grep checks), update todo/history state, and commit the runtime-enabled-contract slice.

## Execution block — 2026-03-17
- [x] Bring `ExperienceBar` watched-reputation progress logic in line with Blizzard major-faction and friendship branches instead of only handling generic standings + paragon.
- [x] Preserve watched reputation visibility/text for capped friendship and account-wide cases without falling through to the honor fallback.
- [x] Re-run static validation (`wow_api.lookup_api`; `npx luaparse`; `git diff --check`; targeted source comparison), update todo/history state, and commit the ExperienceBar reputation-progress slice.

## Execution block — 2026-03-17
- [x] Invalidate panel undo/apply history after destructive settings rewrites (`Reset`, profile import) so stale pre-reset values cannot leak back into the new profile.
- [x] Align Settings subcategory registration IDs with the registry contract instead of double-prefixing `FGUI_`.
- [x] Re-run static validation (`npx luaparse`; `git diff --check`; targeted grep checks), update todo/history state, and commit the settings-history invalidation slice.

## Execution block — 2026-03-17
- [x] Collapse `ActionBars` button-facing visual refresh into one idempotent normalization path instead of splitting skin/typography/cooldown/state across runtime and callback glue.
- [x] Re-run that normalization from action/state change callbacks so hidden Blizzard button art cannot resurface after the initial skin pass.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the ActionBars visual-normalization slice.

## Execution block — 2026-03-17
- [x] Add shared `Settings` layout/scaffold helpers so remaining simple pages stop hand-assembling anchor chains one widget at a time.
- [x] Migrate `OptionsPanelGeneral.lua`, `OptionsPanelCompanion.lua`, and `OptionsPanelEditMode.lua` onto that shared layout contract while preserving their existing binding/apply behavior.
- [x] Extract schema/reset/legacy-purge policy out of `core/DB.lua` into a dedicated core layer so migrations stay pure and `DB` stops owning schema plumbing.
- [x] Re-run static validation (`npx --yes luaparse`; targeted grep/diff checks), update todo/history state, and commit each completed slice.

## Execution block — 2026-03-17
- [x] Move `UnitFrames` target/focus bookkeeping out of `UnitFramesRuntime` owner-level event routing into `UnitFramesTarget` frame-local observers and header-anchor hooks.
- [x] Refactor `UnitFramesTarget` target-info refresh from owner-bound `"target"` logic into frame-local reconcile helpers, then collapse the dead `UF` proxy/fallback glue that only existed for the runtime bridge.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the UnitFrames target-coordinator slice.

## Execution block — 2026-03-17
- [x] Extend `FeatureRegistry` from panel-only metadata into the canonical source of truth for feature lifecycle/apply contracts, including feature order, apply order, and theme-consumer ownership.
- [x] Rewire `core/App.lua` to consume that registry contract instead of rebuilding feature/apply specs locally.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the feature-registry ownership slice.

## Execution block — 2026-03-17
- [x] Stabilize `Companion` micro-menu takeover so failed or half-initialized `OverrideMicroMenuPosition` passes do not get treated as success, and retry only after Blizzard has real button geometry again.
- [x] Sync Blizzard `MultiBarRight` / `MultiBarLeft` toggles to explicit enabled and disabled states so `Bar4/Bar5` no longer leave stale Blizzard layout/tracker state behind.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the Companion/ActionBars Blizzard hand-off slice.

## Execution block — 2026-03-17
- [x] Restore `ActionBars` Blizzard shell suppression so `hideBlizzard` and lifecycle detach paths can re-show Blizzard shell frames instead of leaving them stuck hidden until `/reload`.
- [x] Reintroduce right-container/tracker isolation around `MultiBarRight` / `MultiBarLeft` with symmetric `SetActionBarToggles` sync + managed-layout refresh after hide/restore.
- [x] Add one narrow post-`SettingsPanel` repair hook path for Blizzard shell resets, then re-run static validation, update todo/history state, and commit the ActionBars shell-restore slice.

## Execution block — 2026-03-17
- [x] Replace the persistent `CenterBars` 20 Hz rune ticker with a narrower scheduled refresh path that only lives while visible runes are actively recharging.
- [x] Keep rune cleanup reversible on `resourceMode`/`Detach`, but stop carrying a broad polling loop through the whole DK cooldown window when a one-shot reschedule is enough.
- [x] Re-run static validation (`npx luaparse`; targeted diff/grep checks), update todo/history state, and commit the CenterBars rune-refresh slice.

## Execution block — 2026-03-17
- [x] Extend the shared `Options` descriptor helper layer with reusable read/transform primitives so descriptorized panels stop re-declaring the same binding glue.
- [x] Migrate `OptionsPanelActionBars.lua` onto `CreateBindingState` + `AddDescriptorBindings` instead of keeping one panel-local legacy binding stack.
- [x] Migrate `OptionsPanelUnitFrames.lua` onto the same descriptor contract, including multi-path scale, size, radio, and color bindings.
- [x] Re-run static validation (`npx luaparse`; targeted diff/grep checks), update todo/history state, and commit the settings-descriptor cleanup slice.

## Execution block — 2026-03-17
- [x] Make `CenterBars` Blizzard class-resource suppression reversible instead of permanently overriding Blizzard frames until `/reload`.
- [x] Restore suppressed Blizzard resource frames on config/resource-mode changes and `Detach`, and stop the rune ticker on `Detach` instead of leaving runtime side effects behind.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the CenterBars suppression-state slice.

## Execution block — 2026-03-17
- [x] Extend the shared `Options` descriptor layer so it can own `radioGroup` and `color swatch` widgets instead of forcing panel-local binding glue.
- [x] Migrate `OptionsPanelCenterBars.lua` onto `CreateBindingState` + `AddDescriptorBindings` so `CenterBars` settings stop carrying their own refresh/bind mini-framework.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the CenterBars settings-descriptor slice.

## Execution block — 2026-03-17
- [x] Add one owner-level `Movers` teardown path for active overlay interaction instead of leaving drag/resize cleanup trapped inside overlay-local stop handlers only.
- [x] Reuse one persistent keyboard listener frame across unlock/lock cycles instead of allocating a new inert listener on every unlock.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the Movers teardown/listener slice.

## Execution block — 2026-03-17
- [x] Move `UnitFrames` combat-deferred dirty-state handling behind one feature-owned flush entrypoint instead of letting `App` read `_configDirty` / `_auraModeDirty` directly.
- [x] Keep `App` on feature-level combat hooks only, while `UnitFrames` owns how deferred `ApplyConfig` / aura-mode reconcile is drained after combat.
- [x] Re-run static validation (`npx luaparse`; targeted grep/diff checks), update todo/history state, and commit the UnitFrames deferred-combat flush slice.

## Execution block — 2026-03-15
- [x] Move Edit Mode reset-positions apply orchestration out of panel code and into `Movers` ownership.
- [x] Make registry/spec contract the source of truth for reset apply routing, including explicit `micromenu -> companion` apply ownership.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the Edit Mode reset ownership slice.

## Execution block — 2026-03-17
- [x] Centralize Options panel ownership metadata (`panelKey` / apply / reset / refresh context) into one shared contract layer instead of duplicating it across panel builders.
- [x] Fix Edit Mode panel semantics so reset/undo own both `movers` and `editor`, and `Movers` can resync overlay/editor state from profile after panel-level changes.
- [x] Re-run static validation (`npx luaparse`, `git diff --check`), update todo/history state, and commit the panel-contract ownership slice.

## Execution block — 2026-03-17
- [x] Reconnect `ExperienceBar` to the active loader/app graph instead of leaving it orphaned on disk.
- [x] Extend active `core/DB.lua` with the minimal `experience` / `xpbar` defaults needed for runtime + movers contract, without switching over to the unfinished `DBCore` branch.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the ExperienceBar integration slice.

## Execution block — 2026-03-17
- [x] Add one target-side refresh coordinator for `UnitFrames` so runtime events stop fanning out through multiple coarse owner proxy calls.
- [x] Narrow `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` / `UNIT_FACTION` / `UNIT_TARGET` / target info events to unit-scoped target refreshes instead of over-updating all extra health colors.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the UnitFrames target-event coordinator slice.

## Execution block — 2026-03-17
- [x] Reconnect `ProfileTransfer` to the active `.toc`/slash surface instead of leaving it as an unreachable helper on disk.
- [x] Add explicit `/fgui export` and `/fgui import` entrypoints through the active command router.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the profile-transfer entrypoint slice.

## Execution block — 2026-03-17
- [x] Bring `ExperienceBar` onto the active mover/settings contract instead of leaving it on fallback behavior only.
- [x] Suppress Blizzard status-tracking bars from the `ExperienceBar` owner path so the addon no longer renders a duplicate XP/reputation/honor bar.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the ExperienceBar contract cleanup slice.

## Execution block — 2026-03-17
- [x] Remove the proven dead-branch files that duplicated the active `DB` and `Companion` architecture (`DBCore`, `DBMigrations`, `DeferQueue`, legacy `MicroBags`, legacy `PetBar`).
- [x] Keep archive/history snapshots untouched, but update active backlog/docs to reflect that the duplicate branch is gone from the live addon tree.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the dead-branch cleanup slice.

## Execution block — 2026-03-17
- [x] Remove the remaining proven no-caller utility orphans from the live tree (`EventManager`, `FeelsGoodFX`) instead of carrying them as fake active infrastructure.
- [x] Rewrite the active architecture ledger so it reflects the real live addon tree rather than archived `CooldownViewer` / `CustomBars` / scheduler branches.
- [x] Re-run static validation (`npx luaparse`; git diff checks are blocked here by the known OneDrive/git `mmap failed: Invalid argument` issue), update todo/history state, and commit the utility-orphan cleanup slice.

## Execution block — 2026-03-17
- [x] Route `CenterBarsRuntime` event/apply flow directly into render entry points instead of bouncing through thin owner proxy methods.
- [x] Keep `modules/CenterBars.lua` as the public facade while `modules/CenterBarsRuntime.lua` owns the render-call contract it actually uses.
- [x] Re-run static validation (`npx luaparse`, `git diff --check`), update todo/history state, and commit the CenterBars runtime-route slice.

## Execution block — 2026-03-15
- [x] Remove hidden shared-typography coupling from `ActionBars` / `Companion` runtime modules to `unitframes.text`.
- [x] Centralize legacy typography back-compat in shared normalization/theme policy instead of per-feature cross-reads.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the shared typography decoupling slice.

## Execution block — 2026-03-15
- [x] Finalize `CenterBars` architecture as an independent owner-module instead of a `UnitFrames` / player-frame submodule.
- [x] Remove hidden `CenterBars -> unitframes.text` coupling by moving typography ownership into the `center` section with back-compat normalization.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the CenterBars architecture slice.

## Execution block — 2026-03-15
- [x] Extract `CenterBars` lifecycle/apply/event coordinator into a dedicated runtime helper module.
- [x] Keep `modules/CenterBars.lua` focused on resource mapping, layout/update/render helpers, and thin public wrappers.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the CenterBars runtime slice.

## Execution block — 2026-03-15
- [x] Перевести `Movers` position apply/read/writeback на spec-aware shared helper layer вместо raw `positions`-доступа, размазанного между runtime, editor и inspector.
- [x] Исправить inspector/edit-mode coordinate contract для non-center defaults (`actionbar4/5` и похожих), чтобы editable offsets брались из живой геометрии frame, а не из сырых anchor offsets.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the Movers position contract slice.

## Execution block — 2026-03-15
- [x] Extract `UnitFrames` health text / low-HP glow / combat timer / aura / power / castbar render helpers into a dedicated helper module.
- [x] Keep `modules/UnitFrames.lua` focused on profile cache, mover descriptors, and thin public/runtime wiring.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the UnitFrames render slice.

## Execution block — 2026-03-15
- [x] Extract `UnitFrames` secret-safe text helpers into a dedicated helper module.
- [x] Extract `UnitFrames` target header/info + target aura mode + target health-color routing into a dedicated helper module.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the UnitFrames target/text slice.

## Execution block — 2026-03-15
- [x] Extract `MinimapIcon` click/tooltip/error-report actions into a dedicated helper module.
- [x] Keep `core/MinimapIcon.lua` focused on `LDB`/`LibDBIcon` transport + persisted config apply.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the MinimapIcon ownership slice.

## Execution block — 2026-03-15
- [x] Extract `UnitFrames` owner/runtime lifecycle (`Attach` / `Detach` / `Init` / `ApplyConfig`) into a dedicated runtime helper module.
- [x] Keep `modules/UnitFrames.lua` focused on style/layout/render helpers and thin public wrappers.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the UnitFrames runtime slice.

## Execution block — 2026-03-15
- [x] Audit the active tree for removed `Cooldown Viewer` / weak/extra-bar names outside legacy purge/QA guard paths.
- [x] Confirm the only remaining legacy mentions live in `history.md`, `core/DB.lua`, `core/QA.lua`, and this backlog note itself.
- [x] Update todo/history state and commit the legacy-name cleanup sweep.

## Execution block — 2026-03-16
- [x] Extract `UnitFrames` owner-level cache/profile helpers and mover descriptor policy into a dedicated helper module.
- [x] Keep `modules/UnitFrames.lua` focused on thin public wrappers and helper/runtime wiring only.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the UnitFrames policy slice.

## Execution block — 2026-03-16
- [x] Extract `CenterBars` threshold/render/update/resource-mode logic into a dedicated helper module.
- [x] Keep `modules/CenterBars.lua` focused on config/resource policy, mover/runtime wiring, and thin public wrappers only.
- [x] Re-run static validation (`npx luaparse`), update todo/history state, and commit the CenterBars render slice.

## Execution block — 2026-03-14
- [x] Extract `Companion` lifecycle/apply orchestration into a dedicated runtime helper module.
- [x] Slim `modules/Companion.lua` into a thin facade over the runtime helper.
- [x] Re-run static validation, update todo/history state, and commit the Companion runtime slice.

## Execution block — 2026-03-14
- [x] Extract `ActionBars` edit-mode registration (`actionbar1..5` mover specs and holder registration) into a dedicated helper module.
- [x] Extract `ActionBars` lifecycle/apply coordinator (`_ApplyNow`, initial-apply queue, attach/detach, combat retry, action-changed callback wiring) into a dedicated helper module.
- [x] Re-run static validation, update todo/history state, and commit the ActionBars coordinator slice.

## Execution block — 2026-03-14
- [x] Extract `ActionBars` visual sync layer (skin, typography, cooldown text, hotkeys) into a dedicated helper module.
- [x] Re-run static validation, update todo/history state, and commit the ActionBars visual slice.

## Execution block — 2026-03-14
- [x] Extract `ActionBars` state/autohide runtime (button state layers, empty-slot refresh, hover/autohide hooks) into a dedicated helper module.
- [x] Re-run static validation, update todo/history state, and commit the ActionBars state slice.

## Execution block — 2026-03-14
- [x] Extract `ActionBars` Blizzard shell delegation (sidebar toggle sync, art-hide pass, endcaps hook) into a dedicated helper module.
- [x] Re-run static validation, update todo/history state, and commit the ActionBars shell slice.

## Execution block — 2026-03-14
- [x] Narrow `Companion` micro menu ownership to source-widget signals instead of `UpdateMicroButtons`-driven reapply churn.
- [x] Keep only the minimal repair hook for real Blizzard ownership resets, then re-run static validation and commit.
- [x] Collapse `Companion` bags layout into an explicit `hidden/compact/expanded` plan instead of one large imperative branch.
- [x] Re-run static validation, update todo state, and commit the bags cleanup slice.
- [x] Split `ActionBars` holder/layout apply path out of `_ApplyNow` into explicit helper layers.
- [x] Re-run static validation, update todo state, and commit the ActionBars layout slice.
- [x] Split `Companion` into explicit `shared`, `pet bar`, and `micro/bags` ownership layers so the top-level module only coordinates lifecycle/apply.
- [x] Re-run static validation, update todo/history state, and commit the Companion ownership slice.

## 1. Остаточный core / schema debt
- [ ] PARTIAL — lifecycle baseline уже есть (`core/App.lua`, `core/Lifecycle.lua`, `core/Events.lua`), а `core/FeatureRegistry.lua` теперь централизует не только panel metadata, но и feature/apply/theme-consumer ownership для `App`; remaining debt здесь уже не в app/runtime spec tables, а в более data-first page policy и оставшихся seams между `Options` / `Movers` вокруг live layout assembly.
- [ ] PARTIAL — текущая schema политика теперь живет отдельным слоем в `core/Schema.lua`: `CURRENT_SCHEMA_VERSION = 1`, hard reset, resolution-preset seed и legacy purge больше не сидят внутри `core/DB.lua`, а import path уже имеет explicit compatibility gate вместо silent reset; remaining debt уже не в DB-local plumbing, а в том, что stepwise migrations/new schema policy по-прежнему не зафиксированы.
- [ ] PARTIAL — hidden cross-feature coupling дальше уменьшен: runtime typography/read coupling из `CenterBars` / `ActionBars` / `Companion` к `unitframes.text` уже убран, panel reset/refresh ownership теперь не держится на scattered hardcoded section lists, а simple и complex pages уже сидят на shared layout scaffold; remaining debt сместился из raw page assembly в live preview/apply coupling и runtime teardown semantics между features.

## 2. Edit Mode / Movers
- [ ] PARTIAL — movers runtime уже разрезан, registered mover specs владеют scale/resize/apply contract, panel reset/undo больше не расходится между `movers` и `editor`, bulk `Reset Positions` path теперь тоже combat-gated, а inspector больше не уходит off-screen и открытая Edit Mode panel ловит runtime lock/unlock state; remaining debt теперь уже не в прямом inspector/panel sync bug, а в более широком ownership/lifecycle contract вокруг overlay registry refresh и полной in-game validation.
- [x] Дожать geometry/writeback contract так, чтобы registry управлял не только scale/resize/apply, но и persisted position semantics без рассыпанных assumptions.
- [ ] In-game перепроверить descriptor-migrated path: drag, wheel, inspector commit, reset positions и `/reload` должны одинаково держать `unitframes` / `center` / `actionbars` / `companion`.

## 3. UnitFrames
- [ ] PARTIAL — `UnitFrames` уже разрезан на `modules/UnitFramesText.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesPolicy.lua` и `modules/UnitFramesRuntime.lua`; target/focus bookkeeping теперь больше не живет в `UnitFramesRuntime` owner-level `_eventFrame`, а detach уже гасит spawned frames/combat timer вместо голой отписки, так что remaining debt уже в in-game behavior и возможных oUF-native polish paths, а не в lifecycle bridge ownership.
- [x] Убрать remaining owner-level manual target/focus bookkeeping events и helper-логику там, где ту же задачу уже должен вести frame-local helper layer вместо runtime bridge.
- [ ] In-game повторно проверить старый риск: эпизодическое исчезновение `player/target`.

## 4. CenterBars
- [x] Архитектурное решение зафиксировано: `CenterBars` — независимый owner-module со своим `center` profile/apply/mover/runtime contract, а не подмодуль `UnitFrames` / player-frame ecosystem.
- [ ] PARTIAL — lifecycle/apply/event-frame coordinator уже вынесен в `modules/CenterBarsRuntime.lua`, threshold/render/update/resource-mode layer живет в `modules/CenterBarsRender.lua`, runtime больше не bounce-ит event/apply path через owner proxy methods, rune refresh narrowed from a persistent 20 Hz ticker to a cancellable one-shot scheduler, а detach теперь прячет owner frame так же, как disabled apply path; remaining debt здесь уже в финальной in-game perf tuning/resource policy, а не в broad polling loop.
- [ ] Перепроверить в игре smoothness/стоимость rune refresh после перехода с persistent ticker на one-shot reschedule path.

## 5. ActionBars
- [ ] PARTIAL — observer narrowing сделан, holder/layout apply path, edit-mode registration, lifecycle/apply coordinator, Blizzard shell delegation, state/autohide runtime и visual sync уже вынесены в отдельные helper layers, shell restore/re-hide contract симметричный, а delayed initial apply больше не переживает detach; remaining debt здесь теперь в основном в in-game regression validation Blizzard-button ownership, а не в еще одном lifecycle queue bug.
- [ ] Повторно проверить визуальные регрессии: случайные рамки, overlay/glow/grid state на кнопках.
- [ ] Повторно проверить `Bar4/Bar5` рядом с Blizzard tracker после current hide/shell logic.

## 6. Companion
- [ ] PARTIAL — `Companion` больше не держит owner runtime в одном файле: `CompanionShared`, `CompanionPetBar`, `CompanionMicroBags` и `CompanionRuntime` разнесены отдельно, micro-menu takeover стабилизирован geometry gate + debounced retry path, detached runtime больше не может заново захватывать `micro/bags` через repair hooks, а pet bar teardown уже возвращает Blizzard ownership/layout вместо голого `holder:Hide()`; remaining debt теперь уже в полной in-game validation pet summon/despawn + bag-state churn, а не в missing default-layout restore path.
- [ ] In-game проверить сценарии: pet summon/despawn, reload, entering world, bag expand/collapse, `BAG_UPDATE_DELAYED`, `MainMenuBarManager.OnExpandChanged`.

## 7. Settings UI
- [ ] PARTIAL — primary register/open flow уже modern `Settings`; page modules вынесены в `OptionsPanel*.lua`, shared widget/apply helpers живут в `core/OptionsSharedHelpers.lua`, descriptor-driven field/binding layer в `core/OptionsFieldBuilders.lua` теперь ведет все active pages, а panel metadata (`apply/reset/refresh context`) централизована в shared contract layer; simple и complex pages теперь сидят на shared `BuildLayout(...)` scaffold, включая `color swatch` и custom grouped sections, а multi-write `UnitFrames` master-scale уже использует shared panel undo batch вместо partial single-path undo; remaining debt сместился из imperative anchor assembly в live preview/apply routing и page-local field semantics.
- [x] Свести remaining complex-page layout assembly к более data-first page descriptors, чтобы `OptionsPanelActionBars.lua`, `OptionsPanelCenterBars.lua` и `OptionsPanelUnitFrames.lua` держали layout spec, а не разрозненный imperative widget placement.
- [x] Убрать remaining handcrafted legacy-style page structure в complex pages там, где можно перейти на более чистый Settings/descriptor layer без размазанного anchor glue.
- [ ] Пересмотреть live preview/apply routing дальше: базовый panel contract уже выровнен, но часть page-local widget/event wiring все еще слишком тесно переплетена с page code.
- [ ] Прогнать весь settings path в игре: открытие, subcategory navigation, resize/reflow, repeated open/close, apply/rollback, `/reload`.

## 8. Utility / cleanup tail
- [ ] PARTIAL — duplicate branch и proven no-caller utility orphans уже убраны из live addon tree; remaining utility tail теперь в основном в stale archive snapshots/tooling notes, а не в competing runtime code.

## 9. Обязательная in-game validation
- [ ] Аддон грузится чисто после `/reload` и fresh login.
- [ ] Не осталось пустых или ghost-остатков `Cooldown Viewer` в settings, movers, QA или runtime.
- [ ] `/fgui qa` проходит legacy-field checks.
- [ ] Нет `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` в типовых боевых сценариях.
- [ ] Settings pages открываются и переоткрываются без layout breakage.
- [ ] Apply queue не оставляет partial runtime state после ошибки на практике.
- [ ] Action bar paging / override / vehicle / possess все еще работают.
- [ ] Pet bar, micro menu и bags стабильны при combat/bag-state churn.
- [ ] EXP / reputation / honor bar показывается и скрывается правильно по состоянию персонажа, без параллельного Blizzard status-tracking дубля.
- [ ] `player` / `target` / `focus` / `targettarget` / `pet` держат правильную видимость после toggles и reload.
- [ ] Perf overlay / diagnostics показывают только живые модули и ожидаемые apply counters.

## 10. Порядок работ
1. `UnitFrames` + `CenterBars` cleanup.
2. `Movers` geometry/writeback polish + Edit Mode QA.
3. `Settings` layout/apply polish.
4. Полный in-game QA / taint / perf gate.
