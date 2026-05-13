extends CanvasLayer

const EFFECTS: Dictionary = {
	"fade_black": {
		"scene": "res://Scenes/Transitions/FadeEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.25,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT
		}
	},
	"panel_drop_top": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "top",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": 0.0
		}
	},
	"panel_drop_bottom": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "bottom",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": 0.0
		}
	},
	"panel_drop_left": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "left",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": 0.0
		}
	},
	"panel_drop_right": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "right",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": 0.0
		}
	},
	"panel_drop_top_diagonal_ccw": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "top",
			"exit_mode": "reverse",
			"panel_scale": 1.55,
			"panel_margin": 160.0,
			"tilt_degrees": -10.0
		}
	},
	"panel_drop_left_diagonal_cw": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "left",
			"exit_mode": "reverse",
			"panel_scale": 1.55,
			"panel_margin": 160.0,
			"tilt_degrees": 10.0
		}
	},
	"panel_drop_bottom_diagonal_cw": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "bottom",
			"exit_mode": "reverse",
			"panel_scale": 1.55,
			"panel_margin": 160.0,
			"tilt_degrees": 10.0
		}
	},
	"panel_drop_right_diagonal_ccw": {
		"scene": "res://Scenes/Transitions/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "right",
			"exit_mode": "reverse",
			"panel_scale": 1.55,
			"panel_margin": 160.0,
			"tilt_degrees": -10.0
		}
	},
	"curtain_vertical": {
		"scene": "res://Scenes/Transitions/CurtainPanelsEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"mode": "vertical",
			"panel_scale": 1.18,
			"panel_margin": 96.0,
			"panel_overlap": 2.0,
			"tilt_degrees": 0.0
		}
	},
	"curtain_horizontal": {
		"scene": "res://Scenes/Transitions/CurtainPanelsEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.36,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"mode": "horizontal",
			"panel_scale": 1.18,
			"panel_margin": 96.0,
			"panel_overlap": 2.0,
			"tilt_degrees": 0.0
		}
	},
	"iris_circle": {
		"scene": "res://Scenes/Transitions/IrisCircleEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT,
			"center_uv": Vector2(0.5, 0.5),
			"feather_px": 2.0
		}
	},
	"iris_inverse": {
		"scene": "res://Scenes/Transitions/IrisCircleEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT,
			"center_uv": Vector2(0.5, 0.5),
			"feather_px": 2.0,
			"cover_hold_duration": 0.1,
			"invert": true
		}
	},
	"diamond_iris": {
		"scene": "res://Scenes/Transitions/DiamondIrisEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT,
			"center_uv": Vector2(0.5, 0.5),
			"feather_px": 2.0
		}
	},
	"diamond_inverse": {
		"scene": "res://Scenes/Transitions/DiamondIrisEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT,
			"center_uv": Vector2(0.5, 0.5),
			"feather_px": 2.0,
			"cover_hold_duration": 0.1,
			"invert": true
		}
	},
	"falling_strips": {
		"scene": "res://Scenes/Transitions/FallingStripsEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"cover_duration": 0.72,
			"reveal_duration": 0.34,
			"column_count": 8,
			"stagger": 0.075,
			"overscan_y": 96.0,
			"rest_top_extra": 24.0,
			"cover_start_gap": 22.0,
			"reveal_end_gap": 22.0,
			"bounce_px": 52.0,
			"bounce_variation": 0.22
		}
	}
}

signal transition_started(effect_id: String)
signal transition_midpoint(effect_id: String)
signal transition_finished(effect_id: String)

var _host: Control
var _active_effect: TransitionEffectBase
var _is_running: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_host = Control.new()
	_host.name = "TransitionHost"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

func is_running() -> bool:
	return _is_running

func has_effect(effect_id: String) -> bool:
	return EFFECTS.has(effect_id)

func list_effects() -> Array[String]:
	var keys: Array[String] = []
	for key: String in EFFECTS.keys():
		keys.append(key)
	keys.sort()
	return keys

func play(effect_id: String, action: Callable = Callable(), transition_params: Dictionary = {}) -> void:
	await _run_transition(effect_id, action, transition_params)

func change_scene(scene_key: String, effect_id: String = "fade_black", options: Dictionary = {}) -> void:
	var scene_data: Variant = options.get("data", null)
	var transition_params: Dictionary = _extract_transition_params(options)
	var action := Callable(self, "_change_scene_action").bind(scene_key, scene_data)
	await _run_transition(effect_id, action, transition_params)

func _run_transition(effect_id: String, action: Callable = Callable(), transition_params: Dictionary = {}) -> void:
	if _is_running:
		push_warning("TransitionManager: ya hay una transición en curso.")
		return

	var definition: Dictionary = EFFECTS.get(effect_id, {})
	if definition.is_empty():
		push_error("TransitionManager: efecto no registrado '%s'." % effect_id)
		return

	var scene_path: String = String(definition.get("scene", ""))
	var effect := _instantiate_effect(scene_path)
	if effect == null:
		return

	_is_running = true
	_set_input_blocking(true)

	_active_effect = effect
	_host.add_child(_active_effect)
	_active_effect.configure(_merge_params(definition.get("params", {}), transition_params))

	transition_started.emit(effect_id)

	_active_effect.play_cover()
	await _active_effect.cover_finished
	transition_midpoint.emit(effect_id)

	if action.is_valid():
		action.call()
		await get_tree().process_frame

	_active_effect.play_reveal()
	await _active_effect.reveal_finished

	_clear_active_effect()
	_set_input_blocking(false)
	_is_running = false
	transition_finished.emit(effect_id)

func _change_scene_action(scene_key: String, data: Variant) -> void:
	ScenesManager.change_to(scene_key, data)

func _instantiate_effect(scene_path: String) -> TransitionEffectBase:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("TransitionManager: no pude cargar el efecto '%s'." % scene_path)
		return null

	var node: Node = packed.instantiate()
	if node is TransitionEffectBase:
		return node as TransitionEffectBase

	push_error("TransitionManager: la escena '%s' no usa TransitionEffectBase." % scene_path)
	node.queue_free()
	return null

func _merge_params(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key in overrides.keys():
		merged[key] = overrides[key]
	return merged

func _extract_transition_params(options: Dictionary) -> Dictionary:
	var transition_params: Variant = options.get("transition", {})
	if transition_params is Dictionary:
		return transition_params as Dictionary
	return {}

func _set_input_blocking(is_blocking: bool) -> void:
	if _host == null:
		return
	_host.mouse_filter = Control.MOUSE_FILTER_STOP if is_blocking else Control.MOUSE_FILTER_IGNORE

func _clear_active_effect() -> void:
	if _active_effect == null:
		return
	_active_effect.cleanup()
	_active_effect = null
