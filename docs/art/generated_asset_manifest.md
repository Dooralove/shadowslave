# Generated asset manifest вЂ” 2026-11-02

**Pipeline:** Hyper3D CLI (`@hyper3d/cli 0.3.0`, OAuth) в†’ GLB в†’ Blender/Godot audit.  
**Canon source of truth:** user's Canon-Checked 3D Asset Bible, 2026-11-02.  
**Rule:** a generated mesh is not accepted until geometry, texture, rig and in-engine checks pass.

## 1. Intake / test entries

### Hero/Auro вЂ” prompt v1 (SUPERSEDED)

- **Raw file:** `incoming_models/P0_characters/hero_auro_gen_v1_raw.glb`
- **Rigged file:** `incoming_models/P0_characters/hero_auro_gen_v1_rigged.glb`
- **Generation ID:** `83cd825c-6284-4719-9960-840eb90d0c8e`
- **Rig generation ID:** `e6f0a97e-8ceb-4140-9992-75ed82a7de62`
- **Raw size:** 9,127,036 B вЂ” SHA-256 `37787f73a7966ee4ccbdc544fc92621fcbdfbe5471d04262d42ecb8e9477864e`
- **Rigged size:** 12,208,808 B вЂ” SHA-256 `4c0861a712acce1eb844594ad79d461468a85c28b5e84315214755944af6910b`
- **Geometry:** 60,000 tri, 46,272 verts, 1 mesh / 1 primitive, 1 material.
- **Textures:** base color 2048ВІ, normal 2048ВІ, metallic-roughness 2048ВІ (PNG, PBR). No tangents.
- **Rig:** 52-bone Mixamo-like humanoid; 1 clip `HumanStandingIdle`, 6 s; no root bone.
- **Dimensions:** 0.823 Г— 0.432 Г— 1.899 m; origin at center, feet at Zв‰€-0.95.
- **Visual:** strong silhouette, readable face, leather cuirass, boots, spear and short sword fused to the mesh.
- **Verdict:** **REJECTED as final** вЂ” prompt v1 fixed an age/gear interpretation that the canon-checked Bible rejects; weapons must be separate props; A-pose not achieved.
- **Keep as:** pipeline test only (rigging works; native human clip deforms without obvious explosion). Do not integrate into scenes.

**Pipeline lessons:**

- CLI generation is viable and cheap: 0.5 subscription credit for a 60k Raw/High model.
- CLI rigging works with `--bone-template human`; the backend rejects `--bone-template ue` with `Invalid tool input: data/bone_template must be equal to one of the allowed values`.
- The generated rig is a 52-bone Mixamo-style skeleton, not the project's 53-bone UE-style rig; native clips can be used, or a retarget pass is required for UAL.
- GLB origin is centered; a ground offset of ~0.95 m is required before placing the character in a scene.
- 2K PBR textures are 9 MB total; optimize to 1K/ORM and generate tangents after acceptance.

### Sunny real вЂ” prompt v2 (canon-checked)

- **Raw file:** `incoming_models/P0_characters/sunny_real_v2_raw.glb`
- **Generation ID:** `4f90c74d-9e60-463d-9c12-177856ab72bf`
- **Rig generation ID:** `f9955d67-2359-4385-ac14-7005ea900ebc` (10 presets)
- **Raw size:** 14,339,624 B вЂ” SHA-256 `e10691591953863c9f82efb5113e618479db4536049fb0652c50a7230d56a7bb`
- **Geometry:** 94,487 tri, 54,989 verts, 1 mesh / 1 primitive, 1 material.
- **Textures:** base color 2048ВІ, normal 2048ВІ, metallic-roughness 2048ВІ (PNG, PBR). No tangents.
- **Dimensions:** 0.580 Г— 0.331 Г— 1.896 m; origin at center, feet at Zв‰€-0.95.
- **Visual:** adolescent, slender, pale, tired face, dark circles, messy black hair, off-white knit sweater, dark trousers, sneakers. Arms down rather than strict A-pose; texture has small white marks on trousers (wear).
- **Verdict:** **ACCEPT GEOMETRY / NEEDS_OPTIMIZATION + RIG CHECK**. Identity matches the updated brief; 94k tri is too high for the game budget, and the rig result is pending.
- **Next:** inspect 10 rendered clips, validate deformation, reduce to ~30k LOD0 + LODs, generate tangents, 1K/ORM textures.

### Hero/Auro вЂ” prompt v2 (canon-checked, no weapons)

- **Raw file:** `incoming_models/P0_characters/hero_auro_v3_raw.glb`
- **Rigged file:** `incoming_models/P0_characters/hero_auro_v3_rigged.glb`
- **Generation ID:** `f619b108-8e69-43af-b4f1-b01f5fafc10f`
- **Rig generation ID:** `054efedc-676b-4b6e-a37b-3069f0dcb397`
- **Raw size:** 10,486,196 B вЂ” SHA-256 `f87c1f0864140b454018fd97250d1154c50f1c20c5b4bb0b55a7939e07753b83`
- **Rigged size:** 13,497,612 B вЂ” SHA-256 `5893f3b514ba4a598d609191363aed3fe4118013ccd9970376ea9c814f7f04f9`
- **Geometry:** 92,411 tri, 51,386 verts, 1 mesh / 1 primitive, 1 material.
- **Textures:** 2048ВІ base color, normal, metallic-roughness; 12.5 MB raw; no tangents.
- **Rig:** 52-bone Mixamo-like humanoid; 7 clips: `HumanStandingIdle`, `HumanRelaxedWalkLoopF`, `HumanSprintLoop`, `HumanCounterAttack`, `HumanDeath`, `HumanSit`, `HumanRoll`.
- **Visual:** correct simple leather cuirass, dark tunic, boots, no weapons. Young adult, borderline older than the brief but acceptable as art direction.
- **Rig verdict:** **NEEDS_WEIGHT_CLEANUP / RETOPO** вЂ” a long brown strap/ribbon near the right wrist and tunic hem stretches during walk/attack. Deleting candidate islands (belt flap, bracer strap) did not remove it; it is part of a larger mixed island. Do not integrate as final. Blender retopo/weight transfer required.
- **Do not use:** `hero_auro_gen_v1_*` (fused weapons, older prompt).

