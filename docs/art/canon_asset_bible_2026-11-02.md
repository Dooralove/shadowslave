# Canon-Checked 3D Asset Bible — prompts (2026-11-02)

**Status:** supersedes the initial prompt blocks in `docs/art/generation_queue_2026-11-02.md` for the models below.  
**Source:** user-supplied canon-checked asset bible, 2026-11-02.  
**Rule:** canon first, silhouette second, geometry third, texture fourth. A beautiful but canonically wrong or un-riggable mesh is rejected. Do not duplicate existing fallbacks before acceptance.

## 0. Critical corrections

- **Carapace Scavenger is not a six-legged crab.** It is a 2.5 m hybrid: eight segmented scythe-ended legs (four pairs), a humanoid armored torso emerging from the carapace, a head directly on the torso with no neck, two narrow eye slits, wet mandibles, and two huge pincers instead of hands.
- **Carapace Centurion is not a scaled Scavenger.** It has eight segmented legs, a humanoid torso, and two arms ending in large curved bone scythes — **not pincers**.
- **Blood Flower is not a standalone plant.** It is a parasite on a massive primate host: dirty grey fur, powerful arms, sharp teeth, two curved dagger-length tusks, crimson flowers growing from bloody wounds; red pollen is a separate VFX.
- **Worm Knot is not a confirmed species.** Use a colony of several carnivorous worms — readable bodies and mouths, not a featureless blob.
- **Mountain King has no horns, armor, tail, extra legs or external weapons.** Exactly two stumpy legs, four arms (two long clawed, two shorter with almost human fingers), five milky eyes, yellowish-grey fur, at least 4 m tall.
- **Hero/Auro does not have a fixed age of 22, and weapons must not be fused to the body.** Generate a young adult only slightly older than a 16-year-old; spear, sword and scabbard are separate props.
- **Sunny's 1.66 m is project scale, not canon.** Under 17, undernourished, adolescent proportions; no heroic/muscular build.
- **Scholar's glasses/coat are unverified art direction.** Do not present them as canon.
- **White horse:** no saddle/bridle fused to the mesh; tack is separate.
- **Police ranks/ages:** only the grey-haired senior and the tired scruffy officer are text-supported; the rest is art direction.

## 1. P0 prompts

### Sunny real — `sunny_real_v2.glb`

```text
Full-body realistic game character: a very young, undernourished teenage boy, visibly under 17, short and extremely slender, narrow shoulders, thin limbs, pale skin, tired dark eyes with pronounced under-eye circles, gaunt youthful face and messy short black hair. Cheap faded off-white knit sweater, worn dark trousers and scuffed everyday sneakers. Clearly adolescent, not an adult, not muscular. Neutral relaxed A-pose, hands and feet fully visible, natural five-finger anatomy. Grounded contemporary dark-fantasy realism, restrained materials, believable skin and knitted fabric. Single isolated character, front three-quarter view, neutral studio background, no props, no base, no text, no watermark.
```

### Sunny nightmare — `sunny_nightmare_v2.glb`

Identity must match `sunny_real_v2`; do not create a new face.

```text
The exact same adolescent boy as the approved Sunny reference: preserve facial identity, pale skin, tired eyes with dark under-eye circles, messy short black hair, narrow shoulders and extremely thin undernourished body. Change only the outfit to a primitive slave's clothing: a threadbare coarse linen tunic, rough worn trousers and bare feet. Show faint pressure wounds around both wrists from iron shackles; add subtle temple-slave markings on the skin without readable symbols. No armor, no weapons, no jewelry, no modern clothing. Full-body neutral A-pose, hands and feet visible, natural anatomy. Realistic grounded dark fantasy, worn cloth, cold muted earth palette, isolated studio character, no chain attached to the mesh, no base, no text.
```

### Hero/Auro — `hero_auro_v3.glb`

```text
Full-body young adult male soldier, only slightly older-looking than a 16-year-old boy. Exceptionally handsome, noble and dignified appearance, calm compassionate expression, naturally athletic but not bulky, realistic human proportions. Simple practical ancient leather cuirass over a plain dark travel tunic, modest leather belt, bracers and worn riding boots; understated, functional equipment, not ornate fantasy armor. No helmet, cape, shield or weapon in hands. Neutral symmetrical A-pose, five fingers visible, feet shoulder-width apart. Grounded realistic dark-fantasy character, believable leather and cloth, isolated front three-quarter studio view, no horse, no scenery, no base, no text.
```

### Shifty — `shifty_v3.glb`

