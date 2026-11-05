# Static Combat Research 01 — 2026-11-05

**Итог: статическая карта существенно уточнена; production gate — BLOCKED.** Найдены реальные skill/timeline/projectile owners, отдельная цепочка отдыха, варианты прокачки и конкретные места, где штатная игра перезаписывает коэффициент урона. Не доказаны доступный pre-commit writer боевого HP-урона и устойчивый идентификатор одной выполненной атаки. Работа не запускала игру, не устанавливала моды и не создавала runtime-диагностику.

## Источники, метод и граница доказательства

База ветки `research/static-combat-01`: актуальный после fetch `main` — `7bfc1fe8890f449d36363a71e0deecebbce497bb`. Требования не менялись. Общие источники: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md), его R-004, R-008, R-010, R-014 и [дизайн-контракт](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md).

Проверенная идентичность доступных данных:

- Steam app `1731070`, manifest build `12996889`, depot `1731071`, manifest `4552465433899076789`; принятый проектный baseline — Steam 1.09 / UE4.27 / Windows x64. Это идентичность установки по manifest, не доказательство неизменности каждого игрового файла.
- Установленный UE4SS DLL SHA-256 `ce5e3c46a920cc00b2817ac61e438c9162830290379d0b5b9c4dfc2b29459290`, совпадает с ранее зафиксированным `83330635`.
- Переиспользован существующий UHTHeaderDump. Все 17 выбранных native headers побайтно совпали с сохранённой копией генерации из прежнего IIP-исследования. Заголовки подтверждают декларации; сгенерированные `.cpp` содержат заглушки, не тела native-функций.
- Переиспользованы прежние `hilda_BP`/Remapping evidence и уже собранный reader CUE4Parse **1.2.2**, `GAME_UE4_27`, `ReadScriptData=true`. Дополнительно прочитаны только относящиеся к вопросам таблицы и Blueprint. Provider читает верхний уровень установленного Paks; там обнаружены штатные `pakchunk0-WindowsNoEditor` и `global`, без корневых mod-container. Подкаталоги модов не включались.
- Точные SHA-256 исследованных деклараций, cooked JSON и ключевых bytecode JSON: [EVIDENCE.json](../research/static-combat-01/EVIDENCE.json). Сырые выгрузки, локальные пути, ключ и полный локализованный текст не опубликованы. Приватный provenance и исследовательские заметки сохранены в ignored `.local/static-combat-01`.

Уровни ниже: **D** — native declaration; **T** — реально прочитанная cooked table; **B** — Blueprint bytecode с указанным offset. Это сильнее догадки по имени, но не runtime execution. Значения кадров — данные timeline при FPS=30, не измеренные задержки игры. Интерпретатор событий timeline и внутренний native damage path этими экспортами не раскрываются.

Основные переносимые пути источников:

| Источник | Путь / объект |
| --- | --- |
| Skill / Talent / Weapon | `/Game/MainContent/Tables/Player/Skill_Player`, `Talent`, `Weapon`, `WeaponTypeInfo` |
| Выполнение | `/Game/MainContent/Tables/TimelineData_PlayerSkill`, `_1`, `_2`, `TimelineData_Status` |
| Источники повреждения | `/Game/MainContent/Tables/Projectile_Player`, `TimelineData_Projectile` |
| Прогрессия и замены | `/Game/MainContent/Tables/Remapping`, `Status_Talent`, `Status_Skill`, `EnhanceCrystalLv` |
| Staff Blueprint | `/Game/MainContent/Act/Skill_BP/PlayerSkill_BP/hilda_staff_*` |
| Отдых | `/Game/MainContent/Act/Scene_BP/BaseScene_BP/BaseSavePoint_BP`, `/Game/MainContent/Act/Scene_BP/SavePoint_BP` |
| Восстановление | `/Game/MainContent/Template/BaseBlueprint/GameGlobalBlueprintLibrary`, `MainGameInstance_BP` |
| Связь имён талантов | `Genesis/Content/Localization/Player/en/Player.locres`, namespace `SkillText` |

## A. Одна атака и несколько последствий

