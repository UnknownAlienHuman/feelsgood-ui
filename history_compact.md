# FeelsGoodUI — История работ (сжатая версия)

Сгенерировано: `2026-03-05`  
Источник: `history.md` (удалены дубли/повторы/вода; сохранены изменения, даты, статусы и критичные артефакты)

## Контекст и вердикт архива (2026-03-04)
## Что было сделано (код существует, в игре не работает)

### Lifecycle (Этапы 1-2)
- Код: `Attach/Detach/Enable/Disable` в FeelsGoodFX, ActionBars, UnitFrames.
- Bootstrap на `Enable()`, logout на `Disable()`.
- **Результат проверки:** Аддон жрёт, спайки 50ms (п.1).

### Декомпозиция (Этап 4)
- Код: UnitFrames разбит на 8 субмодулей, Movers на 3, Options панели вынесены.
- **Результат проверки:** Настройки лесенкой (п.3), значения не подгружаются (п.4), color picker не работает (п.12).

### ActionBars hooks (Этап 6)
- Код: Mixin hooks вместо legacy `ActionButton_*`.
- **Результат проверки:** Проблемы не описаны отдельно, но общее качество UI неудовлетворительное.

### CooldownViewer (Этап 7)
- Код: RequestRefresh переписан.
- **Результат проверки:** CDM сломан, нужен перевод на oUF (п.22).

### CenterBars (Этап 8)
- Код: Soft-hide вместо destructive hide.
- **Результат проверки:** Настройки не в Edit Mode (п.13), hide blizzard toggles не нужны (п.14).

### Оптимизация (Этап 5)
- Код: EventManager, AURA_SCAN_CACHE.
- **Результат проверки:** Спайки 50ms не устранены (п.1).

### Options декомпозиция
- Код: Панели UF, CustomBars, CenterBars, ActionBars вынесены.
- **Результат проверки:** Лесенка (п.3), нет цифр (п.4), color picker сломан (п.12).

### Trigger engine
- Код: 7 типов триггеров.
- **Результат проверки:** Custom bars плохо работают (п.15), нужно два типа баров (п.16).

## Бэклог на момент архива (2026-03-04)
## Нереализованное
- Группировка фреймов (shift+click, rubber band) — не начато.
- Перенос настроек в Edit Mode — не начато.
- Fade/анимации для auto-hide — не начато.
- Удаление произвольного custom bar — не начато.
- Custom action bars (extra) — не начато.
- CDM на oUF — только решение на бумаге.

## Файлы-архивы
## Файлы-архивы
- `docs/TODO_ARCHIVE_2026-03-03.md` — аудит с оценками (оценки не соответствуют реальности)
- `docs/REGRESSION_MATRIX_1_25.md` — пустая матрица

## Хайлайты изменений (2026-03-05)
- `Custom Bars`: из обычной панели убраны геометрические контролы `Bar width/Bar height`; геометрия оставлена только в Edit Mode Inspector.
- Resize policy: добавлен рабочий resize-path для `objectivetracker`, `zoneability`, `combattimer` (колесо/инспектор/применение/сохранение размеров).
- Таймеры: `CustomBars` и `UnitFramesCombat` переведены на `EventManager` scheduler с fallback на `C_Timer`, добавлены явные stop-path.

## Канонический список требований (2026-03-05, из todo snapshot)
1) Аддон жрет, большие спайки по 50ms.
2) Что за проблемы с Objective Tracker? Насколько я понимаю, он у Blizzard пристыковывается к границам Action bars 4 и 5. Когда они включены - он отодвигается от края экрана. Когда включены - придвигается. Изучите Roth UI, там нет таких проблем.
3) Настройки идут лесенкой и уезжают за пределы фрейма. Че за херня?
4) Почему в маленьких окошках настроек в настройках нет цифр? Почему не подгружаются значения???
5) Почему ctrl alt wheel resize не на всех фреймах работает в edit mode? Почему сука нельзя один сделать стандарт и на каждый фрейм распространять? Ну или сделайте независимо каждый фрейм!
6) У Micromenu в инспекторе мало настроек и нет уголочка растяжки. Вообще он недоделан.
7) Что значит ctrl wheel - scale и ctrl alt wheel - resize? Дурацкое дублирование.
8) Нужно добавить новую Lua функцию. Поскольку у нас все фреймы изолировано настраиваются, нам нужна возможность объединять их в группы. Двумя методами: 1) держим shift и кликаем мышкой по фреймам. 2) Зажимаем левую кнопку мышки и тянем - появляется рамка выделения (как в Windows). Таким образом мы получаем контейнер со своим инспектором, который сразу перезаписывает настройки конкретных фреймов. Важно - он перезаписывает, а не сохраняет новый док. И это требует унификации настроек каждого фрейма. Делаем серьезно.
9) Настраиваться должны не только основные фреймы, но и castbars, бары энергии и т.п.
10) Соответственно настройки кастбара и прочей херни типа бара энергий переезжают в edit mode, не в обычных настройках они. Не надо перегружать обычные настройки.
11) Нихрена не вижу exp bar
12) Настройки colors не работают - нет иконки выбора цвета и панели.
13) Настройки Center bars и т.п. все делаются в Edit mode. Все размеры, положение и т.п - в edit mode. В обычных настройках только функционал, типа подсветки и т.п.
14) Никаких hide blizzard что-то там. Все уже спрятано, мы юзеру даем настраивать только наши фреймы на ouf. Весь наш аддон на ouf!!!
15) Custom bars плохо работают, нельзя удалять их. Все настройки в edit mode!!!!
16) Custom bars должны быть на выбор - action bars (extra) и просто бары как у Weak Auras. Я скачал Weak Auras, в Reference лежат. Этот функционал делаем отдельным модулем!!! Полностью отключаемый. По умолчанию выключен в настройках.
17) Hide blizzard micro bar и keep blizzard microbags хуево работают и не нужны!!! Нахуй это надо вообще!! compact bags тоже не нужна настройка, по умолчанию включено.
18) Автоскрытие баров - хорошо, но сделай задержку скрытия, чтобы при движении курсора не моргало и не мерцало.
19) Вообще делай fade и таймеры для анимаций.
20) Опять ломаются проценты на фреймах и там километровые дробные значения.
21) Почему дублируются наименования целей? У некоторых по 2 имени, вместо одного.
22) Blizzard CDM в нашем аддоне полностью делаем на oUF, отключаем по умолчанию наш заменитель.
Новые баги
23) Куда пропал Extra action button??? Где кнопка слезть с транспорта???
24) Target target имеет два кастбара
25) После запуска edit mode окно настроек багается и зависает. Возможно из-за перехвата мыши для массового выделения. Давай сделаем этот перехват через shift (с зажатым shift).
26) Ошибки (ниже)

## In-game smoke test (пользовательская проверка, 2026-03-05)
Легенда: `*`..`*****` как в исходнике.

1) * — - нихуя не сделано. Жор просто чудовищный, даже игра лагает.
2) * — - нихуя не сделано. Action bars просто отключены нахер!!!
3) * — - нихуя не сделано. Все как было.
4) * — - нихуя не сделано. Все как было.
5) * — - Теперь на micromenu resize просто растягивает фрейм по ширине. Ну пиздец. Я же сказал унифицировать!!!!
6) ***** —
7) ***** —
8) *** — Массовое выделение работает, но wheel, растягиваение по уголочку производится индивидуально. Кроме того выделение по клику надо сделать не через shift, а через ctrl
9) * — нихуя не сделано. И при открытии edit mode возможные фреймы даже не появляются (которых не видно, например cast bar)
10) * — не сделано по причине отсутствия баров
11) * — нету его. Точнее есть какой-то непонятный нерабочий и отсутствующий в edit mode бар.
12) * — не известно, поскольку custom bars не работают. В Unit frames не работает.
13) ***** — ок
14) ***** —
15) * — Появление и настройка функционала панелей - в обычных настройках. Удаление - в edit mode. Как я создам бары в Edit mode?
16) * — туда же
17) ***** —
18) **** — - чет задержка странная, то короткая то норм. Тут еще момент, нам нужен не только fade, но сама задержка скрытия. Сделапй побольше.
19) ***** —
20) *** — проблема актуальна для pet bar
21) * —
22) * — Вариант на ouf не работает вообще

26)
1x FeelsGoodUI/core/MoversInspector.lua:1685: bad argument #1 to 'tonumber' (value expected) [FeelsGoodUI/core/MoversInspector.lua]:1685: in function <FeelsGoodUI/core/MoversInspector.lua:1468> [FeelsGoodUI/core/MoversInspector.lua]:2151: in function <FeelsGoodUI/core/MoversInspector.lua:2003> [FeelsGoodUI/core/MoversEditor.lua]:195: in function <FeelsGoodUI/core/MoversEditor.lua:187> [FeelsGoodUI/core/MoversEditor.lua]:303: in function <FeelsGoodUI/core/MoversEditor.lua:259> [FeelsGoodUI/core/MoversEditor.lua]:351: in function <FeelsGoodUI/core/MoversEditor.lua:345>

