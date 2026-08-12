# FeelsGoodUI — history

Этот файл архивирует то, что по аудиту дерева на 2026-03-14 уже сделано, сознательно закрыто или больше не должно висеть в активном `todo.md`.

Принцип аудита:
- source of truth — текущий код дерева `FeelsGoodUI`, а не старые галочки;
- в history попадает только подтвержденное кодом или явно выведенное из активного scope;
- все runtime-проверки, которые нельзя доказать чтением кода, оставлены в `todo.md`.

## Подтверждено как сделанное

### 2026-03-17 — UnitFrames batch-undo slice
Закрытые хвосты:
- `unitframes master-scale partial undo tail`;
- `settings panel multi-write undo integration tail`.

Смысл закрытия:
- `core/Settings.lua` теперь держит shared panel undo batch contract (`BeginPanelUndoBatch` / `EndPanelUndoBatch`) и складывает multi-write changes в один undo entry вместо серии независимых single-path records;
- `core/OptionsPanelUnitFrames.lua` поднимает `ctx.Settings` и оборачивает master-scale write fan-out (`player/target/focus/targettarget/pet`) в один panel undo batch, так что `Undo last` больше не откатывает только последний unit scale из логически одного UI-action;
- batch teardown теперь закрывается даже при ошибке внутри write loop, а static/syntax validation повторно прогнана через `npx --yes luaparse`, `node check_lua.js` и `git diff --check`.

### 2026-03-17 — Companion pet-bar teardown slice
Закрытые хвосты:
- `companion pet-bar default-layout restore tail`;
- `companion pet-holder reattach visibility tail`.

Смысл закрытия:
- `modules/CompanionPetBar.lua` получил явный `RestoreDefaultLayout()` path: detach теперь снимает `visibility` state driver с addon holder, возвращает `PetActionButton1..10` в Blizzard button containers и рефрешит Blizzard `PetActionBar` через built-in grid/art/update path вместо простого `holder:Hide()`;
- `EnsurePetAnchor()` теперь заново вооружает reused secure holder visibility driver, а `PetBar:Apply()` явно показывает holder, чтобы `Disable -> Enable` не оставлял pet bar на скрытом anchor после teardown;
- `modules/CompanionRuntime.lua` дергает pet-bar restore в `FinalizeDetach()` симметрично `MicroBags:RestoreDefaultLayout()`;
- синтаксис для измененных файлов повторно прогнан через `npx --yes luaparse`, весь addon перепроверен через `node check_lua.js`, `git diff --check` чистый, а глобальные `RegisterStateDriver` / `UnregisterStateDriver` подтверждены по `C:\Tools\WoW_Dev_Tools\wow-ui-source` (`Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`) из-за неполного ответа `wow-api` MCP по этим функциям.

### 2026-03-17 — ActionBars detached-apply guard slice
Закрытые хвосты:
- `actionbars delayed initial apply after detach tail`.

Смысл закрытия:
- `modules/ActionBarsRuntime.lua` теперь явно режет `ApplyNow()` / `ApplyConfig()` / `QueueInitialApply()` по detached state, а queued initial-apply callback после `C_Timer.After(...)` проверяет этот state перед входом обратно в runtime apply path;
- `Attach()` сбрасывает detached marker, а `Detach()` помечает модуль detached и очищает `_initialApplyQueued`, так что lifecycle disable больше не оставляет таймеру путь назад в `ApplyConfig()` уже после teardown;
- это сужает remaining `ActionBars` debt до live Blizzard-button regression QA и полного visual/runtime validation, а не до очереди, которая переживает detach;
- синтаксис для измененного runtime файла повторно прогнан через `npx --yes luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Runtime detach-visibility slice
Закрытые хвосты:
- `unitframes detach leaves live frames tail`;
- `centerbars detach leaves owner frame visible tail`.

Смысл закрытия:
- `modules/UnitFramesRuntime.lua` больше не трактует detach как одну только отписку от target-owner callbacks: runtime теперь переиспользует уже существующий disabled-state contract, снимает `RegisterUnitWatch` с optional units, прячет `player/target` frames и останавливает combat timer, а также сбрасывает deferred dirty flags вместо переноса их через disabled state;
- `modules/CenterBarsRuntime.lua` теперь при detach не только останавливает rune ticker и восстанавливает Blizzard class resources, но и прячет owner frame, так что lifecycle disable больше не оставляет на экране stale center bar до следующего apply/reload;
- это сужает remaining runtime teardown debt до `ActionBars` initial-apply guard и полного `Companion` pet-bar restoration contract, а не до уже подтвержденных visibility leaks в `UnitFrames/CenterBars`;
- синтаксис для измененных runtime files повторно прогнан через `npx --yes luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Companion teardown-guard slice
Закрытые хвосты:
- `companion detached reapply tail`;
- `companion lost micro/bags restore-on-detach tail`.

Смысл закрытия:
- `modules/CompanionRuntime.lua` теперь помечает модуль detached state отдельно от обычного attach/apply flow, режет `ApplyConfig()` / `RequestApply()` по этому state и отменяет pending debounce keys до teardown, так что lifecycle больше не считает фичу выключенной в одном месте, пока runtime еще может сам себя переактивировать в другом;
- detach path больше не теряет restore при combat disable: если teardown случается в combat, runtime оставляет только узкий `PLAYER_REGEN_ENABLED` watcher, чтобы восстановить default `micro/bags` layout сразу после выхода из combat, а не навсегда зависнуть в managed state;
- `modules/CompanionMicroBags.lua` получил explicit active-module guards вокруг repair hooks, source-widget refresh callbacks и bag texture hooks, поэтому one-time `hooksecurefunc`/`HookScript` surfaces больше не могут снова вызвать `RequestApply()` после detach;
- shared micro-layout retry timer теперь отменяется явно во время teardown, а restore path вынесен в отдельный reusable helper вместо скрытого local-only поведения;
- это сужает remaining `Companion` debt до полного pet-bar/default-layout restoration contract и in-game QA, а не до live micro-menu takeover after detach;
- синтаксис для измененных `Companion*.lua` файлов повторно прогнан через `npx --yes luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Movers inspector/state-sync slice
Закрытые хвосты:
- `movers off-screen inspector placement tail`;
- `editmode stale unlock-state panel sync tail`.

Смысл закрытия:
- `core/MoversInspector.lua` больше не открывает numeric inspector слепо справа от overlay: inspector теперь `SetClampedToScreen(true)` и получает явный edge-aware placement поверх `UIParentRect()`, так что mover у правой/нижней границы не делает numeric edit path недоступным;
- inspector хранит активный overlay reference и перепозиционируется на `UpdateInspector(...)`, поэтому drag/nudge/update paths не оставляют panel за пределами экрана после открытия;
- `core/Movers.lua` получил lightweight state-listener contract для unlock/lock transitions, а `core/OptionsPanelEditMode.lua` подписывается на него только для live refresh открытой panel, так что `Esc`, `/fgui lock` и `/fgui unlock` больше не оставляют stale checkbox state до переоткрытия окна настроек;
- это сужает remaining `Movers` debt до in-game QA и более широкого overlay lifecycle ownership, а не до локального inspector placement/panel sync breakage;
- статическая проверка синтаксиса для измененных `Movers*.lua` / `OptionsPanelEditMode.lua` повторно прогнана через `npx --yes luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Complex settings layout slice
Закрытые хвосты:
- `settings complex-page imperative layout tail`;
- `settings handcrafted anchor-chain structure tail`.