**D:** `/Script/Genesis.GenesisCharacter:BeginSkillStateEvent(FName Skill)`, `EndSkillStateEvent(FName Skill)`, `SpecialSkillTimelineEvent(FName EventName)`; `/Script/Genesis.GameGlobal:UseSkill(Character, skillIndexName, bForce)`, `GetDoingSkill(Character)`, `PlaySkillTimeline(...)`; `FSkillData` имеет отдельные `SkillBeginTimelineData`, `TimelineData`, `SkillEndTimelineData`. Это кандидаты для наблюдения состояния, а не доказанный момент расхода заряда. Начало skill может предшествовать созданию поражающего источника.

**T:** обычные `hilda_staff_atk1`, `hilda_staff_atk2`, `hilda_staff_atk3` и elemental/idle варианты ссылаются на собственные timeline. Для базовых Astral:

| Действие | Timeline | `fire event = fire object` | `projectile name` |
| --- | --- | --- | --- |
| Первая атака | `staff_atk1` | кадр 23 | `hilda_staff_bolt_astral` |
| Вторая | `staff_atk2` | 22, 25 | тот же тип |
| Третья | `staff_atk3` | 26, 29, 32 | тот же тип |
| Четвёртая | `staff_atk4` | 33 | `hilda_staff_astral_atk4_first` |

Thunder timelines повторяют схему 1/2/3 событий. Следствие: callback создания каждого projectile нельзя автоматически превращать в списание заряда. Начало skill, каждый `fire object` и каждое попадание — разные сущности. Предпочтительная проверяемая граница — **первое подтверждённое создание поражающего источника в одном исполнении skill**, с сохранением принадлежности остальных источников тому же исполнению. Наличие пригодного live token и callback именно этой границы пока не доказано; интервалы времени и имя skill не заменяют token повторного исполнения.

**T, Fourth Quadrant:** `Skill_Player/hilda_staff_atk3` подключает `talent_e805_atk3` при status `talent_e805`; в `TimelineData_Status` эта timeline задаёт на кадре 37 переход в `hilda_staff_atk4`. Его `staff_astral_atk4_main` создаёт шесть дочерних источников на кадрах 0/4/9/15/20/24, затем `staff_astral_atk4_hit` задаёт отдельное создание hit-source на кадре 15. Это данные многоступенчатой цепочки, не шесть новых пользовательских атак.

**T, Charged Rays:** семейство `hilda_staff_spatk_str[_idle]` → `hilda_staff_spatk_loop` → `hilda_staff_spatk_draw_str` → `...draw_loop[/loop2]` → `...draw_shoot_aim` или `...draw_shoot_full`. Только shoot timelines из этой пары содержат `fire object` на кадре 3 для `hilda_staff_arrow`; состояние aim/charge само по себе не выстрел. **B:** `hilda_staff_arrow:ExecuteUbergraph` offsets 643/663/727 получает character owner, читает `GameGlobal.GetDoingSkill` и сравнивает с `hilda_staff_spatk_draw_shoot_full`; на offset 3323 вызывает `GameGlobal.SpawnProjectile` с `Damage Projectile Param`. Статически виден отдельный носитель выстрела и отдельный damage-projectile, а не готовое правило единого charge.

**T, Rapid Fire:** English key `p802_Name`; `Talent/p802` → `talent_p802` → `Status_Talent` function `Remapping` → `Remapping/talent_p802`: `hilda_staff_spatk_draw_str` заменяется на `...draw_str_fast`. Skill имеет SP cost 20 вместо 15; `TimelineData_Status/talent_p802_draw_str_fast` и `...draw_shoot_aim_fast` изменяют переходы (кадры 3 и 15). Нельзя зашивать стартовые интервалы стрельбы или брать SP под управление мода.

**T, Judgment** (в локализации именно это написание; ранее в плане — Judgement): key `u805_Description`, `Talent/u805` → `talent_u805` → `ApplySpecialSkill=hilda_ult_com05`. `ult_com05` направляет обе weapon A/B ветви в `hilda_ult_com05_atk1`; его timeline создаёт `hilda_staff_astral_atk4_first` на кадре 36, с `staff_astral_atk4_main`. Существует и `...atk1_short`. Фильтр исключительно по префиксу `hilda_staff_` пропустит этот путь. Это active stance с собственным AP-путём; исследование **не принимает** новое продуктовое решение о расходе отдельного заряда для него.