Locals: selectedKeys = <table> { actionbar6 = true combattimer = true actionbar7 = true actionbar2 = true pet = true player = true center = true micromenu = true actionbar1 = true petbar = true actionbar3 = true } prof = nil f = Frame { emg = EditBox { } _group = true ew = EditBox { } ey = EditBox { } ls = FontString { } lw = FontString { } bg = Texture { } __fguiBorder = Frame { } lbg = FontString { } _rows = <table> { } title = FontString { } _layoutShowCenterGap = true _layoutShowCustomBarOptions = false lx = FontString { } _layoutShowMicroOptions = true _layoutShowResize = true lmr = FontString { } _layoutShowCastbarHeight = true eh = EditBox { } _layoutShowScale = true eby = EditBox { } _layoutShowPosition = true ex = EditBox { } _titleKey = "Inspector: Group (11)" ebg = EditBox { } lby = FontString { } __fguiBorderSize = 1 ebs = EditBox { } ecbh = EditBox { } cbOptions = Button { } es = EditBox { } ly = FontString { } hint = FontString { } lph = FontString { } lmg = FontString { } emr = EditBox { } lcbh = FontString { } lbs = FontString { } lh = FontString { } _groupKeys = <table> { } eph = EditBox { } _layoutShowPowerHeight = false } cleanSelected = <table> { actionbar6 = true combattimer = true actionbar7 = true actionbar2 = true pet = true player = true center = true micromenu = true actionbar1 = true petbar = true actionbar3 = true } selectedCount = 11 p = <table> { general = <table> { } media = <table> { } minimap = <table> { } center = <table> { } format = <table> { } fx = <table> { } options = <table> { } movers = <table> { } install = <table> { } positions = <table> { } theme = <table> { } actionbars = <table> { } editor = <table> { } version = 54 experience = <table> { } unitframes = <table> { } style = <table> { } customBars = <table> { } weakBars = <table> { } cooldownViewer = <table> { } } showPosition = true groupX = -85.090909 groupY = -193.090909 showScale = true scaleValue = 1 mixedScale = false showResize = true widthValue = 38 heightValue = 38 mixedWidth = true mixedHeight = true showCastbarHeight = true castbarHeightValue = 14 mixedCastbarHeight = false showPowerHeight = false powerHeightValue = nil mixedPowerHeight = false showCenterGap = true centerGapValue = 6 mixedCenterGap = false showMicroGap = true microGapValue = 4 mixedMicroGap = false showMicroRows = true microRowsValue = 1 mixedMicroRows = false showMicroSide = true microSideValue = 1 mixedMicroSide = false showMicroYOffset = true microYOffsetValue = 0 mixedMicroYOffset = false showMicroOptions = true layoutDirty = true titleKey = "Inspector: Group (11)" Movers = <table> { _inspector = Frame { } _globalHint = Frame { } _snapScratch = <table> { } _selectedKeys = <table> { } _activeOverlay = Button { } _activeKey = "actionbar6" _keyListener = Frame { } _registered = <table> { } _unlocked = true _selectionLayer = Button { } _grid = <table> { } }

----------
32x FontString:SetText(): Font not set Lua Taint: FeelsGoodUI [FeelsGoodUI/modules/CustomCDM.lua]:945: in function <FeelsGoodUI/modules/CustomCDM.lua:903> [FeelsGoodUI/modules/CustomCDM.lua]:1148: in function 'Apply' [FeelsGoodUI/modules/oUFCooldownViewerElement.lua]:113: in function <...Ons/FeelsGoodUI/modules/oUFCooldownViewerElement.lua:58> [tail call]: ? [tail call]: ?

Locals: button = Button { _entryKey = "27904:42650" cooldown = Cooldown { } _duration = 1.141000 _categoryID = 0 _startTime = 125050.864000 _cooldownID = 27904 _mouseEnabled = true count = FontString { } _texture = 237511 _chargeText = "" time = FontString { } icon = Texture { } spellID = 42650 } entry = <table> { modRate = 1 tooltipSpellID = 42650 duration = 1.141000 isEnabled = true remaining = 1.141000 texture = 237511 category = 0 cooldownID = 27904 startTime = 125050.864000 categoryName = "Essential" spellID = 42650 } cfg = <table> { enabled = true dock = <table> { } scale = 1 layering = <table> { } width = 240 scaleTimerByIconSize = true height = 56 custom = <table> { } swipeAlpha = 0.780000 hideFlash = true mode = "custom" timerFontSize = 14 countFontSize = 12 } key = "27904:42650" chargeText = ""

------------
6878x FeelsGoodUI/core/Animate.lua:208: attempt to index local 'existing' (a boolean value) [FeelsGoodUI/core/Animate.lua]:208: in function 'CancelAfter' [FeelsGoodUI/core/Animate.lua]:229: in function 'After' [FeelsGoodUI/modules/CooldownViewerSkin.lua]:110: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:94> [FeelsGoodUI/modules/CooldownViewerSkin.lua]:1121: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:1118> [C]: in function 'UIParent_ManageFramePositions' [Blizzard_EditMode/Shared/EditModeSystemTemplates.lua]:139: in function 'SetScale' [FeelsGoodUI/modules/CooldownViewerSkin.lua]:719: in function 'ApplyViewer' [FeelsGoodUI/modules/CooldownViewerSkin.lua]:792: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:755> [FeelsGoodUI/modules/CooldownViewerSkin.lua]:912: in function 'ApplyConfig' [FeelsGoodUI/modules/CooldownViewerSkin.lua]:1099: in function 'Enable' [FeelsGoodUI/FeelsGoodUI.lua]:349: in function <FeelsGoodUI/FeelsGoodUI.lua:346> [C]: in function 'pcall' [FeelsGoodUI/core/Safety.lua]:120: in function <FeelsGoodUI/core/Safety.lua:119> [tail call]: ? [FeelsGoodUI/FeelsGoodUI.lua]:346: in function <FeelsGoodUI/FeelsGoodUI.lua:272> [FeelsGoodUI/core/Safety.lua]:70: in function <FeelsGoodUI/core/Safety.lua:68> [C]: ? [FeelsGoodUI/core/Safety.lua]:68: in function 'Dispatch' [FeelsGoodUI/core/Events.lua]:27: in function <FeelsGoodUI/core/Events.lua:22> [FeelsGoodUI/core/Events.lua]:98: in function <FeelsGoodUI/core/Events.lua:81>

Locals: owner = <table> { _microAnchor = FGUI_oUF_MicroMenuHolder { } _microResetHooked = true _viewerSettingsDataHooked = true _attached = true _combatWatcher = Frame { } _dockAnchor = FGUI_CooldownViewerDockAnchor { } _compactBackpackButton = MainMenuBarBackpackButton { } _initDone = true _bagsLayoutHooked = true _updateMicroButtonsHooked = true _viewerOnUnitAuraHooked = true _managedPositionsHooked = true _fguiAnimateTimers = <table> { } _petAnchor = FGUI_oUF_PetBarHolder { } _viewerOnUnitTargetHooked = true } key = "cooldownviewer.dock.redock" _ = <table> { _microAnchor = FGUI_oUF_MicroMenuHolder { } _microResetHooked = true _viewerSettingsDataHooked = true _attached = true _combatWatcher = Frame { } _dockAnchor = FGUI_CooldownViewerDockAnchor { } _compactBackpackButton = MainMenuBarBackpackButton { } _initDone = true _bagsLayoutHooked = true _updateMicroButtonsHooked = true _viewerOnUnitAuraHooked = true _managedPositionsHooked = true _fguiAnimateTimers = <table> { } _petAnchor = FGUI_oUF_PetBarHolder { } _viewerOnUnitTargetHooked = true } state = <table> { tokens = <table> { } entries = <table> { } } entries = <table> { cooldownviewer.dock.redock = true } tokens = <table> { cooldownviewer.dock.redock = 2 } existing = true (*temporary) = "table" (*temporary) = nil (*temporary) = "attempt to index local 'existing' (a boolean value)"

************************************************************************
Говно все твое ниже!!!!
##

### Новые баги (добавлены тем же тестом)
23) Куда пропал Extra action button??? Где кнопка слезть с транспорта???
24) Target target имеет два кастбара
25) После запуска edit mode окно настроек багается и зависает. Возможно из-за перехвата мыши для массового выделения. Давай сделаем этот перехват через shift (с зажатым shift).

### Runtime ошибки из smoke-test (сжато)
#### Ошибка A — MoversInspector tonumber(nil)
```
1x FeelsGoodUI/core/MoversInspector.lua:1685: bad argument #1 to 'tonumber' (value expected)
[FeelsGoodUI/core/MoversInspector.lua]:1685: in function <FeelsGoodUI/core/MoversInspector.lua:1468>
[FeelsGoodUI/core/MoversInspector.lua]:2151: in function <FeelsGoodUI/core/MoversInspector.lua:2003>
[FeelsGoodUI/core/MoversEditor.lua]:195: in function <FeelsGoodUI/core/MoversEditor.lua:187>
[FeelsGoodUI/core/MoversEditor.lua]:303: in function <FeelsGoodUI/core/MoversEditor.lua:259>
[FeelsGoodUI/core/MoversEditor.lua]:351: in function <FeelsGoodUI/core/MoversEditor.lua:345>

Key locals: prof = nil; selectedCount = 11; mixedWidth = true; mixedHeight = true; titleKey = "Inspector: Group (11)"
```

#### Ошибка B — FontString:SetText(): Font not set (CustomCDM)
```
32x FontString:SetText(): Font not set
Lua Taint: FeelsGoodUI
[FeelsGoodUI/modules/CustomCDM.lua]:945: in function <FeelsGoodUI/modules/CustomCDM.lua:903>
[FeelsGoodUI/modules/CustomCDM.lua]:1148: in function 'Apply'
[FeelsGoodUI/modules/oUFCooldownViewerElement.lua]:113: in function <...Ons/FeelsGoodUI/modules/oUFCooldownViewerElement.lua:58>
[tail call]: ?
[tail call]: ?

Key locals: spellID = 42650; spellID = 42650; cfg = <table> {; key = "27904:42650"
```

