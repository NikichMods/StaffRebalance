# StaffRebalance — HUD Design 01

**Сопоставление с играми и UX-источниками:** [HUD Benchmark Research 01](HUD_BENCHMARK_RESEARCH_01.md) (2026-11-09). Его рекомендации уточняют исходные три кристалла: требуется обозначить **силу посоха**, учесть слабую стрельбу при нуле, отдельные event cues и контекстное обучение. Исходное предложение остаётся не утверждённым макетом.

**Статус:** первый UMG HUD реализован в dev и прошёл ограниченный игровой smoke-тест. Внешний вид и полная совместимость ещё не приняты. Рабочая ветка `dev/reserve-core-01`. См. результат HUD 01 ниже.

## Пользовательская цель и актуальная очередь

Сделать видимым отдельный магический резерв посоха: выполненный сильный выстрел тратит заряд, уникальный melee-контакт возвращает заряд, подтверждённый Conduit rest наполняет его; при нуле посох **остаётся рабочим, но слабым**. Значение должно показывать именно **игровой `session.reserve`**, а не диагностический `diag_total=0/50`, штатный AP/APR или AstralPool. В dev-моде capacity=3 — временное число, позже будет обсуждаться баланс. Код индикатора должен получать `current` и `capacity` от работающего механизма без отдельного сохранения/пользовательских настроек.

**Решение владельца о порядке (2026-11-09):** Ice и Thunder достаточно долго недоступны для live-тестирования. Их базовые staff и melee-пути **CI/mock PASS, runtime NOT TESTED (отложены до реальной доступности)**. Отсутствие этих игровых проверок **не блокирует отдельный HUD-проект и будущую балансировку**, но не снимает release/acceptance gate для неподтверждённых стихий. Сейчас активная работа — HUD.

## Предложенный UX для первого кандидата (не финальная приёмка)

- Маленький ряд одинаковых **сегментов/кристаллов** рядом с нижней левой боевой панелью, вблизи HP/AP. При текущей ёмкости 3: `◆ ◆ ◆` (полон), `◆ ◇ ◇` (один), `◇ ◇ ◇` (пуст). Сегментация — лишь визуальный способ показать резерв; её не путать с фиксированным количеством зарядов будущего баланса. Цвет нейтральный относительно Astral/Fire/Ice/Thunder.
- Расход происходит **при исполнении staff-действия**, а не при попадании; UI должен переходить 3→2 и т.д. сразу после подтверждённого дебета. Дубликаты / дополнительные снаряды/дочерние эффекты не должны создавать второе изменение.
- Пополнение только при уникальном подходящем `MELEE` и до лимита; при `DUPLICATE` или при полном запасе видимое значение не меняется. Подтверждённый `REST` = полный резерв; сам `REST_REQUEST`, меню Conduit и телепорт не наполняют индикатор.
- На 0 показать **пустой ресурс, но не состояние «выстрел запрещён»**; сильная/слабая магия в первом прототипе различается прежде всего наполнением/пустотой. Краткая подсветка при изменении и особая эмблема weak — возможное следующее UX-улучшение, не необходимость для самого первого теста.
- Не дублировать поверх AP, HP, быстрых предметов и подсказок. Сначала проверить 2560×1440 и контроллер/клавиатуру на реальном UI. Размеры, точный отступ и материалы **не утверждены**.

## Проверенная техническая база и рекомендуемая граница

