extends Control
class_name GameTestEnemy

signal defeated(gold_reward: int)
signal child_enemy_spawned(enemy: GameTestEnemy)

enum State { MOVING, ATTACKING, DEAD }
enum AttackMode { CONTACT, RANGED, HEAL_AURA, SUMMON }
enum MovementPattern { STRAIGHT, SINE }
enum ArrivalBehavior { ATTACK_LOOP, EXPLODE }

@export var move_speed: float = 155.0
@export var attack_interval: float = 1.0
@export var attack_damage: int = 1
@export var arrival_threshold: float = 8.0
@export var gold_reward: int = 1
@export var attack_mode: AttackMode = AttackMode.CONTACT
@export var movement_pattern: MovementPattern = MovementPattern.STRAIGHT
@export var arrival_behavior: ArrivalBehavior = ArrivalBehavior.ATTACK_LOOP
@export var preferred_ring_radius: float = -1.0
@export var projectile_travel_duration: float = 0.22
@export var projectile_size: float = 12.0
@export var projectile_color: Color = Color(1.0, 0.85, 0.45, 1.0)
@export var explosion_radius: float = 58.0
@export var heal_amount: int = 1
@export var heal_radius: float = 92.0
@export var sine_amplitude: float = 24.0
@export var sine_cycles: float = 1.0
@export var split_spawns: Array[EnemySplitSpawn] = []
@export var summon_spawns: Array[EnemySummonSpawn] = []
@export var move_body_color: Color = Color(0.47, 0.71, 1.0, 1.0)
@export var move_accent_color: Color = Color(0.86, 0.95, 1.0, 1.0)
@export var attack_body_color: Color = Color(1.0, 0.46, 0.39, 1.0)
@export var attack_accent_color: Color = Color(1.0, 0.88, 0.69, 1.0)

@onready var health_controller: HealthController = $HealthController
@onready var body: Panel = $Body
@onready var accent: Panel = $Body/Accent

var _tower_health: HealthController
var _tower_center: Vector2 = Vector2.ZERO
var _target_center: Vector2 = Vector2.ZERO
var _state: State = State.MOVING
var _attack_timer: float = 0.0
var _effect_host: Control
var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0
var _spawn_center: Vector2 = Vector2.ZERO
var _path_total_distance: float = 0.0
var _path_progress: float = 0.0
var _sine_sign: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_controller.died.connect(_on_died)
	_apply_state_visual()

func setup(tower_health: HealthController, spawn_center: Vector2, target_center: Vector2, effect_host: Control = null) -> void:
	_tower_health = tower_health
	_tower_center = _resolve_tower_center()
	_spawn_center = spawn_center
	_target_center = target_center
	_effect_host = effect_host
	_path_total_distance = maxf(spawn_center.distance_to(target_center), 0.001)
	_path_progress = 0.0
	_sine_sign = -1.0 if randf() < 0.5 else 1.0
	_set_center_position(spawn_center)
	_state = State.MOVING
	_attack_timer = 0.0
	_apply_state_visual()

func _process(delta: float) -> void:
	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
			modulate = Color.WHITE

	match _state:
		State.MOVING:
			var travel_delta: float = move_speed * _slow_multiplier * delta
			_path_progress = minf(_path_progress + travel_delta / _path_total_distance, 1.0)
			var next_center := _get_path_position(_path_progress)
			_set_center_position(next_center)
			if attack_mode == AttackMode.HEAL_AURA:
				_attack_timer += delta
				if _attack_timer >= attack_interval:
					_attack_timer -= attack_interval
					_emit_heal_aura()

			if _path_progress >= 1.0 or next_center.distance_to(_target_center) <= arrival_threshold:
				_finish_arrival()

		State.ATTACKING:
			if _tower_health == null or not _tower_health.is_alive():
				return

			_attack_timer += delta
			if _attack_timer >= attack_interval:
				_attack_timer -= attack_interval
				_perform_attack()

func is_point_inside_enemy(screen_point: Vector2) -> bool:
	return get_global_rect().has_point(screen_point)

func receive_player_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	health_controller.apply_damage(amount)

func _on_died() -> void:
	if _state == State.DEAD:
		return

	_state = State.DEAD
	_spawn_split_children()
	defeated.emit(gold_reward)
	queue_free()

func get_preferred_ring_radius(default_radius: float) -> float:
	if preferred_ring_radius > 0.0:
		return preferred_ring_radius
	return default_radius

func apply_slow(speed_multiplier: float, duration: float) -> void:
	if _state == State.DEAD:
		return
	var clamped_multiplier := clampf(speed_multiplier, 0.1, 1.0)
	if clamped_multiplier < _slow_multiplier or _slow_timer <= 0.0:
		_slow_multiplier = clamped_multiplier
	_slow_timer = maxf(_slow_timer, duration)
	modulate = Color(0.76, 0.9, 1.0, 1.0)

func _perform_attack() -> void:
	if attack_mode == AttackMode.RANGED:
		_launch_projectile()
		return
	if attack_mode == AttackMode.HEAL_AURA:
		_emit_heal_aura()
		return
	if attack_mode == AttackMode.SUMMON:
		_emit_summon()
		return
	_tower_health.apply_damage(attack_damage)