### Mountain King вЂ” prompt v2, first generation

- **Raw file:** `incoming_models/P0_characters/mountain_king_gen_v1_raw.glb`
- **Generation ID:** `1cfda560-68c0-4b30-bcc9-080e3c3eab2c`
- **Size:** 23,438,556 B
- **Geometry:** 150,000 tri, 176,407 verts, 1 mesh / 1 primitive, 1 material.
- **Textures:** 2048ВІ base color, normal, metallic-roughness; 15.99 MB; PBR. No tangents.
- **Dimensions:** 1.901 Г— 1.109 Г— 1.810 m (project scale; scale up in Godot).
- **Visual:** excellent fur/face/maw/texture, two long clawed arms, two stumpy legs, five-ish milky eyes, worm-like chest growths, **no horns/armor/tail**.
- **Canon verdict:** **REJECT** вЂ” only the two long arms read; the required second pair of shorter human-fingered arms is not visible/functional. High visual quality cannot override the four-arm anatomy.
- **Keep as:** texture/face reference and fallback for a later two-short-arm add/retopo.
- **Next:** regenerate with a stronger four-arm prompt, or add two short arms in Blender and rig them.

### Mountain King вЂ” Image-to-3D concept (ACCEPTED BY USER)

- **Concept:** `incoming_models/concepts/mountain_king/photo_2026-11-02_18-47-57.jpg` (user-approved; horns/eye count are accepted art direction).
- **Raw file:** `incoming_models/P0_characters/mountain_king_gen_image_raw.glb`
- **Raw generation ID:** `66a2410e-1025-4124-ba8a-b6da2b96f50f`
- **Size:** 19,200,276 B; 120,000 tri, 138,257 verts, 2K PBR.
- **Rigged file:** `incoming_models/P0_characters/mountain_king_gen_image_rigged.glb` (custom 60-bone rig: base human + extra left/right arm chains; no clips).
- **Custom-animation run:** `46aedcfd-45c4-475b-af06-528f99903db1` (human presets on the custom rig; pending).
- **Visual:** excellent match to the approved four-arm horned concept; all four arms read, long claws, fur, maw, textures.
- **Verdict:** accepted base + custom rig; animation pass pending.

### Carapace Scavenger вЂ” Image-to-3D concept (ACCEPTED BY USER)

- **Concept:** `.../carapace_scavenger/photo_2026-11-02_18-47-24.jpg` (user-approved).
- **Raw file:** `incoming_models/P1_monsters/carapace_scavenger_gen_image_raw.glb`
- **Raw generation ID:** `562eef84-bfd5-4ab5-9de3-149957def7e3`
- **Size:** 14,690,652 B; 120,000 tri, 103,079 verts, 2K PBR.
- **Custom rig:** `carapace_scavenger_gen_image_rigged.glb` вЂ” **38 bones**: shell/spine/head, two pincer arms, eight leg chains (4 pairs). No clips.
- **Visual:** strong crab-centaur silhouette, eight legs and two pincers; accepted concept is preserved.
- **Verdict:** accepted base + custom rig; needs authored 5 clips (idle/walk/telegraph/attack/death) and integration.

### Carapace Centurion вЂ” Image-to-3D concept (ACCEPTED BY USER)

- **Concept:** `.../carapace_centurion/photo_2026-11-02_18-46-10.jpg` (user-approved).
- **Raw file:** `incoming_models/P1_monsters/carapace_centurion_gen_image_raw.glb`
- **Raw generation ID:** `8ca2d452-2058-4eb5-951c-c053de22ab20`
- **Size:** 17,468,020 B; 120,000 tri, 120,598 verts, 2K PBR.
- **Human rig attempt:** `carapace_centurion_gen_image_rigged.glb` вЂ” 52 bones, 5 clips; **rejected** due severe armor/leg deformation.
- **Custom rig:** `carapace_centurion_gen_image_custom_rigged.glb` вЂ” **54 bones**: humanoid base + `LeftScythe`/`RightScythe`; no clips.
- **Visual:** strong scythe-armed armored centurion, accepted concept.
- **Verdict:** accepted base + custom rig; needs animation pass (scythes must be keyed).

### Hero/Auro вЂ” Image-to-3D concept v2 (ACCEPTED)

- **Concept:** `incoming_models/concepts/hero_auro/photo_2026-11-02_18-50-31.jpg` (user-approved); cropped views in `.../image2d/`.
- **Raw file:** `incoming_models/P0_characters/hero_auro_v6_image_raw.glb`
- **Rigged file:** `incoming_models/P0_characters/hero_auro_v6_image_rigged.glb`
- **Raw generation ID:** `9e652ed5-dfb2-484a-bd2b-29b147455953`
- **Rig generation ID:** `56849a40-ffae-4dea-a695-0f58de65c9a3`
- **Raw size:** 14,708,808 B вЂ” SHA-256 `25452923c742421de66c0795fa59955aef476643f589312d41f79e7e81532afe`
- **Geometry:** 90,000 tri (rigged), 49,139 verts, 1 material, 2K PBR maps.
- **Rig:** 52 bones; 7 clips (`HumanCounterAttack`, `HumanDeath`, `HumanRelaxedWalkLoopF`, `HumanRoll`, `HumanSit`, `HumanSprintLoop`, `HumanStandingIdle`).
- **Visual:** young male, brown hair, dark blue tunic, leather cuirass with cross straps, bracers, short armored skirt, tall boots; no weapons. The concept is preserved well.
- **Rig check:** idle/walk/counter/death read cleanly; no cloth-ribbon artefact in the previewed frames. Some foot sliding and soft facial texture remain.
- **Verdict:** **ACCEPTED base**; needs LOD optimization, tangents/single-sided, texture resize, and final in-engine test.
- **Supersedes:** Hero v3/v5 and the old v1/v2 text-only generations.