Смысл закрытия:
- `core/OptionsFieldBuilders.lua` расширен до `colorSwatch` layout items, которые сохраняют row-anchor reference на самом swatch widget, так что complex pages теперь могут описывать color rows через тот же shared `BuildLayout(...)` contract, что и обычные check/slider/radio controls;
- `core/OptionsPanelCenterBars.lua` и `core/OptionsPanelUnitFrames.lua` больше не hand-assemble-ят длинные `CreateHeader/CreateCheck/CreateSlider/CreateColorSwatch` chains: весь widget order теперь задается одной layout-spec таблицей, а существующие descriptor bindings / apply routing оставлены прежними;
- `core/OptionsPanelActionBars.lua` переведен на тот же layout contract для core controls, а repeating center/side bar groups завернуты в custom layout items поверх уже существующих bar-spec arrays вместо page-local anchor glue;
- это сужает remaining `Settings UI` debt до live preview/apply coupling и in-game validation, а не до еще одного imperative layout rewrite;
- статическая проверка синтаксиса для измененных settings files повторно прогнана через `npx luaparse`, whitespace/diff integrity — через `git diff --check`, а targeted grep подтвердил, что три remaining complex pages больше не держат локальные chains из raw widget builders.

### 2026-03-17 — Movers reset-safety slice
Закрытые хвосты:
- `movers bulk reset combat-safety tail`.

Смысл закрытия:
- `core/Movers.lua` больше не позволяет `Reset Positions` проходить через единственный bulk-move path без combat gate: reset теперь проверяет тот же `IsSafeToEdit()` contract, что drag/wheel/numeric edit paths, и просто отказывается работать в combat;
- guard оставлен именно на user-facing reset entrypoint, а не на `Movers:Apply()`, поэтому normal runtime holder setup и module-level reapply paths не получают случайный combat regression;
- это сужает remaining `Movers` debt до ownership/state-sync contract между owner, editor, inspector и Edit Mode panel, а не до прямого unsafe move path;
- статическая проверка синтаксиса для измененного mover file повторно прогнана через `npx luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Profile import compatibility slice
Закрытые хвосты:
- `profile import silent reset tail`;
- `schema QA compatibility visibility tail`.

Смысл закрытия:
- `core/ProfileTransfer.lua` больше не отдает любой импортированный payload в `DB:Init()` вслепую: import сначала читает schema compatibility state и принимает только current-version exports, а older/future/missing-version payloads возвращают явную ошибку вместо silent profile reset;
- `core/Schema.lua` теперь держит один compatibility state contract (`status`, `needsReset`, `canImport`) поверх текущего reset-first policy, так что import/runtime QA больше не угадывают schema semantics локально;
- live schema purge дополнительно вычищает removed `customBars` / `weakBars` top-level scopes, а `core/QA.lua` теперь явно показывает schema mismatch, ловит возврат этих removed scopes и не ругается на boolean keys, которые сам import validator допускает;
- статическая проверка синтаксиса для измененных schema/import/QA files повторно прогнана через `npx luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — ActionBars settings-factory slice
Закрытые хвосты:
- `actionbars settings repeated section assembly tail`;
- `actionbars page-local bar descriptor drift tail`.

Смысл закрытия:
- `core/OptionsPanelActionBars.lua` больше не собирает `Bar1..Bar5` sections вручную как пять отдельных chains из `CreateSlider/CreateCheck`; page теперь задает bar-spec arrays для center/side bars и строит их через shared section factory;
- layout widgets и descriptor bindings теперь выводятся из одного и того же spec source, так что `enabled/buttons/rows` для action bars больше не могут разъехаться между UI assembly и profile write paths;
- это сужает remaining settings debt в `ActionBars` до panel-wide policy, а не к повторяющемуся page-local glue;
- синтаксис измененного panel file повторно прогнан через `npx luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — Runtime enabled-contract slice
Закрытые хвосты:
- `unitframes enabled-state mutation tail`;
- `centerbars enabled-state mutation tail`.

Смысл закрытия:
- `modules/UnitFramesRuntime.lua` и `modules/CenterBarsRuntime.lua` больше не force-write-ят `enabled = true` обратно в профиль во время `ApplyConfig()` / `Init()`;
- persisted disabled state теперь реально потребляется runtime-слоем: `UnitFrames` скрывает live frames и останавливает combat timer, а `CenterBars` скрывает owner frame и возвращает Blizzard class resources вместо того, чтобы silently перезаписывать schema flag;
- это возвращает profile/ import/manual edits роль source of truth и убирает side effect, где runtime сам менял SavedVariables просто из-за очередного apply;
- синтаксис для измененных runtime files повторно прогнан через `npx luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — ExperienceBar reputation-progress slice
Закрытые хвосты:
- `experiencebar watched-reputation branch tail`;
- `experiencebar friendship/major-faction progress tail`.

Смысл закрытия:
- `modules/ExperienceBar.lua` больше не трактует watched reputation только как generic reaction-threshold data + paragon fallback; runtime теперь повторяет Blizzard branches для `major faction` и `friendship` reputations поверх того же `C_Reputation.GetWatchedFactionData()` source;
- capped friendship / renown edge cases больше не схлопываются в fake binary bar из-за missing generic thresholds, а остаются видимыми как корректный full progress state;
- account-wide watched reputations теперь получают тот же label suffix, который использует Blizzard status-tracking bar;
- API surface для новых веток перепроверен через `wow_api.lookup_api(...)`, а синтаксис/whitespace для измененного runtime файла повторно прогнаны через `npx luaparse` и `git diff --check`.