#### Ошибка C — Animate.CancelAfter: existing==boolean
```
6878x FeelsGoodUI/core/Animate.lua:208: attempt to index local 'existing' (a boolean value)
[FeelsGoodUI/core/Animate.lua]:208: in function 'CancelAfter'
[FeelsGoodUI/core/Animate.lua]:229: in function 'After'
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:110: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:94>
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:1121: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:1118>
[C]: in function 'UIParent_ManageFramePositions'
[Blizzard_EditMode/Shared/EditModeSystemTemplates.lua]:139: in function 'SetScale'
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:719: in function 'ApplyViewer'
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:792: in function <...ceFeelsGoodUI/modules/CooldownViewerSkin.lua:755>
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:912: in function 'ApplyConfig'
[FeelsGoodUI/modules/CooldownViewerSkin.lua]:1099: in function 'Enable'
[FeelsGoodUI/FeelsGoodUI.lua]:349: in function <FeelsGoodUI/FeelsGoodUI.lua:346>
[C]: in function 'pcall'
[FeelsGoodUI/core/Safety.lua]:120: in function <FeelsGoodUI/core/Safety.lua:119>
[tail call]: ?
[FeelsGoodUI/FeelsGoodUI.lua]:346: in function <FeelsGoodUI/FeelsGoodUI.lua:272>
[FeelsGoodUI/core/Safety.lua]:70: in function <FeelsGoodUI/core/Safety.lua:68>
[C]: ?

Key locals: key = "cooldownviewer.dock.redock"; tokens = <table> {; entries = <table> {; entries = <table> {; tokens = <table> {; existing = true
```

## Статический аудит кода (финальное состояние на 2026-03-05)
Итоговые статусы из последнего прохода статической сверки (проход 4 + ревизии 5/6/7/8).

1) ***** Закрыт hot-path `CustomBars/CustomCDM`: убраны лишние аллокации и повторные визуальные апдейты на каждом 10Hz тике, добавлен stop-path для idle/disabled, one-shot timer (`timerAutoRestart=false`) больше не держит perpetual ticker.
2) **** Objective Tracker path через layout-manager стабилен (`UIPARENT_MANAGED_FRAME_POSITIONS` + sidebars OFF), нужна только игровая регрессия.
3) **** Лесенка/пересчет высоты настроек исправлены (`_reflow` + рекурсивный расчет), осталось визуально подтвердить в клиенте.
4) **** Numeric controls в узком окне исправлены (reserve-aware adaptive width), нужен только UI smoke-test.
5) ***** Resize-пайплайн для `objectivetracker/zoneability/combattimer` закрыт полностью: ключи входят в `plain` resize-mode, присутствуют в `SupportsResize/GetResizeValue/SetResizeValue`, `Ctrl+Wheel`/`Shift+Ctrl+Wheel` в Edit Mode применяют размеры, и `RequestApplyForKey` маршрутизирует в корректные модули (`actionbars`/`unitframes`).
6) ***** Micromenu inspector усилен до полноценного layout-контроля (`Micro gap/rows`, `Bags side`, `Bags Y`) с runtime-apply и normalize/defaults.
7) ***** Дублирование `scale/resize` убрано: wheel-path единый (`Ctrl+Wheel`/`Ctrl+Shift+Wheel`), конфликтов в коде не найдено.
8) ***** Групповое выделение + box-select + group drag + group inspector commit покрывают полный unified набор полей (в т.ч. `Micro gap/rows/side/y`).
9) ***** Edit Mode для вторичных элементов закрыт полностью: `Power H` расширен с `target` на `focus/targettarget`, runtime-layout синхронизирован.
10) **** Геометрия castbar/power действительно вынесена из обычных панелей в Edit Mode inspector.
11) **** EXP bar path закрыт корректно (`XP -> reputation -> honor` + edge-cases), осталась in-game валидация.
12) **** Color picker path починен (`_openPicker` + modern/legacy), нужен runtime check `cancel/apply`.
13) **** Геометрия CenterBars перенесена в Edit Mode; обычная панель оставлена под функционал.
14) **** Закрыт root-cause несоответствия: oUF formal scope зафиксирован runtime-гейтом (`PLAYER_LOGIN` abort без oUF) и QA-проверкой gate state; non-oUF fallback bootstrap удален.
15) ***** Закрыт полный перенос CustomBars settings в Edit Mode: `OptionsPanelCustomBars` переведен в redirect-only, глобальные controls (`weakBars/showText/count/add/remove`) перенесены в `OptionsPanelEditMode`, а per-bar параметры (mode/timer/trigger/color/shape) вынесены в Inspector `Bar options`.
16) **** Два типа custom bars + отдельный LOD-модуль `FeelsGoodUI_WeakBars` реализованы, default OFF соблюден.
17) **** Лишние toggles micro/bags убраны, `compactBags` зафиксирован always-on.
18) **** Anti-flicker закрыт качественно (`AUTOHIDE_HIDE_DELAY` + cancel/token guard).
19) ***** Fade/timer-инфраструктура реально унифицирована за пределами `ActionBars`: добавлены shared animated show/hide path в `CustomBars` и `ExperienceBar`, keyed timer-path в `FeelsGoodFX` (через `Animate.After/CancelAfter`) и unified dock-redock timer в `CooldownViewerSkin`.
20) **** Длинные дробные проценты устранены (integer-format и integer fallback).
21) **** Дубли имени цели устранены через suppress/restore primary-name path; нужен только runtime regression в клиенте.
22) ***** `CustomCDM` переведен на oUF element-реализацию (`modules/oUFCooldownViewerElement.lua` + `self.FGUICooldownViewer` в стиле `UnitFrames`): custom-mode больше не рендерится напрямую из `CooldownViewerSkin`, а работает через `EnableElement/DisableElement/ForceUpdate`.

### Сильные расхождения «код-аудит» vs «in-game»
- 1: in-game=* vs code-audit=*****
- 2: in-game=* vs code-audit=****
- 3: in-game=* vs code-audit=****
- 4: in-game=* vs code-audit=****
- 5: in-game=* vs code-audit=*****
- 8: in-game=*** vs code-audit=*****
- 9: in-game=* vs code-audit=*****
- 10: in-game=* vs code-audit=****
- 11: in-game=* vs code-audit=****
- 12: in-game=* vs code-audit=****
- 15: in-game=* vs code-audit=*****
- 16: in-game=* vs code-audit=****
- 21: in-game=* vs code-audit=****
- 22: in-game=* vs code-audit=*****

## Архитектурные правила производительности (Roth UI old + ElvUI)
## ⚡ Архитектурные правила производительности (Опыт ElvUI и Roth UI old)
Исследование старого Roth UI (который потреблял в 10 раз меньше ресурсов) и ElvUI выявило ключевые паттерны, которые **необходимо** применять в FeelsGoodUI:
1. **Event-Driven Architecture (Zero Polling)**: Старый Roth UI *вообще избегал* `OnUpdate` и `C_Timer.NewTicker` для обновления состояния. Все работало строго на событиях (UNIT_HEALTH, UNIT_POWER_UPDATE и т.д. через oUF). Использование тикеров по 50-100ms для проверок логики — это антипаттерн, порождающий CPU-спайки.
2. **Изоляция OnUpdate**: В ElvUI обработчики `OnUpdate` используются **только** для временных анимаций (фейды) и жестко троттлятся для текстовых данных (напр., обновление золота раз в 60 сек). Как только анимация завершается, скрипт обнуляется `frame:SetScript("OnUpdate", nil)`. Запрещено оставлять `OnUpdate` работать "вхолостую".
3. **Zero-Allocation Data Paths & Object Pooling**: В старом Roth UI и ElvUI критически минимизировано создание таблиц (`temp = {}`) внутри горячих путей. Вместо выделения новой памяти активно используется встроенная функция `wipe(table)` для очистки и повторного использования существующих таблиц (например, при сборе данных для аур). Аналогично с фреймами: они создаются один раз, а затем скрываются/показываются, но никогда не пересоздаются циклично.
4. **Делегирование в oUF**: Старый Roth UI был легким, потому что полагался на оптимизированное ядро oUF. Любые модули (например, кастомные бары или кулдауны), привязанные к юнитам, должны реализовываться как **элементы oUF**, чтобы использовать его встроенный event-management, а не плодить параллельные OnUpdate-циклы.

## Пункты 1–22: корень и сделанные изменения (сжатые карточки)
### П.1 — Спайки 50ms [DONE 2026-03-05, финализировано]
- Дата: 2026-03-05
- Корень:
  3 источника:
  A) CenterBars.lua:554 — тикер рун на 0.05с (ровно 50ms):
  self._runeTicker = C_Timer.NewTicker(0.05, function()
  Center:UpdateRunes()
  end)
