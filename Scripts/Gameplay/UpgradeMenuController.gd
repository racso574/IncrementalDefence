extends Control

const BOARD_SIZE: Vector2 = Vector2(5200.0, 3400.0)
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.0
const ZOOM_STEP: float = 1.1

const KIND_NUMERIC := "numeric"
const KIND_TOGGLE := "toggle"
const KIND_MODE := "mode"

const TOWER_TARGET_MODES: Array[int] = [
	PlayerAbilityConfig.TargetMode.MOUSE,
	PlayerAbilityConfig.TargetMode.NEAREST_ENEMY
]

const RANDOM_TARGET_MODES: Array[int] = [
	PlayerAbilityConfig.TargetMode.MOUSE,
	PlayerAbilityConfig.TargetMode.RANDOM_DIRECTION
]

@onready var board_viewport: Control = $BoardViewport
@onready var board_root: Control = $BoardViewport/BoardRoot
@onready var continue_button: Button = $ContinueButton
@onready var end_run_button: Button = $EndRunButton

var _run_state: Dictionary = {}
var _board_zoom: float = 0.92
var _is_panning: bool = false
var _action_value_labels: Dictionary = {}
var _note_info_labels: Dictionary = {}
var _action_definitions: Dictionary = {}
var _note_definitions: Array[Dictionary] = []

func _ready() -> void:
	_run_state = PlayerAbilityConfig.merge_run_state(ScenesManager.consume_payload())
	CurrencySystem.set_amount("gold", int(_run_state.get("gold", 0)))
	_action_definitions = _build_action_definitions()
	_note_definitions = _build_note_definitions()

	continue_button.text = "Resume Run"
	end_run_button.text = "End Debug Run"
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

func _build_board() -> void:
	for child in board_root.get_children():
		child.queue_free()
	_action_value_labels.clear()
	_note_info_labels.clear()

	board_root.custom_minimum_size = BOARD_SIZE
	board_root.size = BOARD_SIZE
	board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var board_bg := ColorRect.new()
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.color = Color(0.129412, 0.180392, 0.176471, 1.0)
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.add_child(board_bg)

	for note_def in _note_definitions:
		_create_sticky_note(note_def)

func _create_sticky_note(note_def: Dictionary) -> void:
	var action_ids: Array = note_def.get("actions", [])
	var computed_height: float = maxf(220.0, 142.0 + float(action_ids.size()) * 42.0)
	var note_size: Vector2 = Vector2(note_def.get("width", 430.0), computed_height)

	var panel := Panel.new()
	panel.name = "%sNote" % String(note_def.get("id", "Note")).capitalize()
	panel.position = note_def.get("position", Vector2.ZERO)
	panel.custom_minimum_size = note_size
	panel.size = note_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.rotation_degrees = float(note_def.get("rotation", 0.0))

	var style := StyleBoxFlat.new()
	style.bg_color = note_def.get("color", Color(0.98, 0.92, 0.52, 1.0))
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
	title_label.text = String(note_def.get("title", "Ability"))
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.14, 0.14, 0.12, 1.0))
	content.add_child(title_label)

	var info_label := Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.16, 1.0))
	content.add_child(info_label)
	_note_info_labels[String(note_def.get("id", ""))] = info_label

	for action_id_variant in action_ids:
		var action_id := String(action_id_variant)
		var action_def: Dictionary = _action_definitions.get(action_id, {})
		if action_def.is_empty():
			continue
		_create_action_row(content, action_id, action_def)

func _create_action_row(parent: VBoxContainer, action_id: String, action_def: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = String(action_def.get("label", action_id))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.1, 1.0))
	row.add_child(label)

	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.custom_minimum_size = Vector2(104.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.1, 1.0))
	row.add_child(value_label)
	_action_value_labels[action_id] = value_label

	var minus_button := _build_action_button(_get_minus_button_text(String(action_def.get("kind", KIND_NUMERIC))))
	minus_button.pressed.connect(_on_action_adjusted.bind(action_id, -1))
	row.add_child(minus_button)

	var plus_button := _build_action_button(_get_plus_button_text(String(action_def.get("kind", KIND_NUMERIC))))
	plus_button.pressed.connect(_on_action_adjusted.bind(action_id, 1))
	row.add_child(plus_button)

