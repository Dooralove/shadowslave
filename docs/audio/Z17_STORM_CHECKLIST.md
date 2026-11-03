# Z17 storm checklist

**Дата:** 2026-11-03  
**Статус:** existing demo layer audited statically; manual listening **NOT TESTED**.

## Existing implementation

| Element | Source | Status |
|---|---|---|
| Storm music | `labyrinth_storm` (3 layers) | existing; tests pass |
| Rain | `scenes/environment/vfx/storm_rain.tscn`, 800 + 48 mist | existing |
| Lightning | `LabyrinthAtmosphere._flash_lightning`, one DirectionalLight3D | existing |
| Thunder | `world_storm_rumble` after 0.35–1.2 s | existing |
| Wind/spray | `world_wind_gust`, `tide_spray` at low gates | existing |
| Zone transition | `labyrinth_z16…z18` → `labyrinth_storm` | existing |

## Acceptance checklist

- [ ] Rain follows player; only one rain instance.
- [ ] Lightning flash 4.2 → 0.2 → 2.1 → 0, no shadow.
- [ ] Thunder never overlaps tide warning; rumble cooldown 2 s.
- [ ] Storm music intensity 0.80–0.95; no trailer braam.
- [ ] 1080p frame time not worse than pre-storm by >20%.
- [ ] Particle budget: rain 800, mist 48, no second storm.

The code path is covered by `test_demo_audio_vfx` and
`tools/audit/audio_vfx_probe.gd`; human storm pass is still **NOT TESTED**.