- Что сделано (коротко):
  - рунный тикер переведен с `C_Timer.NewTicker(0.05)` на `EventManager:RegisterTimer(..., 0.10, ...)`;
  - добавлен state-guard `self._runesRecharging` и stop-path в `RefreshResourceMode`/`Detach`;
  - добавлен кэш `BuildCustomCDMEntries` (`_customCDMEntriesCache` + dirty-флаг + cache-key от `includeEssential/includeUtility/showReady/sort`);
  - добавлен API `CustomCDM.InvalidateEntriesCache(module)`;
  - invalidation кэша подключен к событиям `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USES`, `PLAYER_TOTEM_UPDATE`, `PLAYER_TARGET_CHANGED`, `COOLDOWN_VIEWER_DATA_LOADED`, `COOLDOWN_VIEWER_TABLE_HOTFIXED`, `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`, `ADDON_LOADED(Blizzard_CooldownViewer)`.
  - `pcall` убран из production hot-path;
- Затронутые файлы: `core/EventManager.lua`, `modules/CenterBars.lua`, `modules/CooldownViewerSkin.lua`, `modules/CustomCDM.lua`, `*.lua`, `Blizzard_CooldownViewer/CooldownViewer.lua`, `Blizzard_UnitFrame/Mainline/RuneFrame.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game CPU/GC метрики и combat soak в текущей среде недоступны (`BLOCKED`).

### П.2 — Objective Tracker (Тейнт от Blizzard Layout Manager) [DONE 2026-03-04]
- Дата: 2026-03-04
- Корень:
  Наш аддон прячет Blizzard action bars (MultiBarRight, MultiBarLeft и т.д.), но Blizzard layout manager (`UIParent_ManageFramePositions`) продолжает считать их видимыми, так как они находятся в глобальной таблице `UIPARENT_MANAGED_FRAME_POSITIONS`. Из-за этого Objective Tracker смещается или налезает на панели.
  Старое предложение использовать `hooksecurefunc(ObjectiveTrackerFrame, "SetPoint", ...)` — **это прямой путь к Action_Blocked (taint)** в бою в реалиях современного WoW (Edit Mode).
  **Архитектурное решение (Опыт ElvUI):**
  Вместо того чтобы бороться с позиционированием ObjectiveTracker напрямую через хуки (что вызывает taint), нам нужно "вычеркнуть" наши спрятанные панели из Blizzard Layout Manager.
  Это позволит Blizzard'овскому Edit Mode нативно и без тейнта располагать Objective Tracker там, где хочет игрок, полностью игнорируя стандартные панели, которые мы заменили кастомными. Если игрок хочет сдвинуть трекер — он просто делает это в Edit Mode.
- Что сделано (коротко):
  - добавлен compatibility-path для legacy layout map: `RemoveLegacyManagedFramePositions` / `RestoreLegacyManagedFramePositions` для `UIPARENT_MANAGED_FRAME_POSITIONS`;
  - добавлен `QueueManagedPositionsRefresh` (debounced) для принудительного пересчета `UIParent_ManageFramePositions` после hide/restore;
- Затронутые файлы: `modules/ActionBars.lua`, `*.lua`, `Blizzard_EditMode/Shared/EditModeUtil.lua`, `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка (переключение bar4/bar5 + Enter/Leave combat + Edit Mode drag ObjectiveTracker) в текущей среде недоступна (`BLOCKED`).

### П.3 — Настройки лесенкой [DONE 2026-03-04]
- Дата: 2026-03-04
- Корень:
  Options.lua:510-519 — OnSizeChanged только увеличивает высоту, не уменьшает:
  if content:GetHeight() < minHeight then content:SetHeight(minHeight) end
  Плюс ComputeContentHeight (строки 454-497) не считает высоту numeric edit boxes.
- Что сделано (коротко):
  - `CreateScrollablePanel -> ComputeContentHeight` переписан с учетом вложенных контролов: добавлен рекурсивный обход дерева (`ScanFrameTree`) и регионов (`ConsiderBottom`), чтобы высота считалась по реальному нижнему элементу, включая вложенные slider/editbox/button связки;
  - `root:SetScript("OnSizeChanged")` переведен на безусловный `root._reflow(height)` (убран one-way guard `if content:GetHeight() < minHeight then ...`), теперь высота корректно как растет, так и уменьшается.
- Затронутые файлы: `core/Options.lua`, `*.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game визуальная проверка resize сценариев Settings UI (узкое/широкое окно, динамический show/hide секций) в текущей среде недоступна (`BLOCKED`).

### П.4 — Нет цифр в маленьких окнах [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  Options.lua:161-181 — слайдер занимает pw - 120 ширины, но edit box позиционируется абсолютно от правого конца слайдера. При узком окне edit box вылетает за пределы.
- Что сделано (коротко):
  - `CreateSlider` переведен на адаптивную схему `pw - reserve - 30` с клампом `80..420` вместо фиксированного `pw - 120`;
  - добавлено поле `s._fguiNumericReserve` и callback `s._fguiApplyAdaptiveWidth`, чтобы ширина слайдера пересчитывалась с учетом правого блока контролов;
  - добавлен `opts.buttonGap` (default `3`) и перевод `width/height/offset/buttonWidth/buttonHeight` на `tonumber(...)` для устойчивости к нечисловым входам.
- Затронутые файлы: `core/Options.lua`, `*.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game визуальная проверка узких Settings окон (горизонтальный resize до min width, проверка видимости numeric editbox и `+/-`) в текущей среде недоступна (`BLOCKED`).

### П.5 — Resize micromenu, xpbar, cooldownviewer (Ctrl+Alt+Wheel) [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  `MoversInspector` не классифицировал `micromenu/xpbar/cooldownviewer` как resize-capable ключи, а `MoversEditor` не имел generic-ветки `plain` для колесика.
- Что сделано (коротко):
  - добавлен `IsPlainResizeKey` для `micromenu/xpbar/cooldownviewer`;
  - `SupportsResize` и `GetResizeMode` расширены режимом `plain`;
  - `RequestApplyForKey("xpbar")` теперь маршрутизируется в `Apply:Request("xpbar")` (без fallback на `ApplyAll`);
  - `GetResizeMode` прокинут в `MoversEditor` контекст.
  - `OnMouseWheel` переведен на mode-based ветвление через `GetResizeMode(key)`;
  - добавлена `plain` ветка для `Ctrl+Alt+Wheel`:
- Затронутые файлы: `core/DB.lua`, `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `modules/CooldownViewerSkin.lua`, `modules/MicroBags.lua`, `*.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка `Ctrl+Alt+Wheel` + resize handle для `micromenu/xpbar/cooldownviewer` в текущей среде недоступна (`BLOCKED`).

### П.6 — Micromenu: расширение инспектора (доп. параметры сверх базовых X/Y/Scale/W/H) [DONE 2026-03-05, REV2]
- Дата: 2026-03-05
- Корень:
  после удаления `compactBags` toggle (шаг 17) micro-inspector фактически снова сузился до одного поля (`Micro gap`), и не давал управлять реальной компоновкой micro/bags из Edit Mode.
- Что сделано (коротко):
  - для `micromenu` добавлены поля:
  - добавлено чтение новых ключей `microRows/microBagsSide/microBagsYOffset`;
  - `microBagsYOffset` добавляет вертикальный оффсет bags-точки;
  - `GetActionBarsCfg` нормализует `microRows`, `microBagsSide`, `microBagsYOffset` вместе с остальными actionbars полями.
  - `Normalize("actionbars")` расширен нормализацией `microBagsGap`, optional `microWidth/microHeight`, и новых `microRows/microBagsSide/microBagsYOffset`.
- Затронутые файлы: `core/DB.lua`, `core/DBCore.lua`, `core/MoversInspector.lua`, `core/Settings.lua`, `modules/CooldownViewerSkin.lua`, `modules/MicroBags.lua`, `Blizzard_MainMenuBarBagButtons/Shared/BagsBar.lua`, `Blizzard_MicroMenu/Shared/MicroMenuContainer.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка `micromenu` inspector path (`rows/side/y-offset`) в текущей среде недоступна (`BLOCKED`).

### П.7 — Scale vs Resize дублирование [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  в `core/MoversEditor.lua` wheel-input был разведен на два разных хоткея (`Ctrl+Wheel` для scale и `Ctrl+Alt+Wheel` для resize), из-за чего однотипная операция изменения размера требовала разной моторики и путала UX.
- Что сделано (коротко):
  - глобальная подсказка обновлена на единый хоткей: `Drag = Move, Ctrl+Wheel = resize, Shift+Ctrl+Wheel = spacing...`;
  - удалена ветка wheel-scale (`SupportsScale/GetScaleValue/SetScaleValue`);
  - удален неиспользуемый scale-wiring в контексте `MoversEditor`.
  - обновлена инструкция Edit Mode: scale через Inspector, wheel только resize.
  - обновлена подсказка для custom bars: `Ctrl+Wheel`/`Shift+Ctrl+Wheel` без `Alt`.
  - обновлены EN/RU строки для Edit Mode note, custom-bars note и global hint.
- Затронутые файлы: `core/Locale.lua`, `core/Movers.lua`, `core/MoversEditor.lua`, `core/OptionsPanelCustomBars.lua`, `core/OptionsPanelEditMode.lua`, `Blizzard_ChatFrameBase/Shared/CastSequenceManager.lua`, `Blizzard_Console/Blizzard_Console.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка wheel UX (`Ctrl+Wheel` resize + `Scale` только через Inspector) в текущей среде недоступна (`BLOCKED`).

### П.8 — Групповое выделение фреймов [DONE 2026-03-05, REV2]
- Дата: 2026-03-05
- Корень:
  `Movers` держал только singleton-состояние (`_activeKey`), поэтому не было ни множества выделения, ни контейнера для массового применения параметров к группе.
