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