### Hero/Auro вЂ” prompt v3, simplified short tunic

- **Raw file:** `incoming_models/P0_characters/hero_auro_v5_raw.glb`
- **Generation ID:** `ce3cbb30-ece2-4132-8e66-b302d39ad2c3`
- **Size:** 10,510,936 B вЂ” SHA-256 `49b94e1217e6f780e5c62a9b57bf8d7045484018f2da4a1a6a46f900472c4d38`
- **Visual:** no weapons, short tunic, no bracers; but the face reads as a 30-year-old bearded strongman, not the young noble soldier; still has a tunic skirt and belt tail.
- **Verdict:** **REJECT as canon** вЂ” simpler for rigging, but the identity/age/silhouette moved away from the brief. Hero v3 is the better face/cuirass; it needs retopo, not a new generic body.
- **Lesson:** text-to-3D ignores fine identity/age constraints; Hero needs an approved concept image + Image-to-3D.

### Mountain King вЂ” prompt v2, second generation (four-arm emphasis)

- **Raw file:** `incoming_models/P0_characters/mountain_king_gen_v2_raw.glb`
- **Generation ID:** `9b9eed3c-15d9-4277-aac0-0c8474ab8d89`
- **Size:** 22,086,944 B вЂ” SHA-256 `520ae24b025c3c396861aeb77bad4b5aabfe938d851821d16666a0a8e35f5ac8`
- **Visual:** same high-quality fur/face; no horns, no armor; two long clawed arms; the lower pink structures read as parasitic worms, not a second pair of human-fingered arms.
- **Canon verdict:** **REJECT** вЂ” four-arm silhouette still fails. Text-to-3D is not preserving the extra short arms; needs an approved front/side/back concept and Image-to-3D, or manual arms+rig.

### Carapace Scavenger вЂ” prompt v2 (eight legs, humanoid torso, pincers)

- **Raw file:** `incoming_models/P1_monsters/carapace_scavenger_gen_a_raw.glb`
- **Generation ID:** `e5eb4672-de97-4cb4-9948-6dee0dcf978f`
- **Size:** 16,452,712 B вЂ” SHA-256 `a0ecf225f11928076fb3f4d2bb6a618afde9da7ed13da2d266011a39cbc4e8b5`
- **Visual:** strong chitin, humanoid torso, two pincer arms, eight spider-like legs; shoulder plates and a **humanoid skull face with teeth and two eyes**, plus head horns.
- **Canon verdict:** **NEEDS_RETOPO / FACE FIX** вЂ” the required no-neck head with two narrow eye slits and several wet mandibles is not there; the face reads as a horned humanoid skull. Use as body/legs reference, but head/face and shoulder armor must be rebuilt or regenerated from a concept.
- **Do not use** current procedural `carapace_scavenger` as final either; v2 texture pass is integrated for tests only.

### Sunny real вЂ” prompt v2, core rig with 10 clips

- **Rigged file:** `incoming_models/P0_characters/sunny_real_v2_rigged_core10.glb`
- **Generation ID:** `4f90c74d-9e60-463d-9c12-177856ab72bf` (raw), `091a5de2-51a1-4dce-99ab-48e0cfefd8af` (core10 rig)
- **Size:** 17,797,800 B вЂ” SHA-256 `2919a1fbc4a147500440c2e9e2cecbdedf5abbb84ff63e99e9bd730be0a261aa`
- **Rig:** 52 bones; 10 clips: idle, walk, sprint, boxing, roll, head hit, death, sit, jump, land-roll.
- **Verdict:** **ACCEPT RIG / NEEDS_OPTIMIZATION** вЂ” core skinning removes the shell method's exploded sweater; walk/boxing/death read correctly; slight underarm pinch remains. 94k tri and 2K textures are too heavy for final; optimize.
- **Rejected:** `sunny_real_v2_rigged.glb` (shell skinning; severe sweater shards).

## 2. Accepted assets

_Sunny real v2 core10 is conditionally accepted pending optimization/in-engine test; Hero v3 requires retopo/weight cleanup; Mountain King is in progress._

## 3. Rejected / archived

| Asset | Reason |
|---|---|
| `hero_auro_gen_v1_raw.glb` | prompt v1: fused weapons, older-looking than updated brief, not A-pose |
| `hero_auro_gen_v1_rigged.glb` | same, plus Mixamo rig not UAL-compatible |

## 4. Pipeline verdict (2026-11-02)

Text-to-3D via CLI is **good for base geometry and textures**, but **not reliable for canon-critical identity or complex anatomy**:

- Sunny: identity/silhouette work; core rig is usable; best current generated character.
- Hero: two attempts gave either a good-but-unriggable face/cuirass (cloth strap artifact) or a riggable-but-generic older man. Needs concept-first Image-to-3D and retopo.
- Mountain King: both attempts produced a high-quality **two-armed** ape; the required second pair of shorter human-fingered arms is absent. Rejected. Needs a front/side/back concept and Image-to-3D, or manual arm construction.
- Carapace: eight legs and pincers read, but the head is a horned humanoid skull with two eyes; the no-neck eye-slit/mandible face is wrong. Needs face rebuild/concept.
- **Decision:** for the remaining complex characters/monsters, use **Image-to-3D with approved front/side/back concept art**; do not burn credits on more text-only prompts for the same anatomy. Humanoid NPCs may still use text prompts if they have simple clothing.