**T, switch:** `Weapon/staff_mod00` и `staff_mod01` используют `SwitchWeaponSkill_Enter=hilda_staff_switch_enter`, `staff_mod02` — `mod2_hilda_staff_switch_enter`. У них есть отдельные timelines/elemental условия. Связь установлена; включение switch и иных специальных действий в расход ресурса остаётся открытым.

## B. Карта урона и изменяемых данных

| Участок | Установлено | Что не установлено |
| --- | --- | --- |
| Skill → timeline | **T:** `FSkillData.DamageRate`, `Tags`, условия status/group/priority; разные строки и коэффициенты для обычных, elemental, fourth и stance атак | Порядок исполнения/замены timeline в native-интерпретаторе; окончательный коэффициент каждого живого экземпляра |
| Timeline → источник | **T:** конкретные `fire object`, projectile rows и параметры; **B:** прямые вызовы `GameGlobal.SpawnProjectile` в дочерних эффектах | Вызывает ли native timeline тот же UFunction через ProcessEvent; доступность hook до collision/damage |
| Источник и элемент | **D:** `ABaseProjectile.DamageRate`, `DamageAttributeName`, `HitStatus`, `HitGainAstralPool`, отдельные force/knockdown fields; `GetCharacterOwner`, `GetBaseDamage`, `GetBaseDamageRate`, `GetBaseTypeDamage`, `GetTypeDamage`, `SetBaseDamage`, `SetBaseDamageRate` | Формула, кэширование, момент snapshot исходных характеристик, сопротивления цели и порядок округления |
| Контакт и цель | **D:** `ProjectileOverlapCharacter(AGenesisCharacter*,...)`, `ProjectileOverlapScene`, `ProjectileOverlapGameEventObject`; `GenesisCharacter.ProjectileHitEvent(projectile,...,float Damage)` и `BaseProjectile.CharacterHitted(float damageValue,...)` | Находятся ли события до или после HP commit; допускают ли они изменение расчётного значения. Float notification не является доказанным mutable pre-damage параметром |
| HP | **D:** `CharacterAttributeComponent.HP/MaxHP/OnCurHPChanged`; `GameGlobal.GetHP/SetHP/AddHP`; у `BaseGameObject` отдельные `GetHP/AddHP` | Конкретный native final writer именно projectile combat damage и все его вызывающие пути. Accessor и delegate изменения HP не заменяют этот writer |

**Найден реальный риск перезаписи (B):** `hilda_staff_bolt_astral:ExecuteUbergraph`, offsets 1263–1397: проверка `talent_e804`, сохранение `Original Damage Rate`, умножение `DamageRate` на 1.1; offset 1100 восстанавливает сохранённое значение. У Thunder аналогичные записи на 932/959/1001/1660. `hilda_staff_arrow` дополнительно пишет `DamageProjectile.DamageRate` на offset 3889. Поэтому «записать множитель в DamageRate один раз после spawn» ещё не полноценный механизм: можно потерять модификацию, изменить штатное stacking или вмешаться после snapshot native-кэша.

**AoE / дочерние источники (T/B):** Fire hit timeline `staff_atk1_fire_hit` порождает `hilda_staff_bolt_fire_explosion`; Ice BP выбирает `Hit timeline` по тегам `staff_ice1` и `talent_e804`, затем вызывает `BaseGameObject.PlaySkillTimeline` (offset 710). `staff_atk1_ice_hit` создаёт `hilda_staff_bolt_ice_hit`. Fourth имеет отдельные beam/main/hit actors. У `hilda_staff_atk4_fire_beam` offset 1776 и Ice beam offsets 1749/3292 явные вызовы `SpawnProjectile(creator=self,...)`; у `hilda_staff_arrow_damage` offset 1689 creator — полученный player character. Следовательно, **Actor.Owner/creator не доказан как универсальный parent-attack ID**: часть дочерних источников создаётся от projectile, часть — от персонажа. Thunder retarget/chain, частота Ice damage ticks и полное наследование damage не установлены только по именам и этим выборкам.