### 2026-03-17 — Settings history invalidation slice
Закрытые хвосты:
- `settings stale undo-after-reset tail`;
- `settings import history invalidation tail`;
- `settings subcategory id drift tail`.

Смысл закрытия:
- `core/Settings.lua` получил явные `InvalidatePanelHistory(...)` и `InvalidateAllHistory()` helpers, так что panel undo/apply rollback history больше не переживает destructive profile rewrites;
- `core/OptionsSharedHelpers.lua` и `core/OptionsPanelEditMode.lua` теперь сбрасывают stale undo/pending state после panel reset, прежде чем runtime снова применяет defaults;
- `core/ProfileTransfer.lua` очищает settings history после успешного import, чтобы `/fgui import` не оставлял кнопке `Undo last` путь назад в pre-import профиль;
- `core/Options.lua` больше не double-prefix-ит subcategory IDs, и registration снова совпадает с `FeatureRegistry` contract вместо `FGUI_FGUI_*` drift;
- статическая проверка синтаксиса для измененных settings files повторно прогнана через `npx luaparse`, а whitespace/diff integrity — через `git diff --check`.

### 2026-03-17 — ActionBars visual normalization slice
Закрытые хвосты:
- `actionbars button visual refresh tail`;
- `actionbars random border/check/pushed regression tail`.

Смысл закрытия:
- `modules/ActionBarsVisuals.lua` теперь держит один idempotent `RefreshButtonVisualState(...)` path, который повторно скрывает Blizzard `Border` / `NormalTexture` / default checked+pushed+highlight art, а не полагается на one-time `SkinButton(...)`;
- `modules/ActionBarsRuntime.lua` и `modules/ActionBarsState.lua` больше не гоняют partial refresh для `typography/cooldown/checked/empty` по разным callsites, а переиспользуют один общий button normalization contract после apply и action/state callbacks;
- это сужает источник правды по кнопке и убирает класс регрессий, где Blizzard art возвращался уже после первичного skin pass;
- статическая проверка синтаксиса для измененных `ActionBars*.lua` повторно прогнана через `npx luaparse`.

### 1. Bootstrap / core contract
- `FeelsGoodUI.lua` сужен до compatibility entrypoint; orchestration вынесен в `core/Commands.lua` и `core/App.lua` (`FeelsGoodUI.lua:1-9`).
- `.toc` грузит активные feature-модули только как `UnitFrames`, `CenterBars`, `ActionBars`, `Companion`; `CooldownViewerSkin` в active tree больше не участвует (`FeelsGoodUI.toc:53-63`).
- feature order, apply order и feature lifecycle/apply/theme-consumer ownership теперь централизованы в `core/FeatureRegistry.lua`, а `core/App.lua` читает этот registry contract вместо локального rebuild feature/apply spec tables; active feature-set включает `companion` и не содержит `cooldownViewer`.
- bootstrap сервисы (`DB.Init`, `DB.ApplyRuntime`, `Theme.RefreshFromDB`, `Perf.RefreshFromProfile`, `Commands.Register`, `Options.RegisterPanel`, `App.RegisterFeatureModules`) собраны в одном месте (`core/App.lua:264-318`).
- core ingress сужен до app-level lifecycle/diagnostic/combat событий: `ADDON_LOADED`, `PLAYER_LOGIN`, `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, `MACRO_ACTION_FORBIDDEN`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` (`core/Events.lua:12-40`).
- введен lifecycle helper с единым `Enable`/`Disable`/`RegisterModule`/`EnableAll` слоем (`core/Lifecycle.lua:83-178`).

### 2. Settings / profile / apply
- multi-key apply теперь ведется как единый transactional batch с `Commit`/`Rollback` и best-effort restore runtime state (`core/Apply.lua:27-35`, `195-268`; `core/Settings.lua:224-264`).
- apply-graph больше не знает про `cooldownViewer`; active keys: `runtime`, `theme`, `unitframes`, `center`, `actionbars`, `companion`, `minimap` (`core/App.lua:174-214`, `core/Apply.lua:112-126`).
- panel-side metadata для `Settings` больше не размазана по `OptionsPanel*.lua`: `core/FeatureRegistry.lua` теперь держит единый contract не только для panel key / apply / reset / refresh-context, но и для app/runtime feature ownership, а `OptionsShared`, panel builders и `App` читают его как source of truth.
- `Settings:SetTx(...)` больше не требует fake apply-key только ради panel undo; panel-level undo/reset теперь могут жить отдельно от apply queue, а `Settings:ResetSections(...)` позволяет reset-ить multi-section pages одним contract call.
- shared descriptor layer в `core/OptionsFieldBuilders.lua` теперь покрывает не только `check` / `slider` / `dropdown`, но и `radioGroup` / `color swatch`, так что page files могут держать binding contract в descriptor data вместо локального binding mini-framework.
- shared descriptor helper layer теперь также держит общие `ReadBoolWithFallback` / `ReadNumberWithFallback` / `ReadIntWithFallback` / `IntTransform` primitives, так что descriptorized pages больше не переобъявляют один и тот же read/transform glue локально.
- shared `Settings` scaffold теперь держит и layout-side contract для простых страниц: `core/OptionsFieldBuilders.lua` получил `BuildLayout(...)` + anchor-ref resolver, а `OptionsPanelGeneral.lua`, `OptionsPanelCompanion.lua` и `OptionsPanelEditMode.lua` больше не собирают линейные widget chains через page-local `CreateHeader/CreateCheck/CreateSlider/...` glue.
- `core/OptionsPanelCenterBars.lua` переведен на `CreateBindingState` + `AddDescriptorBindings`; `CenterBars` page больше не держит собственные `refreshing` / `AddBinding` / `BindIntSlider` / ad-hoc `BindRadioGroup` / `BindColorSwatch` обходы поверх shared `Options` layer.
- `core/OptionsPanelActionBars.lua` и `core/OptionsPanelUnitFrames.lua` тоже переведены на `CreateBindingState` + `AddDescriptorBindings`, так что в active tree больше не осталось settings pages со старым panel-local `bindings` stack и ручным `BindCheck` / `BindSlider` / `BindRadioGroup` / `BindColorSwatch` glue.
- active DB/schema больше не игнорирует `ExperienceBar`: минимальные defaults для `profile.experience` и `positions.xpbar` теперь живут в активном `core/DB.lua`, без переключения на незавершенный `DBCore` branch.
- section normalizers вычищают legacy-поля `actionbars._bar45Imported`, `keepMicroBags`, `compactBags`, `layering.petBar*` (`core/Settings.lua:321-339`).
- `unitframes.showPet` оформлен как официальный schema/defaults/normalize flag (`core/DB.lua:333`; `core/Settings.lua:468-471`).
- текущая schema политика теперь вынесена в отдельный `core/Schema.lua`: `CURRENT_SCHEMA_VERSION = 1`, resolution-preset seed, positions validation и legacy purge больше не размазаны по `core/DB.lua`, а `DB:Init()` только orchestrates reset/merge/normalize path.
- `DB:Init()` явно purges removed scope: `profile.cooldownViewer`, `positions.cooldownviewer`, `positions.actionbar6/7`, `actionbars.bars[6/7]`, `_bar45Imported`, `keepMicroBags`, `compactBags`, `layering.petBar*`, `options.livePreview.cooldownViewer` (`core/DB.lua:50-88`).
- `QA` теперь явно ловит возвращение removed scope и legacy schema мусора (`core/QA.lua:141-190`).
- `DB:GetProfile()` больше не раскидан по runtime feature-модулям; в active tree осталась только сама дефиниция в `core/DB.lua:619`, а runtime читает section-level данные.