## 5. Integration status (2026-11-02)

- **Hero/Auro v6:** integrated through `Mannequin` as `hero`/`auro`; native 52-bone AnimationPlayer branch added. `test_caravan_site`, `test_pilgrim_path`, `test_full_route` вЂ” **20/20, 1012 assert**. Capture: `docs/art/previews/generated/hero_auro_v6_raw.png`.
- **Carapace Scavenger generated:** custom 38-bone rig + 5 authored clips (`Idle`, `Walk`, `Telegraph`, `Attack`, `Death`) integrated into `scenes/enemies/carapace_enemy.tscn`. `test_carapace_enemy` + `test_combat_arena` вЂ” **11/11, 43 assert**. Capture: `docs/art/previews/generated/carapace_scavenger_image_raw.png`.
- **Sunny real v2 core10:** accepted asset; native 52-bone rig with 10 clips. Integration into `sunny_waking_poc` is still pending; the current campaign still uses the POC UAL model.
- **Mountain King image-to-3D:** raw model and 60-bone custom rig accepted; human-preset animation and rigid-weight test show fur/armor plate explosions. Do not integrate; fallback `mountain_king_p3` remains.
- **Carapace Centurion image-to-3D:** raw model and 54-bone custom rig accepted; human-preset and rigid-island animation both show detached plates. Do not integrate; needs retopo/weight pass.
- **Procedural Carapace v2 / p3 / P1 models:** retained as fallbacks; Hero v6 replaces only the Hero/Auro render path.

## 6. Checklist per accepted asset

- [ ] exact filename/SHA-256
- [ ] tri/vert count, materials, UVs, tangents
- [ ] base color/normal/roughness/metallic maps
- [ ] bbox, origin, scale, forward axis
- [ ] front/side/back/wireframe renders
- [ ] rig bones, weights, rest pose
- [ ] animation clips and loop modes
- [ ] Godot import, lighting, LOD, draw calls/VRAM
- [ ] canon verdict ACCEPT / NEEDS_RETOPO / REJECT

## 7. Late intake вЂ” 2026-11-02 evening

These are raw Hyper3D outputs generated after the first manifest pass. They are **not integrated**; the preview paths are under `docs/art/previews/generated/`.

### White horse вЂ” `white_horse_v2_raw.glb` (SUPERSEDES v1)

- **Generation ID:** `26bd4fcf-2bd3-49eb-830c-a20b49fff7bd`
- **Reference:** `incoming_models/concepts/white_horse/reference.png`, cropped from the public-domain Wikimedia Commons photo `White horse.jpg` (Rosendahl).
- **Size / hash:** 19,347,916 B вЂ” SHA-256 `1DB4B2115C53F5C8ACEEF5EFD891CB75AA2E4207ADE8074FDC0ECA25A619B40F`
- **Geometry:** 120,000 tri, 86,776 verts, 1 mesh / 1 material, 120k raw; dimensions 0.896 Г— 1.904 Г— 1.852 m; origin centred.
- **Visual:** correct horse anatomy and readable head/legs/tail; white leopard-spotted coat, pale mane/tail, **dark halter remains from the reference**.
- **Rig:** `white_horse_v2_rigged.glb`, generation ID `10ad659e-8c00-487d-988d-6a63aced1b3e`; quadruped template, `core` skinning, 33 bones. Ten native `LeanHooved` clips: idle, walk, trot, run, walkstart, walkstop, trotstart, runstop, tosshead, standup. Walk/idle deformation reads correctly.
- **Verdict:** **SUPERSEDED by the clean stock horse in section 9.** The generated scan/rig remains a rejected experiment; it is not used in a scene.
- **Preview:** `docs/art/previews/generated/white_horse_v2.png`, `white_horse_v2_rigged.png`

### Blood Flower host вЂ” `blood_flower_gen_b_raw.glb` (ACCEPT BASE)

- **Generation ID:** `2de76adc-ae6c-4537-9bf8-c0ad545dc9d5`
- **Size / hash:** 20,654,448 B вЂ” SHA-256 `33C43896D4634F0F86FB5B7099DEBA838D63E95B304FBC9B5818F782DCB88368`
- **Geometry:** 120,000 tri, 132,656 verts, 1 mesh / 1 material; dimensions 1.861 Г— 1.040 Г— 1.899 m.
- **Visual:** dark grey gorilla-like primate host, exactly two tusks, several red fleshy flowers on the face/chest/shoulder, pale parasite stems, blood wounds. Much closer to the approved host concept than the white v1 gorilla.
- **Verdict:** **ACCEPT RAW / NEEDS_RIG + CRIMSON TINT** вЂ” flower petals read pink rather than deep crimson; tint the flower material, keep pollen as VFX, add a custom rig (spine/arms/legs/flowers optional). Do not replace the procedural fallback until a clip set exists.
- **Preview:** `docs/art/previews/generated/blood_flower_v2.png`

### Giant centipede вЂ” `centipede_gen_a_raw.glb` (ACCEPT BASE)

