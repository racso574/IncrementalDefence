extends Control
class_name TransitionEffectBase

signal cover_finished
signal reveal_finished

var params: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func configure(config: Dictionary = {}) -> void:
	params = config.duplicate(true)
	_on_configured()

func play_cover() -> void:
	visible = true
	_play_cover()

func play_reveal() -> void:
	visible = true
	_play_reveal()

func cleanup() -> void:
	queue_free()

func finish_cover() -> void:
	cover_finished.emit()

func finish_reveal() -> void:
	visible = false
	reveal_finished.emit()

func get_duration(key: String = "duration", fallback: float = 0.25) -> float:
	return float(params.get(key, params.get("duration", fallback)))

func get_tween_trans() -> Tween.TransitionType:
	return int(params.get("trans", Tween.TRANS_SINE))

func get_tween_ease() -> Tween.EaseType:
	return int(params.get("ease", Tween.EASE_IN_OUT))

func _on_configured() -> void:
	pass

func _play_cover() -> void:
	finish_cover()

func _play_reveal() -> void:
	finish_reveal()