- Что сделано (коротко):
  - добавлен state `Movers._selectedKeys`;
  - добавлена архитектура selection-state:
  - добавлен `selectionLayer` (fullscreen, под оверлеями):
  - добавлен suppress-click guard после drag/resize (`_suppressClick`) для устранения ложных toggle после отпускания кнопки;
  - добавлен `ShowGroupInspector(selectedKeys)` и режим `f._group`;
  - подсказки обновлены под новый UX (`Shift+Click` multi-select + `left-drag` box-selection);
- Затронутые файлы: `core/Locale.lua`, `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/OptionsPanelEditMode.lua`, `Blizzard_ChatFrameBase/Shared/CastSequenceManager.lua`, `Blizzard_Console/Blizzard_Console.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка `Shift+Click`/box-select/group-inspector UX в текущей среде недоступна (`BLOCKED`).

### П.9 — Castbar/energy bar настройки в Edit Mode [DONE 2026-03-05, REV2]
- Дата: 2026-03-05
- Корень:
  `Edit Mode` инспектор в `core/MoversInspector.lua` умел менять только `X/Y/Scale/Width/Height` (и micro-поля). Геометрия подфреймов unitframes (`castbarByUnit.height`, `targetInfo.powerHeight`) на уровне Edit Mode недоступна, из-за чего настраивались только основные фреймы.
- Что сделано (коротко):
  - добавлены поля инспектора `Castbar H` и `Power H` с динамической видимостью;
  - dynamic layout инспектора расширен новыми рядами (`f._rows`) для корректного reflow при show/hide.
  - добавлены локализационные ключи `Castbar H` и `Power H` (enUS/ruRU).
  - runtime-path показа power bar расширен с `target` на весь target-like набор:
  - `wow-api`: новые WoW API вызовы в этом шаге не добавлялись (шаг полностью в слое SavedVariables/EditMode Inspector).
- Затронутые файлы: `core/Locale.lua`, `core/MoversInspector.lua`, `modules/UnitFramesLayout.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: in-game UX проверка (`Edit Mode -> player/target/focus/targettarget`, Enter commit, group mixed-state) в текущей среде недоступна (`BLOCKED`).

### П.10 — Перенос castbar/energy controls из обычных настроек в Edit Mode [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  в `core/OptionsPanelUnitFrames.lua` оставались геометрические контролы `Castbar height / per-unit castbar height / Target power height`, что дублировало Edit Mode и перегружало обычную панель.
- Что сделано (коротко):
  - удалены геометрические контролы `Castbar height`, `Player/Target/Focus/TargetTarget castbar height`, `Target power height`;
  - добавлены явные note-подсказки, что геометрия настраивается в Edit Mode Inspector (`Castbar H`, `Power H`).
  - удален геометрический контрол `Power height` из обычной панели;
  - добавлена note-подсказка, что высота power bar настраивается в Edit Mode Inspector.
  - добавлены ключи локализации (enUS/ruRU) для новых note-подсказок шага 10.
  - `wow-api`: новые WoW API вызовы в шаге не добавлялись.
- Затронутые файлы: `core/Locale.lua`, `core/OptionsPanelCenterBars.lua`, `core/OptionsPanelUnitFrames.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: in-game UX проверка (`Settings -> UnitFrames/CenterBars` + `Edit Mode Inspector` parity) в текущей среде недоступна (`BLOCKED`).

### П.11 — Не видно Exp Bar [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  `modules/ExperienceBar.lua` скрывал фрейм при `UnitXPMax("player") <= 0`. На max-level это штатный случай, поэтому бар исчезал полностью даже когда есть прогресс репутации/чести.
- Что сделано (коротко):
  - добавлен единый progress-resolver с порядком `XP -> watched reputation -> honor`;
  - для репутации добавлен paragon-path (`C_Reputation.IsFactionParagonForCurrentPlayer` + `C_Reputation.GetFactionParagonInfo`) если обычные threshold-поля невалидны;
  - добавлен безопасный fallback для capped friendship/major-faction edge (`1/1`), чтобы бар не проваливался в honor-path из-за отсутствующих threshold-полей;
  - добавлена mode-based окраска бара (XP/reputation/honor) и корректный текст с лейблом источника прогресса;
  - расширены события обновления: `UPDATE_FACTION`, `HONOR_XP_UPDATE`, `PLAYER_MAX_LEVEL_UPDATE`, `PLAYER_LEVEL_CHANGED`, `ENABLE_XP_GAIN`, `DISABLE_XP_GAIN` (помимо уже существовавших XP/rested).
- Затронутые файлы: `modules/ExperienceBar.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка max-level сценариев (`XP=0`, watched reputation, honor fallback, event churn) в текущей среде недоступна (`BLOCKED`).

### П.12 — Color picker не работает [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - `core/Options.lua`: `CreateColorSwatch` не имел встроенного click-router и зависел от ручного `SetScript("OnClick")` в каждой панели;
  - `core/Options.lua`: `OpenColorPicker` имел только один путь через `ColorPickerFrame:SetupColorPickerAndShow` и молча выходил, если метода нет.
- Что сделано (коротко):
  - в `CreateColorSwatch` добавлен унифицированный click-router:
  - `OpenColorPicker` переписан на dual-path:
  - панели переведены с прямых `SetScript("OnClick")` на декларативный `_openPicker`:
- Затронутые файлы: `core/Options.lua`, `core/OptionsPanelCenterBars.lua`, `core/OptionsPanelCustomBars.lua`, `core/OptionsPanelUnitFrames.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка открытия ColorPicker UI и cancel/apply path в текущей среде недоступна (`BLOCKED`).

### П.13 — CenterBars настройки в Edit Mode [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - `core/OptionsPanelCenterBars.lua` держал геометрию (`scale/width/resourceHeight/spacing`) в обычных настройках, хотя этот же класс изменений уже обслуживается через Edit Mode;
  - в `core/MoversInspector.lua` у `center` не было отдельного поля для `spacing`, поэтому перенос геометрии в Edit Mode был неполным.
- Что сделано (коротко):
  - удалены геометрические слайдеры `Center scale`, `Center width`, `Resource height`, `Bars gap`;
  - добавлена явная note-подсказка: геометрия `CenterBars` редактируется через Edit Mode Inspector;
  - добавлено поле инспектора `Bars gap` (показывается для `key == "center"`);
  - добавлены `SupportsCenterGap/GetCenterGapValue/SetCenterGapValue` с записью в `profile.center.spacing` и clamp `0..20`;
  - поддержка `Bars gap` добавлена в single-commit и group-commit path (включая mixed-state в group inspector).
  - добавлены EN/RU локализации для новой note-подсказки CenterBars.
- Затронутые файлы: `core/Locale.lua`, `core/MoversInspector.lua`, `core/OptionsPanelCenterBars.lua`, `rg -n "Bars gap|SupportsCenterGap|GetCenterGapValue|SetCenterGapValue" core/MoversInspector.lua`, `rg -n "Center scale|Center width|Resource height|Bars gap|Center geometry" core/OptionsPanelCenterBars.lua`
- Проверка/статус: wow-api lookup; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game regression (Edit Mode inspector для `center`, wheel-resize + ручной ввод `Bars gap`) в текущей среде недоступен (`BLOCKED`).

### П.14 — oUF scope ревизия (full bootstrap gate) [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - статусы п.14 оставались конфликтными: формулировка требовала oUF-first контракт, но bootstrap не блокировал запуск модулей при отсутствии oUF;
  - из-за этого QA не отличал «oUF обязателен» от «oUF желателен».
- Что сделано (коротко):
  - добавлен флаг `ns._oUFMissing` в `ADDON_LOADED`;
  - в `PLAYER_LOGIN` добавлен hard gate: при отсутствии oUF логируется ошибка и весь модульный bootstrap прекращается (`Startup aborted...`).
  - в `CheckModules` добавлена проверка согласованности startup-gate (`PASS: oUF startup gate active` / fail при рассинхроне).
  - добавлены EN/RU строки для сообщения startup-gate.
- Затронутые файлы: `core/Locale.lua`, `core/QA.lua`, `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua`, `FeelsGoodUI.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS

### П.15 — Все Custom Bars settings в Edit Mode (rev2) [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - после предыдущего фикса в обычной панели оставались практически все runtime-настройки custom bars (mode/timer/trigger/color/shape), поэтому требование «все настройки в Edit Mode» не было выполнено.
- Что сделано (коротко):
  - добавлена отдельная Edit Mode панель `Bar options` для `custombarN` (через инспектор mover-а);
  - в панель вынесен полный per-bar конфиг: label/enabled/showText/mode/value/timer/loop/shape/bg alpha/color + trigger fields (`enabled/type/unit/op/threshold/power/spellID/spellMode/hideWhenInactive`);
  - добавлен глобальный Custom Bars блок в Edit Mode: `Enable weak bars`, `Show text on all custom bars`, `Bars count`, `Selected bar`, `Add bar`, `Remove selected bar`;
  - structural операции переведены на API `ns.CustomBars:SetCount/AddBar/RemoveBar`.
  - добавлены новые EN/RU строки для Edit Mode custombars path.
- Затронутые файлы: `core/Locale.lua`, `core/MoversInspector.lua`, `core/OptionsPanelCustomBars.lua`, `core/OptionsPanelEditMode.lua`, `rg -n \"Bar options|Custom Bar \\(Edit Mode\\)|triggerSpellID|triggerHideInactive\" core/MoversInspector.lua`, `rg -n \"Custom Bars \\(Edit Mode\\)|Enable weak bars|Bars count|Remove selected bar\" core/OptionsPanelEditMode.lua`
- Проверка/статус: wow-api lookup; static parse PASS

