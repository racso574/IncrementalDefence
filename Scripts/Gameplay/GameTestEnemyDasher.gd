extends GameTestEnemy
class_name GameTestEnemyDasher

@export var ally_dash_search_radius: float = 170.0
@export var ally_dash_speed: float = 520.0
@export var ally_dash_damage: int = 1
@export var ally_dash_cooldown: float = 0.15
@export var tower_charge_radius: float = 188.0
@export var tower_charge_time: float = 2.0
@export var tower_dash_speed: float = 640.0
@export var tower_damage_per_dash: int = 5

var _is_dashing_to_enemy: bool = false
var _is_charging_tower: bool = false
var _is_dashing_to_tower: bool = false
var _tower_charge_remaining: float = 0.0
var _dash_target_enemy: GameTestEnemy
var _dashed_enemy_ids: Dictionary = {}
var _completed_dash_count: int = 0
var _dash_cooldown_remaining: float = 0.0
var _cling_target_enemy: GameTestEnemy

func _process(delta: float) -> void:
	if _state == State.DEAD:
		return

	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
			modulate = Color.WHITE

	if _dash_cooldown_remaining > 0.0:
		_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)

	_tower_center = _resolve_tower_center()

	if _is_dashing_to_tower:
		_update_tower_dash(delta)
		return

	if _is_charging_tower:
		_update_tower_charge(delta)
		return

	if _is_dashing_to_enemy:
		_update_enemy_dash(delta)
		return

	var current_center := _get_center_position()
	if _cling_target_enemy != null and is_instance_valid(_cling_target_enemy) and _cling_target_enemy._state != State.DEAD:
		_set_center_position(_cling_target_enemy._get_center_position())
		current_center = _get_center_position()
	elif _cling_target_enemy != null:
		_cling_target_enemy = null

	var tower_distance := current_center.distance_to(_tower_center)
	if tower_distance <= tower_charge_radius:
		_cling_target_enemy = null
		_begin_tower_charge()
		return

	if _dash_cooldown_remaining <= 0.0:
		_cling_target_enemy = null
		var dash_target := _find_dash_target(current_center, tower_distance)
		if dash_target != null:
			_begin_enemy_dash(dash_target)
			return

	var next_center := current_center.move_toward(_target_center, move_speed * _slow_multiplier * delta)
	_set_center_position(next_center)
	if next_center.distance_to(_target_center) <= arrival_threshold:
		_begin_tower_charge()

func _find_dash_target(current_center: Vector2, tower_distance: float) -> GameTestEnemy:
	var parent_node := get_parent()
	if parent_node == null:
		return null

	var nearest_enemy: GameTestEnemy
	var nearest_distance: float = INF

	for child in parent_node.get_children():
		var enemy := child as GameTestEnemy
		if enemy == null or enemy == self:
			continue
		if enemy._state == State.DEAD:
			continue
		var enemy_id := enemy.get_instance_id()
		if _dashed_enemy_ids.has(enemy_id):
			continue

		var enemy_center := enemy._get_center_position()
		var enemy_distance := current_center.distance_to(enemy_center)
		if enemy_distance > ally_dash_search_radius:
			continue
		var enemy_tower_distance := enemy_center.distance_to(_tower_center)
		if enemy_tower_distance >= tower_distance - 4.0:
			continue
		if enemy_distance < nearest_distance:
			nearest_distance = enemy_distance
			nearest_enemy = enemy

	return nearest_enemy

func _begin_enemy_dash(target_enemy: GameTestEnemy) -> void:
	_dash_target_enemy = target_enemy
	_is_dashing_to_enemy = true
	_state = State.ATTACKING
	_apply_state_visual()

func _update_enemy_dash(delta: float) -> void:
	if _dash_target_enemy == null or not is_instance_valid(_dash_target_enemy) or _dash_target_enemy._state == State.DEAD:
		_end_enemy_dash()
		return

	var current_center := _get_center_position()
	var target_center := _dash_target_enemy._get_center_position()
	var next_center := current_center.move_toward(target_center, ally_dash_speed * _slow_multiplier * delta)
	_set_center_position(next_center)

	if next_center.distance_to(target_center) <= maxf(arrival_threshold, 12.0):
		var enemy_id := _dash_target_enemy.get_instance_id()
		_dashed_enemy_ids[enemy_id] = true
		_completed_dash_count += 1
		_cling_target_enemy = _dash_target_enemy
		if _dash_target_enemy.health_controller != null and _dash_target_enemy.health_controller.is_alive():
			_dash_target_enemy.health_controller.apply_damage(ally_dash_damage)
			_spawn_dash_hit_feedback(_dash_target_enemy._get_center_position())
		_end_enemy_dash()

func _end_enemy_dash() -> void:
	_is_dashing_to_enemy = false
	_dash_target_enemy = null
	_dash_cooldown_remaining = ally_dash_cooldown
	_state = State.MOVING
	_apply_state_visual()

func _begin_tower_charge() -> void:
	if _is_charging_tower or _is_dashing_to_tower or _state == State.DEAD:
		return
	_is_charging_tower = true
	_tower_charge_remaining = tower_charge_time
	_state = State.ATTACKING
	_apply_state_visual()
	_spawn_charge_feedback()

func _update_tower_charge(delta: float) -> void:
	_tower_charge_remaining = maxf(_tower_charge_remaining - delta, 0.0)
	if _tower_charge_remaining <= 0.0:
		_is_charging_tower = false
		_is_dashing_to_tower = true

func _update_tower_dash(delta: float) -> void:
	var current_center := _get_center_position()
	var next_center := current_center.move_toward(_tower_center, tower_dash_speed * _slow_multiplier * delta)
	_set_center_position(next_center)
	if next_center.distance_to(_tower_center) <= maxf(arrival_threshold, 10.0):
		_target_center = _tower_center
		attack_damage += _completed_dash_count * tower_damage_per_dash
		_explode()

func _spawn_charge_feedback() -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var pulse := Panel.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.size = Vector2(32.0, 32.0)
	pulse.pivot_offset = pulse.size * 0.5
	pulse.global_position = _get_center_position() - pulse.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.56, 0.28, 0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.86, 0.56, 0.92)
	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_right = 48
	style.corner_radius_bottom_left = 48
	pulse.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(pulse)

	var tween := pulse.create_tween()
	tween.parallel().tween_property(pulse, "scale", Vector2(1.7, 1.7), 0.28)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.28)
	tween.tween_callback(Callable(pulse, "queue_free"))

func _spawn_dash_hit_feedback(center: Vector2) -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var spark := Panel.new()
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.size = Vector2(18.0, 18.0)
	spark.pivot_offset = spark.size * 0.5
	spark.global_position = center - spark.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.82, 0.58, 0.84)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	spark.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(spark)

	var tween := spark.create_tween()
	tween.parallel().tween_property(spark, "scale", Vector2(1.4, 1.4), 0.16)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(spark, "queue_free"))
