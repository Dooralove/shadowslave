# A09 Stage 5 report — polish, regression and finalization

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Audio & VFX  
**Branch:** `demo/audio-vfx`  
**Base:** `ee97325`  
**Handoff commit:** reported in the final A09 message (one local commit; no push).

---

## 1. Closed Task IDs

| ID | State | Result |
|---|---|---|
| **A09-01** | CLOSED | 5 M1 music cues, 6 ambience beds, 7 typed scene profiles |
| **A09-02** | CLOSED | P05/P06 SFX, car loop, checkpoint, mirror, radio, doors |
| **A09-03** | CLOSED | P09 HVAC, induction, capsule, crowd, time-skip |
| **A09-04** | CLOSED | B01/B02 sea/water/statue/shroud/tide/coral; dialogue duck |
| **A09-05** | CLOSED | Z10 camp night, dynamic and save-loaded path |
| **A09-06** | CLOSED | 7 M1 VFX scenes, profiles, budgets, persistent shroud |
| **A09-QA-1** | CLOSED | profile/cue/event validation tools |
| **A09-QA-2** | CLOSED | asset-usage audit: 0 orphan files |
| **A09-QA-3** | CLOSED | persistent-state, transition, duck and camp tests |
| **A09-QA-4** | CLOSED | visual captures of P05/P06/B01 player views |

## 2. Partial / dependent

| ID | State | Remaining |
|---|---|---|
| A09-07 | PARTIAL | 29 M1 lines have no VO; text-only accepted; SAPI not shipped |
| A09-08 | PROTOCOL | human listening/mix is **NOT TESTED** |
| A09-09 | EXISTING VERIFIED | storm probe pass; manual storm pass **NOT TESTED** |
| P2 mix/occlusion | PARTIAL | loop occlusion + duck done; full SFX send/final mix **NOT TESTED** |

## 3. Final quality fixes

- Rain in P05 moved into the yard and captured visible.
- Snow in P06/P07/P08 follows the player; size/position adjusted for readability.
- Shroud VFX attaches to the player; brightness/ribbon size adjusted; visible in B01 capture.
- Camp-night ambience no longer duplicates fire crackle; positional campfire remains the only fire source.
- Local loops duck −4 dB during text dialogue and release after it.
- `shroud_summoned` restores audio/VFX when loading a save directly into B01.
- Canonical/legacy interaction aliases cover Jett, terminal, guard, Rock/Kasper/Cassia/medic and p07/p08/p09 paths.
- Profiles are `preload`ed for export dependency safety.
- HUD/subtitles feedback remains the existing A08 path; no duplicate UI.

## 4. Tests actually run

| Check | Result |
|---|---|
| `--import` | exit 0 |
| `test_audio_system.gd` | 19/19, 216 asserts |
| `test_audio_playback.gd` | 7/7, 36 asserts |
| `test_demo_audio_vfx.gd` | 8/8, 66 asserts |
| `test_post_nightmare_locations.gd` | 15/15, 513 asserts |
| `test_level_transition.gd` | 22/22, 83 asserts |
| `test_labyrinth_audio.gd` | 6/6, 65 asserts |
| `test_labyrinth_first_fragment.gd` | 13/13, 332 asserts |
| `test_main_menu.gd` | 7/7, 45 asserts |
| `audio_vfx_probe.gd` | storm/atmosphere/cues/VFX pass |
| `validate_m1_audio.gd` | VALIDATION PASS |
| `validate_m1_events.gd` | EVENT VALIDATION PASS |
| `validate_auto_scene.gd` | pass |
| `validate_scene_transition.gd` | pass |
| `validate_persistent_state.gd` | pass |
| `validate_camp_night.gd` | pass |
| `validate_dialogue_duck.gd` | pass |
| `check_m1_audio.py` | 44 files, 0 failures |
| `audit_m1_assets.py` | 0 orphan audio/VFX/profiles |
| `audit_voice_coverage.py` | 12 sequences, 29 missing VO |

### Visual captures

`godot --path . -s tools/audio/capture_m1_vfx.gd` was used for player-view
captures:

- P05: rain visible in the yard.
- P06: snow visible around the player along the approach.
- B01 with `shroud_summoned`: shroud ribbons visible around the player.

Captures are diagnostic only and are not committed. Full 18-zone visual pass is
**NOT TESTED**; A07's statue/platform art remains outside A09.

### NOT TESTED

- Human listening/balance/fatigue.
- Full manual M1 route with audio.
- Final VO and SAPI approval.
- Full GUT suite (known unstable baseline; targeted suites above are evidence).
- Export build and 4K/performance.
- Final SFX reverb send/mix.

## 5. New issues / remaining dependencies

1. **A00:** review the additive `audio_director.gd` hook and reverb presets; formalize `tools/audio/**`; approve license proposal.
2. **A03:** replace generic `POST_NIGHTMARE_AUDIO` entries with `m1_*` IDs and add canonical Jett/terminal/shroud interaction IDs.
3. **A01:** provide canonical line/voice IDs; M1 text-only sign-off.
4. **A04:** canonical flags/aliases; keep `DialogueRunner.line_started/finished` public.
5. **A08:** captions/credits; existing overlay is sufficient.
6. **A10:** convert A09 validation tools into GUT coverage; run listening and full QA.

## 6. Files

### New

- `scripts/audio/scene_audio_{director,profile,event}.gd`
- `scripts/vfx/scene_vfx_{director,profile,event}.gd`
- `resources/audio/scene_profiles/*.tres` (7)
- `resources/audio/scene_vfx_profiles/*.tres` (7)
- `scenes/environment/vfx/m1_*.tscn` (7)
- `assets/audio/m1/{sfx,ambience,music}/**`
- `resources/audio/voice_manifest_m1.json`
- `tools/audio/generate_m1_audio.py`
- `tools/audio/build_m1_profiles.gd`
- `tools/audio/check_m1_audio.py`
- `tools/audio/audit_voice_coverage.py`
- `tools/audio/audit_m1_assets.py`
- `tools/audio/validate_*.gd` (audio/event/auto/transition/camp/persistent/duck)
- `tools/audio/capture_m1_vfx.gd`
- `docs/audio/A09_STAGE3_REPORT.md`, `A09_STAGE4_REPORT.md`, `A09_STAGE5_REPORT.md`
- `docs/audio/A09_INTEGRATION_REQUESTS.md`, `A09_SHARED_HOOK_REQUEST.md`
- `docs/audio/M1_LISTENING_TEST.md`, `M1_MIX_TARGETS.md`
- `docs/audio/M1_ASSET_LICENSES_PROPOSAL.md`
- `docs/audio/VO_M1_COVERAGE.md`
- `docs/audio/Z17_STORM_CHECKLIST.md`

### Modified

- `scripts/audio/audio_director.gd` — shared hook + reverb presets, A00 review
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd` — A09 carve-out camp-night transition
- `resources/audio/audio_cue_library_demo.tres` — M1 cue addendum
- `tools/audio/build_demo_cues.gd` — M1 cue builder extension

No A03/A04/A08/A01 gameplay files were modified.