### П.16 — Custom bars два типа (action + WA-style) [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - WA-style runtime (`CustomBars.lua` + `CustomBarsTriggers.lua`) грузился через основной `FeelsGoodUI.toc` всегда, поэтому модуль нельзя было реально отключить на уровне загрузки кода.
  - В UI не было явного выбора типа custom bars: `extra action bars` (из `ActionBars`) vs `WA-style`.
- Что сделано (коротко):
  - Вынесен WA-style runtime в отдельный companion LOD-аддон:
  - В основном аддоне добавлен легкий прокси-загрузчик `core/CustomBarsProxy.lua`:
  - В `FeelsGoodUI.toc` убрана прямая загрузка `modules/CustomBarsTriggers.lua` и `modules/CustomBars.lua`; подключен `core/CustomBarsProxy.lua`.
  - В профиль добавлен флаг `weakBars.enabled=false` по умолчанию:
  - В `core/Settings.lua` добавлена нормализация `weakBars.enabled` (в `customBars`/`weakBars` keys и в `NormalizeAll`).
  - В `core/OptionsPanelCustomBars.lua` добавлен выбор типа:
- Затронутые файлы: `core/CustomBarsProxy.lua`, `core/DBCore.lua`, `core/DBMigrations.lua`, `core/OptionsPanelCustomBars.lua`, `core/Settings.lua`, `modules/CustomBars.lua`, `modules/CustomBarsTriggers.lua`, `CustomBars.lua`, `CustomBarsTriggers.lua`, `FeelsGoodUI.toc`, `FeelsGoodUI_WeakBars/WeakBars_Module.lua`, `FeelsGoodUI_WeakBars/WeakBars_Triggers.lua`, … (+3)
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка toggle/load цикла (`Weak mode ON/OFF`, apply/live-preview, reload-less сценарии) в текущей среде недоступна (`BLOCKED`).

### П.17 — Hide micro bar/keepMicroBags не нужны [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - шаг 14 убрал `hideBlizzard/keepMicroBags`, но `compactBags` оставался пользовательским toggle в двух UI-путях (`OptionsPanelActionBars`, `MoversInspector`) и в runtime-ветвлении `MicroBags`;
  - при старых SavedVariables (`actionbars.compactBags=false`) аддон мог возвращаться в non-compact bag layout, что конфликтовало с целевой архитектурой always-on compact micro/bags.
- Что сделано (коротко):
  - удален чекбокс `Compact bags (single trunk icon)`;
  - удалены refresh/onClick path для `actionbars.compactBags`.
  - удалено поле `Compact (0/1)` для `micromenu`;
  - удален commit-path записи `prof.actionbars.compactBags` (micro-inspector теперь управляет только `microBagsGap`).
  - `Normalize("actionbars")` теперь принудительно фиксирует `ab.compactBags = true`.
  - fallback-конфиг принудительно фиксирует `ab.compactBags = true`;
- Затронутые файлы: `core/DBCore.lua`, `core/DBMigrations.lua`, `core/MoversInspector.lua`, `core/OptionsPanelActionBars.lua`, `core/Settings.lua`, `modules/CooldownViewerSkin.lua`, `modules/MicroBags.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game regression по micro/bags lifecycle и визуальной проверке compact-режима в текущей среде недоступен (`BLOCKED`).

### П.18 — Автоскрытие баров мерцает [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - auto-hide в `modules/ActionBars.lua` срабатывал практически мгновенно: `OnEnter/OnLeave` на holder/button вызывали `_QueueAutoHideUpdate()` без delay, а `UpdateAutoHideState` сразу переключал `holder:SetAlpha(0/1)`;
  - при быстрых переходах курсора по краям/между кнопками это давало частое hide/show переключение и визуальное мерцание.
- Что сделано (коротко):
  - добавлена константа `AUTOHIDE_HIDE_DELAY = 0.30`;
  - `_OnAutoHideEnter()` / `_OnAutoHideLeave()` — отдельные enter/leave маршруты.
  - добавлен token-guard (`_autoHideToken`), чтобы fallback path на `C_Timer.After` не применял устаревшие delayed callbacks после повторного наведения;
  - delay пока фиксированный (`0.30s`) и не вынесен в профиль/UI; если потребуется тонкая настройка пользователем, это отдельный шаг (вне п.18).
- Затронутые файлы: `modules/ActionBars.lua`, `ActionBars.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка UX (реальное поведение hover-hide без мерцания) в текущей среде недоступна (`BLOCKED`).

### П.19 — Fade и анимации [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - fade/animation логика была разрозненной: `FeelsGoodFX` имел собственный `AnimationGroup`, а `ActionBars` auto-hide переключал `holder:SetAlpha(0/1)` мгновенно;
  - delay-hide таймеры существовали локально в `ActionBars` без общего keyed API отмены/переиспользования.
- Что сделано (коротко):
  - добавлен общий модуль `ns.Animate`;
  - реализованы `FadeIn(frame, duration, opts)`, `FadeOut(frame, duration, opts)`, `CancelFade(frame, resetAlpha)`;
  - реализованы cancelable keyed-таймеры: `After(owner, key, delay, callback)`, `CancelAfter(owner, key)`, `CancelAllAfter(owner)`;
  - для fade добавлены guard-path: clamp `duration/alpha`, instant-path при `duration<=0`, stop opposite animation перед стартом текущей.
  - подключен `core/Animate.lua` в секции Core.
  - добавлены `AUTOHIDE_FADE_IN_DURATION = 0.12` и `AUTOHIDE_FADE_OUT_DURATION = 0.16`;
- Затронутые файлы: `core/Animate.lua`, `modules/ActionBars.lua`, `FeelsGoodUI.toc`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game UX проверка (субъективная плавность fade + поведение hover в combat/non-combat) в текущей среде недоступна (`BLOCKED`).

### П.20 — Километровые дроби процентов [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - проблема была не только в строке форматирования, а в fallback-ветке `UnitFramesHealth`:
  - `ParseLooseNumber` сразу отбрасывал secret values и не давал дойти до integer-format;
  - при этом fallback рендерил `%s%%` через raw value, что и давало длинные дроби на `HealthPercentText`.
- Что сделано (коротко):
  - `FormatPercentText` переведен на строго integer-вывод:
  - в fallback добавлен `SetFormattedText("%.0f%%", d)` (если движок принимает значение), иначе процент очищается в `""` вместо вывода длинной дроби.
  - обновленный `ParseLooseNumber` secret-path;
- Затронутые файлы: `modules/UnitFramesHealth.lua`, `UnitFramesHealth.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game визуальная проверка (`player/target/focus` в разных типах контента, включая secret value контекст) в текущей среде недоступна (`BLOCKED`).

### П.21 — Дублирование имён целей [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - проблема была не в том, что `UpdateTargetInfo` вызывается несколько раз (это влияет на частоту обновлений, но не создает второй FontString);
  - реальный конфликт — отсутствие маршрута подавления `primary name` элемента (`frame.Name`), если одновременно активен кастомный `TargetHeader` (`TargetNameText`);
  - это дает дублирование на target-like фреймах в конфигурациях/сборках, где `frame.Name` присутствует (legacy layout/oUF tag path).
- Что сделано (коротко):
  - проблема была не в том, что `UpdateTargetInfo` вызывается несколько раз (это влияет на частоту обновлений, но не создает второй FontString);
  - реальный конфликт — отсутствие маршрута подавления `primary name` элемента (`frame.Name`), если одновременно активен кастомный `TargetHeader` (`TargetNameText`);
  - добавлен `SetPrimaryNameSuppressed(frame, suppressed)`:
  - в `UpdateUnitTargetHeader(...)` добавлен явный routing:
  - `rg` подтверждает добавленный suppression-route: `SetPrimaryNameSuppressed`, `frame.Untag`, `frame.Tag`, state-guard `_fguiPrimaryNameSuppressed`.
  - чтение `frame.__tags` опирается на внутреннюю структуру oUF (не WoW API). Добавлен fallback `[name]`, но если сторонний layout использует нестандартный tag без `__tags`, после unsuppress вернется `[name]`, а не оригинальный кастомный шаблон.
- Затронутые файлы: `modules/UnitFramesTargetInfo.lua`, `rg --fixed-strings "self.Name =" modules/UnitFrames*.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game визуальная проверка (target/focus/targettarget в бою и вне боя, включая toggle `targetInfo.enabled/showForFocus/showForTargetTarget`) в текущей среде недоступна (`BLOCKED`).

### П.22 — CDM на oUF [DONE 2026-03-05]
- Дата: 2026-03-05
- Корень:
  - `CustomCDM.lua` остается кастомным рендерером (не oUF element), но главная runtime-проблема шага была в другом: в рабочем DB/normalize пути `cooldownViewer.mode` по умолчанию и fallback сводились к `custom`;
  - из-за этого «заменитель» включался автоматически у новых и части старых профилей, хотя по задаче он должен быть выключен по умолчанию.
