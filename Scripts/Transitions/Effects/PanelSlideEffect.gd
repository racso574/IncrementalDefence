extends TransitionEffectBase

@onready var panel: ColorRect = $Panel

func _on_configured() -> void:
	panel.color = params.get("color", Color(0, 0, 0, 1))
	panel.rotation_degrees = float(params.get("tilt_degrees", 0.0))
	_layout_panel()
	panel.position = _get_enter_position()
	visible = false

func _play_cover() -> void:
	_layout_panel()
	panel.position = _get_enter_position()

	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(panel, "position", _get_cover_position(), get_duration("cover_duration", 0.34))
	tween.finished.connect(finish_cover)

func _play_reveal() -> void:
	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(panel, "position", _get_exit_position(), get_duration("reveal_duration", 0.34))
	tween.finished.connect(finish_reveal)

func _layout_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_scale: float = float(params.get("panel_scale", 1.28))
	panel.size = viewport_size * panel_scale
	panel.rotation_degrees = float(params.get("tilt_degrees", 0.0))

func _get_cover_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return (viewport_size - panel.size) * 0.5

func _get_enter_position() -> Vector2:
	return _get_directional_position(String(params.get("enter_from", "top")), false)

func _get_exit_position() -> Vector2:
	var exit_mode: String = String(params.get("exit_mode", "reverse"))
	if exit_mode == "through":
		return _get_directional_position(_get_opposite_direction(String(params.get("enter_from", "top"))), true)
	return _get_directional_position(String(params.get("enter_from", "top")), true)

func _get_directional_position(direction: String, is_exit: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = _get_cover_position()
	var margin: float = float(params.get("panel_margin", 96.0))

	match direction:
		"bottom":
			return Vector2(center.x, viewport_size.y + margin) if is_exit else Vector2(center.x, viewport_size.y + margin)
		"left":
			return Vector2(-panel.size.x - margin, center.y) if not is_exit else Vector2(-panel.size.x - margin, center.y)
		"right":
			return Vector2(viewport_size.x + margin, center.y) if is_exit else Vector2(viewport_size.x + margin, center.y)
		_:
			return Vector2(center.x, -panel.size.y - margin) if not is_exit else Vector2(center.x, -panel.size.y - margin)

func _get_opposite_direction(direction: String) -> String:
	match direction:
		"top":
			return "bottom"
		"bottom":
			return "top"
		"left":
			return "right"
		"right":
			return "left"
		_:
			return "bottom"
