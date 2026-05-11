extends CanvasLayer
class_name TransitionManager

const EFFECTS: Dictionary = {
	"fade_black": {
		"scene": "res://Scenes/Transitions/Effects/FadeEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.22,
			"trans": Tween.TRANS_SINE,
			"ease": Tween.EASE_IN_OUT
		}
	},
	"panel_drop_top": {
		"scene": "res://Scenes/Transitions/Effects/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "top",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": -6.0
		}
	},
	"panel_drop_left": {
		"scene": "res://Scenes/Transitions/Effects/PanelSlideEffect.tscn",
		"params": {
			"color": Color(0, 0, 0, 1),
			"duration": 0.34,
			"trans": Tween.TRANS_QUART,
			"ease": Tween.EASE_IN_OUT,
			"enter_from": "left",
			"exit_mode": "reverse",
			"panel_scale": 1.28,
			"panel_margin": 96.0,
			"tilt_degrees": 6.0
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

func play(effect_id: String, overrides: Dictionary = {}) -> void:
	await run_transition(effect_id, Callable(), overrides)

func change_scene(scene_key: String, effect_id: String = "fade_black", data: Variant = null, overrides: Dictionary = {}) -> void:
	var action := Callable(self, "_change_scene_action").bind(scene_key, data)
	await run_transition(effect_id, action, overrides)

func run_transition(effect_id: String, action: Callable = Callable(), overrides: Dictionary = {}) -> void:
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
	_active_effect.configure(_merge_params(definition.get("params", {}), overrides))

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

func _set_input_blocking(is_blocking: bool) -> void:
	if _host == null:
		return
	_host.mouse_filter = Control.MOUSE_FILTER_STOP if is_blocking else Control.MOUSE_FILTER_IGNORE

func _clear_active_effect() -> void:
	if _active_effect == null:
		return
	_active_effect.cleanup()
	_active_effect = null