```text
Full-body adult male slave with a wary, shifty expression and quick, desperate eyes. Lean, slightly gaunt build from hardship, guarded posture, tense shoulders, alert face; age and facial details are a restrained production interpretation, not a fixed canon likeness. Worn threadbare slave tunic, rough simple trousers and damaged practical footwear or bare feet, muted dusty fabric. No armor, weapons, jewelry or noble accessories. Neutral A-pose with hands visible and fingers natural; remove any chain from the body mesh. Realistic grounded dark fantasy, believable human anatomy and worn cloth, isolated front three-quarter studio view, no scenery, no base, no text.
```

### Scholar — `scholar_v2.glb`

```text
Full-body tall, lean male slave in his forties, unusually handsome but understated, intelligent gentle face, calm observant eyes and dignified scholarly bearing. Refined facial proportions, mature but not elderly. Worn, modest ancient travel clothing: plain dark tunic, simple outer coat and practical trousers, all visibly used but not ragged beyond recognition. No glasses unless approved as a later art-direction choice; no staff, books, armor, weapons or wizard robes. Neutral A-pose, hands visible, natural anatomy. Grounded realistic dark fantasy, restrained charcoal and brown fabric, isolated front three-quarter studio view, no scenery, no base, no text.
```

### Veteran — `veteran_v3.glb`

```text
Full-body older male caravan officer, visibly older than the young soldier, stern angry weathered face and hard commanding expression. Practical ancient military travel gear: sturdy worn leather armor or cuirass, a heavy fur cloak, durable leather boots, plain belt and functional bracers. The clothing is better made than ordinary soldiers' gear but not luxurious or ornate. No helmet, no weapon in hands; whip and sword should be separate props, not fused to the body. Neutral A-pose, hands fully visible, natural anatomy. Realistic grounded dark fantasy, aged leather and coarse fur, isolated front three-quarter studio view, no horse, scenery, base or text.
```

### Broad slave — `broad_slave_v1.glb`

```text
Full-body broad-shouldered adult male slave, noticeably wider and heavier in the upper body than an average exhausted prisoner. Thick shoulders and neck, strong working build, weathered tired face, restrained exhausted expression. Coarse threadbare slave tunic with a torn, blood-stained upper back, rough trousers and simple worn footwear or bare feet. No armor, weapons, jewelry or heroic equipment. Neutral A-pose, full hands and feet visible, natural human anatomy. Realistic dark fantasy, subdued dirty earth palette, isolated front three-quarter studio view; create the bloodied back as a material/decal-friendly surface, no chains, no scenery, no base, no text.
```

### White horse — `white_horse_v1.glb`

```text
A beautiful realistic white riding horse, full body, anatomically correct equine proportions, strong but elegant neck, chest, back and hindquarters, four correctly formed legs and natural hooves. Natural white coat with subtle realistic hair detail, white mane and tail, calm alert expression. Neutral standing pose with all four legs separated and visible, head slightly raised. No rider, saddle, bridle, armor, banners or decorative tack; create tack as separate props if required. Premium grounded realistic game animal, clean front three-quarter side view, neutral studio background, no scenery, no base, no text.
```

### Mountain King — `mountain_king_gen_v1.glb`

```text
A terrifying giant hunched nightmare humanoid, at least 4 m tall, with EXACTLY two short powerful legs and EXACTLY four separate arms. Gaunt hunched torso covered in thick ragged dirty yellowish-grey fur. The upper pair of arms is extremely long and multi-jointed, each ending in huge sword-length bone claws. A second, shorter pair grows lower on the torso and ends in almost human hands with long fingers. The face has EXACTLY five milky-white eyes, a half-open maw full of razor-sharp teeth and viscous drool. Subtle worm-like bulges move beneath patches of fur and skin. Keep all four arms visibly separated and anatomically attached. No horns, armor, tail or extra limbs. Neutral hunched pose, front three-quarter view, realistic biological horror, isolated studio background, no base, text or scenery.
```

## 2. P1 prompts

### Carapace Scavenger A — `carapace_scavenger_gen_a.glb`

```text
A 2.5-meter-tall nightmare creature combining a demonic crab, a centaur and a humanoid. EXACTLY eight long segmented legs arranged as four pairs, each ending in sharp scythe-like chitin protrusions. A clearly visible humanoid armored torso emerges from the front of a massive thick carapace. The head sits directly on top of the torso with NO neck, has exactly two narrow eye slits and a vicious mouth with several wet mandibles. Both arms terminate in enormous powerful crab pincers instead of hands. Preserve a readable torso-to-shell transition and eight separately articulated legs. No extra limbs, no tail, no wings. Realistic dark-fantasy biological armor, layered chitin, restrained dark crimson/charcoal palette as art direction, full isolated creature, front three-quarter view, no base or text.
```

### Carapace Scavenger B — `carapace_scavenger_gen_b.glb` (optional after A)

