# A09 Stage 7 report — audience-facing quality pass

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Audio & VFX  
**Branch:** `demo/audio-vfx`  
**Previous commits:** `c069416`, `1330c0c`  
**Final commit:** reported in the A09 handoff.

## 1. What was visibly wrong

Player-view captures exposed four high-impact defects:

1. **P09 induction particles were huge opaque squares**, looking like a rendering
   bug rather than an induction effect.
2. **B02 tide foam rendered as hollow white rings** on the ground.
3. **P05 rain had no ground splashes**, only falling streaks.
4. **Scene entry had a slow generic-audio crossfade** before the M1 profile
   took over; this is most noticeable on every transition.

## 2. Fixes

- `m1_induction_pulse.tscn`: soft radial particle texture, 64 particles,
  0.12 quads, lower scale/velocity; no more blocky squares.
- `m1_tide_foam.tscn`: filled foam gradient, fewer/smaller patches; no rings.
- `m1_rain_light.tscn`: added 90 ground splash particles; rain and splash are
  now separate emitters under a ground-level root.
- `SceneAudioProfile`: M1 fade shortened to 0.5 s music / 0.7 s ambience.
- `SceneAudioDirector`: scene poll reduced from 0.20 s to 0.05 s, reducing the
  generic-map bleed window.
- `p07_flag_flap`: loop extended from 2.2 s to 6.5 s; no mechanical flap cycle.
- P05 rain position/root fixed; P05 breath attached to `Player`.
- `capture_m1_vfx.gd`: supports fixed audit cameras for P09/B02 inspection.

## 3. Verification

| Check | Result |
|---|---|
| `test_audio_system` | 19/19 |
| `test_audio_playback` | 7/7 |
| `test_demo_audio_vfx` | 8/8 |
| `test_post_nightmare_locations` | 15/15 |
| `test_level_transition` | 22/22 |
| `test_main_menu` | 7/7 |
| `test_labyrinth_audio` | 6/6 |
| `test_labyrinth_first_fragment` | 13/13 |
| `validate_m1_audio` | PASS |
| `validate_m1_events` | PASS |
| `validate_scene_transition` | P05→P06 music/ambience pass |
| `validate_persistent_state` | B01 shroud save-load pass |
| `validate_camp_night` | dynamic + loaded flag pass |
| `validate_dialogue_duck` | music/ambience/local-loop duck pass |
| `validate_vfx_cleanup` | induction one-shot freed, loop remains |
| `check_m1_audio.py` | 44 files, 0 failures |
| `audit_m1_assets.py` | 0 orphan audio/VFX/profiles |
| `audit_voice_coverage.py` | 29 M1 lines, 29 missing |

Visual captures now show:
- P05: rain + ground splashes in the yard.
- P06: readable snow around the player.
- P09: soft induction motes/ring instead of squares.
- B01: visible shroud ribbons around the player.
- B02: soft foam patches instead of rings.

## 4. Remaining work and ownership

### A00
- Accept/revert the shared `audio_director.gd` hook.
- Formalize `tools/audio/**` ownership.
- Approve the license proposal.

### A03
- Replace generic `POST_NIGHTMARE_AUDIO` with `m1_*` IDs.
- Add canonical Jett/terminal/shroud interactions and missing M1 scene content
  (P05 cell/Jett, P08 terminal, P09 cast, B01 Shroud, B02 ramp).
- This is why the profile currently needs a 0.5–0.7 s override after scene load.

### A04
- Canonical flags/aliases for `academy_jet_seen`, `sleeper_ready`,
  `black_sea_*`; A09 listens to canonical flags.

### A01
- 29 M1 lines have no VO; text-only is the current accepted fallback.
- Final VO needs recording/licensing, not SAPI shipping.

### A08
- Captions/credits; existing subtitle overlay is sufficient.

### A10
- Convert A09 validation tools into GUT tests.
- Run full GUT, export build, manual M1 route, listening and final mix.
- Human listening and full route remain **NOT TESTED**.

## 5. Known limitations

- Procedural M1 music/ambience is demo-quality, not final soundtrack.
- Full mix, SFX reverb send and final occlusion tuning are not done.
- Storm manual pass/FPS capture is not done.
- Current scene art remains greybox in P05/P06/B01; A03/A07 own it.
- No full GUT/export/manual pass is claimed.