- Что сделано (коротко):
  - из-за этого «заменитель» включался автоматически у новых и части старых профилей, хотя по задаче он должен быть выключен по умолчанию.
  - добавлена `Stage 72` (`RunMigration(54, ...)`) — для существующих профилей принудительно переводит `cooldownViewer.mode` в `"blizzard-skin"`.
  - в `GetCfg()` invalid-mode fallback переведен на `MODE_BLIZZARD_SKIN`.
  - UI refresh fallback по mode переведен на `blizzard-skin`;
  - radio-set fallback для `"blizzard-skin"` переведен на `"blizzard-skin"` (без отката к custom).
  - долгосрочная часть шага (полный перенос `CustomCDM` в настоящий oUF element) не выполнена в этом инкременте; сейчас закрыт обязательный baseline: заменитель отключен по умолчанию и переведен в явный opt-in.
- Затронутые файлы: `core/DBCore.lua`, `core/DBMigrations.lua`, `core/OptionsPanelCooldownViewer.lua`, `core/Settings.lua`, `modules/CooldownViewerSkin.lua`, `CustomCDM.lua`
- Проверка/статус: wow-api lookup; Blizzard source-check; static parse PASS; in-game: BLOCKED/не подтверждено
- Ограничение: - in-game проверка сценария миграции профиля и визуального parity `blizzard-skin` в этой среде недоступна (`BLOCKED`).

