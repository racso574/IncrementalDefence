extends Control

const FREE_COST: int = 0
const BOARD_SIZE: Vector2 = Vector2(3600.0, 2400.0)
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.0
const ZOOM_STEP: float = 1.1

const MIN_ATTACK_COOLDOWN: float = 0.15
const SPEED_COOLDOWN_STEP: float = 0.05

const LIGHTNING_COOLDOWN_STEP: float = 0.2
const MIN_LIGHTNING_COOLDOWN: float = 0.8
const LIGHTNING_AREA_STEP: float = 18.0

const SNOWBALL_COOLDOWN_STEP: float = 0.25
const MIN_SNOWBALL_COOLDOWN: float = 1.2
const SNOWBALL_SLOW_STEP: float = 0.06
const MIN_SNOWBALL_SLOW_FACTOR: float = 0.25
const SNOWBALL_FIELD_RADIUS_STEP: float = 10.0
const SNOWBALL_FIELD_DURATION_STEP: float = 0.25

const BLADE_SIZE_STEP: float = 4.0
const BLADE_ORBIT_STEP: float = 10.0
const BLADE_ROTATION_STEP: float = 0.28

@onready var board_viewport: Control = $BoardViewport
@onready var board_root: Control = $BoardViewport/BoardRoot
@onready var continue_button: Button = $ContinueButton
@onready var end_run_button: Button = $EndRunButton

var _run_state: Dictionary = {}
var _board_zoom: float = 0.92
var _is_panning: bool = false
var _note_info_labels: Dictionary = {}
var _action_buttons: Dictionary = {}

func _ready() -> void:
	_run_state = _build_run_state(ScenesManager.consume_payload())
	CurrencySystem.set_amount("gold", int(_run_state.get("gold", 0)))

	continue_button.pressed.connect(_on_continue_button_pressed)
	end_run_button.pressed.connect(_on_end_run_button_pressed)
	board_viewport.gui_input.connect(_on_board_viewport_gui_input)

	_build_board()
	_refresh_board_ui()
	call_deferred("_reset_board_view")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed and (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			or mouse_event.button_index == MOUSE_BUTTON_MIDDLE
		):
			_is_panning = false

func _build_run_state(payload: Variant) -> Dictionary:
	var state: Dictionary = {
		"gold": 250,
		"player_damage": 1,
		"player_attack_cooldown": 0.5,
		"damage_level": 0,
		"speed_level": 0,
		"elapsed_time_sec": 0.0,
		"lightning_unlocked": false,
		"lightning_damage": 2,
		"lightning_count": 3,
		"lightning_cooldown": 2.4,
		"lightning_area_radius": 96.0,
		"lightning_damage_level": 0,
		"lightning_count_level": 0,
		"snowball_unlocked": false,
		"snowball_damage": 2,
		"snowball_cooldown": 3.1,
		"snowball_slow_factor": 0.70,
		"snowball_field_radius": 66.0,
		"snowball_field_duration": 1.8,
		"snowball_damage_level": 0,
		"snowball_slow_level": 0,
		"blades_unlocked": false,
		"blade_count": 3,
		"blade_size": 18.0,
		"blade_orbit_radius": 72.0,
		"blade_rotation_speed": 2.6,
		"blade_damage": 1,
		"blade_count_level": 0,
		"blade_size_level": 0
	}

	if typeof(payload) != TYPE_DICTIONARY:
		return state

	for key in state.keys():
		if payload.has(key):
			state[key] = payload[key]

	return state