**Мир и бой:** разделение contact callbacks существует. В прочитанных projectile rows, включая Fire explosion и Ice hit, одновременно разрешены `IsCanHitScene` и `IsCanHitCharacter`. Общий source-level `DamageRate` нельзя объявить combat-only. Нужны наблюдение реальных целей и доказательство избирательного расчёта; не все `GenesisCharacter` обязательно враги, и не всякий `BaseGameObject` — безопасно исключаемый декор.

Стандартный `ApplyDamage`/`ReceiveAnyDamage` UE не объявляется реальным путём Asterigos. В исследованных Blueprint не найден полный combat pipeline до записи enemy HP. Это **не доказательство отсутствия native-пути**, а предел доступных деклараций и cooked bytecode. `GameGlobal.DamageCharacter_Cpp` существует как отдельная декларация, но связь со staff hit не обнаружена.

## Прогрессия — что уже запрещает стартовую упрощённую модель

**T/D:** три staff weapon module rows, `mod_staff_02` заменяет значительную часть skill family; Enchantite выбирает elemental/remapping/status ветви; `Status_Talent/talent_e809` содержит `SkillDamageRate` с параметром `talent_e809,0.1`; `GameGlobal` объявляет `GetPlayerWeaponLevelDamage`, `GetEnhanceCrystalBuffData`, `GetWeaponAtk_by_Buff`, `GetWeaponAtkRate_by_Buff`, `GetDamageType_by_Buff` и `GetDamageTypeDefence_by_Buff`.

Это подтверждает несколько уровней данных/модификаторов, **не итоговую формулу**. Полную зависимость от характеристик, weapon level, Enchantite и resistances установить не удалось. Сохраняется гипотеза масштабировать **штатный итоговый боевой урон** множителем, не подменять его константой и не вычислять заново собственную формулу. Native consumer этого множителя ещё нужно найти. Новые числовые настройки StaffRebalance здесь не принимаются.

## C. Результативная melee-атака

**T:** `hilda_dual_atk1` → `dual_atk1`: два `fire object` (кадры 6 и 18), оба `hilda_dual_attack`. `hilda_cudgel_atk1` создаёт `hilda_cudgel`, `hilda_spear_atk1` — `hilda_spear`. Значит, melee тоже использует projectile/source модель; «projectile означает дальнобойное оружие» неверно.

Особенно важно: **`Skill_Player/hilda_staff_atk1/2/3/4` имеют `Melee=true`**, как и прочитанные dagger/hammer/spear attacks. Значение не является пригодным семантическим фильтром пополнения. Его native назначение здесь не установлено.

Для будущего credit нужен подтверждённый идентификатор исполнения подходящей атаки, её успешный combat hit и отметка «зачтено» на всё исполнение, включая несколько sources и targets. Декларации `SetGroup(int32)` и table field `Group` не доказывают, что это такой идентификатор. Полный перечень допустимых normal/special/switch действий требует принятой продуктовой границы; исследование не назначает её само.

## D. Отдых у Conduit

Здесь статическая локализация существенно сильнее, чем просто имя события:

1. **D:** `ExtendedCoherentUIGTGameHUD` имеет разные `SavePointOnRest`, `SavePointOnTransport`, `SavePointOnExit`, `SavePointOnFail`.
2. **B:** `BaseSavePoint_BP:BindHUDDelegates` ведёт к ubergraph offset 7072 (bind `Interact_Rest`) и 7118 (`BindSavePointDelegates`). `Interact_Rest` — wrapper в entry 5991, не событие открытия меню.
3. Entry 5991 создаёт таймер 3.5; ветка 6241 выполняет `CharacterExecuteAction(use_savepoint_rest)` и `Respawn Refill`, затем отдельный таймер 1.5. Его `Complete_94792...` ведёт к entry 2214 и `GameGlobalBlueprintLibrary.RecoverPlayerAndScene(self)` на offset 2241.
4. `GameGlobalBlueprintLibrary.RecoverPlayerAndScene` вызывает `GenesisGameInstance.ExecuteAction` с именем `RecoverPlayerAndScene`. Найден соответствующий `MainGameInstance_BP.RecoverPlayerAndScene`, wrapper → entry 46713. В нём: проверка player → `SetHP(GetMaxHP)` (46839), `SetStamina(GetMaxStamina)` (46924), `SetAstralPool(GetMaxAstralPool)` (47009), `ResetCharacterCreators(false)` (47038).
5. `Complete_743790...` таймера 3.5 ведёт к entry 1985 и `GTGameHUDBPLocal.EventOnRestEnd` (2149), отдельно от teleport path. Конкретный `SavePoint_BP.UseRest` задаёт animation/sound/VFX; это не сам HP refill.

