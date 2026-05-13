extends Label
class_name HealthValueLabel

@export var health_controller_path: NodePath
@export var show_max_health: bool = true
@export var prefix: String = ""
@export var suffix: String = ""
@export var animation_duration: float = 0.18

var _health_controller: HealthController
var _displayed_health: float = 0.0
var _display_tween: Tween

func _ready() -> void:
	_health_controller = _resolve_health_controller()
	if _health_controller == null:
		push_warning("HealthValueLabel: no se encontro HealthController.")
		text = prefix + "0" + suffix
		return

	_health_controller.health_changed.connect(_on_health_changed)
	_displayed_health = float(_health_controller.get_health())
	_refresh()
	call_deferred("_sync_initial_display")

func _resolve_health_controller() -> HealthController:
	if not health_controller_path.is_empty():
		return get_node_or_null(health_controller_path) as HealthController

	for child in get_parent().get_children():
		if child is HealthController:
			return child as HealthController

	return null

func _refresh() -> void:
	if _health_controller == null:
		text = prefix + "0" + suffix
		return

	var shown_health := int(round(_displayed_health))
	if show_max_health:
		text = "%s%d/%d%s" % [
			prefix,
			shown_health,
			_health_controller.get_max_health(),
			suffix
		]
	else:
		text = "%s%d%s" % [
			prefix,
			shown_health,
			suffix
		]

func _on_health_changed(_current_health: int, _max_health: int, _delta: int) -> void:
	_animate_to(float(_current_health))
	_refresh()

func _sync_initial_display() -> void:
	if _health_controller == null:
		return
	_displayed_health = float(_health_controller.get_health())
	_refresh()

func _animate_to(target_health: float) -> void:
	if _display_tween != null:
		_display_tween.kill()

	if animation_duration <= 0.0:
		_displayed_health = target_health
		_refresh()
		return

	_display_tween = create_tween()
	_display_tween.tween_method(_set_displayed_health, _displayed_health, target_health, animation_duration)

func _set_displayed_health(value: float) -> void:
	_displayed_health = value
	_refresh()