func _build_board() -> void:
	for child in board_root.get_children():
		child.queue_free()
	_note_info_labels.clear()
	_action_buttons.clear()

	board_root.custom_minimum_size = BOARD_SIZE
	board_root.size = BOARD_SIZE
	board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var board_bg := ColorRect.new()
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.color = Color(0.129412, 0.180392, 0.176471, 1.0)
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.add_child(board_bg)

	_create_sticky_note(
		"tick",
		"Tick",
		Vector2(1320.0, 660.0),
		Vector2(360.0, 0.0),
		Color(0.98, 0.92, 0.52, 1.0),
		[
			{"id": "tick_damage", "label": "Damage"},
			{"id": "tick_speed", "label": "Speed"}
		]
	)
	_create_sticky_note(
		"lightning",
		"Lightning",
		Vector2(1910.0, 620.0),
		Vector2(380.0, 0.0),
		Color(0.98, 0.78, 0.38, 1.0),
		[
			{"id": "lightning_unlock", "label": "Unlock"},
			{"id": "lightning_damage", "label": "Damage"},
			{"id": "lightning_count", "label": "Ray Count"},
			{"id": "lightning_cooldown", "label": "Cooldown"},
			{"id": "lightning_area", "label": "Area"}
		]
	)
	_create_sticky_note(
		"snowball",
		"Snowball",
		Vector2(1305.0, 1140.0),
		Vector2(390.0, 0.0),
		Color(0.71, 0.91, 1.0, 1.0),
		[
			{"id": "snowball_unlock", "label": "Unlock"},
			{"id": "snowball_damage", "label": "Damage"},
			{"id": "snowball_cooldown", "label": "Cooldown"},
			{"id": "snowball_slow", "label": "Slow"},
			{"id": "snowball_radius", "label": "Field Radius"},
			{"id": "snowball_duration", "label": "Field Duration"}
		]
	)
	_create_sticky_note(
		"blades",
		"Blades",
		Vector2(1910.0, 1140.0),
		Vector2(380.0, 0.0),
		Color(0.96, 0.77, 0.9, 1.0),
		[
			{"id": "blades_unlock", "label": "Unlock"},
			{"id": "blades_damage", "label": "Damage"},
			{"id": "blades_count", "label": "Count"},
			{"id": "blades_size", "label": "Size"},
			{"id": "blades_orbit", "label": "Orbit"},
			{"id": "blades_speed", "label": "Spin"}
		]
	)

func _create_sticky_note(note_id: String, title: String, pos: Vector2, note_size: Vector2, note_color: Color, actions: Array) -> void:
	var computed_height: float = maxf(note_size.y, 150.0 + float(actions.size()) * 46.0)
	var computed_size := Vector2(note_size.x, computed_height)
	var panel := Panel.new()
	panel.name = "%sNote" % note_id.capitalize()
	panel.position = pos
	panel.custom_minimum_size = computed_size
	panel.size = computed_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.rotation_degrees = {
		"tick": -2.0,
		"lightning": 1.5,
		"snowball": -1.0,
		"blades": 2.0
	}.get(note_id, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = note_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	board_root.add_child(panel)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18.0
	content.offset_top = 16.0
	content.offset_right = -18.0
	content.offset_bottom = -18.0
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.14, 0.14, 0.12, 1.0))
	content.add_child(title_label)

	var info_label := Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.16, 1.0))
	content.add_child(info_label)
	_note_info_labels[note_id] = info_label

	for action_def in actions:
		var button := Button.new()
		button.text = String(action_def.get("label", action_def.get("id", "")))
		button.custom_minimum_size = Vector2(0.0, 36.0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1.0))

		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.98, 0.98, 0.96, 0.92)
		button_style.corner_radius_top_left = 6
		button_style.corner_radius_top_right = 6
		button_style.corner_radius_bottom_right = 6
		button_style.corner_radius_bottom_left = 6
		button_style.border_width_left = 1
		button_style.border_width_top = 1
		button_style.border_width_right = 1
		button_style.border_width_bottom = 1
		button_style.border_color = Color(0.16, 0.16, 0.14, 0.18)
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_style)
		button.add_theme_stylebox_override("pressed", button_style)

		var action_id := String(action_def.get("id", ""))
		button.pressed.connect(_on_action_pressed.bind(action_id))
		content.add_child(button)
		_action_buttons[action_id] = button