func _finish_arrival() -> void:
	_set_center_position(_target_center)
	if arrival_behavior == ArrivalBehavior.EXPLODE:
		_explode()
		return
	_state = State.ATTACKING
	_attack_timer = 0.0
	_apply_state_visual()

func _launch_projectile() -> void:
	if _tower_health == null:
		return

	var projectile_host: Control = _effect_host if _effect_host != null else get_parent() as Control
	if projectile_host == null:
		_tower_health.apply_damage(attack_damage)
		return

	var projectile := Panel.new()
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(projectile_size, projectile_size)
	projectile.pivot_offset = projectile.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = projectile_color
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_right = 32
	style.corner_radius_bottom_left = 32
	projectile.add_theme_stylebox_override("panel", style)

	projectile_host.add_child(projectile)
	projectile.global_position = _get_center_position() - projectile.size * 0.5

	var tower_body := _tower_health.get_parent() as Control
	var target_center := _get_center_position()
	if tower_body != null:
		target_center = tower_body.get_global_rect().position + tower_body.size * 0.5
	var tower_health_ref := _tower_health
	var damage_amount := attack_damage
	var tween := projectile.create_tween()
	tween.tween_property(projectile, "global_position", target_center - projectile.size * 0.5, projectile_travel_duration)
	tween.finished.connect(func() -> void:
		if tower_health_ref != null and tower_health_ref.is_alive():
			tower_health_ref.apply_damage(damage_amount)
		if is_instance_valid(projectile):
			projectile.queue_free()
	)

func _apply_state_visual() -> void:
	match _state:
		State.MOVING:
			body.self_modulate = move_body_color
			accent.self_modulate = move_accent_color
		State.ATTACKING:
			body.self_modulate = attack_body_color
			accent.self_modulate = attack_accent_color
		State.DEAD:
			body.self_modulate = Color(0.4, 0.4, 0.4, 1.0)
			accent.self_modulate = Color(0.7, 0.7, 0.7, 1.0)

func _get_center_position() -> Vector2:
	return global_position + size * 0.5

func _set_center_position(center_position: Vector2) -> void:
	global_position = center_position - size * 0.5

func _get_path_position(progress_ratio: float) -> Vector2:
	var clamped_progress: float = clampf(progress_ratio, 0.0, 1.0)
	var base_center := _spawn_center.lerp(_target_center, clamped_progress)
	if movement_pattern != MovementPattern.SINE:
		return base_center

	var path_direction := (_target_center - _spawn_center).normalized()
	if path_direction == Vector2.ZERO:
		return base_center
	var perpendicular := Vector2(-path_direction.y, path_direction.x)
	var offset_strength: float = sin(clamped_progress * TAU * sine_cycles) * sine_amplitude * _sine_sign
	return base_center + perpendicular * offset_strength

func _explode() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_spawn_explosion_feedback()
	if _tower_health != null and _tower_health.is_alive():
		_tower_health.apply_damage(attack_damage)
	defeated.emit(gold_reward)
	queue_free()

func _spawn_explosion_feedback() -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var burst := Panel.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2(explosion_radius * 2.0, explosion_radius * 2.0)
	burst.pivot_offset = burst.size * 0.5
	burst.global_position = _target_center - burst.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.58, 0.22, 0.24)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.84, 0.44, 0.95)
	style.corner_radius_top_left = 96
	style.corner_radius_top_right = 96
	style.corner_radius_bottom_right = 96
	style.corner_radius_bottom_left = 96
	burst.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(burst)

	var tween := burst.create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.58, 1.58), 0.14)
	tween.tween_interval(0.10)
	tween.parallel().tween_property(burst, "scale", Vector2(1.82, 1.82), 0.24)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(burst, "queue_free"))

func _emit_heal_aura() -> void:
	var allies := _get_healable_allies()
	for ally in allies:
		if ally == self:
			continue
		ally.health_controller.heal(heal_amount)
		_spawn_heal_target_feedback(ally._get_center_position())
	_spawn_heal_pulse()

func _get_healable_allies() -> Array[GameTestEnemy]:
	var allies: Array[GameTestEnemy] = []
	var parent_node := get_parent()
	if parent_node == null:
		return allies

	var center := _get_center_position()
	for child in parent_node.get_children():
		var ally := child as GameTestEnemy
		if ally == null or ally == self:
			continue
		if ally._state == State.DEAD:
			continue
		if ally.health_controller == null or not ally.health_controller.is_alive():
			continue
		if center.distance_to(ally._get_center_position()) <= heal_radius:
			allies.append(ally)

	return allies

func _spawn_heal_pulse() -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var pulse := Panel.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.size = Vector2(heal_radius * 2.0, heal_radius * 2.0)
	pulse.pivot_offset = pulse.size * 0.5
	pulse.global_position = _get_center_position() - pulse.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.93, 0.58, 0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.64, 1.0, 0.74, 0.88)
	style.corner_radius_top_left = 128
	style.corner_radius_top_right = 128
	style.corner_radius_bottom_right = 128
	style.corner_radius_bottom_left = 128
	pulse.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(pulse)

	var tween := pulse.create_tween()
	tween.parallel().tween_property(pulse, "scale", Vector2(1.12, 1.12), 0.20)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.20)
	tween.tween_callback(Callable(pulse, "queue_free"))