func _build_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44.0, 34.0)
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
	return button

func _refresh_board_ui() -> void:
	for note_def in _note_definitions:
		var note_id := String(note_def.get("id", ""))
		var info_label := _note_info_labels.get(note_id, null) as Label
		if info_label != null:
			info_label.text = String(note_def.get("subtitle", "Debug controls"))

	for action_id in _action_definitions.keys():
		var action_def: Dictionary = _action_definitions[action_id]
		var value_label := _action_value_labels.get(action_id, null) as Label
		if value_label != null:
			value_label.text = _get_action_value_text(action_def)

func _get_action_value_text(action_def: Dictionary) -> String:
	var kind := String(action_def.get("kind", KIND_NUMERIC))
	var key := String(action_def.get("key", ""))
	var default_value: Variant = action_def.get("default")
	match kind:
		KIND_TOGGLE:
			return "ON" if bool(_run_state.get(key, default_value)) else "OFF"
		KIND_MODE:
			return PlayerAbilityConfig.get_target_mode_label(int(_run_state.get(key, default_value)))
		_:
			return _format_numeric_value(action_def, _run_state.get(key, default_value))

func _format_numeric_value(action_def: Dictionary, value: Variant) -> String:
	var display := String(action_def.get("display", "int"))
	match display:
		"float0":
			return "%.0f" % float(value)
		"float1":
			return "%.1f" % float(value)
		"float2":
			return "%.2f" % float(value)
		"percent_inverse":
			return "%d%%" % int(round((1.0 - float(value)) * 100.0))
		_:
			return str(int(value))

func _get_minus_button_text(kind: String) -> String:
	match kind:
		KIND_TOGGLE:
			return "OFF"
		KIND_MODE:
			return "<"
		_:
			return "-"

func _get_plus_button_text(kind: String) -> String:
	match kind:
		KIND_TOGGLE:
			return "ON"
		KIND_MODE:
			return ">"
		_:
			return "+"

func _on_action_adjusted(action_id: String, direction: int) -> void:
	var action_def: Dictionary = _action_definitions.get(action_id, {})
	if action_def.is_empty():
		return

	var kind := String(action_def.get("kind", KIND_NUMERIC))
	var key := String(action_def.get("key", ""))
	var default_value: Variant = action_def.get("default")
	match kind:
		KIND_TOGGLE:
			_run_state[key] = direction > 0
		KIND_MODE:
			var allowed_modes: Array[int] = action_def.get("modes", TOWER_TARGET_MODES)
			_run_state[key] = _cycle_mode_delta(int(_run_state.get(key, default_value)), allowed_modes, direction)
		_:
			var step: Variant = action_def.get("step", 1)
			if typeof(default_value) == TYPE_FLOAT:
				_run_state[key] = float(_run_state.get(key, default_value)) + float(step) * float(direction)
			else:
				_run_state[key] = int(_run_state.get(key, default_value)) + int(step) * direction

	_refresh_board_ui()

func _cycle_mode_delta(current_mode: int, allowed_modes: Array[int], direction: int) -> int:
	if allowed_modes.is_empty():
		return current_mode
	var current_index := allowed_modes.find(current_mode)
	if current_index == -1:
		return allowed_modes[0]
	var next_index := posmod(current_index + direction, allowed_modes.size())
	return allowed_modes[next_index]

