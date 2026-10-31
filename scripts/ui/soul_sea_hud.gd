class_name SoulSeaHud
extends CanvasLayer
## Лёгкий HUD внутреннего пространства. Показывает здоровье оставленного
## в мире тела и подсказки, но не является вторым HUD боя.

@onready var root: Control = $Root
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var warning: Label = %Warning
@onready var prompt: Label = %Prompt
@onready var message: Label = %Message

var _health: HealthComponent
var _warning_left := 0.0
var _message_left := 0.0


func _ready() -> void:
	visible = false
	root.theme = RpgMenuTheme.build()
	warning.visible = false
	prompt.visible = false
	message.visible = false
	set_process(false)


func bind(health: HealthComponent) -> void:
	if _health == health:
		return
	if _health != null and is_instance_valid(_health):
		if _health.health_changed.is_connected(_on_health_changed):
			_health.health_changed.disconnect(_on_health_changed)
		if _health.damaged.is_connected(_on_damaged):
			_health.damaged.disconnect(_on_damaged)
	_health = health
	if _health == null:
		return
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_on_health_changed(_health.current_health, _health.max_health)


func set_active(value: bool) -> void:
	visible = value
	if value:
		warning.visible = false
		message.visible = false
		prompt.visible = false
		_warning_left = 0.0
		_message_left = 0.0
		_refresh_health()
		set_process(true)
	else:
		set_process(false)


func set_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = not text.is_empty()


func show_message(text: String, duration := 2.4) -> void:
	message.text = text
	message.visible = true
	_message_left = duration
	set_process(true)


func show_damage_warning() -> void:
	warning.text = "ТЕЛО ПОД АТАКОЙ · ВЫХОД НЕ ОСТАНАВЛИВАЕТ МИР"
	warning.visible = true
	_warning_left = 2.2
	set_process(true)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left = maxf(_message_left - delta, 0.0)
		if _message_left <= 0.0:
			message.visible = false
	if _warning_left > 0.0:
		_warning_left = maxf(_warning_left - delta, 0.0)
		if _warning_left <= 0.0:
			warning.visible = false
	if _message_left <= 0.0 and _warning_left <= 0.0:
		set_process(false)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_damaged(amount: float) -> void:
	if amount > 0.0 and visible:
		show_damage_warning()


func _refresh_health() -> void:
	if _health != null and is_instance_valid(_health):
		_on_health_changed(_health.current_health, _health.max_health)