- **Generation ID:** `9968cc2b-5be9-4dfc-92da-df113cdf9fea`
- **Size / hash:** 14,579,176 B вЂ” SHA-256 `6EE9D98F7E5897635D488B84CC3F46BA67FDE478A44C8F98DF287ED19E2414B5`
- **Geometry:** 120,000 tri, 86,734 verts, 1 mesh / 1 material; dimensions 1.087 Г— 1.899 Г— 0.462 m.
- **Visual:** long segmented body, consistent leg pairs, readable head and tapering tail; no duplicate heads. Material is too clean/shiny for wet dark chitin.
- **Verdict:** **ACCEPT SILHOUETTE / NEEDS_MATERIAL + RIG** вЂ” darken/roughen the chitin, add mandible detail, rig with a spine/leg chain; the static mesh is not a final enemy.
- **Preview:** `docs/art/previews/generated/centipede_v1.png`

### Worm colony вЂ” `worm_knot_gen_b_raw.glb` (SUPERSEDES v1)

- **Generation ID:** `732ddfd1-6481-44b3-82b3-b8f94faf137a`
- **Size / hash:** 15,428,148 B вЂ” SHA-256 `FC955F0B78F2D37AA78821E0A200EB1EAAE3001D37B859B483D5478D2C5A500D`
- **Geometry:** 120,000 tri, 1 mesh / 1 material; low tangled cluster dimensions.
- **Visual:** several distinct segmented worms with visible mouths and overlapping bodies, not a single donut. Still pale pink/white; the canon calls for muted pale-grey and dark red.
- **Verdict:** **ACCEPT BASE / NEEDS_MATERIAL + SIMPLE RIG** вЂ” darken and desaturate the skin, add wetness, rig a slow writhe or use a procedural shader; v1 is rejected.
- **Preview:** none yet; use `docs/art/previews/generated/` after the next render pass.

### Police desk / patrol вЂ” `police_desk_v2_raw.glb`, `police_guard_v2_raw.glb`

- **Generation IDs:** desk `b763ff2e-b5c4-42a2-8e91-c29ce902e8c9`; patrol `9c145a5c-37fe-4b24-a749-8291a7cc1e00`.
- **Sizes / hashes:** desk 10,395,016 B вЂ” SHA-256 `94AD66D1244578ADB29E1D335FF957CEA69D90EEAFB26E0606050887050DD5F2`; patrol 11,111,304 B вЂ” SHA-256 `6E7913A37886211D403C66CF777E3610C829B7F20CFD5C83AD1C0878C8544790`.
- **Geometry:** desk 90,339 tri / 49,740 verts; patrol 87,738 tri / 49,887 verts; 1 material each; ~1.9 m tall, unrigged.
- **Visual:** modern police uniform and gear read correctly; faces are still semi-stylized, not at the Sunny-v3 photorealism level.
- **Verdict:** **PLACEHOLDER ONLY** вЂ” keep P1 rigged `police_desk`/`police_guard` in scenes until these are rigged and retextured; do not swap in an unrigged body.
- **Previews:** `docs/art/previews/generated/police_desk_v2.png`, `police_guard_v2.png`.

### NPC realism tests вЂ” `veteran_v4_raw.glb`, `broad_slave_v2_raw.glb`

- **Generation IDs:** veteran `d30f27c3-61fa-49a3-8a75-48e83b43825e`; broad slave `aa6a6e1d-bc0e-45c6-a84e-5294ca0022b1`.
- **Sizes / hashes:** veteran 13,274,404 B вЂ” SHA-256 `22C91BF2C218A7B6EAC3C9A72395D5097140A58BE18691D3F236B83FCF64F18E`; broad slave 14,953,992 B вЂ” SHA-256 `5BD42E5CB5ADF60F35F5B684090967ABE72B70BDD58D67640C334BCC7DE0DAD9`.
- **Visual:** both remain **stylized fantasy caricatures** (oversized shoulders, exaggerated faces, cartoon musculature) despite explicit photoreal/3D-scan prompts.
- **Verdict:** **REJECT FOR STYLE** вЂ” do not integrate. Keep the existing P1 rigged models as fallbacks.
- **Pipeline conclusion:** text-to-3D humanoids cannot hit the new Sunny reference style. The only model that matched it was **Sunny v3 via Image-to-3D from a realistic reference**. Shifty, Scholar, Veteran and BroadSlave need realistic front/side/back concept sheets or a realistic 3D-scan source; further text prompts are wasted credits.

## 8. NPC style v2 and integration вЂ” 2026-11-03

The four main P0 NPCs were retried with simplified clothing and explicit "photorealistic 3D scan" prompts. They are still **semi-stylized**, not at the Sunny-v3 photorealism level, but they are grounded, correctly proportioned and substantially better than the P1 caricatures. All four were rigged with the 52-bone human template, `core` skinning and the same 10 native clips, then integrated through `Mannequin`.

| Asset | Rigged file / SHA-256 | Tri | Integration | Verdict |
|---|---|---:|---|---|
| Shifty v4 | `incoming_models/P0_characters/shifty_v4_rigged.glb` вЂ” `D6E6FA79CC8199514AE49A45301445924C4D5C7350B860730E0865ED792EF822` | 120,080 | `assets/characters/generated/shifty_v4/`, `Mannequin` key `shifty` | **ACCEPT PLACEHOLDER / NEEDS_POLISH** |
| Scholar v3 | `incoming_models/P0_characters/scholar_v3_rigged.glb` вЂ” `291D767903AB454BCDE5246A2691E4F55590623762E5B21B779C1E5FF7C9F9DB` | 120,080 | `assets/characters/generated/scholar_v3/`, `Mannequin` key `scholar` | **ACCEPT PLACEHOLDER / COAT WEIGHTS** |
| Veteran v5 | `incoming_models/P0_characters/veteran_v5_rigged.glb` вЂ” `664E92628E871E706783CEC214D8180C1F4CD0B8B4EE5CB917D049F0526F8812` | 120,080 | `assets/characters/generated/veteran_v5/`, `Mannequin` key `veteran` | **ACCEPT PLACEHOLDER / NO FUR MANTLE** |
| Broad slave v3 | `incoming_models/P0_characters/broad_slave_v3_rigged.glb` вЂ” `91A337E50C28EFEEFAD493D6B5BD8EDED11ABFCE1A08E78DFF5F854D0A7457C7` | 120,080 | `assets/characters/generated/broad_slave_v3/`, new `Mannequin` key `broad_slave` | **ACCEPT PLACEHOLDER / NEEDS_POLISH** |

