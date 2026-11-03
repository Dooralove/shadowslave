# Character rework status — 2026-11-02

**Status:** blocked on 3D generation credentials; v2 gear pass reverted.

## 1. Why the current cast is rejected

User review is correct:

- v2 gear pass added rigid pauldrons, bracers, skirts, spear/sword and fur that do not follow the body; they read as floating parts.
- P1 bodies are MPFB base meshes with low-poly clothing. The pants are especially weak (some meshes have very few polygons and open edges), and the silhouette is narrow/lanky.
- The UAL retarget is not visually clean: poses can twist knees/feet and put the character off the ground. Tests only confirm clip playback, not deformation quality.
- The current cast should **not** be treated as final or shipped.

## 2. What was rolled back

`scripts/slice/mannequin.gd` was returned to the original P1 assets for:

- `hero` / `auro` → `hero_auro.glb`
- `veteran` → `veteran.glb`
- `shifty` → `shifty.glb`
- `slave` / `mass_slave` → `mass_slave.glb`
- `knight` / `mass_soldier` → `mass_soldier.glb`

The v2 GLBs remain on disk as fallback but are not used by scenes.

Extreme scene width scales were reduced:

- Shifty/Scholar `0.9` → `1.0`;
- caravan slaves `1.4/1.35` → `1.15/1.12`;
- Hero `0.98` → `1.04`.

Tests after rollback: `test_caravan_site`, `test_pilgrim_path`, `test_caravan_march`, `test_slice_locations` — **32/32, 871 asserts**.

This rollback removes the floating gear but does **not** solve the body/clothing/animation quality.

## 3. Generator recheck (actual API errors)

The Blender addon has Hyper3D enabled and both fields filled. Rechecked directly:

| Route | Result |
|---|---|
| Hyper3D, free-trial key (scene override) | `API_INSUFFICIENT_FUNDS` |
| Hyper3D, saved private key (addon preferences, 64 chars) | `API_NO_ACTIVE_SUBSCRIPTION` |
| Hyper3D via `fal.ai` mode | `Authentication is required to access this application.` |
| Tencent Hunyuan 3D | generator off; no API URL/secret configured |
| Meshy | generator off; no API key configured |
| Tripo | generator off; no API key configured |
| MCP for Blender Premium generators | none; `premium_license_key` is empty |

The free-trial key was a 10-character scene override; it is exhausted. Clearing it makes the addon use the saved 64-character private key, which authenticates but has no active subscription. This is not a prompt or bbox problem.

To generate, one of these must happen:

1. Activate a Hyper3D subscription / add credits to the account that owns the saved private key; or
2. Replace the saved private key with a key from an account that has active credits; or
3. Provide a working FAL.ai key; or
4. Enable and configure Hunyuan3D/Meshy/Tripo with a valid key.

No generation was charged in these checks.

## 4. Options for the rework

### A. Generator-first (recommended if quality is the priority)

After the Hyper3D account is active:

- generate one A-pose body per main character (Hero/Auro, Sunny, Shifty, Scholar, Veteran; then police if needed);
- inspect mesh/UVs/textures; reject bad generations before rigging;
- retarget/clean weights to the existing 53-bone humanoid rig;
- bake UAL clips with proper rest-pose compensation and verify foot contact/knee deformation;
- only then replace P1 assets and delete the v2 gear files.

This is the only route that gives genuinely new sculpted bodies/faces from the requested generator.

### B. High-quality stock source

Use a small set of realistic rigged characters (e.g. Character Creator/UE-style assets) and retarget animations. This can produce better faces/bodies without generation, but:

- licenses must be checked and registered;
- stock clothing/style may not match canon;
- skeletons and animations need a retarget pipeline;
- consistency across the cast is harder.

### C. MPFB rebuild (interim)

Rebuild bodies/clothing from MPFB with body-derived, weighted garments instead of rigid gear, and fix the retarget/rest pose. This removes holes/floating and is fully controllable, but faces remain generic and it is not the requested generator quality.

## 5. Blender scene note

During the diagnostics, the open Blender scene was reset to an empty factory scene. Project files are untouched. An autosave from the session is at:

`C:\Users\user\AppData\Local\Temp\55564_autosave.blend`

If that scene matters, open it from Blender's File > Recover > Auto Save or the path above before continuing.

## 6. Not done

- No new generated model has been imported.
- No new rig or animation has been validated.
- No final model replacement has been made.
- Full GUT, manual playthrough, foot sliding, 1080p/60 — **NOT TESTED**.
