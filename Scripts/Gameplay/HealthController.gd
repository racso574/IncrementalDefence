extends Node
class_name HealthController

signal health_changed(current_health: int, max_health: int, delta: int)
signal damaged(amount: int, current_health: int, max_health: int)
signal healed(amount: int, current_health: int, max_health: int)
signal died()

@export var max_health: int = 100

var current_health: int = 0
var is_dead: bool = false

func _enter_tree() -> void:
	max_health = maxi(max_health, 1)
	current_health = max_health
	is_dead = false

func _ready() -> void:
	health_changed.emit(current_health, max_health, 0)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return not is_dead

func set_health(value: int) -> void:
	var previous_health := current_health
	current_health = clampi(value, 0, max_health)
	is_dead = current_health <= 0

	var delta := current_health - previous_health
	if delta == 0:
		return

	health_changed.emit(current_health, max_health, delta)

	if delta < 0:
		damaged.emit(-delta, current_health, max_health)
	elif delta > 0:
		healed.emit(delta, current_health, max_health)

	if current_health == 0 and previous_health > 0:
		died.emit()

func apply_damage(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	set_health(current_health - amount)

func heal(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	set_health(current_health + amount)

func reset_health() -> void:
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health, 0)

func kill() -> void:
	if is_dead:
		return
	set_health(0)