### 3. Scope cut: CDM / weak bars / extra bars
- весь active runtime больше не строится вокруг `Cooldown Viewer`; `.toc`, `App`, `Apply`, `QA`, `Options` и feature-tree живут без него (`FeelsGoodUI.toc:40-46`; `core/App.lua:57-72`, `174-214`; `core/QA.lua:248-267`).
- live settings path больше не содержит `Cooldown Viewer` page/control/text; active canvas-панели — `General`, `Edit Mode`, `UnitFrames`, `CenterBars`, `ActionBars`, `Companion` (`core/Options.lua:959-962`, `2256-2314`).
- weak/extra bars и `actionbar6/7` выведены из active schema/runtime/QA (`core/DB.lua:57-87`; `core/QA.lua:156-185`).
- legacy CDM/weak-bars остатки оставлены только как purge/QA guard, а не как active feature-scope.

### 4. Slash / options / utility contract
- slash surface формализован по группам `user`, `transitional`, `diagnostic` (`core/Commands.lua:58-220`, `268-276`).
- primary register/open flow опирается на modern `Settings` path: `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterCanvasLayoutSubcategory`, `Settings.OpenToCategory` (`core/Options.lua:921-930`, `2256-2314`).
- старый `InterfaceOptions` fallback убран из active register/open flow; в текущем `core/Options.lua` нет live path через `InterfaceOptions_AddCategory` / `InterfaceOptionsFrame_OpenToCategory`.
- `General`, `Edit Mode`, `UnitFrames`, `CenterBars`, `ActionBars` и `Companion` больше не собирают panel refresh context вручную каждый по-своему: shared panel contract layer отдает им section aliases и reset/apply metadata, так что page files держат меньше ownership-логики.
- `MinimapIcon`, `Perf`, `QA` больше не завязаны на giant bootstrap file; они входят в общий core/app contract (`core/App.lua:264-318`, `core/QA.lua:248-267`, `core/MinimapIcon.lua:60-156`).
- `MinimapIcon` больше не смешивает transport и user actions в одном файле: `core/MinimapIconActions.lua` держит click/tooltip/error-report behavior, а `core/MinimapIcon.lua` остался owner-модулем для `LDB`/`LibDBIcon` transport и persisted config.

### 5. Feature-level подтвержденные cleanup changes
- `ActionBars` уже сузил observer surface от legacy global `ActionButton_*` путей к mixin / spell-alert / callback surfaces:
  - fallback на `ActionBarActionButtonMixin:UpdateAction` только если нет `EventRegistry` callback (`modules/ActionBarsState.lua:329-333`);
  - grid sync через `BaseActionButtonMixin:SetShowGrid` (`modules/ActionBarsState.lua:336-342`);
  - proc glow через `ActionButtonSpellAlertManager:ShowAlert/HideAlert` (`modules/ActionBarsState.lua:352-370`);
  - callback lifetime через `EventUtil.CreateCallbackHandleContainer()` + `EventRegistry` callback `ActionButton.OnActionChanged` (`modules/ActionBars.lua:491-506`).
- `ActionBars` shell delegation вынесен из owner-coordinator в отдельный `modules/ActionBarsBlizzardShell.lua`; sidebar toggle sync, Blizzard art-hide pass и endcaps re-hide больше не размазаны по основному runtime-файлу (`modules/ActionBarsBlizzardShell.lua:53-199`, `modules/ActionBars.lua:388-416`, `modules/ActionBars.lua:467-526`).
- `ActionBars` shell suppression снова стал обратимым после helper split regression: `modules/ActionBarsBlizzardShell.lua` теперь снапшотит parent/alpha/mouse/shown state для Blizzard shell frames, умеет `RestoreBlizzardArt(...)`, синхронно выталкивает `MultiBarRight` / `MultiBarLeft` из right-container через symmetric `SetActionBarToggles`, дергает `UIParent_ManageFramePositions` после hide/restore и чинит shell после `SettingsPanel` close/back transitions; `modules/ActionBarsRuntime.lua` маршрутизирует hide/restore как явный runtime contract и больше не оставляет Blizzard shell stuck-hidden до `/reload`.
- `ActionBars` state/autohide runtime вынесен в `modules/ActionBarsState.lua`; button state textures, empty-slot refresh, hover/autohide hooks и related state observers больше не сидят в основном coordinator file (`modules/ActionBarsState.lua:23-389`, `modules/ActionBars.lua:271-313`).
- `ActionBars` visual sync вынесен в `modules/ActionBarsVisuals.lua`; button skin, typography, cooldown text и hotkey visibility больше не лежат в coordinator file (`modules/ActionBarsVisuals.lua:13-199`, `modules/ActionBars.lua:297-328`, `modules/ActionBars.lua:398`).
- `ActionBars` edit-mode registration и lifecycle/apply coordinator вынесены в `modules/ActionBarsEditMode.lua` и `modules/ActionBarsRuntime.lua`; `modules/ActionBars.lua` сужен до owner facade с holder graph и state/runtime delegation, а `QA` снова видит canonical `_inited` state (`modules/ActionBarsEditMode.lua:1-85`, `modules/ActionBarsRuntime.lua:1-462`, `modules/ActionBars.lua:1-135`).
- `Companion` стал каноническим owner-модулем для pet/micro/bags:
  - secure pet holder и `RegisterStateDriver` живут в `modules/CompanionPetBar.lua:44-60`;
  - micro menu использует `OverrideMicroMenuPosition(...)`, если surface доступен (`modules/CompanionMicroBags.lua:696-703`, `757-770`);
  - expand callback живет через callback handle container в `modules/CompanionRuntime.lua`, а refresh-handler — в `modules/CompanionMicroBags.lua:875-882`.