**What changed in-engine**

- `Mannequin` now resolves `shifty`, `scholar`, `veteran` and `broad_slave` to the generated wrappers. The old P1 models remain in the repository as fallbacks.
- Generated humanoids use their native 52-bone `AnimationPlayer`; `Mannequin` builds `WalkClean` from `HumanRelaxedWalkLoopF` and loops idle/walk/run/sit. No UAL retarget is involved.
- `BroadSlave` in `caravan_site.tscn` uses `archetype="broad_slave"` and `height_scale=0.975` (1.85 m target). `Scholar` height was raised to 0.98 (1.86 m). Shifty stays 0.93 (1.75 m); Veteran stays 0.95 (1.80 m).
- **Verification:** targeted GUT `test_caravan_site`, `test_pilgrim_path`, `test_full_route`, `test_carapace_enemy`, `test_combat_arena` вЂ” **36/36, 1077 asserts, exit 0**; full GUT вЂ” **636/636, 7333 asserts, exit 0**. LOD/VRAM, hand contact and long-session visual tests remain **NOT TESTED**.

**Known defects (do not call final)**

- Scholar's coat back/right shoulder balloons during idle/walk; needs coat weight cleanup or a shorter coat.
- Shifty and Broad hands/fingers are still soft and slightly claw-like; Veteran's face/hair reads older and more CG than the reference.
- All four are 120k tri with no LOD, 2K textures and embedded PBR; optimize to ~30вЂ“40k LOD0 + LOD1/2, 1K ORM, tangents and single-sided materials before release.
- They are still **semi-stylized**, not photoreal. A realistic concept/reference sheet per NPC is the route to the Sunny-v3 level; retrying the same text prompts is not.

**Previews:** `docs/art/previews/generated/npc_integration/front3/{shifty,scholar,veteran,broad}.png` (front close-ups in the caravan scene).

## 9. Mountain King / Nightmare / horse вЂ” 2026-11-03

### Mountain King вЂ” custom native clips + integration

- **Raw/rig:** `incoming_models/P0_characters/mountain_king_gen_image_rigged.glb` (60 bones, four arms including the extra chains).
- **Animation:** `incoming_models/P0_characters/mountain_king_gen_image_anim_v2.glb` вЂ” custom `Idle`, `Walk`, `Telegraph`, `Attack`, `Hit`, `Death`; authored at small rotations on the base skeleton and extra arm chains. This replaces the human presets that shredded the fur/armour on `HumanDeath`.
- **Integrated:** `assets/characters/generated/mountain_king_v2/mountain_king_v2.tscn`, scaled Г—2.37 with a +2.25 m ground offset; `scenes/characters/mountain_king.tscn` now uses it in the `ModelRoot` slot. The procedural mesh body remains as the hidden fallback.
- **Verification:** `test_mountain_king` 11/11, `test_ambush_site` 16/16, `test_caravan_site` 7/7, `test_full_route` 3/3 (37/37, 902 asserts). Visual capture: `docs/art/previews/generated/mountain_king_v2/`.
- **Remaining:** the custom Death reads as a hunched collapse, not a full ragdoll fall; the extra arm/fur weights still need a manual pass. No LOD.

### Sunny nightmare вЂ” dressed image-to-3D v2 + native clips

- **Source:** `sunny_nightmare_v2_raw.glb` (generation `eb32752b-17d9-42d7-94b5-bb90974d6c46`).
- **Dress pass:** `incoming_models/P0_characters/sunny_nightmare_v2_rigged_dressed.glb` вЂ” original face/hair/skin material kept; torso/sleeves use coarse brown cloth, legs dark wool, footwear dirty leather. 52-bone core rig with 10 native clips.
- **Integrated:** `assets/characters/generated/sunny_nightmare_v2/sunny_nightmare_v2.tscn`; `sunny_waking_nightmare.tscn` now uses the native v3-style AnimationTree, `WalkClean` and native clips. `SunnyAnimator`/`CombatController` paths were moved to `Visual/ModelPoc/Model/AnimationPlayer`.
- **Verification:** `test_sunny_waking` 10/10, `test_sunny_poc` 10/10, `test_sunny_animation` 16/16, `test_caravan_site` 7/7, `test_full_route` 3/3 (46/46, 1111 asserts). Captures: `docs/art/previews/generated/nightmare_v2_capture/`.
- **Remaining:** the silhouette is still a sweater/jeans; it is a colour/cloth placeholder, not a rebuilt ragged tunic and bare feet. A real clothing mesh/retopo is still needed.

### White horse — stock source accepted, generated scan rejected

