# StaffRebalance — Staff VFX Feedback Research 01

**2026-11-09. Status:** UX concept + bounded external/host research; **NO executable VFX edits, NO runtime acceptance**, no acceptance of final scale/brightness values. Owner asked to study whether strong staff projectiles can retain the original large/bright VFX while weak staff projectiles become smaller, less bright and clearer. This extends [HUD Benchmark Research 01](HUD_BENCHMARK_RESEARCH_01.md): visual character of the shot itself can indicate strength without requiring constant HUD attention.

## Desired observable result, independent of technology

- **Strong** ordinary staff attack: retain vanilla visual presentation and gameplay semantics.
- **Weak** ordinary staff attack (no reserve): make the *rendered staff projectile and appropriate secondary impact/blast cues* perceptibly smaller, softer and less visually intrusive. Preserve projectile flight, collision, homing, impact timing, damage application path, elemental status/control, AP/APR and world interactions. At zero the staff is still usable, not disabled.
- Visual intensity must describe **that specific executed action**, not the current reserve at the time of rendering, and not the current wielded weapon. A final strong action can decrement reserve to 0 and leave a delayed **strong** Fire explosion visible after the next **weak** action has begun. This transition was already **game-tested for damage inheritance** in [DEV_PROTOTYPE_01](DEV_PROTOTYPE_01.md#fire-игровой-прогон-общего-dev-резерва--2026-11-08); it is **not** a visual-effect PASS.
- Use the same concept for Astral, Fire, Ice and Thunder, but do not assume the same VFX objects/parameters for all. Ice and Thunder remain gameplay **runtime NOT TESTED / deferred** until unlocked. Their optional cosmetic coverage may be statically scoped without demanding live proof now.
- Keep a small accessible reserve HUD for precise quantity/causality, even if the shot appearance communicates strong vs weak in the middle of combat. No visual-only cue should be the sole way to learn remaining charge count or the recovery rule.

## Existing third-party mods — what they genuinely establish

### Candidate A: [No-HUD-No-Effects (Gametism), Nexus mod 15](https://www.nexusmods.com/asterigoscurseofthestars/mods/15)

Published 2025-11-15, latest v0.3 2026-04-02. Author says it uses ReShade **ShaderToggler** to hide groups of HUD and effects. The documented groups include **CHARGE FX (LESS)** (Backspace), **HIT FX (LESS)** (Page Up), weapon swing/charge trails, shield effects, lighting, fog/volumetrics. This supplies a concrete **catalog of render-pass categories** worth examining while isolating visual noise. It does *not* prove that a selected group is specific to Hilda's basic staff projectile, nor identify particle/Blueprint owner or per-instance size.

[Original ShaderToggler readme](https://github.com/FransBouma/ShaderToggler/blob/main/README.md) confirms it toggles **marked pixel/vertex/compute shader groups** on/off, configured through ReShade, with group assignments saved to `ShaderToggler.ini`. This is a render-level selective suppression mechanism, not a documented API to set UE4 projectile-instance scale and brightness. The mod's links to additional source at `Gametism/ShaderTogglerAdvanced` were not retrievable in this research (404); exact package/config files were not inspected. ReShade/ShaderToggler may also affect other actors/effects sharing a shader. Its external trigger/timed-toggle functionality does not establish collision-safe per-spawn attribution.

**Copyright/permission:** Nexus author forbids reupload and modification of his files without permission. Use the publicly described grouping and independent observations as **research leads only**. Do not copy/repackage the mod's private toggle config, modified shaders or bundled binaries into StaffRebalance.

### Candidate B: [asterigos care package (thrive4), Nexus mod 7](https://www.nexusmods.com/asterigoscurseofthestars/mods/7)

Uses **3Dmigoto** shader tweaks; description includes global bloom reduction, tonemap, exposure, UI and some effect masks. Its reducing bloom/lighting is relevant as an image-comfort reference, but it is **global or shader-category-level**, so it is not sufficient for "vanilla strong and weaker only on a particular staff attack". The mod itself is not inspected locally; no evidence its tweaks shrink staff projectile geometry.

### Research status for user's unnamed reference

These are two **plausible independently verified public examples**, particularly A for effects toggling; the user has not supplied a name or archive in this conversation. **Do not assert that either is definitely the exact mod the owner meant.** If the owner later supplies the exact archive/link, inspect its own packaging and usage terms and narrow the map of effect groups. No installation, 3Dmigoto/ReShade injection or alterations to existing mod loadout are authorized by this research alone.

## Technical solution-space checkpoint

| Option | Can strong/weak differ per *actual* projectile? | Risk / constraints | Current choice |
|---|---|---|---|
| Render-layer shader suppressor (ShaderToggler/3Dmigoto) | **Not established**; groups act on draw shaders, may span both strong/weak and other objects | External injection, possible shared shaders, poor delayed-parent attribution, no reliable size change | **Reference and diagnostic aid only** |
| Change scale of whole `BaseProjectile` / Actor | Could affect appearance | **Unsafe assumption:** actor scale can propagate into collision, overlap geometry, child transforms, flight offsets; cannot promise visuals-only | **Reject pending strong safety proof** |
| Per-instance **cosmetic-only** particle/component and material parameters on exact projectile / child VFX | **Potentially yes**, keyed by already recorded action mode | Need exact component tree, effect owners, UFunction/parameter names and write timing. Setting arbitrary parameter names or global material assets is not proven | **Preferred bounded research target** |
| Replace cooked Niagara/Cascade/material assets wholesale or alter global bloom | Broad style change, potentially technically viable | Distribution/licensing, collision between mods, unrelated objects, updates, no per-shot state | **Not first candidate** |

UE4.27 has general documented particle parameter and dynamic-material mechanisms ([Niagara 4.27](https://dev.epicgames.com/documentation/unreal-engine/niagara-quick-start?application_version=4.27), [particle material DynamicParameter](https://dev.epicgames.com/documentation/unreal-engine/particle-expressions?application_version=4.27)), but **these only prove the engine supports such concepts**, not that Asterigos' staff effects use compatible parameterized Niagara or Cascade emitters, exposed UE4SS functions, or any particular `brightness` or `size` name. Do not implement a guessed `SetFloatParameter`, transform or material write without asset/component evidence.

## Smallest useful evidence slice

1. Start from the exact accepted staff sources [STAFF_ELEMENTAL_COVERAGE_01](STAFF_ELEMENTAL_COVERAGE_01.md): `hilda_staff_bolt_astral_C`, `hilda_staff_bolt_fire_C`, `hilda_staff_bolt_ice_C`, `hilda_staff_bolt_thunder_C`, exact `ProjectileDataName` guards, and Fire child `sphere_200_C`, Ice separate `sphere_150_C` hit and VFX. Locate **only the visual components/emitters and rendering/material references** of one accessible Astral/Fire basic projectile, then any visual child. Use retained host exports or a tiny read-only component inspection before building a new observer. Distinguish render-only components from root/collision/movement/scene and damage actors.
2. Confirm whether usable **instance-local** renderer parameters exist for intensity/emissive color/opacity and size on the actual cooked assets, and exact time they are safe to change after spawn. If particle size is baked with no instance override, consider a **cosmetic child-component local scale only** once proven not to affect collision, trace, homing or spawn positioning. Never scale the root Actor or shared asset in the first experiment.
3. Reuse *existing action identity* for visuals. Astral direct `session.shots` mode; Fire bolt mode with existing `fireParents` and child exact row/owner; Ice `iceParents` for repeated hit/VFX children with explicit row/parent guards; Thunder direct source where available. Do **not** infer strong/weak from current `session.reserve`, because reservation is debited on first actual projectile and older strong impact can outlive a new weak shot.
4. Build one **Astral or Fire weak-only VFX candidate** with untouched vanilla strong objects, readback/rollback and bounded GameThread callbacks; preserve current gameplay tests. Check immediate and delayed effects separately. If the first asset has no safe scoped cosmetic writable seam, document and stop; compare simpler renderer-only fallback in light of actual acceptance needs rather than expanding to global hooks, binary patches or asset re-cooking.
5. Before claiming success, run one targeted A/B with strong vs weak **same element** and same camera conditions, including projectile **flight and explosion**, HUD with CombatHUD 0.4.1, high/low brightness backgrounds, clarity of aim/target identification, no missing impact cues and unchanged collision/interaction. Exact source SHA, closed log and rollback. This must remain a separate visual/gameplay gate; CI/mock cannot prove actual brightness/perceived size.

## Design/UX recommendation

**Two-channel feedback:** (a) persistent compact indicator communicates **number of empowered shots and how recharge works**; (b) projectile appearance communicates **whether this particular shot is strong or weak**, including when HUD is dimmed. Strong retains vanilla brightness/size; weak reduces both moderately at the effect owner level, preserving enough trail/impact to recognize hit direction, element and successful contact. A dim/empty reserve must never suggest staff ability is locked.

Do not hardcode final weak VFX scale/intensity before comparing actual footage; 50% gameplay damage is **not** evidence that 50% emitted light or 50% rendered particle size gives a perceptually matching contrast. Do not alter VFX of melee, enemy projectiles or scene effects. Avoid screen-global toggles and third-party dependency merely to realize one local event.

**Verdict:** the user's idea strengthens diegetic/combat-readability substantially and is worth prototyping as a separate **cosmetic-only** stream, in parallel with HUD. Technical implementation seam is **RESEARCH REQUIRED**, not READY. First bounded step is identifying Astral/Fire projectile visual components and allowed instance-local controls, using the two Nexus mods as pointers, not as source to transplant.

## Bounded component audit — 2026-11-09 (public evidence, static only)

**Question:** can the actual Astral/Fire basic shot's *render-only* effect, not its damaging Actor/geometry, be made smaller and dimmer **per executed weak shot** while strong remains vanilla? **Verdict at this access level: partially resolved.** The exact gameplay classes, stable per-projectile mode and Fire child provenance are verified. A concrete particle/light/mesh component name, material instance or writeable value **has NOT been verified**; therefore no safe executable VFX change is READY.

### Actual target classes and existing mode source

| Shot/effect | Established concrete actor class / relation | Relevant exact-row/mode evidence | Confirmed VFX component name |
|---|---|---|---|
| Basic Astral | `hilda_staff_bolt_astral_C` deriving from `BaseBoxProjectile_BP_C` | `ProjectileDataName=hilda_staff_bolt_astral`; `session.shots[sourceId]=strong/weak` in [current dev source](../dev/StaffRebalanceDev/Scripts/main.lua) | **UNKNOWN** |
| Basic Fire carrier | `hilda_staff_bolt_fire_C` deriving from `BaseSphereProjectile_BP_C` | `ProjectileDataName=hilda_staff_bolt_fire`; `session.shots` / `session.fireParents` | **UNKNOWN** |
| Basic Fire delayed explosion | `sphere_200_C`, created from Fire bolt's hit timeline | `ProjectileDataName=hilda_staff_bolt_fire_explosion` and checked Actor Owner = exact accepted parent (live), `fireParents[parentId]` | **UNKNOWN** |

These are **damage/projectile Actors**, not evidence that any one of them is the luminous renderer itself. A glow could be a component on the actor, an inherited base-class component, or a separately spawned emitter during BeginPlay/flight/impact. In particular `sphere_200_C` is a **damage Actor**, not proof that the visible Fire blast is a particle component inside the sphere.

**Existing evidence inputs:** [research/static-combat-01/EVIDENCE.json](../research/static-combat-01/EVIDENCE.json) records prior CUE4Parse 1.2.2 `ReadScriptData=true`, `GAME_UE4_27` and byte-identity:
- `hilda_staff_bolt_astral.json` SHA-256 `19659b7e9e21a07fb652959ebc8862a1921f46cc801599eb933601d50f7e3a0a` (187866 bytes)
- `hilda_staff_bolt_fire.json` SHA-256 `90a57d6457de86ea58db185c849844392fce3cb7bfc5db5d0ec0185f348bdfb1` (223085 bytes)
- `BaseBoxProjectile_BP.json` SHA-256 `e7db8895008af4e2faba655d39c4b135dd33c87e4742bf902807d78879b313cd`
- `BaseSphereProjectile_BP.json` SHA-256 `66f16097ce27f06287cc01f2d61ba6972ffbce63410f10dca6d197f55118bbf7`
- `BaseProjectile_BP.json` SHA-256 `38005205f7e305c56f1345ee478af30b2955d94bd012c0a75e5852e51eaf821c`
- `hilda_staff_bolt_astral--ExecuteUbergraph_hilda_staff_bolt_astral.bytecode.json` SHA-256 `252e803aa36a9a3cc37853623a9e76a9c15ba562895be804f2b9f6c0959889cb`.

**Access boundary verified:** in the public repo `research/static-combat-01/` contains **only `EVIDENCE.json`**. Raw game-derived exports are deliberately ignored and retained on the local research machine, not on GitHub. A check of existing StaffRebalance/central Asterigos-Research documents and public GitHub code search found **no exact Astral/Fire rendering component list**. No local cooked JSON or installed-game processes can be reached through this GitHub research. Therefore claiming e.g. `ParticleSystemComponent_0`, `PointLight` or `EmissiveIntensity` as a confirmed game property would be fabricated.

### UE4.27 API feasibility versus proven game feasibility

1. Unreal 4.27 Cascade effects have **instance-controlled distributions/parameters only if the cooked particle asset actually exposes them**. [Epic — Key Particle Concepts](https://dev.epicgames.com/documentation/en-us/unreal-engine/key-particle-concepts?application_version=4.27), [Parameter Modules](https://dev.epicgames.com/documentation/unreal-engine/parameter-modules?application_version=4.27), [Particle Expressions](https://dev.epicgames.com/documentation/en-us/unreal-engine/particle-expressions?application_version=4.27). A generic `UParticleSystemComponent:SetFloatParameter(FName,value)` function does **not** create a meaningful brightness/size channel unless it is consumed by an existing module/material. [Epic UParticleSystemComponent](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UParticleSystemComponent/SetFloatParameter). This method may create a named instance-parameter entry **without changing a single rendered pixel**.
2. If the exact effect is a Niagara component rather than Cascade, inspect its **real exposed user/system parameters** separately; do not transpose Cascade parameter names or assume the game uses Niagara. [Epic Niagara Quick Start, UE4.27](https://dev.epicgames.com/documentation/en-us/unreal-engine/niagara-quick-start?application_version=4.27).
3. A visible `PointLightComponent` can in principle be adjusted per actor if it is owned only by the shot; a material can in principle use runtime scalar parameters if a **per-instance dynamic material** is held on an own renderer. The game-specific presence, parameter names, lifetime, setter order and ownership remain UNKNOWN. Never change a shared UMaterial/CDO/particle template, global bloom or root Actor scale.
4. Object class/row and action mode are already available in the accepted dev flow, so **no reserve poll, time guess or new combat hook is needed** to decide strong vs weak. The uncertain section is solely *which exact render component receives the change and when*. Astral's current code establishes `session.shots[sourceId]=mode`; Fire's `fireParents` handles a delayed explosion. Read-only VFX discovery should keep this identity rather than create a new currency/skill decision.

### Minimal read-only local follow-up — executable task for local Codex (no game launch)

**Purpose:** close the one material unknown by reading **already existing cooked exports**, not by installing a new UE4SS observer or using runtime polling.

1. Recover actual local Git/worktree state and apply DevRules `WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, repo `AGENTS.md`. Confirm the current remote `dev/reserve-core-01` HEAD and preserve all uncommitted/ignored content. Do not touch `main`, game payload, UE4SS installation, saves or third-party mods.
2. Locate the **pre-existing** five component-relevant exports above (plus any existing `sphere_200` cooked export, if present), and check their SHA-256 against this manifest. Reuse the previously configured CUE4Parse reader only if a relevant extract is genuinely missing; no new dumper and no whole-game scan. If a file/hash is absent, mark only its evidence as unavailable rather than fabricating an equivalent.
3. Parse `ExportType`/`Class`, Blueprint CDO, `SimpleConstructionScript`/`USCS_Node`, `ComponentTemplates`, `InheritableComponentHandler`, inherited base components, and reference edges. Inventory concrete **particle/Niagara/static-mesh/light/trail/beam renderers**, their **full object path**, class, parent/attachment, CDO template and asset references. Separately inventory **collision/root/movement** components and their attachment ancestry, so no renderer is mistaken for an Actor or physics owner. The component list may be empty if effects are spawned dynamically.
4. Scope the existing Astral and Fire Blueprint bytecode/event graphs and relevant `BaseProjectile` ancestor to **render-affecting spawn/activate/attach calls** (`SpawnEmitterAtLocation/Attached`, Niagara spawn, light activate, component visibility/scale, material changes) and to source assets used by the flight/trail/impact. For the delayed Fire blast also trace `sphere_200_C` and any separate effect spawn in the **Fire hit timeline**. Record offset/graph path and which actor owns each result. Do not treat substring matches as execution evidence or project rows as particle asset paths.
5. Inspect **only referenced** particle systems/material instances and any named exposed parameters for size, alpha/emissive and light intensity; determine whether the relevant knob is **per-instance** and **cosmetic-only**. If the scalar is baked with no exposed parameter, report `NO VERIFIED PARAMETER`; do not propose a random name. For a proposed component-local relative scale, verify it has no collision/movement/damage child in its attachment subtree; otherwise mark unsafe. Material/DMI ownership and dynamic override lifetime must be explicit.
6. Produce a concise matrix per effect: `class + exact render component path + asset + template/parameter + owner + safe read/write candidate + timing/known risk + evidence reference (export SHA, object path/bytecode offset)`. Distinguish `VERIFIED STATIC`, `POSSIBLE ENGINE API`, `RUNTIME NOT TESTED`, `BLOCKED`. If there is at least one credible independent instance-local knob for **one** Astral or Fire effect, specify the smallest weak-only visual A/B runtime acceptance test; **do not implement** gameplay or VFX edits in this read-only pass.
7. Update **this report** and `docs/STATUS.md` only with decision-bearing findings, keeping raw game exports, screenshots, binaries and internal machine paths out of Git. Commit and push documentation on dev after checking a fresh HEAD; return SHA and a one-paragraph finding. Do not report visibility/brightness/scale PASS from static inspection alone.

**Stop rule:** after reaching a complete, referenced component/asset inventory for one accessible Astral/Fire flight effect and, if available, its matched impact effect, **stop**. If the exports do not include the renderer owner, record the exact missing dependency and recommend a single strictly bounded read-only in-game component observation *only then*. No general ProcessEvent hook and no global shader injector investigation.

### Current gate after this public-read audit

- **Confirmed:** source classes/rows, Astral and Fire per-shot strong/weak mode attribution, Fire parent of delayed explosion, precise existing export identities, generic UE4.27 parameterization capabilities and constraints.
- **Not confirmed:** exact game VFX component, particle/material asset, tunable parameter, isolation from gameplay/collision, safe timing and actual visual effect.
- **Implementation verdict:** **VFX cosmetic modification BLOCKED pending local static component inventory**; current staff damage and HUD research can continue unchanged. This is one finite static-data task, not a request to reopen previously accepted combat mechanisms.
