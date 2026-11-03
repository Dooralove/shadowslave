# A07 → A03 integration package — post-nightmare art overlays

**Date:** 2026-11-03
**Owner:** A07 Environment Art
**Status:** A07 side implemented and preview-verified. Shipping scenes are A03-owned and were **not edited** in this branch.
**A03 check (2026-11-03):** `demo-03` has uncommitted `DemoEndZone`/`CampNight` additions in `labyrinth_first_fragment.tscn`, but still no `ArtOverlay` node in any post-nightmare scene. The A07 camp-prop clearance test uses the new `DemoEndZone` coords `(-100, 18.2, -5)`, radius 4.

## 1. What A03 needs to do

For each location below, instance the A07 art scene as a **direct child of the location root** and name the node `ArtOverlay`:

| Location scene (A03) | Art scene (A07) | Root node name |
|---|---|---|
| `scenes/locations/post_nightmare/police_precinct.tscn` | `res://scenes/environment/post_nightmare/police_precinct_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/academy_approach.tscn` | `res://scenes/environment/post_nightmare/academy_approach_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/academy_gate.tscn` | `res://scenes/environment/post_nightmare/academy_gate_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/academy_campus.tscn` | `res://scenes/environment/post_nightmare/academy_campus_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/academy_sleeper_center.tscn` | `res://scenes/environment/post_nightmare/academy_sleeper_center_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/black_sea_platform.tscn` | `res://scenes/environment/post_nightmare/black_sea_platform_art.tscn` | `ArtOverlay` |
| `scenes/locations/post_nightmare/tide_descent.tscn` | `res://scenes/environment/post_nightmare/tide_descent_art.tscn` | `ArtOverlay` |

Minimal `.tscn` addition (example for P05):

```text
[ext_resource type="PackedScene" path="res://scenes/environment/post_nightmare/police_precinct_art.tscn" id="7_art"]

[node name="ArtOverlay" parent="." instance=ExtResource("7_art")]
```

No `host_path` is needed for this production layout: `EnvironmentArtOverlay` finds its parent `GreyboxLocation`, waits for `layout_built`, and applies the profile after `Generated` exists.

Do **not** add this overlay to `coral_labyrinth`: that sandbox uses the existing `ArtFinal` / `labyrinth_art.gd` layer.

## 2. What the overlay changes

- Replaces `WorldEnvironment.environment` with the A07 environment profile.
- Applies PBR material swaps by original `.tres` path suffix; it never deletes or rewrites A03 resources.
- Adds visual-only props, lights, decals and (P05) a reflection probe.
- Optionally hides generated visual mesh prefixes (P08 hides the old metal `GalleryColumn` props; collision is untouched).
- Adjusts the key light (`Sun`/`Moon`/`AbyssFill`) and water material.

It **never** touches `Generated/Collision`, `Spawns`, `Portals`, `Markers`, `Gameplay`, `TideController`, `Player`, HUD or dialogue.

## 3. P05 mirror note

A03's original `MirrorFrame`/`MirrorGlass` blockout sits outside the interrogation west wall, so the mirror is not visible from the camera. A07 adds an art-side `InterrogationMirrorPanel` and frame at `x = -18.80` on the visible inner wall; this is visual only. A03 can keep or remove the original blockout boxes without affecting gameplay.

## 4. Verification

A07 preview wrappers (A07-owned) are under `scenes/environment/post_nightmare/preview/`. They load the A03 location at runtime and instance the art scene, but do not change the shipping scene.

```text
godot --headless --path . res://tools/art/validate_environment_art.tscn
# A07_VALIDATE ... applied=true ... art_collision=0
# A07_VALIDATE_DONE failures=0

godot --headless --path . res://tools/art/validate_direct_overlay.tscn
# A07_DIRECT P05 applied=true ... B02 applied=true
# A07_DIRECT_DONE failures=0
```

Targeted tests after the A07 changes:

- `tests/test_post_nightmare_locations.gd`: **15/15 passed, 513 asserts**.
- `tests/test_labyrinth_first_fragment.gd`: **13/13 passed, 332 asserts**.

Actual in-game A03 integration remains **NOT TESTED** until A03 adds the child nodes.

## 5. Captures

- `docs/art/previews/post_nightmare/p05_overview.png`
- `docs/art/previews/post_nightmare/p05_entrance.png`
- `docs/art/previews/post_nightmare/p05_interrogation.png`
- `docs/art/previews/post_nightmare/p06_overview.png`
- `docs/art/previews/post_nightmare/p06_north.png`
- `docs/art/previews/post_nightmare/p07_overview.png`
- `docs/art/previews/post_nightmare/p07_gate_detail.png`
- `docs/art/previews/post_nightmare/p07_inner_road.png`
- `docs/art/previews/post_nightmare/p08_overview.png`
- `docs/art/previews/post_nightmare/p08_gallery.png`
- `docs/art/previews/post_nightmare/p09_overview.png`
- `docs/art/previews/post_nightmare/p09_dormitory.png`
- `docs/art/previews/post_nightmare/p09_observation.png`
- `docs/art/previews/post_nightmare/b01_overview.png`
- `docs/art/previews/post_nightmare/b01_start.png`
- `docs/art/previews/post_nightmare/b01_sword.png`
- `docs/art/previews/post_nightmare/b02_overview.png`
- `docs/art/previews/post_nightmare/b02_top.png`
- `docs/art/previews/post_nightmare/b02_bottom.png`
- `docs/art/previews/forgotten_shore/environment_art/z10_camp.png`
- `docs/art/previews/forgotten_shore/environment_art/z02_carcass.png`
- `docs/art/previews/forgotten_shore/environment_art/z15_refuge.png`
- `docs/art/previews/forgotten_shore/environment_art/z18_cliffs.png`