func _refresh_board_ui() -> void:
	_set_note_text("tick", _get_tick_info_text())
	_set_note_text("lightning", _get_lightning_info_text())
	_set_note_text("snowball", _get_snowball_info_text())
	_set_note_text("blades", _get_blades_info_text())

	_set_button_state("tick_damage", "Damage +1 [0]", false)
	_set_button_state("tick_speed", "Cooldown -0.05 [0]", float(_run_state.get("player_attack_cooldown", 0.5)) <= MIN_ATTACK_COOLDOWN + 0.001)

	var lightning_unlocked := bool(_run_state.get("lightning_unlocked", false))
	_set_button_state("lightning_unlock", "Unlock [0]" if not lightning_unlocked else "Unlocked", lightning_unlocked)
	_set_button_state("lightning_damage", "Damage +1 [0]", not lightning_unlocked)
	_set_button_state("lightning_count", "Ray +1 [0]", not lightning_unlocked)
	_set_button_state("lightning_cooldown", "Cooldown -0.20 [0]", not lightning_unlocked or float(_run_state.get("lightning_cooldown", 2.4)) <= MIN_LIGHTNING_COOLDOWN + 0.001)
	_set_button_state("lightning_area", "Area +18 [0]", not lightning_unlocked)

	var snow_unlocked := bool(_run_state.get("snowball_unlocked", false))
	_set_button_state("snowball_unlock", "Unlock [0]" if not snow_unlocked else "Unlocked", snow_unlocked)
	_set_button_state("snowball_damage", "Damage +1 [0]", not snow_unlocked)
	_set_button_state("snowball_cooldown", "Cooldown -0.25 [0]", not snow_unlocked or float(_run_state.get("snowball_cooldown", 3.1)) <= MIN_SNOWBALL_COOLDOWN + 0.001)
	_set_button_state("snowball_slow", "Slow +6% [0]", not snow_unlocked or float(_run_state.get("snowball_slow_factor", 0.70)) <= MIN_SNOWBALL_SLOW_FACTOR + 0.001)
	_set_button_state("snowball_radius", "Field +10 [0]", not snow_unlocked)
	_set_button_state("snowball_duration", "Duration +0.25 [0]", not snow_unlocked)

	var blades_unlocked := bool(_run_state.get("blades_unlocked", false))
	_set_button_state("blades_unlock", "Unlock [0]" if not blades_unlocked else "Unlocked", blades_unlocked)
	_set_button_state("blades_damage", "Damage +1 [0]", not blades_unlocked)
	_set_button_state("blades_count", "Blade +1 [0]", not blades_unlocked)
	_set_button_state("blades_size", "Size +4 [0]", not blades_unlocked)
	_set_button_state("blades_orbit", "Orbit +10 [0]", not blades_unlocked)
	_set_button_state("blades_speed", "Spin +0.28 [0]", not blades_unlocked)

func _set_note_text(note_id: String, text: String) -> void:
	var label := _note_info_labels.get(note_id, null) as Label
	if label != null:
		label.text = text

func _set_button_state(action_id: String, text: String, disabled: bool) -> void:
	var button := _action_buttons.get(action_id, null) as Button
	if button == null:
		return
	button.text = text
	button.disabled = disabled

func _get_tick_info_text() -> String:
	return "Basic auto tick around the cursor.\nDamage: %d\nCooldown: %.2fs" % [
		int(_run_state.get("player_damage", 1)),
		float(_run_state.get("player_attack_cooldown", 0.5))
	]

func _get_lightning_info_text() -> String:
	return "Status: %s\nDamage: %d\nRays: %d\nCooldown: %.2fs\nArea: %.0f" % [
		"Ready" if bool(_run_state.get("lightning_unlocked", false)) else "Locked",
		int(_run_state.get("lightning_damage", 2)),
		int(_run_state.get("lightning_count", 3)),
		float(_run_state.get("lightning_cooldown", 2.4)),
		float(_run_state.get("lightning_area_radius", 96.0))
	]

func _get_snowball_info_text() -> String:
	return "Status: %s\nDamage: %d\nCooldown: %.2fs\nSlow: %d%%\nField: %.0f\nDuration: %.2fs" % [
		"Ready" if bool(_run_state.get("snowball_unlocked", false)) else "Locked",
		int(_run_state.get("snowball_damage", 2)),
		float(_run_state.get("snowball_cooldown", 3.1)),
		int(round((1.0 - float(_run_state.get("snowball_slow_factor", 0.70))) * 100.0)),
		float(_run_state.get("snowball_field_radius", 66.0)),
		float(_run_state.get("snowball_field_duration", 1.8))
	]

func _get_blades_info_text() -> String:
	return "Status: %s\nDamage: %d\nCount: %d\nSize: %.0f\nOrbit: %.0f\nSpin: %.2f" % [
		"Ready" if bool(_run_state.get("blades_unlocked", false)) else "Locked",
		int(_run_state.get("blade_damage", 1)),
		int(_run_state.get("blade_count", 3)),
		float(_run_state.get("blade_size", 18.0)),
		float(_run_state.get("blade_orbit_radius", 72.0)),
		float(_run_state.get("blade_rotation_speed", 2.6))
	]

