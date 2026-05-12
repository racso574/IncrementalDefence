extends Control

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var options_button: Button = $Center/VBox/OptionsButton
@onready var exit_button: Button = $Center/VBox/ExitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_play_pressed() -> void:
	TransitionManager.change_scene("GameTest", "fade_black")

func _on_options_pressed() -> void:
	TransitionManager.change_scene("Options", "fade_black")

func _on_exit_pressed() -> void:
	get_tree().quit()