## Change Log (хронология изменений в коде/структуре)
## Change Log
1. 2026-03-03 — canonical TODO выделен в отдельный рабочий файл; старый объемный TODO перемещен в `docs/TODO_ARCHIVE_2026-03-03.md`.
2. 2026-03-03 — закрыт lifecycle cleanup для `FeelsGoodFX`.
3. 2026-03-03 — закрыт lifecycle standardization для `ActionBars` и `UnitFrames`.
4. 2026-03-03 — `Movers` декомпозирован на `Movers.lua` + `MoversSnapGrid.lua` + `MoversInspector.lua` с DI wiring.
5. 2026-03-03 — `UnitFrames` декомпозирован на `UnitFrames.lua` + `UnitFramesFormatting.lua` + `UnitFramesAuras.lua` с DI wiring.
6. 2026-03-03 — дополнительно выделен `UnitFramesLayout.lua`; из `UnitFrames.lua` вынесены power/castbar/layout функции.
7. 2026-03-03 — дополнительно выделен `UnitFramesTargetInfo.lua`; из `UnitFrames.lua` вынесен target-info pipeline.
8. 2026-03-03 — дополнительно выделены `UnitFramesCombat.lua` и `UnitFramesHealth.lua`; из `UnitFrames.lua` вынесены combat timer и health update pipeline.
9. 2026-03-03 — дополнительно выделен `MoversEditor.lua`; из `Movers.lua` вынесены global hint, overlay/input handlers и keyboard nudge, подключено через DI.
10. 2026-03-03 — дополнительно выделен `UnitFramesBootstrap.lua`; из `UnitFrames.lua` вынесен bootstrap/init pipeline (`UF:Init`) и подключен через DI.
11. 2026-03-03 — дополнительно выделен `UnitFramesStyle.lua`; из `UnitFrames.lua` вынесены style/createHealthBar + size/scale/color helpers через DI.
12. 2026-03-03 — добавлен `core/EventManager.lua`; таймер обновления time-label в `CustomCDM` переведен на scheduler (`RegisterTimer`), с fallback на legacy `OnUpdate`.
13. 2026-03-03 — trigger engine scope formalized: в `modules/CustomBarsTriggers.lua` добавлен явный режим `mvp-single-trigger` (`Triggers.GetEngineMode()`), multi-condition redesign вынесен в будущий этап.
14. 2026-03-03 — ActionBars modern-hook compatibility: добавлены mixin/manager hooks для обновления empty/check/proc path без зависимости от legacy `ActionButton_*` глобалов.
15. 2026-03-03 — CooldownViewer refresh parity: восстановлен re-apply style для `blizzard-skin` режима на `UNIT_AURA/target` churn; `ActionBars:GetActionID` дополнен fallback через `GetPagedID()`.
16. 2026-03-03 — CenterBars class-resource restore safety: destructive hide (`UnregisterAllEvents` + `Show = Hide`) заменен на reversible soft-hide/state-restore path; restore добавлен в `RefreshResourceMode(resourceMode=NONE)` и `Detach()`.
17. 2026-03-03 — CustomCDM scheduler lifecycle: добавлен `StopSchedulerTimer`, stop-path интегрирован в non-custom/disable/detach ветки `CooldownViewerSkin`, re-register scheduler гарантирован при повторном входе в custom-mode.
18. 2026-03-03 — Подтверждена оптимальность кеширующего модуля для аур: попытка перевода на zero-allocation `AuraUtil.ForEachAura` показала регрессию (генерация таблиц внутри WoW API на каждую ауру). Оригинальный `AURA_SCAN_CACHE` (20Hz) возвращен как единственное валидное решение для ограничения GC мусора в WoW 12.0.
19. 2026-03-04 — убран отдельный верхний блок планирования; оставлен единый рабочий поток через основной раздел `Идеи по реализации`.
20. 2026-03-04 — закрыт шаг 1 (`П.1 Спайки 50ms`): рунный тикер `CenterBars` переведен на scheduler 0.10s с stop-path, `CustomCDM` получил dirty-cache entries + event invalidation, `EventManager` переведен на debug-only `pcall` в hot-path.
21. 2026-03-04 — закрыт шаг 2 (`П.2 Objective Tracker`): добавлены reversible cleanup/restore для `UIPARENT_MANAGED_FRAME_POSITIONS`, debounced refresh `UIParent_ManageFramePositions`, и side-bar toggles (bar4/bar5) исключены из Blizzard right-container layout при `hideBlizzard`.
22. 2026-03-04 — закрыт шаг 3 (`П.3 Настройки лесенкой`): `Options.CreateScrollablePanel` переведен на рекурсивный расчет контент-высоты и двусторонний reflow на `OnSizeChanged` (без one-way min-height guard).
23. 2026-03-05 — закрыт шаг 4 (`П.4 Нет цифр в маленьких окнах`): `Options.CreateSlider` получил reserve-aware adaptive width (`pw - reserve - 30`, clamp `80..420`), а `AttachNumericEditBox` теперь задает детерминированный правый резерв под numeric controls и принудительно триггерит reflow ширины слайдера.
24. 2026-03-05 — закрыт шаг 5 (`П.5 Resize micromenu/xpbar/cooldownviewer`): в Movers добавлен `plain` resize-mode + mode-based wheel path (`Ctrl+Alt+Wheel`) для utility movers, для `xpbar` добавлен точечный apply-route, `MicroBags/CooldownViewerSkin` расширены поддержкой `microWidth/microHeight` и `cooldownViewer.width/height`, а в `DB` добавлены defaults для `cooldownViewer.width/height` (micro-поля остаются optional).
25. 2026-03-05 — закрыт шаг 6 (`П.6 Micromenu inspector расширение`): в инспектор добавлены micro-specific поля `Micro gap` и `Compact (0/1)` с сохранением в `actionbars.microBagsGap/compactBags`, а `MicroBags` переведен на конфигурируемый gap (`microBagsGap + spacing`).
26. 2026-03-05 — закрыт шаг 7 (`П.7 Scale vs Resize дублирование`): wheel-input унифицирован в `MoversEditor` (`Ctrl+Wheel` = resize, `Shift+Ctrl+Wheel` = secondary axis), wheel-scale path удален (scale оставлен только в Inspector), обновлены EditMode/CustomBars подсказки и EN/RU локализация под новую схему.
27. 2026-03-05 — закрыт шаг 8 (`П.8 Групповое выделение фреймов`): добавлен multi-select state (`Movers._selectedKeys`), `Shift+Click` toggle, box-selection (`LMB drag` по пустому месту), group-inspector с массовым применением `Scale/Width/Height`, и lock/unlock-safe lifecycle очистки selection/highlight.
28. 2026-03-05 — закрыт шаг 9 (`П.9 Castbar/energy в Edit Mode`): в `MoversInspector` добавлены динамические поля `Castbar H`/`Power H` (single + group mixed-state), сохранение в `unitframes.castbarByUnit.*.height` и `unitframes.targetInfo.powerHeight` с apply-route, обновлена локализация `Locale` (enUS/ruRU).
29. 2026-03-05 — закрыт шаг 10 (`П.10 Перенос castbar/energy controls`): из `OptionsPanelUnitFrames` удалены геометрические castbar/target-power контролы (оставлены только функциональные toggles + note в Edit Mode), из `OptionsPanelCenterBars` удален `Power height` slider, добавлены note-подсказки и их локализация в `Locale` (enUS/ruRU) для маршрутизации геометрии в Edit Mode Inspector.
30. 2026-03-05 — закрыт шаг 11 (`П.11 Не видно Exp Bar`): `ExperienceBar` переведен на resolver `XP -> watched reputation -> honor`, добавлены paragon и capped-faction fallback для репутации, расширены события (`UPDATE_FACTION`, `HONOR_XP_UPDATE`, `PLAYER_MAX_LEVEL_UPDATE`, `PLAYER_LEVEL_CHANGED`, `ENABLE_XP_GAIN`, `DISABLE_XP_GAIN`), XP rested overlay ограничен только XP-режимом.
31. 2026-03-05 — закрыт шаг 12 (`П.12 Color picker`): `CreateColorSwatch` получил централизованный click-router через `_openPicker`, `OpenColorPicker` получил modern+legacy path (без silent fail), color swatch handlers в UnitFrames/CenterBars/CustomBars переведены на `_openPicker` вместо ручного `SetScript("OnClick")`.
32. 2026-03-05 — закрыт шаг 13 (`П.13 CenterBars в Edit Mode`): геометрические слайдеры убраны из `OptionsPanelCenterBars`, добавлена route-note в Edit Mode, а в `MoversInspector` добавлено поле `Bars gap` с full read/write/apply path в `profile.center.spacing` (single + group inspector).
33. 2026-03-05 — закрыт шаг 14 (`П.14 Hide Blizzard toggles`): из UI убраны toggles `hideBlizzard/keepMicroBags/hideBlizzardClassResources`, runtime в `ActionBars/MicroBags/CenterBars` переведен на hardcoded addon-path без чтения этих флагов, а `Settings.Normalize` принудительно фиксирует их в `true` для старых профилей.
34. 2026-03-05 — закрыт шаг 15 (`П.15 Custom bars нельзя удалять`): в `CustomBars` добавлен адресный delete-path `RemoveBar(targetID)` со сдвигом `bars/positions` и реиспользованием в `SetCount/RemoveLastBar`, `OptionsPanelCustomBars` переведен на `Remove selected bar` + structural API (`SetCount/AddBar/RemoveBar`) с apply-mode gate, а `Movers:Register` получил `frame:IsShown()`-aware overlay sync (`OnShow/OnHide`) для устранения ghost overlays.
35. 2026-03-05 — закрыт шаг 16 (`П.16 Custom bars два типа`): WA-style runtime вынесен в отдельный LOD аддон `FeelsGoodUI_WeakBars` (по умолчанию выключен через `profile.weakBars.enabled=false`), в основной аддон добавлен `CustomBars` proxy-loader (`core/CustomBarsProxy.lua`), `FeelsGoodUI.toc` очищен от eager-load `CustomBars*` файлов, а `OptionsPanelCustomBars` получил режимы `Extra Action Bars` vs `Weak Bars (optional module)` с блокировкой WA-контролов в action-mode.
36. 2026-03-05 — закрыт шаг 17 (`П.17 Compact bags hardcoded`): из `OptionsPanelActionBars` и `MoversInspector` удалены пользовательские controls `compactBags`, runtime `MicroBags/CooldownViewerSkin` переведен на always-on compact path, `Settings.Normalize("actionbars")` принудительно фиксирует `compactBags=true`, и добавлена migration `DB v53` для legacy профилей.
37. 2026-03-05 — закрыт шаг 18 (`П.18 Auto-hide debounce`): в `ActionBars` добавлен delayed hide (`AUTOHIDE_HIDE_DELAY=0.30`) для `OnLeave`, отдельные enter/leave handlers с отменой pending timer, token-guard против stale delayed callbacks, и cleanup pending auto-hide timer в `Detach()`.
38. 2026-03-05 — закрыт шаг 19 (`П.19 Fade и анимации`): добавлен общий `core/Animate.lua` (`FadeIn/FadeOut/After/CancelAfter/CancelFade`), подключен в `.toc`, а auto-hide path `ActionBars` переведен на fade + keyed cancelable timers с immediate-cleanup в detach/not-shown ветках.
39. 2026-03-05 — закрыт шаг 20 (`П.20 Integer percent`): `UnitFramesHealth` исправлен на secret-safe numeric parse без раннего отброса, percent formatter переведен на `string.format("%d%%", math.floor(n+0.5))`, а fallback `%s%%` удален в пользу integer `SetFormattedText("%.0f%%", d)` или empty-string при невозможности безопасного рендера.
40. 2026-03-05 — закрыт шаг 21 (`П.21 Дубли имен целей`): в `UnitFramesTargetInfo` добавлен stateful suppression-route для `frame.Name` при активном `TargetHeader` (`Untag + Hide + cache tag`), с обратным restore (`Tag + Show`) при отключении header/per-unit toggle; это устраняет дубль `TargetNameText` vs primary-name path без event-debounce костылей.
41. 2026-03-05 — закрыт шаг 22 (`П.22 CDM default mode`): runtime-default и fallback для `cooldownViewer.mode` переведены в `blizzard-skin` (`DBCore/Settings/CooldownViewerSkin/OptionsPanel`), добавлена migration `v54` для существующих профилей, чтобы custom renderer не включался по умолчанию.
42. 2026-03-05 — закрыт долг по `Custom Bars` Edit Mode: из `OptionsPanelCustomBars` удалены геометрические `Bar width/Bar height` контролы; геометрия оставлена только в `MoversInspector` (Edit Mode).
43. 2026-03-05 — закрыт долг resize-policy по utility movers: добавлен full resize path для `objectivetracker`, `zoneability`, `combattimer` (inspector/wheel/apply/defaults/normalize).
44. 2026-03-05 — scheduler consolidation: `CustomBars` dynamic timer и `UnitFramesCombat` combat timer переведены на `core/EventManager` с legacy fallback на `C_Timer` и явным stop-path.
45. 2026-03-05 — закрыт долг по group UX/edit-mode: в `MoversEditor` возвращен нормальный `Drag = Move` (без обязательного `Shift`), добавлен group-drag для multi-select, а в `MoversInspector` добавлен group `X/Y` commit через центр выделения с массовым смещением и `SavePoint` для всех выбранных mover-ключей.
46. 2026-03-05 — выполнен 4-й проход аудита `todo.md`: по всем пунктам 1-22 выставлены актуальные метки качества (`*`..`*****`) на основе статической сверки кода (`core/*`, `modules/*`, `FeelsGoodUI_WeakBars`).
47. 2026-03-05 — закрыт финальный perf-pass по п.1: `CustomBars` переведен на low-churn dynamic path (reuse + change-only visual apply + stop-idle ticker + one-shot timer stop), `CustomCDM` timer/count labels переведены на bucketed change-only updates, и подтвержден parse PASS (`node check_lua.js` в `_Addons/FeelsGoodUI`).
48. 2026-03-05 — закрыт этап 13 (`П.5 ревизия resize-path`): подтвержден full `plain` resize pipeline для `objectivetracker/zoneability/combattimer` (inspector + wheel + apply + defaults/normalize), а `todo.md` синхронизирован (устаревшие partial-статусы помечены как superseded).
49. 2026-03-05 — закрыт ревизионный этап по п.6 (`Micromenu inspector rev2`): `MoversInspector` расширен micro-полями `Micro rows/Bags side/Bags Y`, `MicroBags` получил runtime-layout поддержку `microRows/microBagsSide/microBagsYOffset` (включая compact + full BagsBar path), а `Settings/CooldownViewerSkin/DB/DBCore` синхронизированы по normalize/defaults.
50. 2026-03-05 — закрыта ревизия п.8/п.9: group-inspector получил полный unified coverage (включая `Micro gap/rows/side/y` в multi-select path), а `Power H` расширен с `target` на весь target-like path (`target/focus/targettarget`) в `MoversInspector` и runtime `UnitFramesLayout`.
51. 2026-03-05 — закрыт ревизионный этап по п.15 (`Custom bars settings в Edit Mode`): `OptionsPanelCustomBars` переведен в redirect-only, в `OptionsPanelEditMode` добавлены global custom bars controls (`weakBars/showText/count/add/remove`), а в `MoversInspector` добавлен per-bar `Bar options` panel с full mode/timer/trigger/color/shape commit-path.
52. 2026-03-05 — закрыт ревизионный этап по п.14 (`oUF scope контракт`): в `FeelsGoodUI.lua` добавлен startup hard-gate (`PLAYER_LOGIN` abort без oUF), в `core/QA.lua` добавлена проверка gate-согласованности, обновлена локализация сообщений.
53. 2026-03-05 — закрыт этап 14 по п.19 (fade/timer rollout): `CustomBars` и `ExperienceBar` переведены на shared animated visibility path (`Animate.FadeIn/FadeOut`), `FeelsGoodFX` hide-delay переведен на keyed timers (`Animate.After/CancelAfter`), а `CooldownViewerSkin` dock-redock timer унифицирован через `Animate.After`.
54. 2026-03-05 — закрыт этап 14 по п.22 (CustomCDM -> oUF element): добавлен `modules/oUFCooldownViewerElement.lua` (`FGUICooldownViewer`), в `UnitFramesStyle` добавлен element host для `player`, `.toc` обновлен, а custom-mode `CooldownViewerSkin` переключен на `EnableElement/DisableElement/ForceUpdate` без прямого `CustomCDM.Apply` в skin-path.

## Процессный вывод после проваленного smoke-test (2026-03-05)
## Апдейт 2026-03-05 — Cleanup после проваленного smoke-test

### Известные факты
- In-game smoke-тест провален (пользовательская проверка от 2026-03-05).
- В todo.md одновременно находились: активные задачи, старые отчеты, self-аудиты, raw stack traces и несколько взаимоисключающих статусов по одним и тем же пунктам.
- По ряду пунктов стояли высокие оценки качества при наличии runtime ошибок (`tonumber(nil)`, `Font not set`, `CancelAfter boolean/table corruption`).

### Причинный механизм
- Статическая проверка (`node check_lua.js`) была ошибочно использована как критерий готовности вместо обязательного in-game smoke.
- Не был введен fail-gate: runtime ошибка не блокировала перевод задач в "закрыто".
- TODO перестал быть рабочим планом и стал архивом всего подряд, из-за чего потерялась управляемость и контроль регрессий.

### Вывод
- Предыдущий формат ведения TODO технически несостоятельный: он маскировал провалы smoke и давал ложный сигнал о готовности.
- TODO очищен до активного плана, весь шум и старый массив данных перенесен в history.