func _build_note_definitions() -> Array[Dictionary]:
	return [
		{
			"id": "tick",
			"title": "Tick",
			"subtitle": "Core debug controls",
			"position": Vector2(380.0, 360.0),
			"width": 430.0,
			"rotation": -2.0,
			"color": Color(0.98, 0.92, 0.52, 1.0),
			"actions": ["tick_damage", "tick_speed"]
		},
		{
			"id": "projectile",
			"title": "Projectile",
			"subtitle": "Tower projectile debug controls",
			"position": Vector2(1380.0, 360.0),
			"width": 430.0,
			"rotation": 1.2,
			"color": Color(0.98, 0.84, 0.62, 1.0),
			"actions": ["projectile_unlock", "projectile_damage", "projectile_cooldown", "projectile_speed", "projectile_size", "projectile_piercing", "projectile_target"]
		},
		{
			"id": "boomerang",
			"title": "Boomerang",
			"subtitle": "Boomerang debug controls",
			"position": Vector2(2380.0, 360.0),
			"width": 430.0,
			"rotation": -1.0,
			"color": Color(0.96, 0.79, 0.71, 1.0),
			"actions": ["boomerang_unlock", "boomerang_damage", "boomerang_cooldown", "boomerang_speed", "boomerang_size", "boomerang_distance", "boomerang_target"]
		},
		{
			"id": "chain_arrow",
			"title": "Chain Arrow",
			"subtitle": "Chain arrow debug controls",
			"position": Vector2(3380.0, 360.0),
			"width": 430.0,
			"rotation": 1.5,
			"color": Color(0.93, 0.86, 0.64, 1.0),
			"actions": ["chain_arrow_unlock", "chain_arrow_damage", "chain_arrow_cooldown", "chain_arrow_speed", "chain_arrow_size", "chain_arrow_targets", "chain_arrow_search"]
		},
		{
			"id": "lightning",
			"title": "Lightning",
			"subtitle": "Lightning debug controls",
			"position": Vector2(380.0, 1100.0),
			"width": 430.0,
			"rotation": 1.5,
			"color": Color(0.98, 0.78, 0.38, 1.0),
			"actions": ["lightning_unlock", "lightning_damage", "lightning_count", "lightning_cooldown", "lightning_area"]
		},
		{
			"id": "snowball",
			"title": "Snowball",
			"subtitle": "Snowball debug controls",
			"position": Vector2(1380.0, 1100.0),
			"width": 430.0,
			"rotation": -1.0,
			"color": Color(0.71, 0.91, 1.0, 1.0),
			"actions": ["snowball_unlock", "snowball_damage", "snowball_cooldown", "snowball_slow", "snowball_radius", "snowball_duration", "snowball_target"]
		},
		{
			"id": "blades",
			"title": "Blades",
			"subtitle": "Blade orbit debug controls",
			"position": Vector2(2380.0, 1100.0),
			"width": 430.0,
			"rotation": 2.0,
			"color": Color(0.96, 0.77, 0.9, 1.0),
			"actions": ["blades_unlock", "blades_damage", "blades_count", "blades_size", "blades_orbit", "blades_speed"]
		},
		{
			"id": "ricochet",
			"title": "Ricochet",
			"subtitle": "Ricochet debug controls",
			"position": Vector2(3380.0, 1100.0),
			"width": 430.0,
			"rotation": -1.2,
			"color": Color(0.74, 0.94, 1.0, 1.0),
			"actions": ["ricochet_unlock", "ricochet_damage", "ricochet_cooldown", "ricochet_speed", "ricochet_bounces", "ricochet_size", "ricochet_target"]
		},
		{
			"id": "tower_aura",
			"title": "Tower Aura",
			"subtitle": "Tower aura debug controls",
			"position": Vector2(380.0, 1840.0),
			"width": 430.0,
			"rotation": -1.6,
			"color": Color(1.0, 0.78, 0.6, 1.0),
			"actions": ["tower_aura_unlock", "tower_aura_damage", "tower_aura_tick", "tower_aura_radius"]
		},
		{
			"id": "flamethrower",
			"title": "Flamethrower",
			"subtitle": "Flamethrower debug controls",
			"position": Vector2(1380.0, 1840.0),
			"width": 430.0,
			"rotation": 1.8,
			"color": Color(1.0, 0.66, 0.46, 1.0),
			"actions": ["flamethrower_unlock", "flamethrower_damage", "flamethrower_tick", "flamethrower_range", "flamethrower_width", "flamethrower_target"]
		},
		{
			"id": "laser",
			"title": "Laser",
			"subtitle": "Laser debug controls",
			"position": Vector2(2380.0, 1840.0),
			"width": 430.0,
			"rotation": -1.0,
			"color": Color(1.0, 0.6, 0.58, 1.0),
			"actions": ["laser_unlock", "laser_cooldown", "laser_width", "laser_target"]
		},
		{
			"id": "acid_rain",
			"title": "Acid Rain",
			"subtitle": "Acid rain debug controls",
			"position": Vector2(3380.0, 1840.0),
			"width": 430.0,
			"rotation": 1.0,
			"color": Color(0.74, 1.0, 0.68, 1.0),
			"actions": ["acid_rain_unlock", "acid_rain_damage", "acid_rain_cooldown", "acid_rain_drops", "acid_rain_radius", "acid_rain_duration", "acid_rain_tick"]
		},
		{
			"id": "map_clear",
			"title": "Map Clear",
			"subtitle": "Map clear debug controls",
			"position": Vector2(1885.0, 2650.0),
			"width": 520.0,
			"rotation": -1.2,
			"color": Color(1.0, 0.92, 0.74, 1.0),
			"actions": ["map_clear_unlock", "map_clear_cooldown"]
		}
	]

