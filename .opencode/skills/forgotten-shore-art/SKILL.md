---
name: Forgotten Shore Art
description: Use for canon and art direction of the Forgotten Shore Labyrinth — red coral reef language, 18 zones, tide cycle, storm, palette, landmarks, and forbidden elements.
---

# Forgotten Shore Art

## Sources

- `docs/design/level_brief_labyrinth_first_fragment.md` — current level plan (Q1 = C, Q2 = C, Q3 = A, Q4 = B).
- `docs/design/forgotten_shore_labyrinth_research.md` — canon research and art direction.
- `docs/art/graphics_audit_and_tooling.md` — visual audit and stage plan.
- `docs/research/post_first_nightmare_dream_realm/03_locations_and_world.md` — locations.
- `docs/story/*` — canon where it does not conflict with the research docs.

## Core image

A **crimson coral reef**, exposed at low tide, not a red forest and not a dungeon of rooms.

- Merged coral masses, vertical blades, pillars, arches, overhangs, tunnels, sudden drops.
- Black/blue mud, bones, shells, carapace debris, azure blood.
- Pale diffuse daylight; long shadows; dark tunnels; no warm sunny forest.
- Scale: masses 4–10× human height; hero blades 30–45 m; the headless knight statue ~200 m.
- The labyrinth is kilometres long in canon; the playable fragment is a compressed adaptation.

## Space

One continuous scene `LabyrinthFirstFragment`, ~1.5 km, 18 zones:

- **East Z01–Z11:** threshold, carcass, fork, mud basin, bone pass, dry pocket, ridge, clearing, camp hill, tide channel.
- **Centre Z12–Z15:** west isthmus, hunting grounds (3 loops), bone bridge, high refuge.
- **West Z16–Z18:** pack territory, storm, cliffs.

Three acts:

1. Descent, first fight, Azure Blade, first meeting, camp.
2. Hunt, tide crossing, bone bridge, high refuge.
3. Pack, storm, climb to the cliffs.

Tide is a full 16-minute cycle: low routes close, high routes stay open, warnings/moisture line/HUD; the final storm is a scripted surge. Never a “wall of death” without a high route.

## Visual language

| Element | Do | Don't |
|---|---|---|
| Form | merged masses, blades, overhangs, flowstone, shells | thin trunks, crowns, leaves, bushes |
| Surface | porous, layered, wet, dark seams | smooth plastic cylinders |
| Colour | dark crimson/maroon, bone, black-blue mud, azure blood | bright scarlet “autumn forest” |
| Ground | black mud, puddles, bones, shell/carapace debris | grass, moss, leaves |
| Light | pale diffuse, long shadows, dark holes | warm sunny forest |
| Distance | statue, pillar/spire, storm wall, sea | empty horizon/black void |

Palette:

- coral dark `#4a1c22`; coral light `#8c4a4a`; dead coral `#6b5550`
- bone `#d8cfc0`; mud `#141018`; water `#05070c`
- carapace blood `#2f7fa8`; fire `#ff8a3c`; sky `#8a8f96`

Landmarks: headless statue, coral pillar with fire, western spire, bone bridge, storm wall, cliffs. With every fork, at least one L0/L1 landmark must be visible. No mini-map dependency.

## Forbidden

- Shrine, altar, star, ritual bowls, empty chairs inside the labyrinth — not canon for this place.
- Red “trees”, bushes, leaves, grass, modern objects.
- Copying the Witcher 3 forest/ruins/monster/character or its exact palette.
- Adding mechanics/content outside the current brief (climbing, swimming, controllable shadow, companion AI) in the first version.
- Treating the old `coral_labyrinth` room layout or its shrine as final art.

## Acceptance

- Reads as a reef at eye level; not a forest, not a corridor maze.
- Each of the 18 zones has a distinct silhouette/palette/landmark.
- Tide and storm visibly change the space.
- Event/landmark density at least one per 60–80 m.
- High route always exists; no mandatory jump/climb/swim.
- Materials hold up in close-up: normal detail, roughness variation, wetness, SSS, decals.
- 1080p 60 FPS on RTX 3060 Laptop; shadows within 120 m; zone culling/LOD active.
