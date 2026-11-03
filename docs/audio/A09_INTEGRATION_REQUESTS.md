# A09 integration requests for M1

**Дата:** 2026-11-03  
**Статус:** requests only; A09 does not edit these owners' files.

## A03 — World & Level

1. **Audio map:** replace the generic `POST_NIGHTMARE_AUDIO` entries with the
   M1 IDs. The runtime profile already overrides them, but the map is the
   canonical scene contract:
   - `police_precinct`: `m1_precinct` / `m1_precinct`
   - `academy_approach|gate|campus`: `m1_academy` / `m1_academy`
   - `academy_sleeper_center`: `m1_sleeper` / `m1_sleeper`
   - `black_sea_platform`: `m1_black_sea` / `m1_black_sea`
   - `tide_descent`: `m1_descent` / `m1_descent`
2. **IDs:** add `precinct_jett`, `black_sea_shroud`, and the canonical campus
   terminal interaction when A01/A03 settle them. Profiles already map these
   IDs, so no A09 follow-up code is needed.
3. **Anchors (optional):** add `AudioAnchors`/`VfxAnchors` only if POIs move.
   Current profiles use the coordinates in `poi_manifest.md`.
4. **Camp night:** set `camp_night_seen` once at the Z10 final beat; A09 listens
   and transitions music/ambience without editing the scene.

## A04 — Gameplay & Quest Systems

1. Confirm `flag_changed` canonical names: `p05_*`, `jett_advice_heard`,
   `academy_gate_passed`, `dorm_assigned`, `induction_seen`, `capsule_entered`,
   `statue_seen`, `shroud_summoned`, `tide_seen`, `camp_night_seen`.
2. Ensure flags are set **after** dialogue/interaction, not before scene ready;
   A09 uses the signal to fire one-shots and VFX.
3. Keep `DialogueRunner.line_started/finished`; A09 uses them for text-dialogue
   ducking.

## A01 — Narrative

1. Keep `DialogueLine.voice_id` or the derived `<sequence>_<index:03d>` rule.
2. M1 is accepted text-only; do not add SAPI files to `assets/audio/voice`
   without a licensing decision.
3. Provide canonical sequence/line IDs when `p05…b02` files are renamed.

## A08 — UI/UX

1. `SfxCue.caption` is populated for key M1 cues; `AudioCaptionOverlay` already
   displays it.
2. No audio settings UI changes are required for M1; existing master/music/
   ambience/SFX/voice/UI sliders are used.
3. Credits should mention procedural M1 audio/VFX as project-owned.

## A10 — QA

1. Add GUT coverage for `SceneAudioDirector` profile application, profile cue
   references, and VFX particle budgets using the A09 validation tools as cases.
2. Run the listening protocol in `docs/audio/M1_LISTENING_TEST.md`; leave
   **NOT TESTED** until a human signs it.
3. Include the M1 profile/event validation commands in the QA report.

## A00 — Technical Director

1. Review `scripts/audio/audio_director.gd` shared hook and reverb presets.
2. Formalize `tools/audio/**` ownership (A09 tooling carve-out).
3. Approve license proposal `docs/audio/M1_ASSET_LICENSES_PROPOSAL.md`.
4. Decide whether `POST_NIGHTMARE_AUDIO` map update is A03 W2 or A09 runtime
   fallback for the M1 gate.