func _build_action_definitions() -> Dictionary:
	return {
		"tick_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "player_damage", "default": 1, "step": 1, "display": "int"},
		"tick_speed": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "player_attack_cooldown", "default": 0.5, "step": 0.05, "display": "float2"},
		"projectile_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "projectile_unlocked", "default": false},
		"projectile_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "projectile_damage", "default": 3, "step": 1, "display": "int"},
		"projectile_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "projectile_cooldown", "default": 1.0, "step": 0.08, "display": "float2"},
		"projectile_speed": {"label": "Speed", "kind": KIND_NUMERIC, "key": "projectile_speed", "default": 580.0, "step": 60.0, "display": "float0"},
		"projectile_size": {"label": "Size", "kind": KIND_NUMERIC, "key": "projectile_radius", "default": 9.0, "step": 2.0, "display": "float0"},
		"projectile_piercing": {"label": "Piercing", "kind": KIND_NUMERIC, "key": "projectile_piercing", "default": 1, "step": 1, "display": "int"},
		"projectile_target": {"label": "Target", "kind": KIND_MODE, "key": "projectile_target_mode", "default": PlayerAbilityConfig.TargetMode.MOUSE, "modes": TOWER_TARGET_MODES},
		"boomerang_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "boomerang_unlocked", "default": false},
		"boomerang_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "boomerang_damage", "default": 2, "step": 1, "display": "int"},
		"boomerang_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "boomerang_cooldown", "default": 1.8, "step": 0.10, "display": "float2"},
		"boomerang_speed": {"label": "Speed", "kind": KIND_NUMERIC, "key": "boomerang_speed", "default": 420.0, "step": 45.0, "display": "float0"},
		"boomerang_size": {"label": "Size", "kind": KIND_NUMERIC, "key": "boomerang_radius", "default": 12.0, "step": 2.0, "display": "float0"},
		"boomerang_distance": {"label": "Distance", "kind": KIND_NUMERIC, "key": "boomerang_distance", "default": 240.0, "step": 30.0, "display": "float0"},
		"boomerang_target": {"label": "Target", "kind": KIND_MODE, "key": "boomerang_target_mode", "default": PlayerAbilityConfig.TargetMode.MOUSE, "modes": TOWER_TARGET_MODES},
		"chain_arrow_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "chain_arrow_unlocked", "default": false},
		"chain_arrow_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "chain_arrow_damage", "default": 2, "step": 1, "display": "int"},
		"chain_arrow_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "chain_arrow_cooldown", "default": 2.0, "step": 0.12, "display": "float2"},
		"chain_arrow_speed": {"label": "Speed", "kind": KIND_NUMERIC, "key": "chain_arrow_speed", "default": 620.0, "step": 55.0, "display": "float0"},
		"chain_arrow_size": {"label": "Size", "kind": KIND_NUMERIC, "key": "chain_arrow_radius", "default": 10.0, "step": 2.0, "display": "float0"},
		"chain_arrow_targets": {"label": "Chains", "kind": KIND_NUMERIC, "key": "chain_arrow_targets", "default": 4, "step": 1, "display": "int"},
		"chain_arrow_search": {"label": "Search", "kind": KIND_NUMERIC, "key": "chain_arrow_search_radius", "default": 220.0, "step": 30.0, "display": "float0"},
		"lightning_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "lightning_unlocked", "default": false},
		"lightning_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "lightning_damage", "default": 2, "step": 1, "display": "int"},
		"lightning_count": {"label": "Rays", "kind": KIND_NUMERIC, "key": "lightning_count", "default": 3, "step": 1, "display": "int"},
		"lightning_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "lightning_cooldown", "default": 2.4, "step": 0.2, "display": "float2"},
		"lightning_area": {"label": "Area", "kind": KIND_NUMERIC, "key": "lightning_area_radius", "default": 96.0, "step": 18.0, "display": "float0"},
		"snowball_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "snowball_unlocked", "default": false},
		"snowball_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "snowball_damage", "default": 2, "step": 1, "display": "int"},
		"snowball_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "snowball_cooldown", "default": 3.1, "step": 0.25, "display": "float2"},
		"snowball_slow": {"label": "Slow", "kind": KIND_NUMERIC, "key": "snowball_slow_factor", "default": 0.70, "step": 0.06, "display": "percent_inverse"},
		"snowball_radius": {"label": "Field Radius", "kind": KIND_NUMERIC, "key": "snowball_field_radius", "default": 66.0, "step": 10.0, "display": "float0"},
		"snowball_duration": {"label": "Duration", "kind": KIND_NUMERIC, "key": "snowball_field_duration", "default": 1.8, "step": 0.25, "display": "float2"},
		"snowball_target": {"label": "Target", "kind": KIND_MODE, "key": "snowball_target_mode", "default": PlayerAbilityConfig.TargetMode.MOUSE, "modes": TOWER_TARGET_MODES},
		"blades_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "blades_unlocked", "default": false},
		"blades_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "blade_damage", "default": 1, "step": 1, "display": "int"},
		"blades_count": {"label": "Count", "kind": KIND_NUMERIC, "key": "blade_count", "default": 3, "step": 1, "display": "int"},
		"blades_size": {"label": "Size", "kind": KIND_NUMERIC, "key": "blade_size", "default": 18.0, "step": 4.0, "display": "float0"},
		"blades_orbit": {"label": "Orbit", "kind": KIND_NUMERIC, "key": "blade_orbit_radius", "default": 72.0, "step": 10.0, "display": "float0"},
		"blades_speed": {"label": "Spin", "kind": KIND_NUMERIC, "key": "blade_rotation_speed", "default": 2.6, "step": 0.28, "display": "float2"},
		"ricochet_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "ricochet_unlocked", "default": false},
		"ricochet_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "ricochet_damage", "default": 1, "step": 1, "display": "int"},
		"ricochet_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "ricochet_cooldown", "default": 1.7, "step": 0.10, "display": "float2"},
		"ricochet_speed": {"label": "Speed", "kind": KIND_NUMERIC, "key": "ricochet_speed", "default": 500.0, "step": 50.0, "display": "float0"},
		"ricochet_bounces": {"label": "Bounces", "kind": KIND_NUMERIC, "key": "ricochet_bounces", "default": 4, "step": 1, "display": "int"},
		"ricochet_size": {"label": "Size", "kind": KIND_NUMERIC, "key": "ricochet_radius", "default": 9.0, "step": 2.0, "display": "float0"},
		"ricochet_target": {"label": "Target", "kind": KIND_MODE, "key": "ricochet_target_mode", "default": PlayerAbilityConfig.TargetMode.MOUSE, "modes": RANDOM_TARGET_MODES},
		"tower_aura_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "tower_aura_unlocked", "default": false},
		"tower_aura_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "tower_aura_damage", "default": 1, "step": 1, "display": "int"},
		"tower_aura_tick": {"label": "Tick", "kind": KIND_NUMERIC, "key": "tower_aura_tick_interval", "default": 0.45, "step": 0.03, "display": "float2"},
		"tower_aura_radius": {"label": "Radius", "kind": KIND_NUMERIC, "key": "tower_aura_radius", "default": 120.0, "step": 12.0, "display": "float0"},
		"flamethrower_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "flamethrower_unlocked", "default": false},
		"flamethrower_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "flamethrower_damage", "default": 1, "step": 1, "display": "int"},
		"flamethrower_tick": {"label": "Tick", "kind": KIND_NUMERIC, "key": "flamethrower_tick_interval", "default": 0.18, "step": 0.02, "display": "float2"},
		"flamethrower_range": {"label": "Range", "kind": KIND_NUMERIC, "key": "flamethrower_range", "default": 230.0, "step": 18.0, "display": "float0"},
		"flamethrower_width": {"label": "Width", "kind": KIND_NUMERIC, "key": "flamethrower_width", "default": 42.0, "step": 6.0, "display": "float0"},
		"flamethrower_target": {"label": "Target", "kind": KIND_MODE, "key": "flamethrower_target_mode", "default": PlayerAbilityConfig.TargetMode.MOUSE, "modes": TOWER_TARGET_MODES},
		"laser_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "laser_unlocked", "default": false},
		"laser_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "laser_cooldown", "default": 6.0, "step": 0.25, "display": "float2"},
		"laser_width": {"label": "Width", "kind": KIND_NUMERIC, "key": "laser_width", "default": 34.0, "step": 6.0, "display": "float0"},
		"laser_target": {"label": "Target", "kind": KIND_MODE, "key": "laser_target_mode", "default": PlayerAbilityConfig.TargetMode.NEAREST_ENEMY, "modes": TOWER_TARGET_MODES},
		"acid_rain_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "acid_rain_unlocked", "default": false},
		"acid_rain_damage": {"label": "Damage", "kind": KIND_NUMERIC, "key": "acid_rain_damage", "default": 1, "step": 1, "display": "int"},
		"acid_rain_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "acid_rain_cooldown", "default": 4.0, "step": 0.25, "display": "float2"},
		"acid_rain_drops": {"label": "Drops", "kind": KIND_NUMERIC, "key": "acid_rain_drop_count", "default": 3, "step": 1, "display": "int"},
		"acid_rain_radius": {"label": "Radius", "kind": KIND_NUMERIC, "key": "acid_rain_puddle_radius", "default": 56.0, "step": 8.0, "display": "float0"},
		"acid_rain_duration": {"label": "Duration", "kind": KIND_NUMERIC, "key": "acid_rain_puddle_duration", "default": 2.2, "step": 0.25, "display": "float2"},
		"acid_rain_tick": {"label": "Tick", "kind": KIND_NUMERIC, "key": "acid_rain_tick_interval", "default": 0.30, "step": 0.03, "display": "float2"},
		"map_clear_unlock": {"label": "Enabled", "kind": KIND_TOGGLE, "key": "map_clear_unlocked", "default": false},
		"map_clear_cooldown": {"label": "Cooldown", "kind": KIND_NUMERIC, "key": "map_clear_cooldown", "default": 16.0, "step": 0.75, "display": "float2"}
	}

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
	board_root.position = board_viewport.size * 0.5 - Vector2(2380.0, 1500.0)

func _on_continue_button_pressed() -> void:
	_run_state["gold"] = CurrencySystem.get_amount("gold")
	TransitionManager.change_scene("GameTest", "fade_black", {
		"data": _run_state
	})

func _on_end_run_button_pressed() -> void:
	TransitionManager.change_scene("Menu", "fade_black")