- `Companion` micro-menu takeover больше не считает failed/transient Blizzard layout за успешный apply: `modules/CompanionMicroBags.lua` теперь проверяет стабильную geometry перед `OverrideMicroMenuPosition(...)`, не маскирует `pcall` failure как success и вместо этого ставит один debounced retry до тех пор, пока Blizzard не вернет реальные centers кнопок.
- `Companion` owner runtime разрезан на внутренние слои `CompanionShared`, `CompanionPetBar`, `CompanionMicroBags`, `CompanionRuntime`; `modules/Companion.lua` сужен до thin owner facade.
- `ExperienceBar` больше не лежит orphaned на диске: модуль снова загружается через активный `.toc`, зарегистрирован в `App` как feature/apply consumer и использует active DB/movers contract вместо незагруженного `DBCore` слоя.
- `ExperienceBar` больше не живет на fallback-only contract: active `Settings.Normalize(\"experience\")`, mover spec для `xpbar` и feature-owned suppression Blizzard `StatusTrackingBarManager`/status-tracking containers теперь идут через сам runtime модуля.
- `ProfileTransfer` больше не лежит unreachable helper-ом: файл загружается через активный `.toc`, а slash surface получил явные `/fgui export` и `/fgui import` entrypoints через `core/Commands.lua`.
- dead-branch, который дублировал active `DB` и `Companion` архитектуру, убран из live tree: `core/DBCore.lua`, `core/DBMigrations.lua`, `core/DeferQueue.lua`, legacy `modules/MicroBags.lua` и legacy `modules/PetBar.lua` удалены как unreachable/double implementations. Архивные markdown snapshots оставлены нетронутыми как история.
- remaining proven no-caller utility orphans тоже убраны из live tree: `core/EventManager.lua` и `modules/FeelsGoodFX.lua` удалены, а `docs/ARCH_PATTERN_LEDGER.md` переписан под фактический active tree вместо устаревших `CooldownViewer`/`CustomBars`/scheduler references.
- `UnitFrames` уже реально oUF-based: стиль регистрируется через `oUF:RegisterStyle`, а live frame-set включает `player`, `target`, `focus`, `targettarget`, `pet` (`modules/UnitFrames.lua:1573-1604`).
- optional unit visibility formalized через `RegisterUnitWatch` и DB flags `showFocus` / `showTargetTarget` / `showPet` (`modules/UnitFrames.lua:1777-1839`).
- secret-safe text path подтвержден в live `UnitFrames`; raw text/value вывод больше не строится на слепом предположении про plain numbers (`modules/UnitFrames.lua:240-306`, `739-813`).
- `UnitFrames` больше не держит secret-safe text formatting и target header/aura plumbing в одном owner-файле: `modules/UnitFramesText.lua` ведет secret-safe text policy, а `modules/UnitFramesTarget.lua` владеет target header/info typography, target aura mode и target health-color sync; `modules/UnitFrames.lua` теперь только делегирует эти внутренние слои.
- `UnitFrames` owner/runtime lifecycle больше не живет в одном giant module: `modules/UnitFramesRuntime.lua` ведет `Attach` / `Detach` / `Init` / `ApplyConfig` и target-related event glue, а `modules/UnitFrames.lua` остался тонким owner facade над runtime/text/target helper layers.
- `UnitFrames` owner-level cache/profile helpers и mover descriptor policy больше не живут в `modules/UnitFrames.lua`: `modules/UnitFramesPolicy.lua` теперь владеет hot-path cache, section/token helpers и size/scale mover specs, а owner-файл оставлен как thin facade над policy/runtime/render/target слоями.
- `UnitFramesRuntime` больше не раскладывает target-related events в несколько широких owner proxy calls: `modules/UnitFramesTarget.lua` теперь держит один target-side refresh coordinator для `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` / `UNIT_FACTION` / `UNIT_TARGET` / target info updates, а runtime дергает его как unit-scoped source of truth вместо дублирующего fan-out.
- `UnitFrames` больше не держит отдельный owner-level `_eventFrame` ради target/focus bookkeeping: `modules/UnitFramesTarget.lua` теперь сам вешает frame-local observers и header-anchor hooks на `target` / `focus` / `targettarget`, target-info refresh стал frame-bound вместо жестко owner-bound `"target"` path, а `modules/UnitFrames.lua`/`modules/UnitFramesRuntime.lua` потеряли dead target proxy/fallback glue от старого runtime bridge.
- combat-deferred `UnitFrames` state больше не принадлежит `App`: `modules/UnitFrames.lua` теперь держит feature-owned `FlushDeferredUpdates()` entrypoint для `_configDirty` / `_auraModeDirty`, а `core/App.lua` больше не читает внутренние dirty flags напрямую.
- `CenterBars` использует secret-safe text helper и event-driven updates вместо always-on `OnUpdate` (`modules/CenterBars.lua:105-108`, `686-689`, `1032-1133`).
- `CenterBars` больше не смешивает lifecycle/apply/event-frame coordinator с resource/render helper-слоем: `modules/CenterBarsRuntime.lua` теперь ведет `Attach` / `Detach` / `Init` / `ApplyConfig` и event dispatch, а `modules/CenterBars.lua` оставлен как owner facade над resource/layout/update logic.
- `CenterBars` threshold/render/update/resource-mode logic больше не живет в owner-файле: `modules/CenterBarsRender.lua` теперь ведет power/resource updates, spark/threshold state, Blizzard class-resource hide path и rune ticker lifecycle, а `modules/CenterBars.lua` оставлен как thin owner facade над config/resource policy и runtime wiring.
- `CenterBars` rune refresh больше не держится на постоянном `C_Timer.NewTicker(0.05)` через весь DK cooldown window: `modules/CenterBarsRender.lua` теперь использует cancellable one-shot `C_Timer.NewTimer(...)` reschedule path, который живет только пока руны реально перезаряжаются и frame/resource bar видимы.
- `CenterBars` suppression Blizzard class-resource frames больше не hard-kill path: `modules/CenterBarsRender.lua` теперь держит обратимый hide/restore contract с `HookScript("OnShow", ...)`, restore на config/resource-mode changes и cleanup на `Detach`, так что toggle `hideBlizzardClassResources` больше не расходится с runtime state до `/reload`.
- `CenterBarsRuntime` больше не гоняет hot event/apply path через owner proxy methods: runtime теперь дергает render entry points напрямую через свой configured context, а `modules/CenterBars.lua` остается thin public facade вместо обязательного middle-hop для `RefreshThresholdConfig` / `RefreshResourceMode` / `UpdatePower` / rune callbacks.
- `CenterBars` архитектурно закреплен как независимый owner-module: typography теперь живет в `center.text` с back-compat переносом из legacy `unitframes.text`, так что active runtime больше не читает `unitframes` section ради power-text styling.
- shared typography coupling дальше выжжен из active runtime: `ActionBars` visual style и `Companion` compact-bag text больше не читают `unitframes.text`, а legacy typography back-compat централизован в shared normalization/theme layer.
- Edit Mode reset ownership сузился до mover registry: `OptionsPanelEditMode` больше не держит статический список feature apply-keys для reset positions, а `Movers:ResetPositions()` сам fan-out-ит runtime refresh через registered spec contract.
- `Movers` position apply/read/writeback больше не размазан между registry, inspector и editor: spec-aware helpers в `core/MoversShared.lua` теперь владеют persisted point apply/save/edit contract, а inspector берет editable offsets из живой frame geometry вместо сырых anchor offsets.
- `Edit Mode` panel-level ownership больше не расходится между `movers` и `editor`: reset этого panel scope теперь сбрасывает обе секции, а `Movers:SyncFromProfile()` восстанавливает overlay/editor state после panel undo/reset без panel-side ручной синхронизации unlock/grid/inspector состояния.
- `Movers` lifecycle больше не теряет active drag/resize state между lock/reset/sync paths: owner-level `ClearActiveInteraction()` теперь гасит `OnUpdate`, `_dragging/_resizing`, highlight state, guides и inspector для всех overlays, а `ResetPositions()` / `SyncFromProfile()` / lock path используют его как единый teardown contract.
- keyboard listener в `core/MoversEditor.lua` больше не аллоцирует новый inert frame на каждый unlock cycle: listener frame создается один раз, потом только `EnableKeyboard(true/false)` + `Show/Hide` reuse, что возвращает `Edit Mode` к idempotent attach/detach contract.
- `ns.ApplyAll()` сохранен только как back-compat shim поверх `Apply:RequestAll()` (`core/Apply.lua:280-284`).

