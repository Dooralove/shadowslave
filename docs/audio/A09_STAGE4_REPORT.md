# A09 Stage 4 report — Audio & VFX completion audit

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Audio & VFX  
**Branch:** `demo/audio-vfx`  **Base:** `ee97325`  
**Commits:** none; changes stay uncommitted for A00.  
**Predecessor:** `docs/audio/A09_STAGE3_REPORT.md`

---

## 1. Fully closed this wave

| ID | Task | Evidence |
|---|---|---|
| A09-01 | M1 music/ambience, 5 cues and 6 beds | 7 scene profiles; validation PASS |
| A09-02 | P05/P06 SFX, car, checkpoint, mirror, radio | interaction/trigger validation PASS |
| A09-03 | P09 induction, capsule, crowd, HVAC | flag/event validation PASS |
| A09-04 | B01/B02 sea, water, statue, shroud, tide | event validation PASS; local-loop duck added |
| A09-05 | Z01–Z10 camp night | dynamic and save-loaded camp tests PASS |
| A09-06 | M1 VFX shroud/tide/splash/rain/snow/steam | 7 VFX scenes; particle budget 208–660 |
| QA-A09 | Asset usage audit | 44/44 audio, 7/7 VFX, 14/14 profiles referenced |
| QA-A09 | Export-safe profile inclusion | profiles use `preload`, not runtime path scan |
| QA-A09 | Save/load persistent shroud | direct-load B01 test PASS |
| QA-A09 | Text-dialogue duck for local loops | music −8, ambience −4, local loops −4; release PASS |

## 2. Partial / deliberately not final

| ID | State | Remaining |
|---|---|---|
| A09-07 VO/captions | **PARTIAL** | 29 M1 lines, 0 voice files; text-only accepted; SAPI not shipped |
| A09-08 Listening/mix | **PROTOCOL ONLY** | human pass is NOT TESTED |
| A09-09 Storm Z17 | Existing layer verified statically/probe | manual storm/listening NOT TESTED |
| P2 mix/occlusion | loop occlusion + local duck implemented | full SFX reverb send and final tuning NOT TESTED |

## 2.1. Additional polish from the second audit pass

- Aliases added for Jett, terminal, guard, Rock/Kasper/Cassia/medic and
  p07/p08/p09 flag paths, so canonical or legacy interaction IDs both receive a
  non-generic cue.
- Snow VFX in P06/P07/P08 follows `Player`, so the 44 m approach and campus do
  not lose precipitation at their ends.
- B01 shroud VFX attaches to `Player` instead of sitting at the statue edge.
- `m1_camp_night` bed now contains wind/distant sea only; the positional
  campfire loop remains the sole fire crackle (no double fire).
- Persistent `shroud_summoned` audio/VFX is restored when loading a save in B01.
- Local loops duck during text dialogue, not only music/ambience.

## 3. New issues found in the audit

1. **Generic scene map still wins at scene `_ready`.** `GreyboxLocation.POST_NIGHTMARE_AUDIO` starts `lobby/park/cell/black_sea`; the profile crossfades to `m1_*` after `current_scene` changes. Playable, but A03 should update the map to avoid a short generic bleed.
2. **Canonical interaction IDs are not all present.** Current scenes have `precinct_mirror`, `academy_checkpoint`, `academy_gate_checkpoint`, `academy_campus_guide`, `sleeper_capsule`, `black_sea_stars/sword/descent`. A03/A04 will add Jett, shroud and terminal; profiles now include aliases for those.
3. **Flag names differ between current scene code and contracts.** Profile listeners use canonical flags; A04 aliases will bridge legacy `academy_jet_seen`, `sleeper_ready`, `black_sea_*`.
4. **Save-loaded persistent shroud was missing.** Fixed with `SceneAudioEvent.persistent` / `SceneVfxEvent.persistent`; B01 restores sound + VFX when loaded with `shroud_summoned`.
5. **Local loops were not ducked during dialogue.** Fixed in `SceneAudioDirector`; ocean/car/HVAC loops now duck −4 dB and release.
6. **Profile resources were path-loaded at runtime.** Changed to `preload` arrays for export dependency safety.
7. **Asset usage was not audited.** Added `tools/audio/audit_m1_assets.py`; no orphans.
8. **A00 shared hook still needs review.** `scripts/audio/audio_director.gd` has the additive scene hook and reverb presets.
9. **`tools/audio/**` ownership is not formalized** in `FILE_OWNERSHIP.md`.

