extends TransitionEffectBase

var _strips: Array[Control] = []
var _bounce_heights: Array[float] = []
var _pending_tweens: int = 0

func _on_configured() -> void:
	_build_strips()
	_build_bounce_heights()
	visible = false

func _play_cover() -> void:
	_position_strips_for_cover()
	_run_cover_tweens()

func _play_reveal() -> void:
	_position_strips_for_reveal()
	_run_reveal_tweens()

func _build_strips() -> void:
	for strip in _strips:
		strip.queue_free()
	_strips.clear()

	var viewport_size: Vector2 = get_viewport_rect().size
	var column_count: int = int(params.get("column_count", 6))
	var overscan_y: float = float(params.get("overscan_y", 64.0))
	var rest_top_extra: float = float(params.get("rest_top_extra", 0.0))
	var strip_width: float = ceilf(viewport_size.x / float(column_count))
	var strip_height: float = viewport_size.y + overscan_y + rest_top_extra
	var tint: Color = params.get("color", Color(0, 0, 0, 1))

	for i in range(column_count):
		var strip := Control.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.size = Vector2(strip_width + 1.0, strip_height)
		strip.position = Vector2(strip_width * i, -strip_height)

		var fill := ColorRect.new()
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = tint
		strip.add_child(fill)

		add_child(strip)
		_strips.append(strip)

func _position_strips_for_cover() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var overscan_y: float = float(params.get("overscan_y", 64.0))
	var rest_top_extra: float = float(params.get("rest_top_extra", 0.0))
	var start_gap: float = float(params.get("cover_start_gap", 22.0))

	for i in range(_strips.size()):
		var strip: Control = _strips[i]
		strip.position.y = -strip.size.y - start_gap * i
		strip.position.x = strip.size.x * i
		strip.size.y = viewport_size.y + overscan_y + rest_top_extra

func _position_strips_for_reveal() -> void:
	var rest_y: float = _get_rest_y()
	for strip in _strips:
		strip.position.y = rest_y

func _run_cover_tweens() -> void:
	var rest_y: float = _get_rest_y()
	var stagger: float = float(params.get("stagger", 0.05))
	var duration: float = get_duration("cover_duration", 0.34)
	var fall_duration: float = duration * 0.36
	var bounce_up_1_duration: float = duration * 0.22
	var bounce_down_1_duration: float = duration * 0.18
	var bounce_up_2_duration: float = duration * 0.14
	var bounce_down_2_duration: float = duration * 0.10

	_pending_tweens = _strips.size()
	for i in range(_strips.size()):
		var strip: Control = _strips[i]
		var bounce_up_1: float = rest_y - _get_bounce_height(i)
		var bounce_up_2: float = rest_y - _get_bounce_height(i) * 0.62
		var tween := create_tween()
		tween.tween_interval(stagger * i)
		tween.set_trans(Tween.TRANS_QUART)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(strip, "position:y", rest_y, fall_duration)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(strip, "position:y", bounce_up_1, bounce_up_1_duration)
		tween.set_trans(Tween.TRANS_QUART)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(strip, "position:y", rest_y, bounce_down_1_duration)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(strip, "position:y", bounce_up_2, bounce_up_2_duration)
		tween.set_trans(Tween.TRANS_QUART)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(strip, "position:y", rest_y, bounce_down_2_duration)
		tween.finished.connect(_on_cover_strip_finished)

func _run_reveal_tweens() -> void:
	var stagger: float = float(params.get("stagger", 0.05))
	var duration: float = get_duration("reveal_duration", 0.34)
	var end_y: float = -(_strips[0].size.y + float(params.get("reveal_end_gap", 22.0)))

	_pending_tweens = _strips.size()
	for i in range(_strips.size()):
		var strip: Control = _strips[i]
		var tween := create_tween()
		tween.set_trans(get_tween_trans())
		tween.set_ease(Tween.EASE_IN)
		tween.tween_interval(stagger * i)
		tween.tween_property(strip, "position:y", end_y, duration)
		tween.finished.connect(_on_reveal_strip_finished)

func _on_cover_strip_finished() -> void:
	_pending_tweens -= 1
	if _pending_tweens <= 0:
		finish_cover()

func _on_reveal_strip_finished() -> void:
	_pending_tweens -= 1
	if _pending_tweens <= 0:
		finish_reveal()

func _get_rest_y() -> float:
	var overscan_y: float = float(params.get("overscan_y", 64.0))
	var rest_top_extra: float = float(params.get("rest_top_extra", 0.0))
	return -(overscan_y + rest_top_extra)

func _build_bounce_heights() -> void:
	_bounce_heights.clear()

	var base_bounce: float = float(params.get("bounce_px", 18.0))
	var variation: float = clampf(float(params.get("bounce_variation", 0.0)), 0.0, 0.95)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _i in range(_strips.size()):
		var factor: float = rng.randf_range(1.0 - variation, 1.0 + variation)
		_bounce_heights.append(base_bounce * factor)

func _get_bounce_height(index: int) -> float:
	if index >= 0 and index < _bounce_heights.size():
		return _bounce_heights[index]
	return float(params.get("bounce_px", 18.0))
