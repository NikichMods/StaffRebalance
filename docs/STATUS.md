# StaffRebalance — статус

**Этап:** Combat Observation 01 загрузился в первом игровом прогоне, но журнал содержит только `ARMED`. Захват боя и отдыха не подтверждён. Observer отключён. [Результат и границы](COMBAT_OBSERVATION_01.md#прогон-01).

- Дизайн: согласованы назначение посоха, принцип расхода заряда **при выполнении атаки**, ослабленный боевой урон при нуле, восполнение melee, полный запас при отдыхе у Conduit и сохранение AP/APR/контроля/стихий без изменений. Требования проекта: [REQUIREMENTS.md](REQUIREMENTS.md); исходные решения: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/WEAPON_BALANCE_CONTRACTS.md).
- Числа: количество зарядов, коэффициент ослабления и пополнение **не приняты**; нужны runtime-доказательства и сравнительные тесты.
- **Production gate: BLOCKED.** Найдены реальные skill/timeline/projectile owners, дочерние damage sources, штатные перезаписи DamageRate и отдельная статическая rest/recovery chain. Не доказаны live commit/token одной выполненной атаки, наследование strong/weak, доступный pre-HP combat consumer, combat/world split и once-per-attack melee credit. Полный gate и точные границы доказательства — в [статическом отчёте](STATIC_COMBAT_RESEARCH_01.md).
- Нет проверенной совместимости StaffRebalance, установленного payload, тестового номера, версии, релиза и проекта HUD. Игровые файлы в рамках bootstrap не исследовались; CI и сборочная инфраструктура не создавались.
- [RESEARCH_PLAN.md](RESEARCH_PLAN.md) сохраняет внешний этап и связь с текущими находками; [EVIDENCE.json](../research/static-combat-01/EVIDENCE.json) фиксирует SHA-256 входов без proprietary payload и приватных путей. Проверены Steam build 12996889, прежний UE4SS DLL и совпадение выбранных UHT headers с сохранённой генерацией.
- Следующий шаг при продолжении — различить доставку горячей клавиши и исполнение задачи на EngineTick до повторного игрового сценария. Безопасная reflected точка прямого наблюдения записи HP пока отсутствует.

## Организационное состояние

Проверка 2026-11-05: подготовлены самостоятельный checkout и ветка `main`; публичный remote — [NikichMods/StaffRebalance](https://github.com/NikichMods/StaffRebalance). Topics: `game-asterigos`, `nikichmods-mod`. DevRules и единственный общий Research подключены ссылками, без submodules и копирования их содержимого.

Начальный коммит: [`1e1540606311c5f279f4212c259676da30cb52d3`](https://github.com/NikichMods/StaffRebalance/commit/1e1540606311c5f279f4212c259676da30cb52d3). Первый push в `origin/main` выполнен успешно; SHA удалённой ветки сверен с локальным. Организационных блокеров нет; технические неизвестные выше относятся к следующему этапу и остаются открытыми.