1. **CombatHUD 0.4.1 принят и опубликован.** [Его статус](https://github.com/NikichMods/CombatHUD/blob/main/docs/STATUS.md), [работающий источник](https://github.com/NikichMods/CombatHUD/blob/main/Scripts/main.lua) и [R-005](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md#r-005--native-hud-menu-owner-и-границы-opacity-групп) устанавливают живой `HUDMainUMG_BP_C`, `LeftBottom_Panel` как `CanvasPanel`, отдельные 17 native targets CombatHUD и общий родительский HUD/menu visibility owner. **Не изменять ни принятый CombatHUD, ни его 17 целей, ни штатный общий `HUD_Panel`/parent opacity/visibility.** Точно прочитанные текущие значения native виджетов можно использовать только для собственного UI; не дублировать его combat/HP/input state machine.
2. **Доказанный UI-примитив:** [R-015](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md#r-015--projected-screen-components-vs-viewport-hud-root-2026-10-29) дал один runtime PASS для создания, показа и удаления *собственного* Canvas-поддерева в `HUDMainUMG.Main_Panel`, не изменяя оригинальную иерархию. Он **не доказывает** автоматическую совместимость с CombatHUD или добавление в `LeftBottom_Panel` без отдельного игрового теста.
3. **Предпочтительный минимальный путь для StaffRebalance:** добавить *только свои* маленькие widgets к проверенной `hud.LeftBottom_Panel` через native `CanvasPanel:AddChildToCanvas`. Это потенциально наследует native menu hiding от общего предка, а не создаёт всегда видимый отдельный fullscreen-viewport overlay. При создании удостовериться в одном живом in-viewport `HUDMainUMG_BP_C`, текущем gameplay pawn Hilda и точном классе/родителе Canvas. Не менять/перемещать уже существующих детей и не завязывать установку UI на наличие CombatHUD.
4. **Совместимость затемнения:** CombatHUD не меняет opacity целого `LeftBottom_Panel`, а отдельно пишет opacity существующим target-группам. Поэтому наш новый sibling **не наследует автоматически его fade**. Кандидат — читать `GetRenderOpacity` одной семантически близкой, *проверенной* штатной AP/status группы и применять соответствующее значение **только к своему Canvas/индикатору** в ограниченном game-thread update, не вызывая setter на native targets. Этот read/следование/меню режим **не имеют самостоятельного live PASS**. При недоступном target корректно скрывать/ограничивать собственное UI, не менять CombatHUD. Проверить при CombatHUD 0.4.1 включённом и отключённом, во время боя, вне боя, Interact, меню и смены HUD.
5. **Обновления:** держать одну authoritative переменную `session.reserve`. Модель визуализации — read-only adapter, которому передаются `current` и `capacity`; не дублировать reserve в settings. Изменения state на `SHOT/FIRE_BOLT/ICE_BOLT/THUNDER_BOLT/MELEE/REST` должны только помечать UI dirty/синхронизировать его по game-thread, без повторной боевой логики. Первое/позднее появление HUD и поколение viewport можно отслеживать ограниченным game-thread refresh по необходимости; **не использовать LoopAsync, глобальный ProcessEvent, изменяемые игровые assets или C++-патч**. При остановке/смене поколения удалять только собственные элементы/handle, затем освобождать собственные ссылки.
6. **Пример альтернатив, сознательно не выбранных для первого кандидата:** постоянно видимый отдельный viewport widget над всеми меню (native hide не наследуется), замена штатной AP-полосы (путаница с AP и конфликт owners), модификация CombatHUD 0.4.1 (другой продукт с принятым неизменяемым релизом) или Coherent/Hud.html injector (необоснованно широкое вмешательство).

## Узкий набор gate'ов

**До игры (для первого HUD-кандидата):** Lua 5.4 syntax/mock для переходов `3→2→1→0`, слабой атаки при нуле (без второго дебета), уникального melee `0→1`, повторов и cap, Conduit REST, отсутствия HUD/ложного owner и stop cleanup. Guard от размножения виджета при нескольких попытках привязки, ограничение dynamic slots реальной capacity и очистка после F7. Не считать mock подтверждением UI рендеринга.

**Один игровой сеанс на уже доступных Astral/Fire:** до включения убедиться, что CombatHUD 0.4.1 работает как до изменения; после включения проверить видимый запас, расход 3→0, слабый выстрел на 0, один melee credit, успешный Conduit REST, показывание/затухание, скрытие при меню, отсутствие накладок с HP/AP и одинаковое поведение при включённом CombatHUD. Обязательно подтвердить фактический detachment своего UI, native cleanup, точные SHA исходника/лога; прочие моды и их конфиги не менять. Второй заход/другое разрешение только при реальном замечании.

**Не смешивать:** эта работа не доказывает Ice/Thunder runtime, e804 или save/load/death; не назначать «балансовую» ёмкость 3 только потому, что первый HUD её отображает. Не выпускать релиз/не менять main без игрового визуального PASS пользователя.

## Открытое дизайн-решение

Предлагаемое место: компактный нейтральный индикатор возле нижней левой HP/AP группы, **не новый элемент на правой skill-панели**. Точные внешний вид/геометрия/цвет требуют пользовательской визуальной приёмки до финального оформления. После этой границы реализацию можно провести узко на уже известной Canvas/widget-подсистеме.

## Визуальная сила выстрела — направление исследования 2026-11-09

Владелец предложил связать сильную/слабую магию **с самим снарядом**: исходный яркий/крупный vanilla projectile в strong, более скромный по размеру и свечению **только конкретный weak staff projectile**, с сохранением полёта, попаданий и нативных боевых эффектов. Это дополняет, но не отменяет резервный HUD. Ссылки на сторонние Asterigos-моды и сравнение технических путей: [STAFF_VFX_FEEDBACK_RESEARCH_01](STAFF_VFX_FEEDBACK_RESEARCH_01.md). Конкретные размеры/яркость и Unreal seam не утверждены; VFX-код не менялся.

**Критическая особенность:** visual mode должен следовать уже исполненному выстрелу, а не текущему `reserve`. Fire-strong explosion может запаздывать после расхода последнего заряда, когда следующий weak-shot уже начался. У Ice повторные damage pulses и отдельная VFX row, у Thunder direct bolt; нельзя глобально затемнять всю стихию, масштабировать Actor root или перерабатывать эффекты общего shader в зависимости от текущего резерва. Первым исследовать визуальные компоненты/параметры **только одного доступного Astral/Fire** source; без нового глобального renderer hook до scoped evidence.


## Проверка границы рефакторинга перед HUD — 2026-11-09 (предложение, не утверждённая реализация)

Владелец принял достигнутые результаты Fire Flight/Blast dev как рабочую основу и предложил обсудить предварительное переоформление накопившегося экспериментального кода перед интеграцией HUD. Текущий осмотр точного HEAD `344844c`: `dev/StaffRebalanceDev/Scripts/main.lua` ≈1002 строки, `tests.lua` ≈1091 строк; Lua 5.4 CI последнего исполняемого кандидата `337ecab` [PASS 42685619089](https://github.com/NikichMods/StaffRebalance/actions/runs/42685619089). **Новая кодовая архитектура пока не принята и здесь не внедрена.**

**Двигатель остаётся тем же:** боевые события через UE4SS (Genesis/Blueprint), HUD через штатные Unreal Engine 4.27 UMG/Canvas и UE4SS. Это отдельный presentation adapter, **не второй игровой движок**. Ни CombatHUD 0.4.1, ни его 17 opacity-targets, ни native HP/AP менять не нужно.

**Фактический кодовый шов (точный исходник dev):**
- `session.reserve` — единственная изменяемая игровая валюта, `capacity=3` пока dev. Прямые записи расположены в обработчиках Astral, Fire, Ice, Thunder, melee и подтверждённого Conduit rest. HUD не должен копировать резерв в новую currency/config; нужен один доменный путь уведомления только после подтверждённого изменения числа.
- `session.combo` — граница native Begin/End skill, отдельно от projectile-hit; `shots`, `fireParents`, `iceParents`, `contacts` — **не одинаковые и не взаимозаменяемые** таблицы: хранят source-mode, delayed blast/pulse parent state и dedup. Fire blast 01 требует сохранять `shots[boltId]` после `fireParents` consume; Ice pulse требует сохранять parent-mode после каждого child. Их удаление/«общая универсальная таблица» без доказанной lifecycle-семантики опасны.
- Проверенная защита exact class/row/owner, native UFunction signatures/property offsets, e804 fail-closed, generation/game-thread, rollback `DamageRate`, 15 опциональных/обязательных script hooks для Fire-ready + native пары, F7 cleanup — не «шелуха», а safety/integration evidence.
- Исследовательское, подлежащее отделению от штатной сборки: `diagnosticCapacity=50` и `diagnostic.byWeapon`, per-hit `notified_damage` logs, `F3` ручной start, `F4` scale/Fade A/B toggle и runtime-probe коэффициенты `0.35/0.15` как диагностические режимы. Это не значит, что их можно сейчас удалить без адаптации mock и без dev/runtime regression.
- Видимый конкретный долгосрочный lifecycle-вопрос: `shots`, `contacts`, `iceParents` хранят ID на протяжении всей dev-сессии без показанного per-actor pruning, а `id()` включает object path+address. Реальный memory/reuse дефект **не наблюдался**, но перед бесконечной production-сессией нужно установить безопасную invalidation/lifetime; не обрезать Fire strong mode до delayed blast и Ice parent до последних pulses.
- `fail()` при ошибке обнуляет `session` и делает хуки инертными, `stop()` снимает их; auto-start, menu/load/death/rebind и lifecycle сохранения резерва пока отдельные production gates. Не смешивать исправление этих требований с механическим переносом функций.

**Рекомендация — небольшой behavior-preserving refactor, не clean-room rewrite:**

1. Зафиксировать **существующий** `344844c` и карты проверенных game/mock gates как контрольный baseline; не делать release/promotion `main`.
2. В рамках **одной** узкой реорганизации отделить (логически, в существующем Lua, либо физически **только после проверки UE4SS module loading/install**) четыре обязанности: (i) validated host bindings/hooks; (ii) боевой reserve/action/parent-mode + dedup; (iii) optional cosmetic VFX Fire; (iv) dev diagnostics. Избавиться от сквозных raw `session.reserve` writers в пользу минимальной **авторитетной** функции перехода с событием `reserveChanged(old,new,cause)`, не создавая отдельную валюту/состояние HUD. Никакого нового generic-element framework ради Ice/Thunder.
3. Сначала обеспечить **эквивалентность** при Lua 5.4 CI: действия Astral/Fire и mock Ice/Thunder; финальный strong Fire blast после следующего weak; multi-bolt; duplicate melee/contacts; rest; foreign owner/class/row rejection; VFX fail-closed; F7 cleanup. Поведение/баланс/выбранные слабые VFX не менять одновременно. После достаточной code-equivalence проверки — один ограниченный Astral/Fire smoke для нового code SHA; runtime Ice/Thunder остаётся deferred, не присваивать им PASS.
4. Подключить независимый UMG-adapter к авторитетному `reserveChanged` + read-on-first-attach. UI владеет только своими widgets, dirty/animation presentation и их removal, а не обработкой сильных/слабых атак и не чужим CombatHUD. HUD может поздно появиться после открытия viewport: изначально запрашивает текущие `reserve/capacity`, без дублирования storage. После UI integration — отдельная native/CombatHUD game acceptance.

**Не выбирать преждевременно:** физическое разбиение на `require`/несколько файлов, авто-F3→auto-start, сохранение между загрузками, финальные числа/дизайн кристаллов. Всё это имеет свои технические или продуктовые gates. Переписывание «с чистого листа» повторно открывает слишком много уже пройденных host/event/damage/owner проверок без доказанного выигрыша в UX.

## Проверка принципа MagicalScabbards — 2026-11-09

[Architecture Simplification Review 01](ARCHITECTURE_SIMPLIFICATION_REVIEW_01.md) сопоставляет StaffRebalance с актуальной веткой MagicalScabbards State Reconcile, где решения по ножнам выводятся из проверяемого текущего состояния, а не длинной истории событий. **Здесь важна асимметрия:** HUD может получать актуальный `session.reserve` без собственного state machine, но списание за выполненное действие, melee-hit и delayed Fire/Ice child mode требуют causal events и per-source ledger. Поэтому предлагается **узкая централизация числовых переходов резерва** с read-only HUD adapter, сохранением exact elemental callbacks и без механической попытки заменить всё polling/reconciliation. Статус — ПРОЕКТНОЕ ПРЕДЛОЖЕНИЕ, исходники не изменены.

## Единая точка изменения резерва — реализована в dev 2026-11-10

По [Architecture Simplification Review 01](ARCHITECTURE_SIMPLIFICATION_REVIEW_01.md#implemented-narrow-refactor-01--2026-11-10) в `dev/StaffRebalanceDev/Scripts/main.lua` выделена одна `setReserve(nextValue)`; прямые изменения `session.reserve` из обработчиков выстрелов/melee/rest удалены. Функция проверяет integer/границы и возвращает `before,next,changed`, **не хранит вторую валюту и пока не сообщает HUD**, которого ещё нет. Также `weakenDamageRate` объединила пять одинаковых операций `DamageRate` с прежним rollback. Action-mode, parent identity, CombatHUD и current Fire VFX остаются как были. [CI 42700548862](https://github.com/NikichMods/StaffRebalance/actions/runs/42700548862) Lua 5.4 + mock PASS; **игровой regression PASS для рефакторинга не проводился**. Следующий HUD adapter будет читать актуальный `session.reserve` при создании и получать только реально изменившийся числовой переход для кратких анимаций; без нового event bus и без хранения currency в UI. До HUD нужен один короткий Astral/Fire smoke на точном SHA.

## Первый отдельный UMG HUD-кандидат — 2026-11-10

**Кандидат первого сеанса.** [Отдельный модуль](../dev/StaffRebalanceDev/Scripts/StaffReserveHud.lua) загружается через `pcall(require,"StaffReserveHud")` и создаётся после успешного F3. UI читает авторитетный запас при поздней привязке и получает от `setReserve` только числовые изменения. Mock покрывает слабый выстрел на нуле, повторный melee-контакт и полное восстановление без изменения значения. Итог игрового сеанса приведён ниже.

**Dev-only visual shape, not final aesthetic:** text label `STAFF` and 1–6 tiny filled/empty rectangular slots in a **new owned Canvas subtree** under native `LeftBottom_Panel` (not under status.Main_Panel, whose exact 12 children CombatHUD checks). Current dev capacity is three; six is a deliberately bounded UI-only construction cap, not a supported balancing recommendation. Provisional anchor bottom-left `x=205,y=-20`, size `138×30` logical UMG units, needs in-game placement inspection. Stock `TextBlock` / resource-free `Image` are taken from published IIP native-UMG evidence; no external fonts, assets or new cooked classes. Same fill for all four elements. Empty slots remain present and do not show a lock/fire prohibition.

**Ownership/fade/lifecycle hypothesis:** one bounded GameThread HUD worker at 100 ms follows **only its own** nodes and read-only `status.APBar:GetRenderOpacity()`, finds the exact current Hilda-owned viewport HUD periodically, inherits native left branch hiding, and unregisters own nodes/worker on F7 or dev stop. Native CombatHUD 0.4.1 is never modified, and no battle-state/HP/input logic is duplicated. This is a **code candidate**; attaching a Canvas child under `LeftBottom_Panel`, exact placement, title font, submenu/menu hiding, opacity follow, rebuild on HUD change and cleanup still require a short real-game test. Actual UI rendering cannot be proven by Lua parser/mock. First test should start at existing Astral/Fire save, exercise 3→0, weak at 0, melee+1, Conduit restore, native menu and combat fade, then F7 and log. Do not declare visual PASS before the owner sees readable non-overlapping slots. If HUD module fails, preserve combat gameplay and stop its own writes rather than investigating a broad replacement engine.

**Do not treat this as release UX:** contextual instruction, semantic staff/rune glyph, nicer filled/outlined crystals and short gain/spend pulse remain independent design steps after first real screenshot. No changes to final VFX coefficients or unverified Ice/Thunder.

**HUD preflight fix & own-widget mock:** исходный `f196d46` создавал UI-детей в Hidden при подготовке, но не раскрывал их перед показом root (пустое дерево на экране при успешном bind). Это устранено до передачи в игру: отдельные собственные children получают `SetVisibility(3)` только после полной настройки. Добавлена независимая проверка `hud_tests.lua` через обычный Lua 5.4 для create/show, reserve 3→1, no phantom event, opacity follow, viewport swap, repeat bind и F7 detach. Реальную геометрию native HUD по-прежнему проверять в игре.

## HUD 01 — первый игровой smoke-тест, 2026-11-10

Кандидат `38a56f3fa84eb3aaf020506b4ec4b6bcd367c97f`, Steam build 12996889, UE4SS `83330635`, CombatHUD 0.4.1. Исходные и установленные Lua совпали побайтово. SHA-256 до и после: `main.lua` — `b8029ca725f106862cdce4a26d8e72d4fa611e97aa5a6b3bd47b661c4ad41878`, `StaffReserveHud.lua` — `9dd5539587530e4cd8cb1cbafd955f3c0cd4dd5cac4c78f337ccc10b208c28f6`. Закрытый UE4SS-журнал хранится локально, SHA-256 `dbc03db3706f7e448bc0e6347f9c17acafedaf97bd3d52dc8fb8d9c20422d86e`.

- **Static/mock/CI — PASS.** [Lua 5.4 syntax и mock для точного SHA](https://github.com/NikichMods/StaffRebalance/actions/runs/42707255151).
- **Runtime observed — PASS для проверенных переходов.** F3: один `HUD_ATTACHED` с тремя слотами, старт 3/3 (718–720). Три одиночных Astral-действия дали 3→2→1→0, по одному дебету. Слабый выстрел выполнился с `debit=0` и попаданием без изменения HUD (721–738). Четыре засчитанных контакта с label `weapon=hammer`, два из них дали 0→1 с обновлением HUD (739–759). Astral-комбо также списало по одному заряду за шаг, дополнительные болты дали `debit=0` (760–774). `REST_REQUEST` сохранил 0, подтверждённый `REST` восстановил 3/3 (778–780). F7: `HUD_DETACH failures=0`, UE4SS подтвердил снятие 13 script hooks, `STOP hooks_remaining=0` (795–809).
- **User visual acceptance — частичная.** Владелец подтвердил появление и обновление сегментов, совместное появление и затухание с CombatHUD и исчезновение после F7. На кадрах 2560×1440 индикатор расположен ниже HP/AP без пересечения со штатными полосами, но собственные сегменты перекрывают надпись `STAFF`. Геометрия и внешний вид не приняты. За сеанс зарегистрирован один attach, на предоставленных кадрах по одному индикатору.
- **NOT TESTED / BLOCKED.** Отдельное визуальное подтверждение скрытия в меню отсутствует. Обе native пары зарегистрированы при старте, но их физическое удаление после F7 не подтверждено журналом до выхода. Ice/Thunder и release acceptance остаются открыты.

**Кинжалы после переката — незакрытое наблюдение.** Владелец сообщил о возможном попадании без заряда. Журнал фиксирует четыре кредита с label `weapon=hammer` и ноль с `weapon=daggers` (`DIAG_SUMMARY`, 794), но отклонённые class/row и owner не логируются, поэтому конкретный контакт не идентифицирован. В cooked-данных `hilda_dual_dodgeatk` ссылается на timeline `dual_dodge_atk`, где используется `hilda_dual_attack`. Для Astral remap ведёт к `hilda_dual_attack_astral` с классом `hilda_dual_atk_C`. Эта пара уже разрешена. Добавлять источник по одному наблюдению нельзя. Для локализации нужен воспроизводимый контакт после переката при запасе ниже лимита и фактические class/row, owner и mob hit; обычный удар кинжалами служит контролем.


### Уточнение владельца к HUD 01 — 2026-11-10 (post-smoke)

Владелец сообщил, что во время HUD 01 атаковал цель **кинжалами** и **не доставал и не экипировал молот**. Это противоречит классификации четырёх `MELEE weapon=hammer`, нуля `daggers` в `DIAG_SUMMARY`. Следовательно, HUD 01 подтверждает наблюдаемые изменения резерва и отображения, но **не подтверждает удар молотом и его фактическую экипировку**. Название `weapon=hammer` в `main.lua` определяется соответствием `source:GetClass():GetFullName()` плюс `ProjectileDataName` точной паре `hilda_cudgel_fire_C` / `hilda_cudgel_<element>`; проверка фактически экипированного оружия не выполняется. Несоответствие пока не объяснено. Это также меняет трактовку ранее описанного предполагаемого пропуска после переката: источник нельзя идентифицировать только по принятому `MELEE` tally.

**Аудит закрытого журнала — CONFLICTING EVIDENCE.** SHA-256 совпал. Строки 739, 743, 756, 758 содержат четыре разные идентичности `source` класса `hilda_cudgel_fire_C`; первые две относятся к одному экземпляру `m052_arvicolina_BP_C`, вторые две — к другому экземпляру того же класса. Зарегистрированы четыре уникальные пары и переходы 0→1, 0→1, 1→2, 2→3. Строка 794 даёт `total=4 daggers=0 hammer=4`. Сырой `ProjectileDataName` и owner не выведены. Сверенный Lua допускает такой `MELEE` только после совпадения exact class/row `hilda_cudgel_fire_C / hilda_cudgel_astral`, совпадения `GetCharacterOwner()` с текущей Хильдой и dedup пары source–target. Строка и owner поэтому выводятся из guards, а происхождение source от конкретного ввода или skill по этому журналу не устанавливается.

Прежние контрольные прогоны раздельно подтвердили [Astral-кинжалы и обычный молот](DEV_PROTOTYPE_01.md#повтор-игровой-интеграции-четырёх-melee-типов--2026-11-08). В [общей cooked-карте](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/COMBAT_STATIC_CONTRACTS.md) обычный `hilda_dual_atk1` порождает `hilda_dual_attack`. Сверка тех же cooked-таблиц для `hilda_dual_dodgeatk → dual_dodge_atk` показывает тот же базовый projectile key. В Astral оба пути ожидают `hilda_dual_atk_C / hilda_dual_attack_astral`, уже разрешённую пару. Обычный молот использует другую пару. Эти данные исключают объяснение «фильтр просто назвал совпавший кинжальный class/row молотом», но не объясняют, почему callbacks сеанса содержат cudgel-source, и не идентифицируют возможное попадание после переката. Проверка экипировки в этом коде отсутствует.

### Диагностический повтор melee HUD 01

**Диагностика для dev-сеанса.** `MELEE_TRACE` включается с F3 и пишет до 24 образцов за первые 90 секунд на уже зарегистрированном mob-hit callback, после известных staff-веток и перед melee whitelist/owner guards. Это позволяет увидеть неизвестную строку и чужого owner. Записываются class, raw row, owner class/ID и совпадение с Хильдой, source/target ID, резерв до обработки и текущий `GetDoingSkill`, если доступен. Текущий skill — контекст на момент callback, его совпадение не доказывает происхождение source. Ошибка диагностического чтения локализуется в пробе. F7 останавливает сбор штатным teardown. Начисление, damage, whitelist и HUD сохранены.

**Один сеанс:** подготовить в игре Astral и кинжалы у обычного живого mob, нажать F3 и потратить три заряда выстрелами в сторону. Сделать одно обычное попадание кинжалами, дать короткую паузу, затем одно попадание кинжалами после переката при запасе ниже 3. Если первый удар заполнил резерв, освободить место выстрелом Astral. Отметить порядок и видимый запас, нажать F7 и выйти. По закрытому логу сопоставить source/target ID с `MELEE` или `DUPLICATE`. Если визуальный контакт не имеет образца при открытом окне, доставка этим callback остаётся непроверенной. Закрытый журнал хранить локально с SHA-256.

### Игровой результат диагностического повтора — 2026-11-10

Кандидат `7593a8b779631a76352cf8528b24f25795b05dc1`, [Lua 5.4 syntax/mock CI PASS](https://github.com/NikichMods/StaffRebalance/actions/runs/42741837162). SHA-256 установленных Lua до и после совпали: `main.lua` — `63a633330cdfffaf7adda0cd8d101ad6111ddacfe0d99a8a06b03da3a6f97480`, `StaffReserveHud.lua` — как в HUD 01. Закрытый UE4SS-журнал хранится локально, SHA-256 `22a3c69d141c308885a1db6b6e5242cf7a75fdb28de1fb31e92713f9178305ed`.

**Runtime observed.** Все восемь образцов — разные экземпляры `hilda_dual_atk_C` с фактической строкой `hilda_dual_attack_astral` и `owner_is_hilda=true`, по одному экземпляру цели `m052_arvicolina_BP_C` на весь прогон. Каждый source ID сопоставился со своим `MELEE weapon=daggers element=astral`. Повторов пары нет.

| Действие владельца | Текущий skill при callback | Источники | Резерв | Строки |
| --- | --- | --- | --- | --- |
| Обычная атака | `hilda_dual_atk1_idle` | Два разных | 0→1→2 | 737–742 |
| Первая атака после переката | `hilda_dual_dodgeatk` | Три разных | 2→3→3→3 | 744–750 |
| Повтор после разрядки | `hilda_dual_dodgeatk` | Три новых | 0→1→2→3 | 764–772 |

Два контакта при 3/3 увеличили только диагностический счётчик. Итог `total=8 daggers=8 hammer=0` (773), фактически начислено шесть зарядов за три атаки. Наблюдение владельца по HUD совпало с переходами в журнале. F7: `HUD_DETACH failures=0`, сняты 13 script hooks, `STOP hooks_remaining=0`, затем UE4SS подтвердил удаление обеих native pre/post пар (774–792).

**Вывод.** Обычная атака и атака после переката в этом Astral-сценарии работают по текущему правилу одного начисления за уникальную пару source–target до cap. Пропуск после переката и cudgel-классификация из HUD 01 не воспроизвелись. Причина четырёх cudgel-источников в исходном сеансе остаётся открытой: повтор подтверждает ожидаемый путь для проверенных атак, а исходный лог не связывает свои источники с конкретными skill. Доказательств для изменения whitelist или начисления нет. Возвращаться к этому расхождению при повторном появлении cudgel-source во время контролируемого удара кинжалами.

## HUD Phase One — принятое направление, 2026-11-17 (дизайн принят; исполняемый HUD 02 ещё не готов)

**Решение владельца.** Вместо временной строки `STAFF` с квадратами в `LeftBottom_Panel` и вместо замены XP-полоски выбран **тонкий индикатор по центру снизу под блоком способностей**. Это сознательно оставляет XP, HP, Stamina, AP и native crystals без изменений и одинаково относится к клавиатуре/мыши и геймпаду. Визуальная цель — минималистичная native-подобная шкала из 10 небольших ячеек; не переносить в runtime сгенерированные иллюстрации как доказанные assets.

### Внешний контракт

- Центрировать весь ряд по горизонтальной оси viewport/HUD, не под `LeftBottom_Panel` и не по координатам отдельных кнопок. В gamepad-разметке — ниже центральных кругов способностей, с самостоятельной безопасной вертикальной границей. В KBM-режиме допускается ряд без расположенных над ним кругов; отдельную постоянную центральную панель не добавлять.
- Ровно **10 модулей в Phase One**. Тонкие прямоугольные ячейки с небольшими промежутками; слабое свечение только у заполненных, пустые остаются темно-серыми с различимым контуром. Мягкая полупрозрачная тёмная подложка и два минимальных декоративных окончания допустимы. **Нижнюю подчёркивающую линию не рисовать.** Ни текста `STAFF`, ни массивной оправы/иконки, ни нового fullscreen-оверлея.
- Цвет заполнения зависит от четырёх штатных стихий **Astral, Fire, Ice, Thunder**. Четыре константных цветовых пресета выбрать однократно по штатным визуальным образцам и проверке контраста; не читать каждый тик live VFX/material и не создавать новые зависящие от них pointers. Чтение **активной стихии** — отдельный exact host getter/data seam; не выводить её из последнего болта или текущего `session.reserve` без доказанного договора. Пока seam не подтверждён, показывать нейтральный цвет / держать цветовую функцию disabled, но не показывать заведомо ложную стихию.
- Заполненная/пустая семантика по-прежнему следует единственной авторитетной `session.reserve`; ноль — слабые, но доступные staff-атаки, не запрет. Общий `opacity` и нативное скрытие в меню должны оставаться под действующими владельцами HUD/CombatHUD; HUD только читает штатный opacity и меняет свои виджеты.
- **Условие видимости:** посох находится **в одном из двух выбранных экипированных слотов**, в том числе когда активное оружие в руке — melee, чтобы пользователь видел пополнение резерва. Если посох отсутствует среди выбранного набора — свой ряд скрывать. Не определять эту семантику по последнему `GetDoingSkill`, наличию произвольного Actor в мире или флагу боевого режима. На временно неизвестном состоянии безопасный fail-closed, без подмены native HUD.
- Скрытие при отсутствии посоха — это presentation-only: combat reserve сохраняется и продолжает законно пополняться от melee, никакого reset / stop core из-за видимости.

### Числа и границы Phase One

**Целевая пробная ёмкость gameplay — 10, без прогрессии максимума, без locked cells, без изменения стоимости выстрела, слабого множителя, melee credit и Conduit-rest.** Старые smoke PASS остаются доказательствами **capacity=3** и не превращаются в PASS для 10. Перевод gameplay `capacity=3→10` требует отдельного обновления mock assertions и короткого runtime smoke, включая cap, слабый режим при нуле и refill до 10. Итоговый баланс числа 10 не принят автоматически.

Идея прогрессии ёмкости с ростом модулей от центра зафиксирована как **отложенная Phase Two**, не часть первого кандидатного кода.

### Известные технические seam и стоп-условия

- В существующем dev HUD 01 `StaffReserveHud.lua` ограничивает виджеты `capacity<=6`, создаёт `LeftBottom_Panel` children и содержит надпись `STAFF`. Это нужно изменить именно в собственной presentation-ветви, не трогая native AP/HP/Xp или CombatHUD.
- [R-015 Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md#r-015--projected-screen-components-vs-viewport-hud-root-2026-10-29) статически установил корневой `HUDMainUMG_BP_C.Main_Panel` как Canvas и рекомендовал собственное дочернее дерево с viewport-normalized anchors. Нативное геометрическое размещение и совместимость после переноса требуют игрового теста. В первой версии можно использовать прежние отдельные Image с программными размерами и цветами, без текстурных assets.
- [MagicalScabbards State Reconcile 01](https://github.com/NikichMods/MagicalScabbards/blob/research/scabbard-state-reconcile-01/docs/SCABBARD_STATE_RECONCILE_01.md) и [universal equipment.lua](https://github.com/NikichMods/MagicalScabbards/blob/research/scabbard-reconcile-bracer-02/research/scabbard-reconcile-universal-01/Scripts/equipment.lua) уже используют native `GameGlobal:GetInUseWeaponType(pawn, 0/1)`, с типом посоха `4` и `None=7`, на проверенном baseline. Повторно исследовать выделение UI по боевому skill не нужно. Для HUD нужен точный read-only selected-slots getter и безопасная обработка промежуточных/недоступных значений.
- Штатный **текущий elemental enchantment до первого выстрела** по имеющимся StaffRebalance/Research документам не локализован как допустимый read-only getter: **BLOCKED для корректного цветового runtime** до узкой evidence-проверки. Это не повод менять боевые фильтры/сканировать граф объектов каждый тик.
- У Phase One **нет runtime PASS, нет принятого UI layout, нет release**. Обязательные проверки: 10/10→0, 0 weak, melee 0→10/cap, successful rest 10, один индикатор без дублей, экипированный staff + melee hand, staff removed, смена стихии без выстрела, KBM/gamepad, native menus, CombatHUD fade, F7 script/native cleanup. Ice/Thunder gameplay runtime остаются deferred, не требовать их live-использования только ради цвета.

**Граница работы:** сначала exact source/host evidence для equipped+element, потом минимальная функциональная правка UI+gameplay cap с Lua mock/CI, затем один игровой тест. Не переносить изменяемый reserve в настройки, не изменять `main` branch.

## HUD Phase One — кандидат реализации, 2026-11-17

**READY для dev-кандидата.** Запас принадлежит только `session.reserve`, а `setReserve` ограничивает все записи общей capacity. Все debit/melee/rest consumers используют этот предел. Изменение ёмкости на 10 покрыто отдельным тестом реального неизменённого кандидата через F3. Прежняя матрица capacity=3 сохранена в тестовом окружении с явной подстановкой прежней константы для регрессии elemental/delayed/VFX ветвей, её PASS не заменяет игровые проверки 10.

Существующий HUD теперь создаёт одно собственное Canvas-поддерево в `HUDMainUMG_BP_C.Main_Panel`. Размер 340×24, anchors/alignment X=0.5, bottom offset −36 UMG units. В нём десять горизонтальных ячеек 28×12 с шагом 32, тёмная подложка и два небольших торца. Текст и подчёркивание отсутствуют. Геометрия экспериментальная, требует просмотра под gamepad и KBM. Стандартный resource-free Image даёт плоскую подсветку заполнения, отдельный blur/glow asset не добавлен.

**Видимость.** Read-only `GameGlobal:GetInUseWeaponType(pawn,0/1)` из принятого MagicalScabbards equipment precedent. Типы EWeaponType 0–5 и None=7 допустимы, COUNT_MAX=6 исключён. Ряд видим, когда любой выбранный слот равен Staff=4, независимо от активного melee. Ошибка чтения/неизвестный enum скрывает только собственный root. Чтение повторяется штатным UI worker 100 ms. Сам reserve продолжает жить при скрытом ряде. Fade читается с APBar, собственный root наследует native visibility Main_Panel. Реальное menu hiding после переноса пока не проверено.

**Стихия — BLOCKED, нейтральная заливка.** В retained UHT `GameGlobal.h` найден выбранный weapon getter, но элементального getter не установлено. Cooked `BaseProjectile_BP:GetOwnerMagicElemental` читает строку `BasePlayerCharacter_BP.Magic_Elemental` у владельца. SHA-256 этого bytecode-входа `4f5f377b960a63cf57088d73bda3f445ea90c705e6162dc8e31946bcf111057d`. В `BasePlayerCharacter_BP:ExecuteUbergraph` offset 794 пишет это поле из actionParameter, далее используется `change_elemental`. Пока не установлена полная связь с применением Enchantite и начальной загрузкой до первого выстрела. Достаточно локализованного кандидата для будущей проверки, недостаточно основания для четырёх гарантированно корректных runtime цветов. Текущая версия оставляет нейтральный цвет.

**Static/mock/CI — PASS.** Исполняемый кандидат `ce0638ab6b7a15aed85bd656317a81f2b624922f`, [Lua 5.4 CI 44001707662](https://github.com/NikichMods/StaffRebalance/actions/runs/44001707662). HUD mock покрывает 10 заполненных/частичных/пустых ячеек, центрирование и границы, один root, смену первого/второго equipped слота, неизвестное состояние, COUNT_MAX, fade, rebind и stop. Core-тест кандидата покрывает 10→0, weak, dedup, 0→10/cap, rest 9→10 и двойной bolt с одним debit. **Runtime и user visual acceptance — NOT TESTED.** Старые HUD 01 факты относятся к старым кандидатам.

**Установка — READY FOR GAME TEST.** Игра закрыта, прежняя установка сохранена вне активного каталога. Экспорт обоих Git blobs сверён, установленные файлы побайтово идентичны. SHA-256 `main.lua` — `03832f3f6114ae4b9f43fdd648a24bf5961cab90cb8ae9d29afbd53fe56218db`, `StaffReserveHud.lua` — `bd73bcc4afcf95569de55fce7729187fb8a9a4f47c28ed70a653408a6c1bc98f`. CombatHUD 0.4.1, его файлы, mods.txt и маркер StaffRebalanceDev сохранили исходные хеши. Backup и manifest хранятся локально.

**Игровой сценарий.** F3 с посохом в наборе, проверить десять заполненных ячеек и положение под gamepad abilities / KBM. Израсходовать 10 оплаченных действий, затем сделать слабый выстрел на нуле. Melee-попаданиями заполнить до 10 и проверить cap. Израсходовать часть и подтвердить Conduit rest до 10. Проверить, что при melee в руке ряд остаётся, без посоха в обоих слотах скрывается, после возврата посоха показывает сохранённый запас. Проверить меню, fade CombatHUD, отсутствие дублей. F7, контрольное действие для native cleanup и выход. Закрытый лог и установленные SHA сверить после сеанса. Ice/Thunder gameplay остаются deferred.

### Phase One — исправление корневой привязки после первого запуска

**Первый игровой запуск — FAIL по появлению HUD.** Установленные SHA совпали с ce0638a. F3 дал START reserve=10, Astral debit и melee credit работают, но HUD_ATTACHED отсутствует. Пользователь не увидел шкалу. Закрытый журнал сохранён локально, SHA-256 `e91dfc22b6cb908444c95fabcb0ee5580e1d391b8e0c10b2af43c0c602aa442f`. F7 и очистка в этом логе не зафиксированы.

**Дефект привязки, READY для узкого исправления.** Phase One ошибочно использовал `hud.Main_Panel`. В ранее live-проверенном [R-015 viewport-кандидате](https://github.com/NikichMods/ImmersiveInteractionPrompts/blob/242a5f0a6f5807dd4cdc3953f1f51acc02b0be06/research/interaction-prompts-owner/viewport/Scripts/main.lua) маршрут — `hud.WidgetTree.RootWidget` с проверкой имени `WidgetTree.Main_Panel`, Canvas-класса и outer. Retained HUDMainUMG export подтверждает RootWidget именно на этом объекте. Ошибочная прямая alias могла привести к тихому отказу hudFor ещё до создания собственного root; закрытый лог не сохраняет отдельные причины этого отказа. Исходный mock сам предоставлял недоказанную alias, поэтому не обнаружил дефект.

Исправленный модуль использует `WidgetTree.RootWidget`, проверяет exact object path, Canvas, outer и отсутствие parent, затем создаёт своё поддерево прежним способом. Mock предоставляет только RootWidget и намеренно отклоняет прямое чтение Main_Panel. Отдельных хуков нет. Повторная игровая проверка нужна для подтверждения результата исправления. Сначала достаточно F3 и появления шкалы; только после этого продолжать полный Phase One сценарий. Цветовой seam остаётся BLOCKED, пользовательская геометрия NOT ACCEPTED.

**Исправленный кандидат установлен:** dceb1fcb47d1a2c17569085efd376083317a1078. [Lua 5.4 syntax/core/HUD mock CI 44002794725 — PASS](https://github.com/NikichMods/StaffRebalance/actions/runs/44002794725). Игра была закрыта, предыдущая установка сохранена вне Mods. Файлы побайтово совпали с Git blobs. SHA-256 main.lua прежний, StaffReserveHud.lua — c2b7ade4cc8c4858fa19fce27d9474edf4cd13b744e969e15b8237b4feac7a62. Protected CombatHUD/mods.txt/enable marker хеши сохранены. READY FOR GAME TEST, runtime исправления NOT TESTED.

### Phase One — игровой прогон и меню, 2026-11-17

**Точный кандидат dceb1fc, проверенные установленные SHA.** Закрытый лог сохранён локально, SHA-256 `cc0ee92dfd5f0bb2ec45cfe59a486736314629448fa467bcc3e30611b66fef9b`. Runtime observed: один HUD_ATTACHED slots=10 (719); 10→0, дополнительные болты без повторного debit (721–756); weak при нуле (758–787); melee 0→10 с HUD_VALUE на каждом приросте, дальнейшие контакты сохраняют 10 (792–840); Conduit REST 8→10 (860–862). F7/STOP в этом сеансе отсутствуют, cleanup для этого прогона NOT VERIFIED.

**User visual acceptance — частичная.** Владелец подтвердил работоспособность шкалы по сценарию, совместный fade с CombatHUD и работоспособность при KBM. При открытии меню шкала остаётся видна — FAIL меню. Полная геометрическая приёмка/все варианты устройств не заявляются.

**Причина и READY-исправление.** Свой Canvas прикреплён к Main_Panel, а native menu visibility owner находится ниже: `LeftBottom_Panel:GetParent()`. После переноса автоматическое наследование его скрытия утрачено. Принятый [CombatHUD nativeScene](https://github.com/NikichMods/CombatHUD/blob/main/Scripts/main.lua) использует этот ancestor:GetVisibility() и `GameGlobal:GetInputMode(true,false)==0`. Собственный root теперь дополнительно показывается только при scene input mode и видимом native owner (0/3/4), при сохранённом equipped-staff условии. Неизвестное/недоступное состояние скрывает свой ряд. Это чтение штатного владельца, без копирования его menu state machine. Fade по APBar остаётся отдельным read-only условием. Mock воспроизводит видимый Main_Panel при hidden/collapsed HUD_Panel и UI-input режиме, возвращение в scene, неизвестную visibility и отсутствие reset/дубликатов. `HUD_VISIBILITY` выводится только при смене собственного shown.

**Следующая игровая граница.** F3 с посохом: открыть/закрыть inventory, map и pause/system menu, убедиться, что шкала отсутствует в меню и возвращается в игровой сцене при прежнем запасе и CombatHUD fade. Затем F7, контрольное действие и выход. Полный 10→0/melee/rest заново не требуется для этого presentation-исправления. Runtime menu fix NOT TESTED до повторного наблюдения владельца.

**Menu fix установлен — READY FOR GAME TEST.** Исполняемый SHA 041b705daa35cf1689ab3dd3f796afaf608e0219, [CI 44003912382 PASS](https://github.com/NikichMods/StaffRebalance/actions/runs/44003912382) для Lua syntax/core/HUD mock. Установка при закрытой игре, прежняя версия сохранена локально вне Mods, оба файла побайтово совпали с Git. SHA-256 HUD — 72dc80e8e5d452c06180b1651a151440f6f1e80fd241ae8812a3efb44a9e242c, main.lua прежний. Protected file hashes совпали. Игровой результат menu fix ещё NOT TESTED.

### Menu fix — игровой результат, 2026-11-17

**Кандидат `041b705daa35cf1689ab3dd3f796afaf608e0219`.** Установленные Lua SHA-256 совпали с манифестом до и после. Закрытый журнал сохранён локально, SHA-256 `83c5145d00413bd706905cc40006eea57fbd2c8c0925ec379853a2d96aaf0a96`.

- **Static/mock/CI — PASS.** [CI точного кандидата](https://github.com/NikichMods/StaffRebalance/actions/runs/44003912382).
- **Runtime observed — PASS для visibility и script cleanup.** Один HUD_ATTACHED с десятью слотами, запас 10/10 (709–712). Три цикла shown=false→true без повторного attach (713–718). После возвращения выстрел дал 10→9 и соответствующий HUD_VALUE (719–720). F7 дал HUD_DETACH reason=stop failures=0, UE4SS подтвердил снятие всех 13 script hooks, STOP reserve=9 hooks_remaining=0 (722–736). Ошибок HUD в этом сеансе нет.
- **User visual acceptance — PASS для меню.** Владелец подтвердил, что шкала исчезает при входе в меню и корректно возвращается. Лог поддерживает три перехода, но не называет конкретные экраны меню.
- **NOT VERIFIED.** Строк фактического снятия двух native pre/post пар после F7 в этом журнале нет, через 2.5 секунды завершился event loop (737). Внутренний hooks_remaining=0 подтверждает выполнение штатной cleanup-процедуры, но не физическое завершение отложенного снятия native hooks. Это ограничение доказательства данного прогона.

Menu-дефект закрыт в проверенном сценарии. Цвет по Enchantite остаётся BLOCKED, полная геометрическая приёмка/все устройства и отдельное live-доказательство снятия staff из обоих selected slots этим menu-тестом не устанавливаются. Ice/Thunder gameplay deferred, release acceptance открыта.

### HUD Phase One — исследование текущей стихии, 2026-11-17

**Цель:** окрасить заполненные ячейки по реальному текущему Enchantite посоха **до первого выстрела**, включая момент после загрузки и переход к ближнему оружию при оставшемся экипированном посохе. Цвет хранить только как четыре собственные статические UI-константы; никаких live VFX/material привязок и собственного хранилища игрового элемента.

**Опубликованные доказательства (исходное состояние, не runtime PASS):**

- Прежняя статическая проверка cooked `BaseProjectile_BP:GetOwnerMagicElemental` показала чтение `BasePlayerCharacter_BP.Magic_Elemental` у владельца; SHA-256 bytecode-входа `4f5f377b960a63cf57088d73bda3f445ea90c705e6162dc8e31946bcf111057d`. В `BasePlayerCharacter_BP:ExecuteUbergraph` у offset 794 есть writer из `actionParameter` и вызов `change_elemental` ([HUD Phase One candidate](#hud-phase-one--кандидат-реализации-2026-11-17)).
- Это **кандидат поля**, а не доказанный текущий staff-Enchantite getter: его точный runtime тип, значения четырёх элементов, стартовая инициализация, чтение после смены Enchantite, поведение при melee in-hand и влияние save/load ещё не установлены.
- Действующий [HUD menu fix](#menu-fix--игровой-результат-2026-11-17) — `041b705`, runtime PASS; HUD опрашивает только native selected weapon slots + menu scene и не читает цвета. Его вход/выход и visibility без основания не перерабатывать.

**Самый узкий evidence gate перед цветовым кодом:**

1. Локально по retained UHT/cooked source подтвердить class/тип `Magic_Elemental`, все точные значения и writer/consumer, особенно отношение к Enchantite (не называть `actionParameter` доказанным выбором посоха без цепочки).
2. Если статическая проверка не доказывает live актуальность, использовать **read-only** диагностику в существующем dev game-thread наблюдении: читать только собственный локальный pawn, печатать значение и идентичность контекста **только при изменении** (и один initial sample), не добавляя глобальные hooks, broad scans или write в штатные поля. Любые неизвестные значения → neutral HUD и bounded diagnostic. Не логировать сырой UObject/личные данные.
3. На доступных Astral/Fire: зафиксировать выбор до выстрела, смену Enchantite без выстрела, после возврата из меню, с melee в руке при выбранном staff, и перезапуск/загрузку с уже выбранной стихией. Наблюдение конкретной смены, а не префикс выстрела, должно подтверждать identity. Ice/Thunder gameplay deferred, но допустима статическая проверка enum/маппинга.
4. Только после достаточного доказательства подключить `element → {R,G,B,A}` как **собственные константы UI**; применять цвет к заполненным десяти слотам при смене элемента и при reserve change. Не менять `session.reserve`, gameplay cost, штатные эффекты или CombatHUD. Mock/CI и короткий Astral/Fire live smoke с точным SHA обязательны. До этого — прежняя нейтральная заливка.

**Статус:** design/gate READY; выбранный data seam **candidate, runtime NOT VERIFIED**, цветовые четыре пресета **NOT IMPLEMENTED**. Остановиться на конкретном evidence gap, если он выявится; не угадывать по последнему projectile или картинке меню. 

#### Magic_Elemental — статическая проверка и evidence gap

**Вывод:** цветовой consumer остаётся BLOCKED. READY только для read-only диагностического кандидата в существующем HUD worker. Поле локального pawn читается через GetPropertyValue, без записи native данных, смены reserve и подключения к fill-color. Начальное значение и изменения пишутся как HUD_ELEMENT_OBS, максимум 16 записей на привязку HUD. Каждая запись содержит ограниченное значение, Lua-тип, поколение HUD и типы selected/in-hand weapon. Это диагностический sample, не второе mutable хранилище игровой стихии. Стабильное значение не порождает повторных строк; ошибка чтения остаётся диагностической и сохраняет работу нейтрального HUD. Новых loops/hooks/объектных scans нет; worker прекращается штатным F7.

| Вопрос | Установлено статически | Что ещё нужно |
| --- | --- | --- |
| Тип и значения | BasePlayerCharacter_BP.Magic_Elemental — StrProperty/FString, ElementSize=16. Потребитель hilda_staff_arrow сравнивает lowercase astral/fire/ice/thunder | Подтвердить форму значения UE4SS при чтении у живого pawn. FString не является закрытым enum, прочие строки возможны |
| Writer | В ExecuteUbergraph действие set_elemental (offsets 677/719) ведёт к записи из actionParameter (794), затем к ExecuteWeaponAction(change_elemental, Magic_Elemental) (110) | Установить live связь с выбором Enchantite, чей native caller в retained-входах не локализован |
| Изменение без выстрела | В показанной ветви writer не зависит от projectile callback | Подтвердить доставку set_elemental непосредственно при применении Enchantite |
| Melee в руке | Поле принадлежит персонажу, GetOwnerMagicElemental читает его у владельца | Это не доказывает сохранение staff-элемента при смене оружия. Нужен контролируемый Astral→Fire при melee in-hand |
| Загрузка | Retained export не даёт достаточной цепочки восстановления выбранного Enchantite в поле | Initial sample после обычной загрузки с заранее выбранным Fire, до выстрела |

Дополнительно GetParameter_String с key=MagicElemental возвращает то же поле. Это альтернативный accessor, не отдельное доказательство своевременной инициализации. Из наличия set_elemental не следует происхождение actionParameter от текущего staff-Enchantite. Четыре цветовых пресета пока не подключены, неизвестные значения сохраняют прежнюю нейтральную заливку.

**Идентичность retained evidence, SHA-256.** Исходные игровые JSON/bytecode остаются локальными.

| Вход | SHA-256 |
| --- | --- |
| BasePlayerCharacter_BP.json | 57201275a283519c94daf668f57e84cf731f7939efa19f0f450df11de23fefdd |
| BasePlayerCharacter_BP ExecuteUbergraph | e5a877e6e3f8417cc3c751a31516910d73a8836492a81dccacc08e4d7e49da50 |
| BasePlayerCharacter_BP GetParameter_String | f58f335a1ab1cc58b8d6b9277cf5c5ef139558b80d287a1f0e8f9b39f63028bd |
| hilda_staff_arrow ExecuteUbergraph | 7770f3c94412f6ceceabb5cb660907240b6aa9b315a0d127519fed30c9a0d65d |

**Узкий игровой сценарий диагностики.** Загрузить обычное сохранение, выбрать Astral, оставить посох в наборе и melee в руке. F3, выдержать 2 секунды до любых выстрелов. Переключить на Fire, подождать 2 секунды с melee в руке, затем достать посох без выстрела, вернуть melee. Переключить обратно на Astral и снова Fire, выдерживая паузы. Отметить, в каком порядке фактически выбирались стихии. F7, контрольный взмах, выход. Достаточно доступных Astral/Fire, Ice/Thunder не нужны. Для проверки загрузки отдельно запустить/загрузить обычное сохранение, в котором игра штатно сохранила Fire, и нажать F3 до первого выстрела. Искусственно изменять сохранение не требуется. Закрытый журнал первого сеанса сохранить до второго запуска.

**Проверки кандидата.** Существующие Lua core/HUD suites плюс probe mock: initial sample, отсутствие per-tick spam, изменение значения, сохранение цвета, ошибка чтения и неподдержанный тип, лимит записей и прежняя menu/equipment/rebind/F7 матрица. Runtime probe и цветовые semantics пока NOT VERIFIED. После получения этих наблюдений достаточно решить gate для подключения пресетов, без нового общего исследования боя.

**Диагностический кандидат установлен — READY FOR ELEMENT OBSERVATION.** Исполняемый SHA 9df8fd5bcfafdfd9d0d179eb4c905751639a340b. [Lua 5.4 syntax/core/HUD mock CI 44005989314 — PASS](https://github.com/NikichMods/StaffRebalance/actions/runs/44005989314). Игра закрыта, предыдущая установка сохранена локально вне активной Mods. Оба установленных файла побайтово совпали с Git blobs. SHA-256 HUD 3b80f6614b680a32e83af9baec7bd1eafed0ac087f7145169663c9cd8bb856c1, main.lua прежний. Хеши CombatHUD/mods.txt/enable marker совпали. Runtime диагностики NOT TESTED; цветовой gate BLOCKED до контролируемого наблюдения.

#### Magic_Elemental — первый игровой прогон, 2026-11-19

Кандидат `9df8fd5bcfafdfd9d0d179eb4c905751639a340b`, установленные SHA совпали. Закрытый журнал сохранён локально, SHA-256 `4e6e7cb393df57e65ec386f17f37b379d38b4708e68294c2ed14abaa1b34c7bc`. Владелец уточнил фактический порядок: сначала выбран Fire, затем F3, далее Astral и продолжение сценария.

**Runtime observed.** Initial sample (734) — value=fire, lua_type=userdata, hand=1 (кинжалы), slots=1,4 (кинжалы+посох). Поле преобразуется через FString:ToString. Затем журнал дал fire→astral→fire→astral→fire (739, 740, 743, 744), все последующие change samples — hand=7 (None), slots=1,4. Первые Astral и Fire смены предшествуют какому-либо staff-действию этого сеанса. Первый Fire action отмечен только в 741–742 как mode=no_bolt, позднее Fire action 745–750 уменьшил reserve 10→9. Это подтверждает обновление поля при выборе доступных стихий без необходимости выстрела. Initial Fire подтверждён при melee in-hand, последующие переходы наблюдены при None, а не при удерживаемых кинжалах.

F7: HUD_DETACH failures=0, сняты 13 script hooks, STOP hooks_remaining=0 (752–766), UE4SS подтвердил фактическое снятие обеих native pre/post пар (767–770), затем выход (771). Диагностика не выводила повторов неизменного поля.

**Evidence gap.** Начальный Fire выбран пользователем до F3 уже после загрузки. Поэтому инициализация поля непосредственно из сохранения остаётся NOT VERIFIED. Следующий достаточный шаг — обычная загрузка с ранее выбранным Fire, F3 до любого переключения Enchantite/выстрела, сверка initial sample с фактически восстановленным выбором в игре. Цветовой consumer пока не подключён. Ice/Thunder остаются static-only/deferred.

#### Magic_Elemental — initial Fire после загрузки, 2026-11-19

Тот же кандидат `9df8fd5`, установленные SHA совпали. Игра продолжает работать для других тестов. Сохранён локальный **live-снимок**, а не закрытый полный журнал, SHA-256 `7253de492c368586b4ede90ec8c89327b4b4354ae6f9214b8b6ba3b16fc6a1d2`. Нужный тестовый интервал уже завершён F7 и физической очисткой.

Владелец подтвердил загрузку с выбранным Fire без предварительной смены стихии и выстрела. Initial sample (728), 02:11:21.951: value=fire, lua_type=userdata, hand=7, slots=1,4. Это совпало с фактическим выбором в игре. В журнале есть последующий FIRE_BOLT в 02:11:32.500 (732), через 10.5 секунды после initial sample. Он не влияет на вывод о правильном чтении до первого выстрела. Этот более поздний выстрел изменил reserve 10→9.

F7: HUD_DETACH failures=0, сняты все 13 script hooks, STOP reserve=9 hooks_remaining=0 (738–752), затем обе native pre/post пары физически сняты (753–756). Сегмент StaffRebalance завершён, дальнейшие действия других модов не меняют сохранённый снимок.

**Data gate — READY для узкого dev consumer.** Два контролируемых Astral/Fire прогона подтвердили изменение без выстрела, Fire с melee in-hand при выбранном посохе и initial Fire после обычной загрузки. Это достаточная evidence для подключения собственного фиксированного UI mapping с нейтральным fallback и отдельным визуальным smoke. Ice/Thunder значения подтверждены только статическим consumer, их gameplay runtime остаётся deferred. Цветовой consumer ещё NOT IMPLEMENTED, приёмка цветов NOT TESTED.

#### Четыре цветовых пресета — dev-кандидат, 2026-11-19

**READY.** Два предыдущих live-прогона подтвердили чтение Magic_Elemental до выстрела, при смене Enchantite, с melee в руке и initial Fire после загрузки. Consumer использует эти данные только для собственных заполненных ячеек. В существующем worker берётся актуальная строка через GetPropertyValue/FString:ToString и exact lowercase lookup, неизвестная строка/ошибка → прежняя нейтральная заливка.

| Пресет | RGB, alpha=0.98 |
| --- | --- |
| Astral, фиолетово-синий | 0.60, 0.44, 1.00 |
| Fire, оранжевый | 1.00, 0.32, 0.08 |
| Ice, голубой | 0.28, 0.78, 1.00 |
| Thunder, золотистый | 1.00, 0.83, 0.20 |
| Neutral | 0.84, 0.93, 1.00 |

RGB являются собственным UI-подбором, не точным извлечением из игровых материалов. Визуальный ориентир Astral — фиолетовый Enchantite, показанный в [игровом руководстве со скриншотами](https://halfglassgaming.com/2022/10/asterigos-curse-of-the-stars-guide-how-to-unlock-the-magic-chests/); прочие пресеты используют различимые тёплые/холодные стихийные оттенки. Финальный контраст и согласованность оттенков требуют пользовательской приёмки.

Перерисовка при изменении reserve или выбранного color table, включая смену элемента без выстрела и при неизменном числе заполнений. Пустые ячейки сохраняют прежнюю заливку. Лимит 16 diagnostic samples ограничивает только журнал, не чтение поля и не обновление цвета. Кеш color — presentation identity, не второе состояние стихии/резерва. Main.lua не менялся. Menu/input/equipment gates из 041b705 и F7 lifecycle сохранены.

Mock проверяет все четыре exact preset, смену при том же запасе, neutral при ошибке/неизвестном значении и неверном регистре, неизменность пустых ячеек и обновление после лимита trace. Сохраняются прежние core/HUD проверки. Runtime цветового consumer NOT TESTED, Ice/Thunder gameplay deferred.

**Игровой smoke.** После обычной загрузки F3, до выстрела проверить цвет текущего Astral/Fire. Переключить Astral↔Fire без стрельбы, включая melee в руке при staff в наборе. Одним выстрелом освободить ячейку и убедиться, что пустая остаётся серой; поменять элемент при частичном запасе. Проверить вход/выход из меню и fade, F7, контрольный взмах, выход. Ice/Thunder специально открывать не требуется.

**Установлено — READY FOR COLOR GAME TEST.** Исполняемый SHA 16f16c9db2b0c1ea7040904b1f8dd82e830fec7b, [Lua syntax/core/HUD CI 44419607973 PASS](https://github.com/NikichMods/StaffRebalance/actions/runs/44419607973). Игра закрыта, предыдущая установка сохранена вне Mods. Оба файла побайтово совпали с Git. SHA-256 HUD b336c5e567197904dfa3dad8af76cf4c92820bbeba6067c9d48d76a8d5b90260, main.lua прежний. Protected CombatHUD/mods.txt/enable marker хеши совпали. Runtime colors NOT TESTED.