- **Generated scan attempts:** `white_horse_v2_raw/rigged` and `white_horse_v3_*` still contain a fused flat tail sheet from the photo scan; the halter is baked into the head. Rejected for the caravan.
- **Accepted replacement:** Sketchfab **“Horse Rig”** by CreativeMachine (UID `bd71883bad9845389ef4ec2801004801`, CC Attribution), re-materialled to a clean white coat. Source GLB: `incoming_models/horse_stock_white.glb`; integrated wrapper `assets/characters/generated/white_horse_stock/white_horse_stock.tscn`.
- **Rider fit:** `caravan_site.tscn` uses the stock horse for Hero and Veteran; WhiteHorse/DarkHorse z-offset is `-0.20`, model scale 0.78, 180° yaw. Capture: `docs/art/previews/generated/white_horse_in_caravan.png`.
- **Verdict:** **ACCEPT AS STATIC BACKGROUND PROP / NOT ANIMATED.** Clean, no halter/spots, proper tail, but no walk clips and lower detail than the failed scan. The low-poly Quaternius `horse.tscn` remains the fallback.
- **No further model generation was used for the horse**; a clean source replaced the broken scan.

### Dark material variants and Blood Flower rig

- **Centurion dark:** `incoming_models/P1_monsters/carapace_centurion_gen_image_rigid_dark.glb` вЂ” `baseColorFactor (0.55, 0.16, 0.13, 1)` over the existing PBR texture; the custom 54-bone rig and five clips are preserved. Preview: `docs/art/previews/generated/centurion_dark_idle/`.
- **Centipede dark:** `incoming_models/P1_monsters/centipede_gen_a_dark.glb` вЂ” dark chitin factor (0.16, 0.10, 0.08); silhouette reads well. Rigged as `centipede_gen_a_rigged.glb` (12-bone spine, `Idle`/`Walk`). Preview: `docs/art/previews/generated/centipede_dark/`.
- **Blood Flower dark:** `incoming_models/P1_monsters/blood_flower_gen_b_dark.glb` вЂ” deep crimson tint; excellent host/flower read. A 52-bone core rig with 10 native clips was also generated (`blood_flower_gen_b_rigged.glb`, generation `9861d6de-1c8c-4c87-b94b-98be2ce2f77a`). Not integrated into a scene.
- **Worm dark:** `incoming_models/P1_monsters/worm_knot_gen_b_dark.glb` вЂ” still too pale because the source texture is nearly white; needs a dedicated dark flesh material. Rigged as `worm_knot_gen_b_rigged.glb` (7-bone spine, `Idle`/`Squirm`).
- **Remaining:** the rigs and dark variants are asset-level only; Centurion, Centipede, Worm and Blood Flower have no enemy scene/AI yet. Blood Flower uses the 52-bone core rig; Centipede/Worm use simple spine rigs, not per-leg IK.

## 2026-11-03 — Loot containers (Hyper3D CLI)

Three text-to-3D props were generated with the project Hyper3D CLI (`Gen-2.5-Medium`, Quad, GLB, PBR), then processed in an isolated Blender 5.1 scene via Blender MCP: join, target scale, decimate, bottom-centre origin, 1K texture resize, GLB export.

| Asset | Generation ID | Raw size / tris | Processed size / tris | Dimensions (m) | Preview |
|---|---|---|---:|---:|---|
| `assets/models/containers/chest_wood_iron.glb` | `4a6852b4-d4ab-47d2-b466-fdb0cc07070a` | 11,577,628 B / 18,327 | 4,076,116 B / 7,423 (Body 3,379 + Lid 4,044) | 1.150 × 0.999 × 0.975 | `docs/art/previews/containers/chest_wood_iron.png` |
| `assets/models/containers/loot_barrel_cluster.glb` | `b716c37b-4a83-45d5-8317-ed9ee6325f01` | 12,419,784 B / 16,465 | 3,894,564 B / 7,000 | 1.550 × 1.368 × 0.909 | `docs/art/previews/containers/loot_barrel_cluster.png` |
| `assets/models/containers/ancient_tomb_sarcophagus.glb` | `60280f7a-5b6a-4bb3-b61a-3a0d37388f7c` | 14,083,316 B / 17,921 | 3,733,612 B / 8,283 (Body 5,254 + Lid 3,029) | 2.200 × 1.561 × 1.670 | `docs/art/previews/containers/ancient_tomb_sarcophagus.png` |

- **Origin:** bottom-centre, `bbox_min_z = 0.0`; object location `(0,0,0)`; transforms applied.
- **Materials:** one PBR material per prop, renamed `nm_chest_wood_iron`, `nm_barrel_wood_iron`, `nm_sarcophagus_stone`; 1K base/normal/metallic-roughness textures embedded in GLB.
- **Raw files:** `incoming_models/P2_environment/containers/*_raw.glb` (gitignored, not shipped).
- **Verdict:** accepted as GD environment props. The sarcophagus is a GD expansion, not canon for the first fragment.
- **Lid split:** chest and sarcophagus were bisected in Blender into `Body`/`Lid`; the `Lid` origin is at the back hinge. `LootCache` animates `Lid` around X (chest 100°, sarcophagus 75°). Open previews: `docs/art/previews/containers/chest_wood_iron_open.png`, `ancient_tomb_sarcophagus_open.png`.
- **Verification:** Godot headless import exit 0; `asset_preview.gd` bounds start at `y=0`; `loot_secret_audit.gd` 10/10.

## 2026-11-03 - Generated armour sets (scout / mercenary / heavy)

**Pipeline:** Hyper3D CLI text-to-3D -> human/core rig -> Blender head-island cleanup -> weight-transfer rebind to `sunny_nightmare_v2` -> glTF-Transform 1024 texture resize -> Godot import.

