class_name Hurtbox
extends Area3D
## Зона, по которой можно попасть. Передаёт урон в HealthComponent.
## Слой коллизии задаёт, чьи атаки её видят (player_hurtbox / enemy_hurtbox).

signal hit_received(damage: float, source: Node)

const VFX := preload("res://scripts/vfx/one_shot_vfx.gd")

@export var health: HealthComponent
## Неуязвимость на время уклонения.
@export var invulnerable := false
## Множитель входящего урона: 1 — обычный, 0.3 — блок.
@export var damage_scale := 1.0
## Множитель слабой точки: 1 — обычная зона, >1 — weak spot.
## Отдельно от damage_scale, чтобы блок не смешивался с бонусом weak spot.
@export var damage_multiplier := 1.0
## Необязательный cue для этой зоны. Для weak spot карапакса — combat_hit_carapace.
@export var hit_cue_override: StringName = &""
## Смещение точки VFX от центра hurtbox. Weak spot ниже/точнее, чем тело.
@export var impact_offset := Vector3(0.0, 0.9, 0.0)


func _ready() -> void:
	# Хёртбокс только обнаруживают, сам он ничего не ищет.
	monitoring = false
	monitorable = true


## Возвращает true, если урон был нанесён.
func receive_hit(damage: float, source: Node, damage_type: StringName = &"physical") -> bool:
	if invulnerable or health == null or health.is_dead():
		return false
	var scaled_damage := damage * maxf(damage_multiplier, 0.0) * clampf(damage_scale, 0.0, 1.0)
	var applied := health.take_damage(scaled_damage, damage_type)
	if applied > 0.0:
		# A lethal hit is followed by the owner's death cue and death VFX.
		# Playing a separate impact cue on top would double the event.
		if not health.is_dead():
			var cue := hit_cue()
			_play_cue(cue)
			_spawn_impact(cue)
	hit_received.emit(applied, source)
	return applied > 0.0


func hit_cue() -> StringName:
	if hit_cue_override != &"":
		return hit_cue_override
	var owner_name := ""
	var host := get_parent()
	if host is CarapaceEnemy:
		return &"combat_hit_carapace"
	if host != null:
		owner_name = String(host.name).to_lower()
	if owner_name.contains("larva") or owner_name.contains("crab") or owner_name.contains("carapace"):
		return &"combat_hit_carapace"
	if owner_name.contains("knight") or owner_name.contains("soldier") or owner_name.contains("guard"):
		return &"combat_hit_armor"
	if owner_name.contains("bone") or owner_name.contains("skeleton"):
		return &"combat_hit_bone"
	return &"combat_hit_flesh"


func _play_cue(cue: StringName) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null or not director.has_method(&"play_sfx"):
		return
	director.call(&"play_sfx", cue, global_position)


func _spawn_impact(cue: StringName) -> void:
	var point := global_position + impact_offset
	match cue:
		&"combat_hit_armor":
			VFX.spawn_dust(point)
		&"combat_hit_bone":
			VFX.spawn_dust(point)
		&"combat_hit_carapace":
			VFX.spawn_ichor(point)
			VFX.spawn_dust(point)
		_:
			VFX.spawn_ichor(point)
