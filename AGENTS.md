# StaffRebalance — working contract

Самостоятельный мод для **Asterigos: Curse of the Stars**, сопровождаемый в `NikichMods/StaffRebalance`. Начинать с [NikichMods/DevRules/WORKING_RULES.md](https://github.com/NikichMods/DevRules/blob/main/WORKING_RULES.md); далее — применимые `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, `PROJECT_BOOTSTRAP.md`, `RUNTIME_INTEGRATION.md`, `RUNTIME_TEST_HARNESS.md` и `LICENSE_POLICY.md` по предмету работы. Исключений из общих правил сейчас нет.

## Владение и источники истины

- Этот репозиторий отвечает за **поведение мода**, его требования, испытания, версии, приёмку, исходники и артефакты.
- Единственный общий технический источник по игре: [NikichMods/Asterigos-Research](https://github.com/NikichMods/Asterigos-Research), точка входа [docs/RESEARCH_INDEX.md](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md). Согласованные продуктовые решения до создания репозитория: [docs/WEAPON_BALANCE_CONTRACTS.md](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md). Не копировать туда изменяемый статус мода.
- Владелец требований этого проекта: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md); текущего состояния — [docs/STATUS.md](docs/STATUS.md); исследовательского шага — [docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md).
- Статическая карта боя и ограничения: [docs/STATIC_COMBAT_RESEARCH_01.md](docs/STATIC_COMBAT_RESEARCH_01.md), идентичность входов — [research/static-combat-01/EVIDENCE.json](research/static-combat-01/EVIDENCE.json). Подготовка и статус observer — [docs/COMBAT_OBSERVATION_01.md](docs/COMBAT_OBSERVATION_01.md), исходное [ТЗ](docs/RUNTIME_OBSERVATION_TASK_01.md).
- Релевантный исследовательский baseline существующих модов: **Steam 1.09 / build 12996889, UE4.27, Windows x64**, UE4SS `v3.0.1-1181-g83330635`. Это **не подтверждение** совместимости/работоспособности StaffRebalance: новое поведение нужно проверить отдельно.

## Границы

- Только усиление **боевого HP-урона** посоха из непрерывного резерва, пополнение пропорционально фактическому melee HP-урону и полный резерв при отдыхе у Conduit. Дискретные заряды за выстрел отменены; актуальный контракт — `docs/REQUIREMENTS.md`.
- Не изменять AP/APR, стоимость способностей, восстановление AP, статусы, контроль, наведение, дальность, ввод или действия иных видов оружия. Не добавлять самостоятельный AI-редизайн в этот мод.
- Интерактивные предметы/разрушаемые объекты мира должны оставаться функциональными. Штатная защита, поглощение и перенаправление обрабатывают усиленный урон. База расхода staff-резерва открыта, melee-пополнение привязано к фактической потере HP. Grouping по атаке не требуется, дочерние/периодические источники требуют надёжной классификации происхождения.
- Параметры и обработка сохранения/загрузки, смерти, особых атак, HUD — открытые вопросы; не выдавать тестовые значения за утверждённые.

## Инженерный и Git-контракт

- Перед production-изменением сформировать reviewable **READY/BLOCKED** по `ENGINEERING_RULES.md`: достоверная классификация боевых staff/melee damage sources, конечный combat-only HP consumer, доступный безопасный pre-write механизм, область влияния, инварианты и тест.
- Пока эти данные неизвестны, допустимо только **research-only** исследование/диагностика; не подменять доказательство общим UE4 API или Wiki. Для cross-mod reusable facts обновлять Asterigos-Research.
- `main` — стабильная линия; `research/*` — исследования; `dev/*` — не принятый runtime. Не помещать непроверенные runtime-изменения в `main`. Документация без runtime-изменений может идти в `main`.
- Версии, пакеты и CI вводить **только при появлении реальной исполняемой реализации**. Принятые нумерованные артефакты неизменяемы. Пользователь подтверждает реальную работу в игре до stable promotion; собранный пакет сам по себе не принят.
- Предпочтительно независимое отключение через `enabled.txt` (когда будет выбран UE4SS-механизм), корректная очистка только собственного состояния, отсутствие конфликтов с другими установленными модами. Это ожидаемый UX, не доказанный механизм на текущем этапе.

## Лицензирование

Для оригинального кода — **MPL-2.0**, полный текст в [LICENSE](LICENSE), рамки в [LICENSING.md](LICENSING.md). Не включать proprietary game binaries/assets/dumps, private machine paths, credentials или сырой исходник игры. Для будущих оригинальных файлов кода использовать `SPDX-License-Identifier: MPL-2.0`.
