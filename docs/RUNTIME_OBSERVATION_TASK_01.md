# Следующий этап — Combat Observation 01 (ТЗ, без реализации)

**Состояние:** подготовлено после [Static Combat Research 01](STATIC_COMBAT_RESEARCH_01.md). Runtime-код, hook registrations и payload не созданы, игра не запускалась. Выполнение требует отдельного запроса. Цель — проверить наличие и порядок конкретных путей, а не начать прототип баланса.

## Вопрос и достаточный результат

Проверить, можно ли однозначно связать одно реальное исполнение skill, создание его sources и успешный combat hit, а также найти наблюдаемую границу до HP commit. Отдельно подтвердить rest path. Результат каждого вопроса — наблюдённый порядок и идентичности либо точный недостающий native seam. Нулевое число UFunction callbacks не доказывает отсутствие native-вызова: он может обходить ProcessEvent.

Первая проверка — доступность точных reflected signatures и безопасного чтения скаляров/объектов на том же baseline. Применить R-008/R-010/R-011 Asterigos-Research: Blueprint RegisterHook callbacks в UE4SS 83330635 post-only; UHT не доказывает native flags/ABI; индексный TArray Get может расширять массив. Не читать вслепую struct/out-array buffers и не считать Blueprint post-hook pre-damage writer.

## 1. Исполнение и происхождение

Ограничить наблюдение owning player и его источниками. Кандидаты:

- `GenesisCharacter.BeginSkillStateEvent` / `EndSkillStateEvent`, `SpecialSkillTimelineEvent`, `GameGlobal.GetDoingSkill`;
- `GameGlobal.SpawnProjectile` / `SpawnProjectileEX`, если реально проходят через доступный UFunction path;
- только нужные `hilda_staff_*` Blueprint BeginPlay/ExecuteAction/overlap paths, найденные статически; children могут создаваться как с creator=self, так и с creator=player;
- фиксировать относительное время/порядковый номер, instance identity + class, creator/character owner, skill, snapshot доступных damage getters и callback phase. Не создавать произвольные objects и не менять исходные параметры.

Сценарии: один normal Astral выстрел и промах; одна вторая/третья атака со всеми sources; отмена до первого fire; aim/hold без выстрела и один Charged Rays; одна Fire атака с дочерним AoE; один удар кинжалами с двумя sources и, если естественно доступно, двумя целями. Не разблокировать отсутствующие таланты/изменять save ради этой стадии. Fourth/Rapid Fire/Judgment и Ice/Thunder добавить только к проверке соответствующей ветви, когда она доступна; отсутствие доступа оставить явным пробелом до full acceptance.

Достаточно установить, какой наблюдаемый момент различает отменённое действие и первое выполненное fire, а также возможен ли общий token для нескольких sources. `GetDoingSkill` — имя состояния, не уникальный ID исполнения. Owner/временное окно/первый projectile не считать окончательной моделью без доказательства на быстрых повторных и delayed событиях.

## 2. HP и доступность pre-write

Для одной реальной боевой цели сопоставить `BaseProjectile.ProjectileOverlapCharacter`, `GenesisCharacter.ProjectileHitEvent`, `BaseProjectile.CharacterHitted`, доступные **native** `GetTypeDamage/GetBaseTypeDamage/GetBaseDamageRate` и HP до/после достигнутых границ. Read-only HP getter разрешён только после проверки типа/ABI, а не по произвольному Actor.

Не изменять HP, DamageRate, buffs, SP/AP или collision. Не подписываться на общий Tick/все события мира. Проверить существование вызовов и порядок: при каком callback HP уже изменён, где ещё виден источник, можно ли отделить scene target от combat target. Реальное разрушение одного штатного объекта проверяется отдельно от вражеского попадания.

**Ограничение наблюдения:** даже native pre/post hook и корреляция HP ещё не доказывают, что изменение конкретного параметра безопасно повлияет только на HP. Если финальный consumer не достижим через отражённые функции, остановить эту ветвь с точным trace gap; отдельно предложить узкую статическую локализацию native routine. Не подменять это широким global ProcessEvent hook, возвратом HP или угадыванием TakeDamage. Контролируемое изменение множителя — возможная отдельная следующая проверка после доказательства владельца и нового разрешения, не часть read-only observer.

## 3. Rest — отличить восстановление от намерения

Наблюдать `BaseSavePoint_BP.Interact_Rest`, `GameGlobalBlueprintLibrary.RecoverPlayerAndScene`, `MainGameInstance_BP.RecoverPlayerAndScene`, `GTGameHUDBPLocal.EventOnRestEnd`. Контекст menu/exit/transport получать только из реально найденных ветвей. Один настоящий rest, открытие/закрытие меню без rest и teleport должны дать различимые последовательности; shared recovery event вне rest не начисляет ничего, observer вообще не владеет charge-ресурсом.

## Безопасность и завершение

Метод: один отдельный выключаемый observer, никаких production mechanics, внешнего save-state, HUD-баланса, диагностических DLL или новых подсистем ради сбора. Если нужен другой формат инструмента, обосновать его отдельно. Скалярные примитивные snapshots; ограниченные события выбранных scenarios; STOP по завершению/ошибке; nil-return callbacks; без sleep/broad scans в game thread. Не менять и не смешивать уже установленные непринятые кандидаты других модов; перед установкой восстановить их фактический статус. Не заменять загруженные файлы и не завершать игру автоматически.

Сохранить точную source/artifact/log identity и закрытую сессию по DevRules; сырые данные оставить локально. Отчёт должен ответить:

1. Есть ли единственная наблюдаемая граница выполненной атаки и общий source lineage?
2. Найден ли реальный pre-HP consumer, либо какая конкретная native-граница осталась невидимой?
3. Можно ли дедуплицировать результативный melee credit независимо от sources/targets?
4. Отличается ли успешный rest от menu/exit/teleport?

После этого пересмотреть механизм и шесть полей production gate. Сам факт успешного observer run не означает READY для изменения урона или принятого игрового баланса.
