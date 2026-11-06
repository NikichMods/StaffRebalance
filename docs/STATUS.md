# StaffRebalance — статус

**Этап:** организационный bootstrap завершён; самостоятельное внешнее техническое исследование начато 2026-11-05. Установленные игровые файлы и combat runtime StaffRebalance ещё не изучены; production-кода нет.

- Дизайн: **принята новая концепция непрерывного бюджета усиленного combat HP-урона**; посох расходует резерв при эффективном боевом HP-уроне, melee восстанавливает пропорционально нанесённому HP-урону, пустой резерв оставляет ослабленный посох, полный резерв при Conduit rest. Дискретные заряды за выстрел и grouping Strong/Weak отдельных атак отменены. Требования проекта: [REQUIREMENTS.md](REQUIREMENTS.md); исходные решения: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md).
- Числа: ёмкость резерва, коэффициенты слабого урона и пополнения **не приняты**; UI ещё не утверждён, но принято требование наглядного, материально воспринимаемого индикатора с отзывчивой обратной связью.
- **Production gate: BLOCKED.** Для новой модели остаются открыты источник/тип эффективного combat HP damage, consumer с безопасной pre-write-модификацией, изоляция от мира, события Conduit rest, lifecycle; grouping по атаке и once-per-attack credit сняты как продуктовые требования.
- Нет проверенной совместимости StaffRebalance, установленного payload, тестового номера, версии, релиза и проекта HUD. Игровые файлы в рамках bootstrap не исследовались; CI и сборочная инфраструктура не создавались.
- Последующие исследования на ветке [research/combat-observation-01](https://github.com/NikichMods/StaffRebalance/tree/research/combat-observation-01) зафиксировали 10 live source events и статический путь Astral→HP; это не подтвердило возможность безопасной модификации урона. [План исследования](RESEARCH_PLAN.md) приведён к новой концепции.

## Организационное состояние

Проверка 2026-11-05: подготовлены самостоятельный checkout и ветка `main`; публичный remote — [NikichMods/StaffRebalance](https://github.com/NikichMods/StaffRebalance). Topics: `game-asterigos`, `nikichmods-mod`. DevRules и единственный общий Research подключены ссылками, без submodules и копирования их содержимого.

Начальный коммит: [`1e1540606311c5f279f4212c259676da30cb52d3`](https://github.com/NikichMods/StaffRebalance/commit/1e1540606311c5f279f4212c259676da30cb52d3). Первый push в `origin/main` выполнен успешно; SHA удалённой ветки сверен с локальным. Организационных блокеров нет; технические неизвестные выше относятся к следующему этапу и остаются открытыми.
