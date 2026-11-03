class_name CombatHud
extends CanvasLayer
## Полосы здоровья и выносливости. Вне боя при полном запасе скрыты; в бою,
## после траты или при первом появлении HUD показывает себя. Холод и шум сюда
## не выводятся: для них есть ConditionFeedback.

@onready var player_bar: ProgressBar = %PlayerHealth
@onready var stamina_bar: ProgressBar = %PlayerStamina
@onready var enemy_bar: ProgressBar = %EnemyHealth
@onready var message: Label = %Message
@onready var player_panel: Control = get_node_or_null(^"Root/PlayerPanel")
@onready var enemy_panel: Control = get_node_or_null(^"Root/EnemyPanel")
@onready var player_label: Label = get_node_or_null(^"Root/PlayerPanel/PlayerLabel") as Label
@onready var enemy_label: Label = get_node_or_null(^"Root/EnemyPanel/EnemyLabel") as Label
@onready var vitals_bar: VitalsBar = get_node_or_null(^"Root/PlayerPanel/VitalsBar") as VitalsBar
@onready var vignette: ColorRect = get_node_or_null(^"Vignette") as ColorRect
@onready var vignette_material: ShaderMaterial = vignette.material as ShaderMaterial if vignette != null else null

@export var auto_bind := true
## Первые секунды после появления игрока HUD виден, чтобы игрок заметил полосы.
@export var first_reveal_seconds := 4.0

var _player: Node
var _player_health: HealthComponent
var _enemy_health: HealthComponent
var _stamina: StaminaComponent
var _enemy_locked := false
var _enemy_scan_timer := 0.0
var _reveal_left := 0.0
var _damage_flash: ColorRect
var _vignette_time := 0.0
var _base_player_fill: StyleBox


func _ready() -> void:
	var root := get_node_or_null(^"Root") as Control
	if root != null and root.theme == null:
		root.theme = RpgMenuTheme.build()
	if player_panel != null:
		player_panel.visible = false
	if enemy_panel != null:
		enemy_panel.visible = false
	_build_feedback_nodes(root)
	if auto_bind:
		call_deferred(&"_auto_bind")


func bind(player_health: HealthComponent, enemy_health: HealthComponent, stamina: StaminaComponent = null) -> void:
	_bind_player_health(player_health, stamina)
	_bind_enemy_health(enemy_health)
	_enemy_locked = enemy_health != null
	_reveal_left = first_reveal_seconds
	_update_visibility()


## Привязка к живому игроку: HUD сам читает боевой контекст.
func bind_player(player: Node, enemy: Node = null) -> void:
	_player = player
	if player != null:
		_bind_player_health(player.get(&"health") as HealthComponent, player.get(&"stamina") as StaminaComponent)
	if enemy != null:
		_bind_enemy_health(enemy.get(&"health") as HealthComponent)
		_enemy_locked = true
		if enemy_label != null and enemy.has_method(&"get_display_name"):
			enemy_label.text = String(enemy.call(&"get_display_name"))
	_reveal_left = first_reveal_seconds
	_update_visibility()


func show_message(text: String) -> void:
	if message == null:
		return
	message.text = text
	message.visible = true


func set_visible_for_combat(value: bool) -> void:
	if player_panel != null:
		player_panel.visible = value
	if enemy_panel != null:
		enemy_panel.visible = value and _enemy_health != null


func _process(delta: float) -> void:
	if auto_bind and _player == null:
		_auto_bind()
	if _player != null and not _enemy_locked:
		_enemy_scan_timer -= delta
		if _enemy_scan_timer <= 0.0:
			_enemy_scan_timer = 0.5
			var found := _find_nearest_enemy_health()
			if found != _enemy_health:
				_bind_enemy_health(found)
	if _reveal_left > 0.0:
		_reveal_left = maxf(_reveal_left - delta, 0.0)
	_update_vignette(delta)
	_update_visibility()


func _auto_bind() -> void:
	if _player != null:
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		bind_player(player)


func _bind_player_health(health: HealthComponent, stamina: StaminaComponent) -> void:
	if health != null and health != _player_health:
		if _player_health != null and is_instance_valid(_player_health):
			if _player_health.health_changed.is_connected(_on_player_health_changed):
				_player_health.health_changed.disconnect(_on_player_health_changed)
			if _player_health.damaged.is_connected(_on_player_damaged):
				_player_health.damaged.disconnect(_on_player_damaged)
		_player_health = health
		_player_health.health_changed.connect(_on_player_health_changed)
		_player_health.damaged.connect(_on_player_damaged)
	if stamina != null and stamina != _stamina:
		_stamina = stamina
		_stamina.stamina_changed.connect(_on_stamina_changed)
	_refresh_bars()


func _bind_enemy_health(health: HealthComponent) -> void:
	if health == _enemy_health:
		return
	if _enemy_health != null and is_instance_valid(_enemy_health):
		if _enemy_health.health_changed.is_connected(_on_enemy_health_changed):
			_enemy_health.health_changed.disconnect(_on_enemy_health_changed)
	_enemy_health = health
	if health != null:
		health.health_changed.connect(_on_enemy_health_changed)
		if enemy_label != null and _enemy_label_is_default():
			enemy_label.text = "Противник"
	_refresh_bars()


func _enemy_label_is_default() -> bool:
	return enemy_label != null and (enemy_label.text.is_empty() or enemy_label.text == "Противник")


