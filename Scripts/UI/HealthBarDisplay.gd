extends Range
class_name HealthBarDisplay

@export var health_controller_path: NodePath
@export var animation_duration: float = 0.12

var _health_controller: HealthController
var _bar_tween: Tween

func _ready() -> void:
	_health_controller = _resolve_health_controller()
	if _health_controller == null:
		push_warning("HealthBarDisplay: no se encontro HealthController.")
		value = 0.0
		return

	_health_controller.health_changed.connect(_on_health_changed)
	_refresh()

func _resolve_health_controller() -> HealthController:
	if not health_controller_path.is_empty():
		return get_node_or_null(health_controller_path) as HealthController

	for child in get_parent().get_children():
		if child is HealthController:
			return child as HealthController

	return null

func _refresh() -> void:
	if _health_controller == null:
		min_value = 0.0
		max_value = 1.0
		value = 0.0
		return

	min_value = 0.0
	max_value = float(_health_controller.get_max_health())
	value = float(_health_controller.get_health())

func _on_health_changed(current_health: int, max_health: int, _delta: int) -> void:
	min_value = 0.0
	max_value = float(max_health)

	if _bar_tween != null:
		_bar_tween.kill()

	if animation_duration <= 0.0:
		value = float(current_health)
		return

	_bar_tween = create_tween()
	_bar_tween.tween_property(self, "value", float(current_health), animation_duration)