func _on_action_pressed(action_id: String) -> void:
	match action_id:
		"tick_damage":
			_run_state["player_damage"] = int(_run_state.get("player_damage", 1)) + 1
		"tick_speed":
			_run_state["player_attack_cooldown"] = maxf(float(_run_state.get("player_attack_cooldown", 0.5)) - SPEED_COOLDOWN_STEP, MIN_ATTACK_COOLDOWN)
		"lightning_unlock":
			_run_state["lightning_unlocked"] = true
		"lightning_damage":
			_run_state["lightning_damage"] = int(_run_state.get("lightning_damage", 2)) + 1
		"lightning_count":
			_run_state["lightning_count"] = int(_run_state.get("lightning_count", 3)) + 1
		"lightning_cooldown":
			_run_state["lightning_cooldown"] = maxf(float(_run_state.get("lightning_cooldown", 2.4)) - LIGHTNING_COOLDOWN_STEP, MIN_LIGHTNING_COOLDOWN)
		"lightning_area":
			_run_state["lightning_area_radius"] = float(_run_state.get("lightning_area_radius", 96.0)) + LIGHTNING_AREA_STEP
		"snowball_unlock":
			_run_state["snowball_unlocked"] = true
		"snowball_damage":
			_run_state["snowball_damage"] = int(_run_state.get("snowball_damage", 2)) + 1
		"snowball_cooldown":
			_run_state["snowball_cooldown"] = maxf(float(_run_state.get("snowball_cooldown", 3.1)) - SNOWBALL_COOLDOWN_STEP, MIN_SNOWBALL_COOLDOWN)
		"snowball_slow":
			_run_state["snowball_slow_factor"] = maxf(float(_run_state.get("snowball_slow_factor", 0.70)) - SNOWBALL_SLOW_STEP, MIN_SNOWBALL_SLOW_FACTOR)
		"snowball_radius":
			_run_state["snowball_field_radius"] = float(_run_state.get("snowball_field_radius", 66.0)) + SNOWBALL_FIELD_RADIUS_STEP
		"snowball_duration":
			_run_state["snowball_field_duration"] = float(_run_state.get("snowball_field_duration", 1.8)) + SNOWBALL_FIELD_DURATION_STEP
		"blades_unlock":
			_run_state["blades_unlocked"] = true
		"blades_damage":
			_run_state["blade_damage"] = int(_run_state.get("blade_damage", 1)) + 1
		"blades_count":
			_run_state["blade_count"] = int(_run_state.get("blade_count", 3)) + 1
		"blades_size":
			_run_state["blade_size"] = float(_run_state.get("blade_size", 18.0)) + BLADE_SIZE_STEP
		"blades_orbit":
			_run_state["blade_orbit_radius"] = float(_run_state.get("blade_orbit_radius", 72.0)) + BLADE_ORBIT_STEP
		"blades_speed":
			_run_state["blade_rotation_speed"] = float(_run_state.get("blade_rotation_speed", 2.6)) + BLADE_ROTATION_STEP

	_refresh_board_ui()

func _on_board_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			_zoom_board(button_event.position, ZOOM_STEP)
			return
		if button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			_zoom_board(button_event.position, 1.0 / ZOOM_STEP)
			return
		if button_event.button_index == MOUSE_BUTTON_LEFT or button_event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = button_event.pressed
			return

	if event is InputEventMouseMotion and _is_panning:
		var motion_event := event as InputEventMouseMotion
		board_root.position += motion_event.relative

func _zoom_board(local_mouse: Vector2, zoom_factor: float) -> void:
	var old_zoom := _board_zoom
	var new_zoom := clampf(old_zoom * zoom_factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var world_point := (local_mouse - board_root.position) / old_zoom
	_board_zoom = new_zoom
	board_root.scale = Vector2.ONE * _board_zoom
	board_root.position = local_mouse - world_point * _board_zoom

func _reset_board_view() -> void:
	board_root.scale = Vector2.ONE * _board_zoom
	board_root.position = board_viewport.size * 0.5 - Vector2(1360.0, 980.0)

func _on_continue_button_pressed() -> void:
	_run_state["gold"] = CurrencySystem.get_amount("gold")
	TransitionManager.change_scene("GameTest", "fade_black", {
		"data": _run_state
	})

func _on_end_run_button_pressed() -> void:
	TransitionManager.change_scene("Menu", "fade_black")
