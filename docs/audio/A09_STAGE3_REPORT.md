# A09 Stage 3 report — Audio & VFX

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Audio & VFX  
**Worktree:** A09 worktree (local path omitted)  
**Branch:** `demo/audio-vfx`  
**Base:** `ee97325`  
**Working state:** changes are uncommitted in the A09 worktree; A00 collects/merges.

---

## 1. Executive status

| Блок | Статус |
|---|---|
| A09-01 M1 ambience/music | **IMPLEMENTED** (profiles + 5 music cues + 6 beds) |
| A09-02 P05/P06 SFX | **IMPLEMENTED** (interactions, car loop, trigger cues) |
| A09-03 P09 induction/capsule | **IMPLEMENTED** (loops, capsule, induction flag) |
| A09-04 B01/B02 sea/tide | **IMPLEMENTED** (sea/water loops, shroud/statue/tide) |
| A09-05 Z01–Z10 / camp night | **IMPLEMENTED** (`camp_night_seen` transition) |
| A09-06 VFX shroud/tide/spray | **IMPLEMENTED** (7 new VFX scenes + profiles) |
| A09-07 VO/captions | **PARTIAL** — captions and coverage; no final VO |
| A09-08 Listening/mix | **PROTOCOL ONLY** — NOT TESTED |
| A09-09 Storm Z17 | Existing layer verified by probe; human pass NOT TESTED |
| P2 loop occlusion refresh | **IMPLEMENTED** in `SceneAudioDirector` |
| Shared hook | Applied in worktree; **A00 review required** |

No new autoload, no second mixer, no second particle framework. One additive
child in `AudioDirector`; all scene-specific behavior is data/profile driven.

---

## 2. New runtime

- `scripts/audio/scene_audio_director.gd` — watches `current_scene`, applies
  typed profile, assigns `Interactable.interact_cue`, listens to
  `TriggerZone.triggered`, `NightmareRunState.flag_changed`, dialogue start/finish,
  spawns local 3D loops, refreshes loop occlusion every 0.5 s.
- `scripts/audio/scene_audio_profile.gd`, `scene_audio_event.gd`.
- `scripts/vfx/scene_vfx_director.gd` — applies typed VFX profile, owns loops and
  one-shot lifetimes; child of `SceneAudioDirector`.
- `scripts/vfx/scene_vfx_profile.gd`, `scene_vfx_event.gd`.
- `audio_director.gd` — 3-line `SceneAudioDirector` hook + five reverb presets.

Profiles are no-ops for scenes without a matching `location_id`, so Labyrinth
and campaign audio are untouched.

---

## 3. Content

### Music

`m1_precinct`, `m1_academy`, `m1_sleeper`, `m1_black_sea`, `m1_descent` — each
3 layers (`base`, `pulse`, `melody`), project-owned procedural OGG.

### Ambience

`m1_precinct`, `m1_academy`, `m1_sleeper`, `m1_black_sea`, `m1_descent`,
`m1_camp_night` — project-owned PCM WAV (exact loop; Vorbis pre-roll removed).

### SFX

23 M1 cues including cell door, radio, mirror whisper, paper, HVAC, car idle,
car door, checkpoint, gate scan, flag, terminal, crowd, induction, capsule,
sea lap, statue, shroud, water flow, wave, rockfall, camp-night stinger.
Existing `world_*`, `ui_*`, footstep and combat cues are reused.

### VFX

`m1_rain_light`, `m1_snow_drift`, `m1_steam_vents`, `m1_induction_pulse`,
`m1_shroud_ribbons`, `m1_black_sea_mist`, `m1_tide_foam`.

Particle totals per VFX profile: 208–660; all below the 900 per-scene check.

---

## 4. Integration

| Owner | Request / status |
|---|---|
| A00 | Review additive `audio_director.gd` hook and reverb presets; formalize `tools/audio/**` carve-out |
| A03 | Map `POST_NIGHTMARE_AUDIO` to `m1_*` IDs; add `precinct_jett`, `black_sea_shroud`, terminal ID when canonical; current profiles already fallback |
| A01 | Canonical line IDs / voice IDs; M1 text-only acceptance |
| A04 | Canonical flags; profile listens to both legacy and canonical where applicable |
| A08 | Captions/volume UI; cue captions already populated |
| A10 | GUT/regression and listening; A09 provides validation tools |