func _on_player_health_changed(current: float, maximum: float) -> void:
	if player_bar != null:
		player_bar.max_value = maximum
		player_bar.value = current
	if vitals_bar != null:
		vitals_bar.set_health(current, maximum)
	_reveal_left = maxf(_reveal_left, 0.6)
	_update_visibility()


func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar != null:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
	if vitals_bar != null:
		vitals_bar.set_stamina(current, maximum)
	_update_visibility()


func _on_enemy_health_changed(current: float, maximum: float) -> void:
	if enemy_bar != null:
		enemy_bar.max_value = maximum
		enemy_bar.value = current
	_update_visibility()


func _on_player_damaged(amount: float) -> void:
	if amount <= 0.0 or _damage_flash == null:
		return
	_damage_flash.color = Color(0.55, 0.05, 0.04, 0.0)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.22, 0.05)
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.35)


func _refresh_bars() -> void:
	if _player_health != null:
		player_bar.max_value = _player_health.max_health
		player_bar.value = _player_health.current_health
		if vitals_bar != null:
			vitals_bar.set_health(_player_health.current_health, _player_health.max_health)
	if _stamina != null and stamina_bar != null:
		stamina_bar.max_value = _stamina.max_stamina
		stamina_bar.value = _stamina.current_stamina
		if vitals_bar != null:
			vitals_bar.set_stamina(_stamina.current_stamina, _stamina.max_stamina)
	if _enemy_health != null:
		enemy_bar.max_value = _enemy_health.max_health
		enemy_bar.value = _enemy_health.current_health
	_update_labels()
	_update_health_color()


func _update_labels() -> void:
	if player_label != null:
		if _player_health != null:
			player_label.text = "Санни · %d / %d" % [roundi(_player_health.current_health), roundi(_player_health.max_health)]
		else:
			player_label.text = "Санни"
	if enemy_label != null and _enemy_health != null:
		var name := "Противник"
		if _enemy_label_is_default():
			name = "Противник"
		else:
			name = enemy_label.text.get_slice(" · ", 0)
		enemy_label.text = "%s · %d / %d" % [name, roundi(_enemy_health.current_health), roundi(_enemy_health.max_health)]


func _update_health_color() -> void:
	if player_bar == null or _player_health == null:
		return
	var ratio := _player_health.current_health / maxf(_player_health.max_health, 1.0)
	var color := Color(0.45, 0.65, 0.5, 1.0)
	if ratio <= 0.3:
		color = Color(0.72, 0.26, 0.18, 1.0)
	elif ratio <= 0.6:
		color = Color(0.72, 0.52, 0.25, 1.0)
	var base_fill := player_bar.get_theme_stylebox("fill")
	if base_fill != null:
		var fill := base_fill.duplicate() as StyleBoxFlat
		if fill != null:
			fill.bg_color = color
			player_bar.add_theme_stylebox_override("fill", fill)
	if player_label != null:
		player_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.62) if ratio <= 0.3 else Color(0.91, 0.88, 0.82))


func _update_vignette(delta: float) -> void:
	if vignette == null or vignette_material == null:
		return
	_vignette_time += delta
	var ratio := 1.0
	if _player_health != null:
		ratio = _player_health.current_health / maxf(_player_health.max_health, 1.0)
	var critical := 1.0 - smoothstep(0.15, 0.55, ratio)
	if _player_health != null and _player_health.is_dead():
		critical = 1.0
	var pulse := 0.5 + 0.5 * sin(_vignette_time * TAU / 1.1)
	vignette_material.set_shader_parameter(&"intensity", critical * 0.82)
	vignette_material.set_shader_parameter(&"pulse", pulse)
	vignette_material.set_shader_parameter(&"viewport_size", get_viewport().get_visible_rect().size)
	vignette.visible = critical > 0.01


func _update_visibility() -> void:
	if player_panel == null or enemy_panel == null:
		return
	var in_combat := false
	if _player != null and _player.has_method(&"is_in_combat"):
		in_combat = bool(_player.call(&"is_in_combat"))
	var player_changed := _player_health != null and _player_health.current_health < _player_health.max_health
	var stamina_changed := _stamina != null and _stamina.current_stamina < _stamina.max_stamina
	player_panel.visible = in_combat or player_changed or stamina_changed or _reveal_left > 0.0
	var enemy_alive := _enemy_health != null and not _enemy_health.is_dead()
	var enemy_changed := _enemy_health != null and _enemy_health.current_health < _enemy_health.max_health
	enemy_panel.visible = enemy_alive and (in_combat or enemy_changed or _reveal_left > 0.0)


func _find_nearest_enemy_health() -> HealthComponent:
	if _player == null or not (_player is Node3D):
		return null
	var best: HealthComponent = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var candidate := node as Node3D
		if candidate == null:
			continue
		var health := candidate.get(&"health") as HealthComponent
		if health == null or health.is_dead():
			continue
		var distance := (_player as Node3D).global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = health
			best_distance = distance
	return best


func _build_feedback_nodes(root: Control) -> void:
	if root == null:
		return
	_damage_flash = ColorRect.new()
	_damage_flash.name = "DamageFlash"
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.color = Color(0.55, 0.05, 0.04, 0.0)
	root.add_child(_damage_flash)
	root.move_child(_damage_flash, 0)
	_update_vignette(0.0)
