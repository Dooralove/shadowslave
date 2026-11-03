# A09 Stage 6 report — deep completeness audit

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Audio & VFX  
**Branch:** `demo/audio-vfx`  
**Base:** `ee97325`  
**Stage 5 commit:** `c069416784ac8bdbde543836f538331430efaa07`  
**Stage 6 commit:** reported in the final A09 handoff.

---

## 1. Baseline → current

Compared against `MASTER_AUDIT.md` §2.11, DP-1.0, `AGENT_TASKS` A09-01…09, the
existing Labyrinth audio/VFX layer and the Stage 5 runtime.

| Metric | Audit baseline | Current |
|---|---:|---:|
| SFX cues | 61 | 84 |
| Music cues | 14 | 19 |
| Ambience zones | 29 | 35 |
| M1 VFX scenes | 0 | 7 |
| M1 scene audio profiles | 0 | 7 |
| M1 scene VFX profiles | 0 | 7 |
| M1 audio files | 0 | 44 |
| M1 VO files | 0 | 0 (text-only decision) |

The existing Labyrinth layer remains intact: 15 emitters / 1478 particles,
storm rain/lightning/spray, campfire, 18 zones.

## 2. Closed in Stage 6

- **P05 rain visibility** moved into the yard; player-view capture now shows it.
- **P06/P07/P08 snow** follows `Player`; size and height tuned so it is visible
  on the 44 m approach instead of only at the centre.
- **B01 shroud** follows the player and is brighter/readable; player-view capture
  shows the ribbons. Persistent save-load restores them.
- **Campfire duplication** removed from `m1_camp_night` bed; positional
  `CampfireLoop` is now the only fire source.
- **P07 Nephis feedback** no longer reuses `world_echo_whisper` with the wrong
  “Шёпот Эха” caption; it uses a neutral wind cue.
- **P08 guide/terminal semantics**: guide uses `ui_confirm`; terminal aliases use
  the terminal beep.
- **Local loops** duck −4 dB during text dialogue and release after it.
- **AudioLibrary addendum** is now `preload`ed, so the exported build has an
  explicit dependency chain for all new cues.
- **P05 paper rustle** is now used as a low cell-area detail instead of only
  existing in the cue table.
- **VFX cleanup test** proves P09 one-shot induction particles are freed while
  the steam loop remains.
- **Asset usage audit**: 44/44 audio files, 7/7 VFX scenes, 14/14 profiles
  referenced; no orphans.

## 3. Deep findings still open

### Blocked by A03
- Current post-Nightmare audio still begins with generic `POST_NIGHTMARE_AUDIO`
  (`lobby/park/cell/black_sea`); A09 profile overrides after scene load. A03
  must switch the map to `m1_*` to remove the short generic bleed.
- Current P05 start is still the yard, Jett is absent, P08 still has a guide
  instead of the terminal, P09 lacks Rock/Kasper/Cassia, B01 lacks the Shroud
  interaction. A09 has aliases/fallbacks but cannot make those gameplay states.
- Canonical interaction IDs are not yet confirmed; A09 maps likely aliases.

### Blocked by A04
- Current scenes set legacy flags (`academy_jet_seen`, `sleeper_ready`,
  `black_sea_*`). A09 listens to canonical flags; A04 aliases are the bridge.

### Blocked by A01 / A00
- 29 M1 dialogue lines have no VO. M1 remains text-only; SAPI is deliberately
  not shipped. Final VO requires a licensing/recording decision.
- Shared `audio_director.gd` hook still requires A00 review; `tools/audio/**`
  ownership and licenses proposal also need A00.

### Blocked by A10
- No full GUT, export build, manual M1 pass or human listening pass.
- A09 validation tools are ready to convert into GUT tests, but `tests/**`
  belongs to A10.

### A09 partials
- A09-09 storm: existing implementation and probe pass; manual storm pass and
  FPS capture remain **NOT TESTED**.
- P2 full SFX reverb send/occlusion tuning remains after loop occlusion/duck.

## 4. Verification

| Check | Result |
|---|---|
| `--import` | exit 0 |
| `test_audio_system.gd` | 19/19, 216 asserts |
| `test_audio_playback.gd` | 7/7, 36 asserts |
| `test_demo_audio_vfx.gd` | 8/8, 66 asserts |
| `test_post_nightmare_locations.gd` | 15/15, 513 asserts |
| `test_level_transition.gd` | 22/22, 83 asserts |
| `test_main_menu.gd` | 7/7, 45 asserts |
| `test_labyrinth_audio.gd` | 6/6, 65 asserts |
| `test_labyrinth_first_fragment.gd` | 13/13, 332 asserts |
| `audio_vfx_probe.gd` | pass |
| `validate_m1_audio.gd` | VALIDATION PASS |
| `validate_m1_events.gd` | EVENT VALIDATION PASS |
| `validate_auto_scene.gd` | pass |
| `validate_scene_transition.gd` | P05→P06 music/ambience pass, loops clean |
| `validate_persistent_state.gd` | loaded B01 shroud pass |
| `validate_camp_night.gd` | dynamic + loaded flag pass |
| `validate_dialogue_duck.gd` | music/ambience/loop duck pass |
| `validate_vfx_cleanup.gd` | P09 one-shot freed, loop remains |
| `check_m1_audio.py` | 44 files, 0 failures, seams <0.005 |
| `audit_m1_assets.py` | 0 orphans |
| `audit_voice_coverage.py` | 12 sequences, 29 lines, 29 missing |

Visual player-view captures were run for P05 (rain), P06 (snow) and B01 with
`shroud_summoned` (ribbons). Captures are diagnostic and not committed.

### NOT TESTED

- Full manual M1 route and listening.
- Final VO/SAPI approval.
- Full GUT / export build / performance.
- Full final mix and storm manual pass.

## 5. Files changed in Stage 6

- `scripts/audio/audio_library.gd` — preload addendum dependency.
- `resources/audio/scene_profiles/{b01_black_sea,p05_police_precinct,p08_academy_campus}.tres`
- `resources/audio/scene_vfx_profiles/p05_police_precinct_vfx.tres`
- `tools/audio/build_m1_profiles.gd`
- `tools/audio/validate_scene_transition.gd`
- `tools/audio/validate_vfx_cleanup.gd`
- `docs/audio/A09_STAGE6_REPORT.md`

No A03/A04/A08/A01 gameplay files were changed.
