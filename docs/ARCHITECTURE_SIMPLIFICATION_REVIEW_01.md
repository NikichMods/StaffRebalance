# StaffRebalance — Architecture Simplification Review 01

**2026-11-09 · Status: source-grounded architecture review / PROPOSED direction, not an approved rewrite, no executable change or new game PASS.** Compared StaffRebalance `dev/reserve-core-01` HEAD `f9674ce`, Lua `main.lua` ~1002 lines and `tests.lua` ~1091 lines, with original MagicalScabbards events architecture and later state-reconciliation research. Keep the accepted Fire/Astral game evidence and the Ice/Thunder live deferral intact.

## 1. What actually changed in MagicalScabbards

[Original integrated-07/08 report](https://github.com/NikichMods/MagicalScabbards/blob/721e60f39fc1bf942ae34611472aab1100707b83/docs/SCABBARD_INTEGRATED_24.md) shows growing special-case state: `drawPending`, Sheath timers, skill-name exceptions, menu-transition and delayed offhand-handling. Changing one transition often exposed another. [State Reconcile 01](https://github.com/NikichMods/MagicalScabbards/blob/eb86b84b23afa30f7b51ac6158edb96374a1bc92/docs/SCABBARD_STATE_RECONCILE_01.md) instead inferred *current*, validated stowed/held state from native equipment getters and a current actor snapshot, then acted on a stable three-second state after fresh confirmation. [Pure policy](https://github.com/NikichMods/MagicalScabbards/blob/eb86b84b23afa30f7b51ac6158edb96374a1bc92/research/scabbard-state-reconcile-01/Scripts/reconcile.lua) retains only identity, start timestamp and latest observation; it does not reconstruct every prior Sheath/draw event. Importantly this is **not** proof that native snapshots cover every visual transition. A bounded read-only game observation supported the policy, and [Reconcile Write 01](https://github.com/NikichMods/MagicalScabbards/blob/fc2f34cc2ff3daa6e229b35e26924ea991556d68/docs/SCABBARD_RECONCILE_WRITE_01.md) remained **Lua PASS / game NOT TESTED** as of its documented branch. We borrow the *decision principle*, not an asserted fully accepted drop-in engine.

**Principle:** derive what is currently observable from the authoritative native state, and preserve historical events only when the required answer really depends on an earlier action.

## 2. Why StaffRebalance cannot be converted wholesale to snapshot reconciliation

- **A single real shot is a debit event, not a stable actor state.** Press/hold/cancel and a performed bolt differ; current `GetDoingSkill` or reserve alone cannot prove whether payment already occurred. Native Begin/End skill plus exact accepted projectile source are justified. The multi-bolt Astral/Thunder action must debit **once**, not once per generated particle.
- **Delayed child attribution is irreducibly historical:** at Fire `FIRE_SPHERE → BLAST_BEGIN`, `session.reserve` may have fallen to zero and a *different* weak bolt may already exist. [Fire Blast Provenance 01 and cosmetic game PASS](STAFF_VFX_FEEDBACK_RESEARCH_01.md) demonstrate owner→original bolt mode, including delayed strong blast after newer weak. Ice may yield repeated damage pulses. Replacing the source-mode ledger with the current selected skill/element/reserve would regress proven behavior.
- **Melee credit depends on unique contact**, not a getter like current HP or combat state. One mob-hit event plus dedup of the same source-target is required. A polling current-state reconciliation cannot reconstruct hits reliably from a snapshot.
- **HUD is the relevant state-read boundary:** it displays current `reserve/capacity`, should attach late, reconcile ownership/viewport/menu and survive independent CombatHUD fade. It does not need a second copy of gameplay state or a complete event-history replay. Optional reserve-change notifications are for brief UI gain/spend animations only.

## 3. Audit of specific simplification candidates

| Candidate | Present situation in exact dev Lua | Benefit / minimal safe change | Status |
|---|---|---|---|
| **One reserve mutation boundary** | Direct `session.reserve` writes in Astral, Fire, Thunder, Ice, melee and confirmed Conduit rest; duplicate cap/debit patterns, future HUD could couple to each callback | One pure, bounded `spend/credit/refill` transition on the **same** session reserve; return `before, after, cause`, notify display only if actual value changes. At cap no fictitious `+1`, weak at 0 no duplicate spend. The validated action callbacks still decide **when** to call it | **HIGH value / recommended first** |
| **One weak-damage write helper** | Repeated float32 ×0.5, DamageRate reflection/offset check, failure rollback and readback across elemental handlers; Ice carrier admits stock 0 | Share mechanically identical validated float32 write+rollback while preserving per-source `rate >0` vs `rate >=0` acceptance and exact class/row/owner checks. No generic "all projectiles" hook | **MEDIUM value / small safe refactor** |
| **Separate optional visuals** | Fire flight and blast cosmetic VFX are embedded in same combat file and perform detailed reflective checks/readback | Encapsulate weak Fire render-only work behind an optional feature boundary; failures disable cosmetics but never debt/damage. Preserve exact `fire_explosion_b_02_bp_C` owner relation and vanilla strong effect | **MEDIUM value / preserve existing PASS** |
| **Remove research-only concerns from shipping path** | `diagnosticCapacity=50`, per-weapon tallies, verbose staff HIT telemetry, F3/F4/F7 and alternating fade/scale probes | Keep in dev harness or debug mode; user-facing build gets no test tally/F4 probe. This does not eliminate the shared mob-hit hook needed for melee | **HIGH housekeeping / at production conversion, not simultaneous gameplay change** |
| **One HUD state adapter** | HUD absent; upcoming design could require polling every combat widget and reimplementing CombatHUD state machine | HUD reads `session.reserve/capacity` once on attach, responds to actual domain transitions, and periodically reconciles *only its own* UMG host/visibility if required; never writes AP/CombatHUD targets. No new engine/layer | **HIGH value / after reserve seam** |
| **Reduce session-sized provenance maps** | `session.shots`, `contacts`, `iceParents` accumulate IDs; Fire additionally uses `fireParents` consumed at sphere and `session.shots[bolt]` for later visual blast | Examine existing lifespan, address reuse, EndPlay and delayed pulses **before** pruning. A shared per-source record might reduce overlap, but could create more lifetime/invalidity assumptions than two simple maps. Do **not** replace with only current mode/last bolt | **RESEARCH / not a prerequisite for first HUD** |
| **Eliminate native BeginDoSkill and class-specific hooks** | Two native action-boundary hooks + exact individual class/row callbacks are needed for demonstrated multi-bolt/action semantics; optional classes load late | A broader hook/snapshot could accidentally debit on aim/cancel, accept specials/e804, or misclassify Ice child/Fire delayed blast. No verified simpler event substitutes all these meanings | **REJECT now** |
| **Replace all code with generic four-element framework** | Astral direct bolts, Fire delayed damage+visual blast, Ice repeated sphere pulses, Thunder direct multiple bolts have different host semantics | A single generic data table erases safety differences and creates combinatorial exceptions. Share policy, **not** proven-different host source handlers | **REJECT now** |

**Observation rather than defect:** the dev source's persistent ID sets and object-address identity may eventually need bounded lifetime, but current tests do **not** establish a memory leak or collision. Any cleanup must preserve late Fire strong blast and repeated Ice child pulses; start from real lifecycle evidence, not a speculative TTL.

## 4. Proposed minimal architecture

```text
Exact host callbacks / UE4SS guards
    (ASTRAL / FIRE + child / ICE + pulses / THUNDER / melee / rest)
             |
             v
    Reserve core (one authoritative session.reserve, capacity)
    Action attribution (source mode, duplicate suppression)
             |
       +-----+---------------------+
       |                           |
       v                           v
 Optional weak VFX          Read-only HUD adapter
 per verified shot          snapshot at late bind
 (never controls core)      + transient change cue
       |                           |
       +----------- lifecycle: release only owned resources
```

The boxes are **responsibilities**, not a requirement to create that many Lua files. UE4SS `require` semantics, install path, initialization order and game-thread scheduling are not automatically proved by this diagram. Prefer one working file with crisp boundaries until physical module loading is verified; avoid a new cross-module event bus/duplicated `reserve`.

Simple conceptual domain interface (not a locked API):
- `spendConfirmedAction(actionId)` returns strong/weak for an executed, authenticated action and changes reserve at most once; only handlers know which observed events belong to one action.
- `creditConfirmedMelee(sourceId,targetId)` returns actual delta after source/target dedup/cap.
- `refillConfirmedRest()` modifies reserve only at the accepted Conduit confirmation.
- `getReserveSnapshot()` returns current/capacity; `onReserveChanged(before,after,reason)` is a small optional push for UI animation and telemetry, not stored user settings.

**Important:** do not implement the conceptual functions by introducing a second action registry that duplicates existing `combo`, `shots`, `contacts` or creates new action identities. First centralize only numeric changes. Action-level consolidation is a later separately proved choice if it demonstrably reduces code/assumptions.

## 5. Smallest proof and stopping rule before the first HUD

1. Freeze known-good combat/VFX dev source `337ecab` (HEAD docs-only `f9674ce`) and its Lua [CI PASS 42685619089](https://github.com/NikichMods/StaffRebalance/actions/runs/42685619089). Preserve accepted game evidence for Astral and Fire and explicitly defer Ice/Thunder in-game.
2. First patch **only** numeric reserve transitions and no-op/cap notification mechanics in the existing dev source. Keep event callbacks, per-action mode, parent ledgers and VFX byte-equivalent wherever possible. Do not simultaneously auto-start, change persistence, VFX intensities, classes/hooks or rename event payloads. Mock test exact debt, melee cap/dedup, rest, Fire strong delayed blast, Ice multi-pulses, e804 and foreign filters.
3. If this centralization is clearly useful, additionally isolate repetitive weak DamageRate mutation helpers while preserving element-specific preconditions; then stop refactoring. No purpose-built generic framework.
4. Verify source-specific Lua 5.4 parse/mock CI, compare key logged event semantics with baseline, then **one** bounded Astral/Fire smoke on exact installed SHA **only if the behavior-bearing runtime refactor merits it**. Native game acceptance can't be borrowed wholesale across newly arranged callbacks. Do not demand unavailable Ice/Thunder sessions now.
5. Begin compact UMG reserve HUD from authoritative snapshot/change only; test with CombatHUD 0.4.1 present and absent, same-game menus, viewport rebinding, and UI-own cleanup. Revisit cast/start FX and lifetime/pruning only on an observed need or production lifecycle gate.

**Verdict:** the MagicalScabbards lesson applies, but leads to a smaller change in StaffRebalance: **stop building event-history or duplicated state around the presentation**, and reuse already minimal event-based causal attribution for combat. Highest-leverage work is a *single reserve transition seam and read-only HUD state adapter*, not reconstructing all verified combat handling from scratch.

## Implemented narrow refactor 01 — 2026-11-10

**Accepted direction, not production/runtime acceptance.** Single coherent Lua refactor at [216540d](https://github.com/NikichMods/StaffRebalance/commit/216540daaa94e91d7da93b155a5ca3d855aed510), based on original executable `337ecab` and docs-only `c66b583`. Only `dev/StaffRebalanceDev/Scripts/main.lua` changed; `tests.lua` remains the existing exact baseline. [GitHub Actions 42700548862](https://github.com/NikichMods/StaffRebalance/actions/runs/42700548862): exact checked-out SHA, Lua 5.4 syntax and full dev mock suite **PASS**. This verifies model equivalence but **does not** revalidate the changed Lua in Asterigos; no new game run, install or visual observation was performed.

**Precisely changed:**
- Added `setReserve(nextValue)`: only writer to `session.reserve` (apart from initialization); validated integer `0..capacity`, returns `before,next,changed`. Confirmed Astral/Thunder first-strong debit, Fire/Ice strong debit, melee credit to cap and Conduit-confirmed REST now call it. No-op at full reserve/unchanged REST does not fabricate a state transition. The actual source-specific action guards and timing are **unchanged**. **No HUD observer, event bus, duplicate state or persisted settings** were introduced; presentation can later observe this single transition point and read `session.reserve` at bind time.
- Added `weakenDamageRate(source,rate,invalidReason,sourceId)`: consolidates exactly five previously duplicated float32 `×0.5` calculations, `DamageRate` write/readback and rollback/log on failure. All specific class/row/owner/native boundary/e804 checks, validation `rate>0` or allowed Ice zero carrier, and type-specific error identifiers remain at their existing call sites. No change to tested weak scale, Fire cosmetic VFX, parent-mode ledgers or damage lifecycle.
- Preserved F3/F4/F7 dev keys, diagnostic `0/50`, script/native hooks, log event format, session setup, Fire/ICE source mode provenance and F7 cleanup. They are still active dev functionality; **no claim that release cleanup or auto-start is implemented**. This keeps the first refactor small and reviewable rather than combining diagnostics/lifecycle and combat changes.

**Review boundary:** the size of the main Lua changed from ~1002 to ~994 lines; line reduction is not the success criterion. Existing mock tests cover Astral/Fire/Thunder/Ice strong→weak, multi-bolt and child modes, Fire delayed blast after weak bolt, weak-rate rollback, melee cap/dedup, Conduit REST, foreign owner/row, e804 fail-closed and F7. No host-specific source modification or new native hook was added. Because this commit rearranges the execution of numeric writes, **one representative Astral/Fire game smoke on exact installed SHA** remains required before treating the refactored code as in-game equivalent. Ice/Thunder remain **game NOT TESTED/deferred**, regardless of mock PASS.

**Stop rule for this refactor:** do not additionally rewrite per-element action semantics, aggregate `shots/fireParents/iceParents/contacts`, generalize the hooks, alter dev VFX coefficients or add HUD in the same runtime-test candidate. After confirming core equivalence, proceed directly to a separately tested UMG HUD adapter. Only revisit lifetime pruning at a proven lifecycle gate or observed issue, and isolate the dev diagnostics when converting to a user-facing candidate.

### Reserve Core smoke 01 — 2026-11-10

**PASS в одном ограниченном Astral/Fire сеансе.** Установлен точный исходник `216540daaa94e91d7da93b155a5ca3d855aed510`, одинаковый с исполняемым файлом на `6fe9d9553866539f5615824d3dbcbee2d6afcfff`. SHA-256 установленного Lua `e415f9d2d5b4f26c6c173932107a9e221968bb7c7cc89cb68f896174638ea37a`, Lua CI `42700548862` PASS. Закрытый лог UE4SS `83330635`, SHA-256 `0772427e1c708b4d5622c6925b9ff454fcb8b4a404f32333262c81898c2ae947`, хранится локально.

- Astral: три одиночных strong дали 3→2→1→0 и сохранили DamageRate ≈0.90. Четвёртый weak при нуле не списал заряд и получил ≈0.45 (781–784). Один подтверждённый контакт кинжалами дал 0→1 (811), запрос и подтверждённый отдых на том же Conduit дали 1→3 (818–826).
- Fire: два одиночных strong дали 3→1. Комбо дало strong 1→0 и два weak с нулевым дебетом. Запоздалые strong sphere и blast первого шага пришли после вылета первого weak, сохранили ID первого болта, DamageRate ≈0.90 и `visual=vanilla` (838–850). Weak sphere совпали со своими болтами и получили ≈1.03→0.515 и ≈1.23→0.615 (854–860). Это проверка DamageRate, фактическая потеря HP в этом сеансе не измерялась.
- VFX: два weak Flight scale и два weak Blast scale подтвердили write/readback, strong blast прошли vanilla, VFX SKIP/FAILED отсутствуют. Владелец подтвердил явную видимую разницу Fire strong/weak. Отдельный Fade A/B в этот smoke не входил.
- F7: старт 15 hooks (780), снятие script hooks и `STOP hooks_remaining=0`, затем обе native pre/post пары (862–879). Ice/Thunder, расширенный lifecycle и production acceptance вне этого прогона.