No A03/A04/A08 scenes or scripts were edited by A09.

---

## 5. Verification actually run

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `test_audio_system.gd` | 19/19, 216 asserts |
| `test_audio_playback.gd` | 7/7, 36 asserts |
| `test_demo_audio_vfx.gd` | 8/8, 66 asserts |
| `test_post_nightmare_locations.gd` | 15/15, 513 asserts |
| `test_labyrinth_audio.gd` | 6/6, 65 asserts |
| `test_labyrinth_first_fragment.gd` | 13/13, 332 asserts |
| `tools/audit/audio_vfx_probe.gd` | storm/atmosphere/cues/VFX probe pass |
| `tools/audio/validate_m1_audio.gd` | VALIDATION PASS; 7 audio + 7 VFX profiles |
| `tools/audio/validate_m1_events.gd` | EVENT VALIDATION PASS (P05/P06/P09/B01/B02) |
| `tools/audio/validate_camp_night.gd` | CAMP NIGHT PASS (`camp`, `m1_camp_night`) |
| `tools/audio/validate_scene_transition.gd` | P05→P06 transition PASS; loops cleaned |
| `tools/audio/check_m1_audio.py` | files=44 failures=0; seams <0.005 |
| `tools/audio/audit_voice_coverage.py` | 12 sequences / 29 lines / 29 missing |

### NOT TESTED

- Human listening, balance, fatigue, speaker comparison — **NOT TESTED**.
- Full manual M1 route with audio — **NOT TESTED**.
- Final VO — absent; no SAPI shipped.
- Full mix / SFX reverb send / final occlusion tuning — **NOT TESTED**.
- Full GUT suite — not run; targeted sets above are the evidence.
- Export build — not run by A09.

---

## 6. Known blockers / risks

1. A03 currently still uses generic `POST_NIGHTMARE_AUDIO`; profile overrides with
   a short crossfade, so a short generic bleed is possible until A03 map update.
2. A03 canonical interaction IDs (`precinct_jett`, `black_sea_shroud`, terminal)
   are mapped in profiles but not present in current scenes; they activate when
   A03 adds them.
3. A01/A04 canonical flags are not all set by current scene code; profiles listen
   to canonical flags and will fire when those land.
4. Shared `audio_director.gd` hook needs A00 review.
5. `tools/audio/**` ownership is not in `FILE_OWNERSHIP.md`; request carve-out.
6. Final VO/licensing is unresolved; M1 is text-only.

---

## 7. Files changed/created

See `git status --short` in the worktree. Main groups:

```text
assets/audio/m1/{sfx,ambience,music}/**
scripts/audio/scene_audio_{director,profile,event}.gd
scripts/vfx/scene_vfx_{director,profile,event}.gd
scripts/audio/audio_director.gd                    # shared hook, A00 review
scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd  # A09 carve-out
resources/audio/audio_cue_library_demo.tres
resources/audio/scene_profiles/*.tres
resources/audio/scene_vfx_profiles/*.tres
scenes/environment/vfx/m1_*.tscn
tools/audio/generate_m1_audio.py
tools/audio/build_m1_profiles.gd
tools/audio/validate_m1_audio.gd
tools/audio/validate_m1_events.gd
tools/audio/validate_auto_scene.gd
tools/audio/validate_camp_night.gd
tools/audio/check_m1_audio.py
tools/audio/audit_voice_coverage.py
docs/audio/M1_LISTENING_TEST.md
docs/audio/M1_MIX_TARGETS.md
docs/audio/M1_ASSET_LICENSES_PROPOSAL.md
docs/audio/VO_M1_COVERAGE.md
docs/audio/Z17_STORM_CHECKLIST.md
docs/audio/A09_SHARED_HOOK_REQUEST.md
resources/audio/voice_manifest_m1.json
```

No commit or push was made in this worktree.
