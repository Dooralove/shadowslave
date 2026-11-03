# Enemy hit/death animation libraries — A06 handoff

Additive `AnimationLibrary` resources for A05. They do not modify the source GLB
or its LODs. The source rigs are:

- `assets/characters/enemies/carapace_generated/carapace_scavenger_generated.glb`
- `assets/characters/enemies/larva/larva_corpse_lod.glb`

| Resource | Clip | Length | Intended use |
|---|---|---:|---|
| `carapace_hit.tres` | `Hit` | 0.42 s | Carapace short recoil; play only outside TELEGRAPH/ATTACK/DEAD |
| `larva_hit.tres` | `Hit` | 0.38 s | Larva squash/flinch |
| `larva_death.tres` | `Death` | 0.80 s | Larva collapse |

## A05 integration

```gdscript
var lib := load("res://assets/animations/enemies/carapace_hit.tres") as AnimationLibrary
animation_player.add_animation_library(&"authored", lib)
animation_player.play(&"authored/Hit")
```

A05 owns `CarapaceAnimator`, `LarvaAnimator` and enemy scenes. A06 only provides
the clips; do not add a second enemy animation framework. The existing
`CharacterLodVisibility` stays active on the same `AnimationPlayer`.

Validated with:

```powershell
godot --headless --path . -s tools/anim/enemy_clip_validate.gd
```
