extends Control
class_name GameTestEnemy

signal defeated(gold_reward: int)

enum State { MOVING, ATTACKING, DEAD }
enum AttackMode { CONTACT, RANGED }

@export var move_speed: float = 155.0
@export var attack_interval: float = 1.0
@export var attack_damage: int = 1
@export var arrival_threshold: float = 8.0
@export var gold_reward: int = 1
@export var attack_mode: AttackMode = AttackMode.CONTACT
@export var preferred_ring_radius: float = -1.0
@export var projectile_travel_duration: float = 0.22
@export var projectile_size: float = 12.0
@export var projectile_color: Color = Color(1.0, 0.85, 0.45, 1.0)
@export var move_body_color: Color = Color(0.47, 0.71, 1.0, 1.0)
@export var move_accent_color: Color = Color(0.86, 0.95, 1.0, 1.0)
@export var attack_body_color: Color = Color(1.0, 0.46, 0.39, 1.0)
@export var attack_accent_color: Color = Color(1.0, 0.88, 0.69, 1.0)

@onready var health_controller: HealthController = $HealthController
@onready var body: Panel = $Body
@onready var accent: Panel = $Body/Accent

var _tower_health: HealthController
var _target_center: Vector2 = Vector2.ZERO
var _state: State = State.MOVING
var _attack_timer: float = 0.0
var _effect_host: Control
var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_controller.died.connect(_on_died)
	_apply_state_visual()

func setup(tower_health: HealthController, spawn_center: Vector2, target_center: Vector2, effect_host: Control = null) -> void:
	_tower_health = tower_health
	_target_center = target_center
	_effect_host = effect_host
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
			var current_center := _get_center_position()
			var next_center := current_center.move_toward(_target_center, move_speed * _slow_multiplier * delta)
			_set_center_position(next_center)

			if next_center.distance_to(_target_center) <= arrival_threshold:
				_set_center_position(_target_center)
				_state = State.ATTACKING
				_attack_timer = 0.0
				_apply_state_visual()

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
	_tower_health.apply_damage(attack_damage)

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
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", target_center - projectile.size * 0.5, projectile_travel_duration)
	tween.finished.connect(_on_projectile_finished.bind(projectile))

func _on_projectile_finished(projectile: Panel) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	if _tower_health != null and _tower_health.is_alive():
		_tower_health.apply_damage(attack_damage)

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
