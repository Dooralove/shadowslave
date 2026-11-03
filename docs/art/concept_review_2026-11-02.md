# Concept review — 2026-11-02

**Purpose:** check the user-generated concept sheets before Image-to-3D.  
**Rule:** Image-to-3D preserves the concept, so canon errors must be fixed at the concept stage. A beautiful 3D mesh from a wrong concept is a rejected asset.

> **User decision (2026-11-02):** the user likes all four concepts and explicitly accepts them for production. The canon deviations listed below are **recorded but overridden** by the user's art-direction decision. Generate the models as approved; do not re-litigate horns/eye count/limb count unless the user asks again.

## 1. Hero/Auro — ACCEPTED for Image-to-3D

**Source:** `incoming_models/concepts/hero_auro/photo_2026-11-02_18-50-31.jpg`  
**Views:** front / side / back, same design, clean neutral background, no weapons.  
**Design:** young male, brown short hair, dark blue tunic, brown leather cuirass with cross straps, belt, bracers, long leather coat tails, tall boots.  
**Assessment:** acceptable art direction; younger/nobler than the text-only v5; no fused weapons.  
**Risks:** the concept is only 638×503, so detail is soft; the long coat tails/bracers may still produce skinning artefacts. Keep the concept as the identity reference; after Image-to-3D, retopo/weight-clean the coat if needed.

**Action:** cropped to `incoming_models/concepts/hero_auro/image2d/{front,side,back}.png`; Image-to-3D generation launched.

## 2. Mountain King — REJECTED

**Source:** `incoming_models/concepts/mountain_king/photo_2026-11-02_18-47-57.jpg`

What is wrong:

- Has **horns/antlers**; the canon prompt forbids them.
- The head has **two eyes**; canon requires **five milky-white eyes**.
- All visible arms end in **claws**; the required second, shorter pair must end in **almost human five-fingered hands**.
- The silhouette reads as a four-armed werewolf, not the hunched four-armed tyrant.

Keep: fur palette, hunch, long upper arms, stumpy legs.  
**Needs a new front/side/back concept**:
- no horns, no antlers, no armor, no tail;
- exactly five milky eyes;
- two long upper arms with bone claws;
- two shorter lower arms with human hands/fingers, clearly visible;
- two stumpy legs; at least 4 m tall.

Suggested image-generation prompt:

```text
Front/side/back character turnaround of a colossal hunched nightmare tyrant, at least four meters tall. Exactly two short stumpy legs and exactly four arms: two extremely long upper arms ending in sword-length bone claws, and two shorter lower arms ending in clearly visible human-like five-fingered hands. Thick ragged dirty yellowish-grey fur, gaunt torso, exactly five milky-white eyes, wide maw with razor teeth and drool, subtle worm-like bulges under the skin. NO horns, NO antlers, NO armor, NO tail, NO extra limbs, NO weapons. Neutral pose, full body, neutral grey studio background, no text, same design in all three views.
```

## 3. Carapace Scavenger — REJECTED (face/head)

**Source:** `incoming_models/concepts/carapace_scavenger/photo_2026-11-02_18-47-24.jpg`

What is good:

- eight segmented legs read as four pairs;
- humanoid torso and two pincer arms;
- layered dark-red chitin; strong silhouette.

What is wrong:

- the head is a **horned humanoid skull/helmet face with two glowing eyes and a fanged mouth**;
- canon requires a head sitting directly on the torso with **no neck**, **two narrow eye slits**, and a mouth with **several wet mandibles**;
- remove the helmet-like horns and the human skull face.

Suggested image-generation prompt:

```text
Front/side/back creature turnaround: a 2.5 m carapace scavenger, a demonic crab-centaur. Exactly eight long segmented legs in four pairs, ending in scythe-like chitin. A humanoid armored torso emerges from a massive layered carapace. The head sits directly on the torso with NO neck; it is a smooth chitin skull-dome with exactly two narrow horizontal eye slits and a mouth surrounded by several wet chitin mandibles. Both arms end in huge crab pincers, not hands. No horns, no helmet, no human face, no teeth like a human, no extra limbs. Dark crimson and charcoal layered chitin, full body, neutral grey studio background, same design in all views.
```

## 4. Carapace Centurion — REJECTED (face/head)

**Source:** `incoming_models/concepts/carapace_centurion/photo_2026-11-02_18-46-10.jpg`

What is good:

- two long bone scythes instead of pincers;
- eight-leg / humanoid-torso silhouette;
- black-crimson chitin and heavy armor.

What is wrong:

- horned **skull/demon face** and helmet-like head; no human face is allowed;
- the head must be integrated into the carapace, with no neck, eye slits and mandibles or a faceless chitin mask, not a horned skull.

Suggested image-generation prompt:

```text
Front/side/back creature turnaround: an elite Carapace Centurion, a large armored crab-centaur. Exactly eight segmented chitin legs; a humanoid torso integrated into a massive black carapace with deep crimson natural patterns. Exactly two arms end in long curved bone scythes, organically attached to the forearms. The head is a faceless chitin mask integrated directly into the carapace, no neck, two narrow eye slits, wet mandibles; no human skull, no horns, no helmet, no extra limbs. Heavy layered shell, battle wear, neutral grey studio background, same design in all views.
```

## 5. Style reference update (2026-11-02)

The user supplied a new realistic Sunny reference:

`incoming_models/concepts/sunny_real/{front,side,back}.png` (from `C:\Users\user\Pictures\Screenshots\Снимок экрана 2026-11-02 193943.png`).

Target style:

- photorealistic cinematic character, natural human proportions and facial asymmetry;
- realistic skin pores, tired eyes, dirt, worn knit/leather/fabric fibers;
- muted desaturated palette, soft studio/overcast light;
- **no** stylized fantasy painting, no oversized armor/pauldrons, no cartoon, no heroic caricature, no smooth plastic skin.

Use this style tail for text-only models:

```text
Photorealistic cinematic character, natural human anatomy and skin pores, subtle facial asymmetry, realistic fabric fibers and grime, 85mm lens, grounded muted realism, no stylized or painterly concept art, no cartoon, no oversized armor or heroic proportions, no base, no background, no text.
```

Text-only generations that come out stylized should be rejected and regenerated from a realistic concept/reference rather than accepted for style.

**2026-11-03 update:** Shifty, Scholar, Veteran and BroadSlave were retried with simplified clothing and a photoreal "3D scan" prompt. The results are grounded, correctly proportioned and integrated as placeholders, but they are still semi-stylized. They do **not** reach the Sunny-v3 reference level. The next pass for these four should use realistic front/side/back concept sheets or a realistic scanned source, not more text prompts.

## 6. Concept sheet rules

- One design per sheet; front, side and back must match in proportions, clothing, armor and limb count.
- Full body/creature; hands/feet not cropped; neutral background; no labels/text.
- Use 1024 px or larger per view if possible.
- No weapons in hand for characters; weapons are separate props.
- For Image-to-3D, crop each view into its own file; do not upload the whole collage with neighbouring arms visible.
