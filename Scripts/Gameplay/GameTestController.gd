extends Control

@export var starting_gold: int = 250

func _ready() -> void:
	CurrencySystem.set_amount("gold", starting_gold)
