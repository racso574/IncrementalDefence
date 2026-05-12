extends TransitionEffectBase

@onready var overlay: ColorRect = $Overlay

func _on_configured() -> void:
	overlay.color = params.get("color", Color(0, 0, 0, 1))
	overlay.modulate = Color(1, 1, 1, 0)
	visible = false

func _play_cover() -> void:
	overlay.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 1), get_duration("cover_duration", 0.22))
	tween.finished.connect(finish_cover)

func _play_reveal() -> void:
	overlay.modulate = Color(1, 1, 1, 1)

	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 0), get_duration("reveal_duration", 0.22))
	tween.finished.connect(finish_reveal)