## Архив выполненных execution blocks из старого todo (2026-03-13)

Старый `todo.md` содержал не только backlog, но и детальный execution log. Ниже — архив закрытых хвостов, которые больше не должны оставаться в активном TODO.

### 2026-03-13 — config / section-access cleanup
Закрытые хвосты:
- `Phase 1 config-access tail`;
- `Phase 1 options fallback tail`;
- `actionbars section-read tail`;
- `qa section-read and companion contract tail`;
- `settings profile-root helper tail`;
- `companion normalized-config tail`;
- `actionbars normalized-bars tail`;
- `centerbars section-read tail`;
- `unitframes section-read tail`.

Смысл закрытия:
- runtime feature-модули ушли с разбросанных whole-profile reads;
- section-level DB helpers стали canonical runtime path;
- `Options` и `Movers` перестали держаться на raw `DB:GetProfile()` fallback там, где хватает section roots.

### 2026-03-13 — cross-feature seam cleanup
Закрытые хвосты:
- `cross-feature policy helper tail`;
- `movers petbar ownership tail`;
- `companion alias cleanup tail`.

Смысл закрытия:
- `Companion` больше не живет через исторические alias/path;
- `petbar` sizing/writeback больше не пишется в `actionbars`;
- shared policy между `ActionBars` и `Companion` больше не построена на прямом чтении чужой feature-section.

### 2026-03-13 — schema / legacy cleanup
Закрытые хвосты:
- `unitframes showPet schema tail`;
- `_bar45Imported runtime-only tail`;
- `db legacy profile purge tail`;
- `qa legacy schema audit tail`;
- `qa dock-captured audit tail`;
- `legacy CDM active-tree audit tail`.

Смысл закрытия:
- `showPet` вошел в нормальную schema/defaults/normalize цепочку;
- `_bar45Imported` убран из persisted schema и оставлен как runtime bookkeeping;
- removed-scope поля теперь активно purged/guarded, а не оставлены как пассивный исторический мусор.

### 2026-03-13 — QA / diagnostics cleanup
Закрытые хвосты:
- `QA holder contract tail`;
- `QA pet visibility tail`.

Смысл закрытия:
- QA-report теперь ориентируется на current runtime names (`FGUI_oUF_PetBarHolder`, `Companion` contract) и показывает текущее состояние pet visibility.

### 2026-03-13 — ActionBars observer narrowing
Закрытые хвосты:
- `actionbars observer narrowing tail`;
- `actionbars grid observer tail`;
- `actionbars glow observer tail`;
- `actionbars tracker hide isolation tail`;
- `extra actionbar contract cut`;
- `actionbars callback lifetime tail`.

Смысл закрытия:
- live ActionBars больше не держатся на legacy global `ActionButton_*` observers;
- observer surface сужен до mixin hooks / spell-alert manager / `EventRegistry` callback;
- extra bars (`actionbar6/7`) больше не входят в active contract.

### 2026-03-14 — ActionBars shell delegation
Закрытые хвосты:
- `actionbars blizzard shell delegation tail`;
- `actionbars endcaps hook surface tail`.

Смысл закрытия:
- sidebar toggle sync, Blizzard shell art-hide и delayed re-hide вынесены из `ActionBars.lua` в отдельный helper module;
- endcaps re-hide теперь сначала цепляется за подтвержденный current-build `MainActionBarMixin:UpdateEndCaps`, сохраняя legacy fallback на `MainMenuBarArtFrame_UpdateEndCaps`.

### 2026-03-14 — ActionBars state/autohide split
Закрытые хвосты:
- `actionbars state helper tail`;
- `actionbars autohide helper tail`;
- `actionbars unconfirmed paged-id fallback tail`.

Смысл закрытия:
- button state textures, empty-slot refresh и hover/autohide runtime вынесены из `ActionBars.lua` в отдельный helper module;
- coordinator file теперь держит только thin wrappers и callsites к `ActionBarsState`;
- empty-slot detection больше не зависит от неподтвержденного `ActionButton_GetPagedID`, а использует подтвержденный current-build path через `self.action` + `GetActionInfo`.

