# 07 Environment Art — Stage 7 quality pass

**Date:** 2026-11-03
**Branch:** `demo/environment`
**Purpose:** final player-facing quality audit of the A07 work; fix only visible, high-impact defects.

## 1. What a player would notice first

1. **P05–B02 are still greybox in shipping gameplay.** All A07 art overlays are ready and direct-parent tested, but A03 has not instanced `ArtOverlay` in the shipping post-nightmare scenes. This is the single biggest presentation issue and cannot be fixed in A07 without editing A03-owned scenes.
2. **Z10 camp framing.** The camp pillar asset is much taller than the A03 camp platform. Earlier it dominated / floated outside the platform; Stage 7 grounds it, scales it down and positions it at the camp landmark.
3. **Z15/Z18 flat platform silhouettes.** Stage 6 edge ledges were placed inside the platform footprint and were almost invisible. Stage 7 replaces them with corner coral masses that actually break the silhouette.
4. **P06 checkpoint entrance** is very dark from the north camera. Stage 7 added emissive guide strips and a warm interior light.
5. **P09 capsules** previously read as black boxes; Stage 7 gives them pale metal bodies and emissive blue lids.

## 2. Fixes in this pass

- Z15: corner coral masses at the actual platform perimeter, plus overhang; no regular ledge ring.
- Z18: corner coral masses on the final summit; sea stacks retained.
- Z10: camp pillar grounded and reduced to a small landmark; no floating prop over the abyss.
- Z15/Z18 captures refreshed (`stage7_refuge.png`, `stage7_cliffs.png`); Z02/Z10 captures refreshed.
- P06/B02 guides and P09 capsule glass came from the immediately preceding quality pass and remain in the final tree.
- 208-instance shore dressing remains at 3 MultiMesh nodes with no physics.

## 3. Verification

| Check | Result |
|---|---|
| Labyrinth smoke scene | no parse/runtime errors |
| `validate_labyrinth_art` | **208 instances / 3 MultiMesh / failures=0** |
| `validate_z10_clearance` | **0 offenders; only campfire inside A03 end-zone sphere** |
| `test_labyrinth_first_fragment.gd` | **13/13, 332 asserts** |
| `test_post_nightmare_locations.gd` | **15/15, 513 asserts** (unchanged tree outside labyrinth) |
| Perf 1920×1080, 180 frames | **1361 draw calls / 4.31M tris / 125.1 avg FPS / 1236 MB VRAM** |

## 4. Remaining presentation risks

- **A03 integration** is still required for P05–B02; until then, players see greybox in those locations.
- **Tris 4.31M** exceeds the 2.5–3.5M target. Draw calls and FPS pass; TD exception or further LOD/decimation is needed.
- **Z15 +25 / Z18 final geometry** remain A03 work; A07 can only dress the existing +18/+35 surfaces.
- **Z02/Z13 hero assets** remain the existing project kit, not new bespoke LOD/GLB.
- **A07-11 SQ props** remain blocked by A02/A03 POI hooks.
- P06 checkpoint-inner camera and B02 `Shots/Stairs` remain dark because the debug cameras sit inside/behind geometry; player-path captures are the useful ones.

## 5. Handoff

Final Stage 7 commit hash is reported to TD. No A03/A00 or other agent files are included. No push.