```text
A second individual of the same Carapace Scavenger species: preserve EXACTLY eight segmented scythe-ended legs, a humanoid armored torso emerging from the carapace, a head directly on the torso with no neck, two narrow eye slits, wet mandibles and two enormous pincers instead of hands. Make this individual broader and older-looking through a heavier shell, chipped plates, asymmetrical battle scars and one damaged pincer. Do not change species anatomy or add limbs. Realistic layered chitin, dark restrained palette, full isolated front three-quarter creature, no base, environment or text.
```

### Carapace Centurion — `carapace_centurion_gen.glb`

```text
An imposing elite Carapace Centurion nightmare creature, a larger and more heavily armored relative of the Carapace Scavenger. EXACTLY eight segmented chitin legs support a massive armored lower body. A clearly integrated humanoid torso rises from a black carapace marked with deep crimson natural patterns. EXACTLY two upper arms end in formidable long curved bone scythes instead of hands; the scythes are organically connected to the forearms, not held weapons. Thick layered shell, jagged natural spikes, battle wear and strong readable anatomy. No crab pincers, no extra arms, no extra legs, no human face. Realistic dark fantasy biological armor, full creature visible, front three-quarter studio view, no base, scenery or text.
```

### Giant centipede — `centipede_gen_a.glb`

```text
A giant nightmare centipede with a long low crawler silhouette and a clearly segmented continuous body. Many pairs of short articulated legs emerge consistently from the underside of successive segments. The front head is armored and distinct, with powerful curved mandibles; the rear tapers naturally. Preserve visible separation between segments and leg pairs, with no tangled coils or duplicate heads. Dark wet chitin and a subtle oily corrosive sheen are art direction, not glowing magic. Full body from head to tail visible in a gentle natural curve. Realistic dark-fantasy creature, neutral studio background, no base, extra creatures or text.
```

### Carnivorous worm colony — `worm_knot_gen_a.glb`

```text
A compact colony of several carnivorous nightmare worms forming one intertwined organic cluster. Each worm has a clearly readable elongated segmented body, a distinct head and a circular fleshy feeding mouth; bodies loop and overlap naturally but remain visually separable. Build a low, dense nest-like knot with visible gaps and layered depth, not a featureless blob. No humanoid anatomy, arms, legs, eyes or decorative tentacles unless clearly part of a worm body. Wet organic skin, muted pale-grey and dark red tones as art direction. Full cluster visible, realistic dark-fantasy biological horror, isolated neutral studio background, no base, scenery or text.
```

### Blood Flower host — `blood_flower_gen_a.glb`

**This replaces the old standalone flower concept.**

```text
A large monstrous primate host parasitized by Blood Flowers. Powerful muscular arms, heavy climbing body, dirty grey matted fur, partially decomposed patches of skin, a brutal mouth full of sharp teeth and exactly two long curved tusks protruding from the mouth. Several deep crimson fleshy flowers grow from bloody gaps and wounds in the host's body. Pale parasite stems visibly slither across the face, with one thin stem connecting the eye-socket area; flowers are parasitic growths, not a separate plant body. Include subtle pollen-bearing structures in the flowers; red pollen should be treated as a separate VFX effect for damage/death, not baked into the static mesh. Keep the primate anatomy dominant and readable. No humanoid clothing, armor or weapons. Realistic dark-fantasy biological horror, full isolated creature, neutral studio background, no base, scenery or text.
```

### Police desk / guard — optional

Use the prompts from the user bible; do not generate before P0/P1. The senior officer has grey hair and a seasoned face; the patrol officer is tired/scruffy, uniform design is art direction.

## 3. Rejection criteria

- Wrong limb count/architecture.
- Missing torso/neck transition on carapace creatures.
- Centurion with pincers instead of bone scythes.
- Blood Flower without a primate host.
- Mountain King with horns, armor, tail, extra legs or fewer/more than four arms/five eyes.
- Hexapod carapace.
- Fused weapons on Hero/Veteran.
- T-pose instead of A-pose (unless rest-pose mode only outputs T-pose; then check rig).
- Visible base/plinth/background, extra objects, missing back geometry.
- Unriggable shoulders/hips/knees or clothing intersecting body.
- Missing PBR maps or texture artifacts.

## 4. Acceptance sequence

1. Sunny real (identity/anatomy calibration).
2. Hero updated (A-pose, no fused weapons).
3. Mountain King (complex anatomy).
4. Sunny nightmare, Shifty, Scholar, Veteran, BroadSlave, White horse.
5. Carapace Scavenger A, then Centurion.
6. Centipede, Worm colony, Blood Flower host.
7. Police, crowd, environment only after P0/P1.

Do not batch-generate. Review each class before continuing.