Это доказательство разных статических ветвей и достижимого пути восстановления, **не выполненного отдыха**. Native dispatcher `GenesisGameInstance.ExecuteAction` между library и game-instance событием отдельно не раскрыт. Для ресурса перспективно связывать подтверждённый rest-контекст с recovery completion; нельзя подписаться на любой `RecoverPlayerAndScene`, предполагая, что он используется исключительно отдыхом. Проверить фактическую последовательность и отсутствие начисления за menu/exit/teleport ещё необходимо.

## Сравнение механизмов и рекомендация

| Вариант | Конкретное основание | Ограничение / решение сейчас |
| --- | --- | --- |
| Только DataTable/pak | Реальные Skill/Timeline/Projectile/Status rows найдены | Статическая замена не реализует динамический запас, once-per-attack credit и combat/world split; не выбирать как готовое решение |
| Удалять или заменять projectiles при нуле | Реальные источники локализованы | Потеряются штатные world interactions, AP/status/control; не соответствует требованиям |
| Масштабировать параметры source при создании | Объявлены `SetBaseDamageRate`, spawn params, type-damage getters; часть child-spawn видна в B | Предпочтительнее переписывания формулы, **если** доказаны snapshot, распространение на children, отсутствие перезаписи и combat-only влияние. Сейчас этих гарантий нет |
| Режим на исполнение + множитель у узкого pre-HP consumer | Соответствует прогрессии, delayed effects и разделению целей | Архитектурный ориентир; реальный consumer и возможность pre-write не найдены. Не выдавать за выбранный hook |
| Общий Attack/buff на персонаже | Статы и buff readers существуют | Захватывает другие skills и delayed damage, зависит от текущего состояния; не подходит без существенно более сильного доказательства |
| Вернуть HP после урона | Есть HP readers/setters | Уже могли произойти death/AP/aggro/kill эффекты. Отклонено как базовый путь; не реализовывать |

**Рекомендация:** дальше проверять модель `исполнение атаки → неизменный strong/weak → связанные damage sources → узкий combat HP consumer`. Ресурс/credit хранить только в состоянии этого мода; множитель применять к штатному значению, не пересчитывать upgrade/resistance формулу. Начать с доказательства цепочки одного normal Astral skill и одного aim shot, затем Fire child и multi-hit melee. Это рекомендация по проверяемой архитектуре, не разрешение на production реализацию и не обещание, что Lua-only будет достаточно.

## Production gate: BLOCKED

| Поле ENGINEERING_RULES | Состояние |
| --- | --- |
| Observable property | Установлено требованиями: один charge на выполненную атаку, weak combat HP damage, сохранение AP/мира/контроля |
| Canonical owner | Частично: skill/timeline/projectile names и rest chain найдены; native commit исполнения/attack token не доказаны |
| Final writer / consumer | **Не установлен** combat HP final writer и доступный pre-write seam; setters/getters его не заменяют |
| Blast radius | Выявлены shared sources, scene/character contacts, child actors и штатные DamageRate writers; полный охват и snapshot не доказаны |
| Preserved invariants | Определены; их сохранение выбранным механизмом пока не проверено |
| Acceptance evidence | Только статические данные. Нет live ordering, ABI, propagation, combat/world separation или игрового сравнения |

Дальнейшее чтение тех же UHT-заглушек не закроет execution/ordering. Независимые вопросы A–D исследованы до полезной границы этих источников. Следующий шаг: [узкое ТЗ наблюдения](RUNTIME_OBSERVATION_TASK_01.md); оно **подготовлено документом, не реализовано**. Числа, save/load/death, HUD, реализация и установка остаются отдельными решениями/этапами.
