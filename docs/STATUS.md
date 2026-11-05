# StaffRebalance — статус

**Этап:** после боевого прогона 05 статически прослежен обычный Astral hit от проверки класса цели до записи HP. `GenesisCharacter.ProjectileHitEvent` передаёт цель и projectile перед штатной записью в исследованной ветви. Доступность этого события из текущего UE4SS в бою предстоит проверить. [Нативная цепочка](ASTRAL_NATIVE_HP_PATH.md).

- Дизайн: согласованы назначение посоха, принцип расхода заряда **при выполнении атаки**, ослабленный боевой урон при нуле, восполнение melee, полный запас при отдыхе у Conduit и сохранение AP/APR/контроля/стихий без изменений. Требования проекта: [REQUIREMENTS.md](REQUIREMENTS.md); исходные решения: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md).
- Числа: количество зарядов, коэффициент ослабления и пополнение **не приняты**; нужны runtime-доказательства и сравнительные тесты.
- **Production gate: BLOCKED.** Для обычной ветви найдены нативный писатель HP и отделение маршрута персонажа от сцены. Открыты live commit/token одной выполненной атаки, наследование strong/weak, доступная точка изменения боевого урона до записи, покрытие других ветвей и once-per-attack melee credit. Остальные требования gate — в [статическом отчёте](STATIC_COMBAT_RESEARCH_01.md).
- Нет проверенной совместимости StaffRebalance, установленного payload, тестового номера, версии, релиза и проекта HUD. Игровые файлы в рамках bootstrap не исследовались; CI и сборочная инфраструктура не создавались.
- [RESEARCH_PLAN.md](RESEARCH_PLAN.md) сохраняет внешний этап и связь с текущими находками; [EVIDENCE.json](../research/static-combat-01/EVIDENCE.json) фиксирует SHA-256 входов без proprietary payload и приватных путей. Проверены Steam build 12996889, прежний UE4SS DLL и совпадение выбранных UHT headers с сохранённой генерацией.
- Следующий исследовательский шаг — проверить доступность `ProjectileHitEvent` для конкретного Blueprint цели и безопасную обработку его сигнатуры с `FVector_NetQuantize`. Подготовка следующего observer относится к отдельной задаче.

## Организационное состояние

Проверка 2026-11-05: подготовлены самостоятельный checkout и ветка `main`; публичный remote — [NikichMods/StaffRebalance](https://github.com/NikichMods/StaffRebalance). Topics: `game-asterigos`, `nikichmods-mod`. DevRules и единственный общий Research подключены ссылками, без submodules и копирования их содержимого.

Начальный коммит: [`1e1540606311c5f279f4212c259676da30cb52d3`](https://github.com/NikichMods/StaffRebalance/commit/1e1540606311c5f279f4212c259676da30cb52d3). Первый push в `origin/main` выполнен успешно; SHA удалённой ветки сверен с локальным. Организационных блокеров нет; технические неизвестные выше относятся к следующему этапу и остаются открытыми.