### 2026-03-14 — ActionBars visual sync split
Закрытые хвосты:
- `actionbars visual helper tail`;
- `actionbars button skin tail`;
- `actionbars typography/cooldown/hotkey tail`.

Смысл закрытия:
- skin, typography, cooldown text и hotkey visibility вынесены из `ActionBars.lua` в отдельный helper module;
- `ActionBars.lua` больше не держит button-facing visual plumbing напрямую и ближе к coordinator/lifecycle роли.

### 2026-03-14 — ActionBars coordinator/edit-mode split
Закрытые хвосты:
- `actionbars edit-mode registration tail`;
- `actionbars lifecycle/apply coordinator tail`;
- `actionbars qa init-state tail`.

Смысл закрытия:
- mover specs и registration для `actionbar1..5` живут в `modules/ActionBarsEditMode.lua`, а не в owner file;
- `_ApplyNow`, initial apply queue, combat retry, event attach/detach и `ActionButton.OnActionChanged` callback wiring живут в `modules/ActionBarsRuntime.lua`;
- `modules/ActionBars.lua` теперь работает как thin owner facade вместо hybrid coordinator file.

### 2026-03-14 — Companion runtime split
Закрытые хвосты:
- `companion lifecycle/apply coordinator tail`;
- `companion owner facade tail`.

Смысл закрытия:
- debounce/apply, combat retry, event attach/detach и `MainMenuBarManager.OnExpandChanged` callback wiring вынесены из `modules/Companion.lua` в `modules/CompanionRuntime.lua`;
- `modules/Companion.lua` теперь работает как thin owner facade вместо hybrid coordinator file.

### 2026-03-15 — UnitFrames text / target split
Закрытые хвосты:
- `unitframes secret-safe text helper tail`;
- `unitframes target header/helper tail`;
- `unitframes target aura mode tail`.

Смысл закрытия:
- secret-safe text/value formatting вынесен из `modules/UnitFrames.lua` в `modules/UnitFramesText.lua`;
- target header/info layout, typography/color sync и target aura mode live теперь живут в `modules/UnitFramesTarget.lua`;
- `modules/UnitFrames.lua` остался owner/runtime файлом, но без этого внутреннего target/text plumbing;
- статическая проверка синтаксиса для измененных `UnitFrames*.lua` повторно прогнана через `npx luaparse`.

### 2026-03-15 — MinimapIcon ownership split
Закрытые хвосты:
- `minimap icon action/tooltip tail`;
- `minimap icon diagnostics tail`.

Смысл закрытия:
- click routing, tooltip copy и recent-errors dump вынесены из `core/MinimapIcon.lua` в `core/MinimapIconActions.lua`;
- `core/MinimapIcon.lua` теперь держит только transport/data-object registration и persisted minimap config apply;
- статическая проверка синтаксиса для измененных minimap files повторно прогнана через `npx luaparse`.

### 2026-03-15 — UnitFrames runtime split
Закрытые хвосты:
- `unitframes owner runtime tail`;
- `unitframes event glue tail`;
- `unitframes config-apply tail`.

Смысл закрытия:
- `Attach`, `Detach`, `Init` и `ApplyConfig` вынесены из `modules/UnitFrames.lua` в `modules/UnitFramesRuntime.lua`;
- mover registration, oUF spawn и target-related event dispatch теперь живут в отдельном runtime helper вместо giant owner file;
- статическая проверка синтаксиса для измененных `UnitFrames*.lua` повторно прогнана через `npx luaparse`.

### 2026-03-15 — UnitFrames render split
Закрытые хвосты:
- `unitframes render helper tail`;
- `unitframes style/layout tail`;
- `unitframes combat/aura/castbar tail`.

Смысл закрытия:
- health text, low-HP glow, combat timer, aura styling/filtering, target power bar и castbar plumbing вынесены из `modules/UnitFrames.lua` в `modules/UnitFramesRender.lua`;
- `modules/UnitFrames.lua` теперь держит только profile-cache/defaults helpers, mover descriptors и thin wiring между `Render`, `Target` и `Runtime`;
- статическая проверка синтаксиса для измененных `UnitFrames*.lua` повторно прогнана через `npx luaparse`.

### 2026-03-16 — UnitFrames policy split
Закрытые хвосты:
- `unitframes owner cache/profile helper tail`;
- `unitframes mover descriptor policy tail`.

Смысл закрытия:
- hot-path cache refresh, section/token helpers и size/scale mover descriptor policy вынесены из `modules/UnitFrames.lua` в `modules/UnitFramesPolicy.lua`;
- `modules/UnitFrames.lua` теперь держит только thin public wrappers и wiring между `Policy`, `Render`, `Target` и `Runtime`;
- `modules/UnitFramesRender.lua` и `modules/UnitFramesRuntime.lua` продолжают получать тот же contract через `Configure(...)`, но source of truth для cache/policy больше не размазан по owner file;
- статическая проверка синтаксиса для измененных `UnitFrames*.lua` повторно прогнана через `npx luaparse`.

### 2026-03-16 — CenterBars render split
Закрытые хвосты:
- `centerbars threshold/render helper tail`;
- `centerbars resource-mode update tail`.

Смысл закрытия:
- threshold state, spark/render helpers, power/rune/point update logic, class-resource hide path и resource-mode orchestration вынесены из `modules/CenterBars.lua` в `modules/CenterBarsRender.lua`;
- `modules/CenterBars.lua` теперь держит только config/resource policy, mover/runtime wiring и thin public wrappers;
- `modules/CenterBarsRuntime.lua` продолжает получать тот же `CreatePowerBar` / `EnsureSegmentPool` contract, но source of truth для render/update logic больше не размазан по owner file;
- статическая проверка синтаксиса для измененных CenterBars-файлов повторно прогнана через `npx luaparse`.

### 2026-03-15 — CenterBars runtime split
Закрытые хвосты:
- `centerbars runtime coordinator tail`;
- `centerbars event-frame ownership tail`;
- `centerbars config-apply tail`.

Смысл закрытия:
- `Attach`, `Detach`, `Init`, `ApplyConfig` и event-frame dispatch вынесены из `modules/CenterBars.lua` в `modules/CenterBarsRuntime.lua`;
- `modules/CenterBars.lua` теперь держит resource mapping, layout/update/render helpers и thin public wrappers поверх runtime coordinator;
- статическая проверка синтаксиса для измененных CenterBars-файлов повторно прогнана через `npx luaparse`.

