# A09 shared-file request — AudioDirector scene hook

**Дата:** 2026-11-03  
**Автор:** A09 / Chat 09  
**Статус:** change is present in `demo/audio-vfx` worktree; **A00 review/claim required before merge**.

## Why

M1 post-Nightmare scenes are owned by A03 and must not be edited by A09. The
runtime `SceneAudioDirector` needs one `add_child()` hook in the existing audio
autoload. Without it, A09 can only supply assets/profiles and cannot apply them
without asking A03 to add a node to every scene.

## Exact additive change

`scripts/audio/audio_director.gd`:

```gdscript
var scene_audio: SceneAudioDirector
```

In `_ready()`, after `voice`:

```gdscript
scene_audio = SceneAudioDirector.new()
scene_audio.name = "SceneAudioDirector"
add_child(scene_audio)
```

No public methods or signal signatures change. `SceneAudioDirector` is a no-op
for scenes without a profile; Labyrinth/campaign audio keep their own directors.

Also added five read-only reverb presets (`precinct_hall`, `academy_hall`,
`sleeper_hall`, `black_sea`, `descent`) to the existing `REVERB_PRESETS`.

## Ownership note

`tools/audio/**` is used for the existing generators/probes and the new M1
validation tools. It is not currently assigned in `FILE_OWNERSHIP.md`; request
A00 to formalize it as an A09 tooling carve-out (runtime-neutral, no game
assets).

## Rollback

Remove the `scene_audio` declaration, the three `_ready()` lines, and the five
presets. All other A09 files remain independent.