## 4. Verification (actually run)

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `test_audio_system.gd` | 19/19, 216 asserts |
| `test_audio_playback.gd` | 7/7, 36 asserts |
| `test_demo_audio_vfx.gd` | 8/8, 66 asserts |
| `test_post_nightmare_locations.gd` | 15/15, 513 asserts |
| `test_level_transition.gd` | 22/22, 83 asserts |
| `test_labyrinth_audio.gd` | 6/6, 65 asserts |
| `test_labyrinth_first_fragment.gd` | 13/13, 332 asserts |
| `tools/audit/audio_vfx_probe.gd` | storm/atmosphere/cues/VFX pass |
| `validate_m1_audio.gd` | VALIDATION PASS |
| `validate_m1_events.gd` | EVENT VALIDATION PASS, including P07/P08 flags |
| `validate_auto_scene.gd` | profile applies via `current_scene` |
| `validate_scene_transition.gd` | P05→P06, loops cleaned |
| `validate_persistent_state.gd` | loaded B01 restores shroud sound/VFX |
| `validate_camp_night.gd` | dynamic + loaded flag PASS |
| `validate_dialogue_duck.gd` | music/ambience/local-loop duck + release PASS |
| `check_m1_audio.py` | 44 files, 0 failures, seams < 0.005 |
| `audit_m1_assets.py` | 0 orphan audio/VFX/profile files |
| `audit_voice_coverage.py` | 12 sequences, 29 lines, 29 missing |

### NOT TESTED

- Human listening / balance / fatigue / speaker comparison.
- Full manual M1 route with audio.
- Final VO, SAPI policy approval, localization.
- Full GUT suite; export build; 1080p/4K performance.
- Full SFX reverb send / final mix.

## 5. Remaining dependencies

| Owner | Needed |
|---|---|
| A00 | Accept/revert shared `audio_director.gd` hook; formalize `tools/audio/**`; license proposal; decide scene-map update window |
| A03 | Update `POST_NIGHTMARE_AUDIO`; add Jett/shroud/terminal interaction IDs; keep POI anchors if moved |
| A01 | Canonical M1 line/voice IDs; text-only sign-off |
| A04 | Canonical flags and aliases; ensure dialogue signals stay public |
| A08 | Captions/credits; no new UI required |
| A10 | Add GUT coverage; run listening; include validation commands in QA report |

## 6. Files added/changed in this wave

```text
scripts/audio/scene_audio_{director,profile,event}.gd
scripts/vfx/scene_vfx_{director,profile,event}.gd
scripts/audio/audio_director.gd                         # A00 review
scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd  # A09 carve-out
resources/audio/audio_cue_library_demo.tres
resources/audio/scene_profiles/*.tres
resources/audio/scene_vfx_profiles/*.tres
scenes/environment/vfx/m1_*.tscn
assets/audio/m1/{sfx,ambience,music}/**
tools/audio/{generate_m1_audio,check_m1_audio,audit_voice_coverage,audit_m1_assets}.py
tools/audio/{build_m1_profiles,validate_m1_audio,validate_m1_events,validate_auto_scene,validate_scene_transition,validate_camp_night,validate_persistent_state,validate_dialogue_duck}.gd
docs/audio/*.md
resources/audio/voice_manifest_m1.json
```

No commit or push was made. A00 can collect the worktree diff.