### 2026-03-15 — CenterBars architecture decision
Закрытые хвосты:
- `centerbars owner-boundary decision tail`;
- `centerbars hidden unitframes typography coupling tail`.

Смысл закрытия:
- `CenterBars` закреплен как независимый owner-module со своим `center` section/apply/mover/runtime contract, а не как часть `UnitFrames` / player-frame ecosystem;
- power-text typography теперь принадлежит `center.text`, а normalizer делает back-compat перенос из legacy `unitframes.text`, чтобы убрать cross-feature read без визуального отката существующих профилей;
- active `CenterBars` runtime больше не читает `unitframes` section, сохраняя только явные shared contracts через theme/style/format layers;
- статическая проверка синтаксиса для измененных CenterBars/theme/settings files повторно прогнана через `npx luaparse`.

### 2026-03-15 — Shared typography decoupling
Закрытые хвосты:
- `actionbars shared typography coupling tail`;
- `companion shared typography coupling tail`.

Смысл закрытия:
- `modules/ActionBarsRuntime.lua` и `modules/ActionBarsVisuals.lua` больше не тянут `unitframes` section ради outline/style config, а используют явный shared theme typography contract;
- `modules/CompanionMicroBags.lua` больше не читает `unitframes.text` для compact-bag count text;
- legacy shared typography back-compat централизован в `core/Settings.lua`, где `media.font` и `theme.fonts.outline` подхватывают старые `unitframes.text.*` значения только как migration path, а не как live cross-feature dependency;
- статическая проверка синтаксиса для измененных ActionBars/Companion/settings files повторно прогнана через `npx luaparse`.

### 2026-03-15 — Edit Mode reset ownership slice
Закрытые хвосты:
- `editmode reset apply-list tail`;
- `micromenu mover apply ownership tail`.

Смысл закрытия:
- `core/OptionsPanelEditMode.lua` больше не знает статический список feature keys для `Reset Positions`;
- `core/Movers.lua` теперь сам после reset fan-out-ит runtime apply по registered mover specs через `RequestApplyFor`, так что reset/apply orchestration принадлежит mover layer, а не panel code;
- `modules/CompanionMicroBags.lua` получил явный `applyKeys = "companion"` для `micromenu` mover spec, чтобы registry оставался полноценным source of truth;
- статическая проверка синтаксиса для измененных movers/options/companion files повторно прогнана через `npx luaparse`.

### 2026-03-15 — Movers position contract slice
Закрытые хвосты:
- `movers position/writeback contract tail`;
- `movers inspector center-offset tail`.

Смысл закрытия:
- persisted position apply/read/writeback вынесен в spec-aware helpers `GetStoredPoint`, `SetStoredPoint`, `ApplyStoredPoint`, `GetEditablePosition`, `SetEditablePosition` в `core/MoversShared.lua` вместо raw `positions` access, размазанного между `Movers.lua`, inspector и editor glue;
- inspector/edit-mode теперь берут editable coordinates из живой geometry frame, так что non-center defaults вроде `actionbar4/5` больше не показывают misleading raw anchor offsets;
- mover specs для `UnitFrames`, `CenterBars`, `ActionBars`, `CompanionPetBar` и `Micro Menu` теперь явно держат свой `positionKey` как часть descriptor contract;
- статическая проверка синтаксиса для измененных mover-related файлов повторно прогнана через `npx luaparse`.

### 2026-03-15 — legacy-name sweep
Закрытые хвосты:
- `cooldown viewer naming tail`;
- `weak/extra bars naming tail`.

Смысл закрытия:
- активное дерево `FeelsGoodUI` повторно просмотрено на `Cooldown Viewer`, `cooldownViewer`, `weak/extra bars`, `actionbar6/7`;
- после текущего аудита эти названия остались только в `history.md`, legacy purge (`core/DB.lua`) и QA guard (`core/QA.lua`), а не в live runtime/settings code.

### 2026-03-13 — Companion runtime tails
Закрытые хвосты:
- `companion micro override tail`;
- `companion observer narrowing tail`;
- `companion bags padding tail`;
- `companion watcher narrowing tail`;
- `companion eventregistry expand tail`.

Смысл закрытия:
- `Companion` использует текущие Blizzard surfaces для micro/bags настолько, насколько это уже сделано в коде;
- runtime apply/reapply вокруг companion больше не держится на старом CDM scope.

### 2026-03-13 — Options / apply / theme tails
Закрытые хвосты:
- `options shared apply routing tail`;
- `options modern settings open-path tail`;
- `options panel apply controller tail`;
- `applyall fallback cut tail`;
- `theme media-token bridge tail`;
- `theme owner-apply collapse tail`;
- `theme apply rollback tail`.

Смысл закрытия:
- apply routing стал явнее;
- modern settings open-path закреплен как active primary path;
- theme/media owner-model перестал fan-out-иться через scattered shared-field apply wiring.

### 2026-03-13 — runtime safety tails
Закрытые хвосты:
- `centerbars secret-safe formatting tail`;
- `unitframes secret-text tail`.

Смысл закрытия:
- text/value formatting в горячих runtime path переведен на secret-safe helpers и explicit plain-number gates.

### Recovery note — 2026-03-13
Старый recovery note архивирован как историческая заметка. Его смысл уже отражен в текущем коде через transactional apply, theme token snapshot/restore и explicit rollback path; как active TODO он больше не нужен.

## Архив process-only пунктов, которые не должны оставаться в active backlog
- `Phase -1 — Canonical baseline и freeze рабочего дерева` — после текущего аудита это уже не backlog, а пройденный/устаревший процессовый слой.
- `Phase 0 — Freeze, аудит и фиксация пользовательского контура` — роль этих пунктов заменена фактическим code audit 2026-03-14.
- Гигантские reference / replacement maps / decision logs из старого `todo.md` не являются активными задачами сами по себе. Всё, что реально еще не закончено, вынесено обратно в новый компактный `todo.md`.

## Что сознательно НЕ считается закрытым
Не перенесено в history как done:
- giant `core/Options.lua` rewrite;
- giant `core/Movers.lua` split;
- финальная schema/migration policy;
- полная owner cleanup для `ActionBars` / `Companion`;
- финальная архитектура `CenterBars`;
- окончательный decomposition `UnitFrames`;
- обязательные in-game QA / taint / perf checkpoints.

Это осталось в `todo.md`.
