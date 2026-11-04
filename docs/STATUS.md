# StaffRebalance — статус

**Этап:** организационный bootstrap; техническое исследование не начато, production-кода нет.

- Дизайн: согласованы назначение посоха, принцип расхода заряда **при выполнении атаки**, ослабленный боевой урон при нуле, восполнение melee, полный запас при отдыхе у Conduit и сохранение AP/APR/контроля/стихий без изменений. Требования проекта: [REQUIREMENTS.md](REQUIREMENTS.md); исходные решения: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md).
- Числа: количество зарядов, коэффициент ослабления и пополнение **не приняты**; нужны runtime-доказательства и сравнительные тесты.
- **Production gate: BLOCKED.** Не установлены source/owner исполнения атаки, grouping всех её последствий, конечный consumer combat damage, событие Conduit rest и надёжная credit-модель melee.
- Нет проверенной совместимости StaffRebalance, установленного payload, тестового номера, версии, релиза и проекта HUD. Игровые файлы в рамках bootstrap не исследовались; CI и сборочная инфраструктура не создавались.
- Подготовлен [RESEARCH_PLAN.md](RESEARCH_PLAN.md) для отдельного следующего этапа. Текущая задача разрешает только организационный bootstrap и не запускает этот план автоматически.

## Организационное состояние

Проверка 2026-11-05: подготовлены самостоятельный checkout и ветка `main`; публичный remote — [NikichMods/StaffRebalance](https://github.com/NikichMods/StaffRebalance). Topics: `game-asterigos`, `nikichmods-mod`. DevRules и единственный общий Research подключены ссылками, без submodules и копирования их содержимого.

Первый коммит и синхронизация пока ожидают выполнения и проверки. Их фактические SHA и результат будут записаны после первого push.