| Set | Final GLB | LOD0/1/2 tri | Verts total | Bones | Dimensions (m) | SHA-256 |
|---|---|---:|---:|---:|---|---|
| Scout leather | `assets/characters/equipment/armor/scout_leather.glb` | 59,457 / 26,754 / 10,702 | 116,339 | 52 | 0.936 x 1.908 x 0.555 | `B1462897C2B99BBB6E71003405C57925BF65C209640CEB168AE906A4A710E874` |
| Mercenary medium | `assets/characters/equipment/armor/mercenary_medium.glb` | 58,458 / 26,306 / 10,522 | 119,948 | 52 | 0.804 x 1.760 x 0.392 (Y x1.0793) | `65291BBAC6C62D116250A8E86127CABE646FD75DD98E6ACACDF762C711D52BFA` |
| Heavy plate | `assets/characters/equipment/armor/heavy_plate.glb` | 60,000 / 27,000 / 10,799 | 109,559 | 52 | 0.827 x 1.902 x 0.442 | `2F3D316D01957F4224EEAB7DAAA8B768333857587006913B2CFDB70ED14762BE` |

### Scout leather

- **Generation ID:** `d3a04960-d300-40f7-9632-4902df14d0ec`; **rig:** `cdddc84f-2ab0-4310-9941-0280c4cd24b6`.
- **Raw / rigged:** `incoming_models/P2_equipment/scout_leather_raw.glb`, `scout_leather_rigged.glb` (gitignored).
- **Visual:** green hood and short cloak, dark brown leather cuirass with cross straps, layered pauldrons, bracers, belt pouches, reinforced trousers, knee guards and boots.
- **Head rule:** the blank mannequin head island was removed; the base Sunny head remains visible inside the hood. The hood region is weighted 100% to `Head`.
- **Materials / LOD:** cloth double-sided + plate single-sided; LOD0/1/2 (59,457 / 26,754 / 10,702 tri), 8/18 m switches.
- **Verdict:** **ACCEPT ALPHA** — silhouette and PBR texture read well; 1K maps; head turn is clean; boxing-attack pauldron clipping remains.

### Mercenary medium

- **Generation ID:** `fedeb263-cf19-4eca-b225-ebd980bd06a6`; **rig:** `38d6f2cc-71a6-4b48-bf00-1692db2a49a2`.
- **Raw / rigged:** `incoming_models/P2_equipment/mercenary_medium_raw.glb`, `mercenary_medium_rigged.glb`.
- **Visual:** riveted chainmail hauberk and chausses, dark steel breastplate and pauldrons, brown belt with pouches, dark red tabard, steel bracers, knee guards, leather boots, open-faced steel helmet.
- **Head rule:** blank mannequin head/neck island removed; the base head is hidden because the helmet is closed.
- **Materials / LOD:** cloth double-sided + plate single-sided; LOD0/1/2 (58,458 / 26,306 / 10,522 tri), 8/18 m switches. Local height 1.760 m; mercenary_medium.tres scales Y by 1.0793 to the 1.900 m base.
- **Verdict:** **ACCEPT ALPHA** — chainmail and plate read clearly; head turn is clean; boxing-attack tabard/pauldron clipping remains.

### Heavy plate

- **Generation ID:** `18d9b4bb-ca0d-45ec-a04d-51dabd958102`; **rig:** `49ebaa26-44a9-4b27-af8e-6f3ac740ec9b`.
- **Raw / rigged:** `incoming_models/P2_equipment/heavy_plate_raw.glb`, `heavy_plate_rigged.glb`.
- **Visual:** full dark-steel plate cuirass, layered pauldrons, articulated gauntlets, tassets, greaves, sabatons, chainmail at the joints and a closed great helm.
- **Head rule:** no separate mannequin head island was found (closed helm); the base head is hidden by `hide_surfaces = [0,1,2,3]`.
- **Materials / LOD:** all plate single-sided; LOD0/1/2 (60,000 / 27,000 / 10,799 tri), 8/18 m switches.
- **Verdict:** **ACCEPT ALPHA** — full-plate silhouette reads; head turn is clean; boxing-attack pauldron clipping remains.

### Processing notes

- `assets/characters/equipment/source/prepare_generated_armor.py` removes the blank head island by head-like bounding box, not by vertex index.
- `assets/characters/equipment/source/rebind_generated_armor.py` transfers the base body's weights, limits to four influences, normalises them and binds the outfit to the base 52-bone armature. A plain `Skin` remap was rejected because the Hyper3D rest proportions compressed the outfit.
- `assets/characters/equipment/source/split_armor_materials.py` splits cloth (double-sided) and plate (single-sided) by the metallic channel.
- `assets/characters/equipment/source/fix_armor_head_weights.py` assigns the Scout hood region to `Head`.
- `assets/characters/equipment/source/build_armor_lods.py` adds LOD1/LOD2 into the same skinned GLB.
- `rigidify_armor_plates.py` was evaluated and rejected: it separated plates in the boxing guard; smooth weights are retained.
- Textures are 1024 PBR (base colour, normal, metallic-roughness); tangents are exported.
- Runtime data: `resources/equipment/armor/*.tres`, `resources/equipment/stats/*_stats.tres`, `resources/equipment/catalog_alpha.tres`.
- **Verification:** headless import exit 0; `test_armor_stats_loot` 20/20 (88 asserts); full GUT 717/717 (7,849 asserts), exit 0. LOD captures at 2/10/20 m and pose captures in `docs/art/previews/equipment/`. Manual playthrough and 1080p/60 FPS are **NOT TESTED**.

## 2026-11-03 — Loot category icons

- `assets/ui/loot/icons/loot_currency.png`, `loot_material.png`, `loot_consumable.png`, `loot_tool.png`, `loot_equipment.png`, `loot_memory.png`, `loot_key.png`, `loot_relic.png` — eight 128×128 RGBA icons, project-owned, generated by `tools/art/make_loot_icons.py` (Pillow). No external source or texture.
- Used by `LootItemData.icon` (assigned by category in `tools/build_loot_resources.gd`) and by `LootBag` (`Sprite3D` shows the first drop's icon).
