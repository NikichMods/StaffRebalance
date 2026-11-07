# StaffRebalance — текущий статус

**Dev Prototype 01: начата ветка `dev/reserve-core-01` с отдельной [копией проверенного Lua baseline](DEV_PROTOTYPE_01.md). Новая dev-установка NOT TESTED; расширения пока BLOCKED. Production gate — BLOCKED.**

**Reserve Slice 01: узкий игровой цикл PASS, срез отключён.** [Прогон](RESERVE_SLICE_01.md#игровой-pass-автоматического-среза--2026-11-07) подтвердил расход 3 → 0, 29,925 у слабого Astral и 59,85 после melee-пополнения на том же мобе. Выход из меню сохранил остаток, отдых вернул полный запас. Все семь хуков сняты.

**Продуктовый дизайн обновлён 2026-11-07.** Источник действующих правил — [REQUIREMENTS.md](REQUIREMENTS.md): отдельный запас сильных выстрелов, расход за фактически выполненное действие (включая промах), melee-пополнение за подтверждённый контакт с врагом, полный резерв при успешном отдыхе у Conduit. Точные HP-потери и строго HP-only ослабление больше не требуются.

**Astral: обычный A/B — PASS, e804 — NOT TESTED. Production gate: BLOCKED.** [Astral Rate Probe 01](ASTRAL_RATE_PROBE_01.md) подтвердил, что post `ReceiveBeginPlay` может разово уменьшить `DamageRate` обычного Astral-болта с 0.90 до 0.45. На том же мобе штатный `ProjectileHitEvent.Damage` снизился с 59.85 до 29.925. Оба хука сняты, проба отключена.

**Melee: PASS для наблюдаемого первого удара кинжалами.** [Melee Contact 01](COMBAT_OBSERVATION_01.md#результат-melee-contact-01) подтвердил источник, владельца и цель в `ProjectileHitEvent`. Промах дал 0 HIT, одиночная цель 1+1, группа 2+3. Повторов одной пары источник–цель в прогоне не было. До начисления остаются границы дедупликации, проверка враждебности и покрытие поглощённого контакта. Observer отключён.

## Принятые инженерные границы

- **Предпочтительный путь:** менять штатный `DamageRate` конкретного Astral-источника, позволяя игре считать броню, HP и зависимые эффекты. `SetBaseDamageRate` управляет другим входом формулы и может пересчитывать кэш.
- **Допустимые компромиссы:** расход за промах или выстрел по миру, одна стоимость за многотаргетный выстрел; уменьшение damage частей тела, зависящих от damage реакций, поглощения защитным AstralPool и числового урона объектам. Нельзя напрямую менять AP/APR, статусы, независимый контроль и другие виды оружия; игровые взаимодействия по факту попадания должны оставаться работоспособными.
- **Дочерние источники:** идеальная передача сильного/слабого режима на каждый actor желательна, но не отдельный обязательный gate. Обязателен заметный эффект ослабления всей заявленной базовой атаки в игре. Fire-взрыв самостоятельный; может оказаться основной долей урона.
- **Отложенный native путь:** изолированный x64 fixture подтвердил ABI/rel32/unwind, но ранний UE4SS lifecycle не предоставляет доказанного барьера установки и безопасного lifetime hot reload. Нативный CALL 0x10C493C остаётся BLOCKED; не возобновлять без новых доказательств.

## Принятые доказательства

- [Коэффициент Astral](ASTRAL_NATIVE_HP_PATH.md#штатный-коэффициент-обычного-astral--2026-11-07) связывает поле `DamageRate` с native spawn и hit consumer, устанавливает порядок BeginPlay и показывает восстановление e804 из отдельного поля в Tick. [Static Combat Research](STATIC_COMBAT_RESEARCH_01.md) сохраняет карту Skill/Timeline/Projectile.
- [Elemental Coverage](STAFF_ELEMENTAL_COVERAGE_01.md) и [Fire trace](COMBAT_OBSERVATION_01.md#повтор-fire-02-после-исправления-регистра) показывают: Fire explosion sphere_200_C связан с родительским болтом и Хильдой, в одном событии получено уведомление Damage=90.719993591309. Это не измеренная потеря HP и не доля взрыва в суммарном уроне.
- [Conduit rest trace](COMBAT_OBSERVATION_01.md#повтор-conduit-rest-01-с-f4f7) отличил меню без отдыха от успешного отдыха и сопоставил rest request и recovery context одному Conduit. Полный модификатор резерва ещё не реализован; interrupt/teleport не тестировались.
- [Melee native path](DAMAGE_RESERVE_SEAM_FEASIBILITY_01.md#melee--фактическая-потеря-hp-от-обычного-удара-кинжалами) показывает маршрут кинжалов до HP; точная потеря HP теперь исторический исследовательский вопрос, не обязательное условие начисления.
- [Feasibility review](DAMAGE_RESERVE_SEAM_FEASIBILITY_01.md#повторный-выбор-механизма-после-остановки-native-call) завершён вердиктом NO VERIFIED IMPLEMENTATION PATH **для прежней строгой модели**. Он не является доказательством невозможности более простой модели.

## Следующий узкий шаг

**Astral-комбо 2/3: gate BLOCKED.** Следующая проверка — локальная read-only корреляция native `BaseCharacterAnimInstance:BeginDoSkill/EndDoSkill` с первым и последующими `ReceiveBeginPlay` для каждого выполнения `hilda_staff_atk2/atk3`. Доставка native skill hooks на `hilda_staff_atk1_idle` уже подтверждена в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md#cudgel-socket-transition-and-skill-hook-delivery--observed-2026-11-06), но **граница именно atk2/atk3 не доказана**. Способ, проверка и ограничения записаны в [DEV_PROTOTYPE_01.md](DEV_PROTOTYPE_01.md#проверка-штатной-границы-astral-комбо--2026-11-07). До этого dev-код не расширять по одному bolt.

Независимая проверка коэффициента Astral с талантом `e804` остаётся [NOT TESTED](ASTRAL_RATE_PROBE_01.md); выполнить, когда талант доступен в штатном сохранении. Melee, Fire и HUD не объединять с текущим шагом.

## Организационное состояние

Репозиторий [NikichMods/StaffRebalance](https://github.com/NikichMods/StaffRebalance), стабильная ветка main, текущие исследования в research/combat-observation-01. DevRules и Asterigos-Research подключены ссылками; [EVIDENCE.json](../research/static-combat-01/EVIDENCE.json) сохраняет идентичность локальных входов без игровых файлов. Steam 1.09 / build 12996889, UE4.27, UE4SS 83330635 — изученный baseline, а не доказательство работоспособности нового мода. Никаких CI/release/build-передач сборок сейчас нет.
