# M1 audio asset license proposal

**Дата:** 2026-11-03  
**Статус:** proposal for A00/A07; `docs/ASSET_LICENSES.md` itself is frozen and is not edited by A09.

| Asset group | Files | Source | License | Runtime target |
|---|---|---|---|---|
| M1 SFX | `assets/audio/m1/sfx/*.wav` | `tools/audio/generate_m1_audio.py` | project-owned procedural | M1 |
| M1 ambience | `assets/audio/m1/ambience/*.wav` | `tools/audio/generate_m1_audio.py` | project-owned procedural | M1 |
| M1 music | `assets/audio/m1/music/*.ogg` | `tools/audio/generate_m1_audio.py` | project-owned procedural | M1 |
| M1 VFX | `scenes/environment/vfx/m1_*.tscn` | A09 authored | project-owned | M1 |

No third-party samples, tracks, or SAPI voice are included in this set.
SAPI remains a dev-only placeholder policy; final VO requires a separate
licensing decision and must be registered before import.
