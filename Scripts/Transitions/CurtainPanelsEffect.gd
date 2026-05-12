extends TransitionEffectBase

@onready var panel_a: ColorRect = $PanelA
@onready var panel_b: ColorRect = $PanelB

func _on_configured() -> void:
	_layout_panels()
	visible = false

func _play_cover() -> void:
	_layout_panels()
	panel_a.position = _get_hidden_position(true)
	panel_b.position = _get_hidden_position(false)

	var duration: float = get_duration("cover_duration", 0.36)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(panel_a, "position", _get_cover_position(true), duration)
	tween.tween_property(panel_b, "position", _get_cover_position(false), duration)
	tween.finished.connect(finish_cover)

func _play_reveal() -> void:
	var duration: float = get_duration("reveal_duration", 0.36)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(panel_a, "position", _get_hidden_position(true), duration)
	tween.tween_property(panel_b, "position", _get_hidden_position(false), duration)
	tween.finished.connect(finish_reveal)

func _layout_panels() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mode: String = String(params.get("mode", "vertical"))
	var panel_scale: float = float(params.get("panel_scale", 1.18))
	var panel_margin: float = float(params.get("panel_margin", 96.0))
	var overlap: float = float(params.get("panel_overlap", 2.0))
	var tilt_degrees: float = float(params.get("tilt_degrees", 0.0))
	var tint: Color = params.get("color", Color(0, 0, 0, 1))

	panel_a.color = tint
	panel_b.color = tint

	var diagonal_size: float = viewport_size.length() * panel_scale
	if mode == "horizontal":
		var width: float = viewport_size.x * 0.5 + panel_margin + overlap
		var height: float = diagonal_size if absf(tilt_degrees) > 0.01 else viewport_size.y * panel_scale
		panel_a.size = Vector2(width, height)
		panel_b.size = Vector2(width, height)
	else:
		var width_v: float = diagonal_size if absf(tilt_degrees) > 0.01 else viewport_size.x * panel_scale
		var height_v: float = viewport_size.y * 0.5 + panel_margin + overlap
		panel_a.size = Vector2(width_v, height_v)
		panel_b.size = Vector2(width_v, height_v)

	panel_a.pivot_offset = panel_a.size * 0.5
	panel_b.pivot_offset = panel_b.size * 0.5
	panel_a.rotation_degrees = tilt_degrees
	panel_b.rotation_degrees = -tilt_degrees

func _get_cover_position(is_first: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mode: String = String(params.get("mode", "vertical"))
	var overlap: float = float(params.get("panel_overlap", 2.0))

	if mode == "horizontal":
		var y: float = (viewport_size.y - panel_a.size.y) * 0.5
		if is_first:
			return Vector2(viewport_size.x * 0.5 - panel_a.size.x + overlap, y)
		return Vector2(viewport_size.x * 0.5 - overlap, y)

	var x: float = (viewport_size.x - panel_a.size.x) * 0.5
	if is_first:
		return Vector2(x, viewport_size.y * 0.5 - panel_a.size.y + overlap)
	return Vector2(x, viewport_size.y * 0.5 - overlap)

func _get_hidden_position(is_first: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mode: String = String(params.get("mode", "vertical"))
	var panel_margin: float = float(params.get("panel_margin", 96.0))
	var cover_pos: Vector2 = _get_cover_position(is_first)

	if mode == "horizontal":
		if is_first:
			return Vector2(-panel_a.size.x - panel_margin, cover_pos.y)
		return Vector2(viewport_size.x + panel_margin, cover_pos.y)

	if is_first:
		return Vector2(cover_pos.x, -panel_a.size.y - panel_margin)
	return Vector2(cover_pos.x, viewport_size.y + panel_margin)