func _spawn_heal_target_feedback(target_center: Vector2) -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var spark := Panel.new()
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.size = Vector2(16.0, 16.0)
	spark.pivot_offset = spark.size * 0.5
	spark.global_position = target_center - spark.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 1.0, 0.82, 0.86)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	spark.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(spark)

	var tween := spark.create_tween()
	tween.parallel().tween_property(spark, "scale", Vector2(1.45, 1.45), 0.18)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(spark, "queue_free"))

func _emit_summon() -> void:
	if summon_spawns.is_empty():
		return

	var current_center := _get_center_position()
	var base_direction := (current_center - _tower_center).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = (_target_center - _tower_center).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.UP
	var base_angle: float = base_direction.angle()

	for summon_spawn in summon_spawns:
		if summon_spawn == null or summon_spawn.enemy_scene == null or summon_spawn.count <= 0:
			continue

		for index in range(summon_spawn.count):
			var child_angle := _get_pattern_child_angle(
				base_angle,
				summon_spawn.angle_offset_degrees,
				summon_spawn.arc_degrees,
				summon_spawn.count,
				index
			)
			var child_direction := Vector2.RIGHT.rotated(child_angle)
			var child_spawn_center := current_center + child_direction * summon_spawn.spawn_radius
			_spawn_child_enemy(summon_spawn.enemy_scene, child_spawn_center, child_direction)

	_spawn_summon_feedback(current_center)

func _spawn_split_children() -> void:
	if split_spawns.is_empty():
		return

	if _tower_health == null:
		return

	var current_center := _get_center_position()
	var base_direction := (_target_center - _tower_center).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.UP
	var base_angle: float = base_direction.angle()

	for split_spawn in split_spawns:
		if split_spawn == null or split_spawn.enemy_scene == null or split_spawn.count <= 0:
			continue

		for index in range(split_spawn.count):
			var child_angle := _get_pattern_child_angle(
				base_angle,
				split_spawn.angle_offset_degrees,
				split_spawn.arc_degrees,
				split_spawn.count,
				index
			)
			var child_direction := Vector2.RIGHT.rotated(child_angle)
			var child_spawn_center := current_center + child_direction * split_spawn.spawn_separation_radius
			_spawn_child_enemy(split_spawn.enemy_scene, child_spawn_center, child_direction)

func _resolve_tower_center() -> Vector2:
	if _tower_health == null:
		return Vector2.ZERO
	var tower_body := _tower_health.get_parent() as Control
	if tower_body == null:
		return Vector2.ZERO
	var tower_rect := tower_body.get_global_rect()
	return tower_rect.position + tower_rect.size * 0.5

func _spawn_child_enemy(enemy_scene: PackedScene, spawn_center: Vector2, direction: Vector2) -> GameTestEnemy:
	var parent_node := get_parent() as Control
	if parent_node == null or _tower_health == null or enemy_scene == null:
		return null

	var child_enemy := enemy_scene.instantiate() as GameTestEnemy
	if child_enemy == null:
		return null

	var child_direction := direction.normalized()
	if child_direction == Vector2.ZERO:
		child_direction = (_target_center - _tower_center).normalized()
	if child_direction == Vector2.ZERO:
		child_direction = Vector2.UP

	var child_target_radius := child_enemy.get_preferred_ring_radius(_target_center.distance_to(_tower_center))
	var child_target_center := _tower_center + child_direction * child_target_radius

	parent_node.add_child(child_enemy)
	child_enemy.setup(_tower_health, spawn_center, child_target_center, _effect_host)
	child_enemy_spawned.emit(child_enemy)
	return child_enemy

func _get_pattern_child_angle(base_angle: float, angle_offset_degrees: float, arc_degrees: float, count: int, index: int) -> float:
	var final_offset_deg: float = angle_offset_degrees
	if count > 1:
		var spread_progress: float = float(index) / float(count - 1)
		final_offset_deg += lerpf(-arc_degrees * 0.5, arc_degrees * 0.5, spread_progress)
	return base_angle + deg_to_rad(final_offset_deg)

func _spawn_summon_feedback(center: Vector2) -> void:
	var effect_parent: Control = _effect_host if _effect_host != null else get_parent() as Control
	if effect_parent == null:
		return

	var pulse := Panel.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.size = Vector2(42.0, 42.0)
	pulse.pivot_offset = pulse.size * 0.5
	pulse.global_position = center - pulse.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.72, 0.82, 0.16)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.88, 0.88, 0.98, 0.88)
	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_right = 48
	style.corner_radius_bottom_left = 48
	pulse.add_theme_stylebox_override("panel", style)
	effect_parent.add_child(pulse)

	var tween := pulse.create_tween()
	tween.parallel().tween_property(pulse, "scale", Vector2(1.45, 1.45), 0.22)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.22)
	tween.tween_callback(Callable(pulse, "queue_free"))
