# StaffRebalance — working contract

Самостоятельный мод для **Asterigos: Curse of the Stars**, сопровождаемый в `NikichMods/StaffRebalance`. Начинать с [NikichMods/DevRules/WORKING_RULES.md](https://github.com/NikichMods/DevRules/blob/main/WORKING_RULES.md); далее — применимые `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, `PROJECT_BOOTSTRAP.md`, `RUNTIME_INTEGRATION.md`, `RUNTIME_TEST_HARNESS.md` и `LICENSE_POLICY.md` по предмету работы. Исключений из общих правил сейчас нет.

## Владение и источники истины

- Этот репозиторий отвечает за **поведение мода**, его требования, испытания, версии, приёмку, исходники и артефакты.
- Единственный общий технический источник по игре: [NikichMods/Asterigos-Research](https://github.com/NikichMods/Asterigos-Research), точка входа [docs/RESEARCH_INDEX.md](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md). Согласованные продуктовые решения до создания репозитория: [docs/WEAPON_BALANCE_CONTRACTS.md](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md). Не копировать туда изменяемый статус мода.
- Владелец требований этого проекта: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md); текущего состояния — [docs/STATUS.md](docs/STATUS.md); исследовательского шага — [docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md).
- Статическая карта боя и ограничения: [docs/STATIC_COMBAT_RESEARCH_01.md](docs/STATIC_COMBAT_RESEARCH_01.md), идентичность входов — [research/static-combat-01/EVIDENCE.json](research/static-combat-01/EVIDENCE.json). Подготовка и статус observer — [docs/COMBAT_OBSERVATION_01.md](docs/COMBAT_OBSERVATION_01.md), исходное [ТЗ](docs/RUNTIME_OBSERVATION_TASK_01.md).
- Релевантный исследовательский baseline существующих модов: **Steam 1.09 / build 12996889, UE4.27, Windows x64**, UE4SS `v3.0.1-1181-g83330635`. Это **не подтверждение** совместимости/работоспособности StaffRebalance: новое поведение нужно проверить отдельно.

## Границы

- **Действующий договор 2026-11-07:** сильная атака посоха оплачивается **за фактически выполненный выстрел/действие**, включая промах; слабая атака доступна при нехватке отдельного резерва. Melee-пополнение — **за подтверждённый контакт с врагом**, не по точной потере HP; Conduit rest полностью восстанавливает запас. Подробности и открытые решения — только [REQUIREMENTS.md](docs/REQUIREMENTS.md).
- При выборе штатного damage-множителя допустимы вторичные изменения числовых последствий: части тела, damage-зависимые реакции, защита, разрушаемые объекты. Требование строго HP-only и безусловного полного наследования коэффициента всеми child actors **снято**. Не менять напрямую AP/APR, статусы, самостоятельный контроль, управление, дальность, наведение и параметры других видов оружия. Проверять базовую работоспособность игровых взаимодействий без отдельного масштабного аудита сюжета.
- Сохранять штатные таланты и прогрессию. Для всего заявленного базового staff-охвата слабый режим должен заметно ослаблять итоговую атаку; у Fire существенный дочерний взрыв. Границы special/switch skills, коэффициенты, HUD, save/load/death пока открыты.

## Инженерный и Git-контракт

- Перед production-изменением проверить владелец/consumer изменяемого штатного коэффициента, реальные Blueprint-перезаписи, момент выполнения атаки, область влияния, инварианты и тест; для melee подтвердить семантику попадания, dedup и источник. Применять per-change READY/BLOCKED по ENGINEERING_RULES.md. Точный HP-writer и абсолютная неизменность частичных body damage **не являются** gates новой модели.
- Предпочитать минимальную модификацию входного параметра хоста. Узкий native CALL 0x10C493C и его загрузочный lifecycle остались BLOCKED; прежние минидампы, x64 fixture и feasibility документы являются доказательством старой ветви, а не разрешением использовать нативный патч.
- Пока нет достаточных доказательств допуска — только research-only/диагностика; не превращать наличие поля DamageRate или UE4SS RegisterHook в утверждение о готовой реализации. Общие подтверждённые игровые факты выносить в Asterigos-Research, а текущие решения и статус оставлять здесь.
- main — стабильная линия; research/* — исследование и обновление текущего дизайна; dev/* — не принятый runtime. Не помещать неиспытанные изменения игры в main. Documentation-only изменения можно продвигать отдельно по правилам проекта.
- Версии, пакеты и CI вводить только при реальной исполняемой реализации. Нумерованные артефакты неизменяемы. Релиз/промоушн после реального пользовательского игрового PASS.
- Предпочтительное отключение через enabled.txt при выбранном UE4SS-механизме и корректная очистка собственного состояния; это UX-цель, не доказанная точка реализации.

## Лицензирование

Для оригинального кода — **MPL-2.0**, полный текст в [LICENSE](LICENSE), рамки в [LICENSING.md](LICENSING.md). Не включать proprietary game binaries/assets/dumps, private machine paths, credentials или сырой исходник игры. Для будущих оригинальных файлов кода использовать `SPDX-License-Identifier: MPL-2.0`.
