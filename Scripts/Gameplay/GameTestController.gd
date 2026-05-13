extends Control

const BASIC_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemy.tscn")
const BRUTE_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemyBrute.tscn")
const RANGED_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemyRanged.tscn")

const LIGHTNING_COOLDOWN: float = 2.4
const LIGHTNING_AREA_RADIUS: float = 96.0
const LIGHTNING_STRIKE_RADIUS: float = 28.0
const LIGHTNING_STRIKE_STAGGER: float = 0.08

const SNOWBALL_COOLDOWN: float = 3.1
const SNOWBALL_PROJECTILE_DURATION: float = 0.4
const SNOWBALL_IMPACT_RADIUS: float = 28.0
const SNOWBALL_FIELD_RADIUS: float = 66.0
const SNOWBALL_FIELD_DURATION: float = 1.8
const SNOWBALL_FIELD_TICK: float = 0.15

const BLADES_ORBIT_RADIUS: float = 72.0
const BLADES_ROTATION_SPEED: float = 2.6
const BLADE_DAMAGE_INTERVAL: float = 0.35
const BLADE_DAMAGE_PER_HIT: int = 1

@export var starting_gold: int = 250
@export var enemy_spawn_interval: float = 1.1
@export var default_player_attack_cooldown: float = 0.5
@export var default_player_damage: int = 1
@export var enemy_ring_radius: float = 160.0
@export var enemy_spawn_margin: float = 90.0
@export var click_feedback_duration: float = 0.16

@onready var tower_health: HealthController = $TowerAnchor/TowerWrap/TowerBody/HealthController
@onready var tower_body: Panel = $TowerAnchor/TowerWrap/TowerBody
@onready var tower_damage_flash: ColorRect = $TowerAnchor/TowerWrap/TowerBody/DamageFlash
@onready var enemy_layer: Control = $EnemyLayer
@onready var effect_layer: Control = $EffectLayer
@onready var survived_time_label: Label = $TopRightHud/TimeLabel
@onready var end_run_button: Button = $BottomRightHud/EndRunButton

var _spawn_timer: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _lightning_cooldown_remaining: float = 0.0
var _snowball_cooldown_remaining: float = 0.0
var _blade_rotation: float = 0.0
var _is_game_over: bool = false
var _survived_time_sec: float = 0.0

var _player_damage: int = 1
var _player_attack_cooldown: float = 0.5
var _damage_level: int = 0
var _speed_level: int = 0

var _lightning_unlocked: bool = false
var _lightning_damage: int = 2
var _lightning_count: int = 3
var _lightning_cooldown: float = LIGHTNING_COOLDOWN
var _lightning_area_radius: float = LIGHTNING_AREA_RADIUS
var _lightning_damage_level: int = 0
var _lightning_count_level: int = 0

var _snowball_unlocked: bool = false
var _snowball_damage: int = 2
var _snowball_cooldown: float = SNOWBALL_COOLDOWN
var _snowball_slow_factor: float = 0.70
var _snowball_field_radius: float = SNOWBALL_FIELD_RADIUS
var _snowball_field_duration: float = SNOWBALL_FIELD_DURATION
var _snowball_damage_level: int = 0
var _snowball_slow_level: int = 0

var _blades_unlocked: bool = false
var _blade_count: int = 3
var _blade_size: float = 18.0
var _blade_orbit_radius: float = BLADES_ORBIT_RADIUS
var _blade_rotation_speed: float = BLADES_ROTATION_SPEED
var _blade_damage: int = BLADE_DAMAGE_PER_HIT
var _blade_count_level: int = 0
var _blade_size_level: int = 0

var _blade_nodes: Array[Panel] = []
var _blade_hit_cooldowns: Dictionary = {}
var _active_slow_fields: Array[Dictionary] = []
var _blade_host: Control

func _ready() -> void:
	randomize()
	_blade_host = Control.new()
	_blade_host.name = "BladeHost"
	_blade_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blade_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect_layer.add_child(_blade_host)

	_apply_run_state(_build_run_state(ScenesManager.consume_payload()))

	tower_health.damaged.connect(_on_tower_damaged)
	tower_health.died.connect(_on_tower_died)
	end_run_button.pressed.connect(_on_end_run_pressed)
	_spawn_timer = enemy_spawn_interval
	_attack_cooldown_remaining = _player_attack_cooldown
	_lightning_cooldown_remaining = _lightning_cooldown
	_snowball_cooldown_remaining = _snowball_cooldown
	tower_damage_flash.modulate.a = 0.0
	_update_survived_time_label()
	_refresh_blades()

func _process(delta: float) -> void:
	if _is_game_over:
		return

	_survived_time_sec += delta
	_update_survived_time_label()

	_update_spawn(delta)
	_update_basic_attack(delta)
	_update_lightning(delta)
	_update_snowball(delta)
	_update_slow_fields(delta)
	_update_blades(delta)

func _build_run_state(payload: Variant) -> Dictionary:
	var state: Dictionary = {
		"gold": starting_gold,
		"player_damage": default_player_damage,
		"player_attack_cooldown": default_player_attack_cooldown,
		"damage_level": 0,
		"speed_level": 0,
		"elapsed_time_sec": 0.0,
		"lightning_unlocked": false,
		"lightning_damage": 2,
		"lightning_count": 3,
		"lightning_cooldown": LIGHTNING_COOLDOWN,
		"lightning_area_radius": LIGHTNING_AREA_RADIUS,
		"lightning_damage_level": 0,
		"lightning_count_level": 0,
		"snowball_unlocked": false,
		"snowball_damage": 2,
		"snowball_cooldown": SNOWBALL_COOLDOWN,
		"snowball_slow_factor": 0.70,
		"snowball_field_radius": SNOWBALL_FIELD_RADIUS,
		"snowball_field_duration": SNOWBALL_FIELD_DURATION,
		"snowball_damage_level": 0,
		"snowball_slow_level": 0,
		"blades_unlocked": false,
		"blade_count": 3,
		"blade_size": 18.0,
		"blade_orbit_radius": BLADES_ORBIT_RADIUS,
		"blade_rotation_speed": BLADES_ROTATION_SPEED,
		"blade_damage": BLADE_DAMAGE_PER_HIT,
		"blade_count_level": 0,
		"blade_size_level": 0
	}

	if typeof(payload) != TYPE_DICTIONARY:
		return state

	for key in state.keys():
		if payload.has(key):
			state[key] = payload[key]

	return state

func _apply_run_state(run_state: Dictionary) -> void:
	CurrencySystem.set_amount("gold", int(run_state.get("gold", starting_gold)))
	_player_damage = int(run_state.get("player_damage", default_player_damage))
	_player_attack_cooldown = float(run_state.get("player_attack_cooldown", default_player_attack_cooldown))
	_damage_level = int(run_state.get("damage_level", 0))
	_speed_level = int(run_state.get("speed_level", 0))
	_survived_time_sec = float(run_state.get("elapsed_time_sec", 0.0))

	_lightning_unlocked = bool(run_state.get("lightning_unlocked", false))
	_lightning_damage = int(run_state.get("lightning_damage", 2))
	_lightning_count = int(run_state.get("lightning_count", 3))
	_lightning_cooldown = float(run_state.get("lightning_cooldown", LIGHTNING_COOLDOWN))
	_lightning_area_radius = float(run_state.get("lightning_area_radius", LIGHTNING_AREA_RADIUS))
	_lightning_damage_level = int(run_state.get("lightning_damage_level", 0))
	_lightning_count_level = int(run_state.get("lightning_count_level", 0))

	_snowball_unlocked = bool(run_state.get("snowball_unlocked", false))
	_snowball_damage = int(run_state.get("snowball_damage", 2))
	_snowball_cooldown = float(run_state.get("snowball_cooldown", SNOWBALL_COOLDOWN))
	_snowball_slow_factor = float(run_state.get("snowball_slow_factor", 0.70))
	_snowball_field_radius = float(run_state.get("snowball_field_radius", SNOWBALL_FIELD_RADIUS))
	_snowball_field_duration = float(run_state.get("snowball_field_duration", SNOWBALL_FIELD_DURATION))
	_snowball_damage_level = int(run_state.get("snowball_damage_level", 0))
	_snowball_slow_level = int(run_state.get("snowball_slow_level", 0))

	_blades_unlocked = bool(run_state.get("blades_unlocked", false))
	_blade_count = int(run_state.get("blade_count", 3))
	_blade_size = float(run_state.get("blade_size", 18.0))
	_blade_orbit_radius = float(run_state.get("blade_orbit_radius", BLADES_ORBIT_RADIUS))
	_blade_rotation_speed = float(run_state.get("blade_rotation_speed", BLADES_ROTATION_SPEED))
	_blade_damage = int(run_state.get("blade_damage", BLADE_DAMAGE_PER_HIT))
	_blade_count_level = int(run_state.get("blade_count_level", 0))
	_blade_size_level = int(run_state.get("blade_size_level", 0))

func _update_spawn(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer += enemy_spawn_interval
		_spawn_enemy()

func _update_basic_attack(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if _attack_cooldown_remaining <= 0.0:
		_attack_cooldown_remaining = _player_attack_cooldown
		_perform_player_attack()

func _update_lightning(delta: float) -> void:
	if not _lightning_unlocked:
		return
	_lightning_cooldown_remaining = maxf(_lightning_cooldown_remaining - delta, 0.0)
	if _lightning_cooldown_remaining <= 0.0:
		_lightning_cooldown_remaining = _lightning_cooldown
		_trigger_lightning_burst()

func _update_snowball(delta: float) -> void:
	if not _snowball_unlocked:
		return
	_snowball_cooldown_remaining = maxf(_snowball_cooldown_remaining - delta, 0.0)
	if _snowball_cooldown_remaining <= 0.0:
		_snowball_cooldown_remaining = _snowball_cooldown
		_trigger_snowball()

func _update_slow_fields(delta: float) -> void:
	for i in range(_active_slow_fields.size() - 1, -1, -1):
		var field: Dictionary = _active_slow_fields[i]
		field["remaining"] = float(field.get("remaining", 0.0)) - delta
		field["tick_remaining"] = float(field.get("tick_remaining", 0.0)) - delta

		var field_node := field.get("node", null) as CanvasItem
		if field_node != null:
			field_node.modulate.a = clampf(float(field.get("remaining", 0.0)) / maxf(_snowball_field_duration, 0.01), 0.15, 0.55)

		if float(field.get("tick_remaining", 0.0)) <= 0.0:
			field["tick_remaining"] = SNOWBALL_FIELD_TICK
			_apply_slow_field(field)

		if float(field.get("remaining", 0.0)) <= 0.0:
			if field_node != null:
				field_node.queue_free()
			_active_slow_fields.remove_at(i)
		else:
			_active_slow_fields[i] = field

func _update_blades(delta: float) -> void:
	if not _blades_unlocked:
		_clear_blades()
		return

	_refresh_blades()
	_blade_rotation += _blade_rotation_speed * delta

	var mouse_position := get_global_mouse_position()
	for i in range(_blade_nodes.size()):
		var blade := _blade_nodes[i]
		var angle := _blade_rotation + TAU * float(i) / float(max(_blade_nodes.size(), 1))
		var center := mouse_position + Vector2.RIGHT.rotated(angle) * _blade_orbit_radius
		blade.rotation = angle + PI * 0.5
		blade.global_position = center - blade.size * 0.5

	var cooldown_keys: Array = _blade_hit_cooldowns.keys()
	for enemy_id in cooldown_keys:
		_blade_hit_cooldowns[enemy_id] = maxf(float(_blade_hit_cooldowns[enemy_id]) - delta, 0.0)

	for enemy in _get_live_enemies():
		var enemy_id := enemy.get_instance_id()
		var enemy_center := _get_enemy_center(enemy)
		var enemy_radius := _get_enemy_radius(enemy)
		var hit_cooldown := float(_blade_hit_cooldowns.get(enemy_id, 0.0))
		if hit_cooldown > 0.0:
			continue

		for i in range(_blade_nodes.size()):
			var angle := _blade_rotation + TAU * float(i) / float(max(_blade_nodes.size(), 1))
			var blade_center := mouse_position + Vector2.RIGHT.rotated(angle) * _blade_orbit_radius
			var hit_radius := _blade_size * 0.55 + enemy_radius
			if blade_center.distance_to(enemy_center) <= hit_radius:
				enemy.receive_player_damage(_blade_damage)
				_spawn_blade_hit_feedback(blade_center)
				_blade_hit_cooldowns[enemy_id] = BLADE_DAMAGE_INTERVAL
				break

func _spawn_enemy() -> void:
	var tower_center := _get_tower_center()
	var viewport_size := get_viewport_rect().size
	var spawn_center := _pick_spawn_position(viewport_size)
	var outward_direction := (spawn_center - tower_center).normalized()
	if outward_direction == Vector2.ZERO:
		outward_direction = Vector2.UP

	var enemy := _instantiate_enemy_variant()
	var target_radius := enemy.get_preferred_ring_radius(enemy_ring_radius)
	var target_center := tower_center + outward_direction * target_radius
	enemy_layer.add_child(enemy)
	enemy.setup(tower_health, spawn_center, target_center, effect_layer)
	enemy.defeated.connect(_on_enemy_defeated)

func _instantiate_enemy_variant() -> GameTestEnemy:
	var roll: float = randf()
	var scene: PackedScene = BASIC_ENEMY_SCENE
	if roll < 0.18:
		scene = RANGED_ENEMY_SCENE
	elif roll < 0.43:
		scene = BRUTE_ENEMY_SCENE
	return scene.instantiate() as GameTestEnemy

func _pick_spawn_position(viewport_size: Vector2) -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf_range(0.0, viewport_size.x), -enemy_spawn_margin)
		1:
			return Vector2(viewport_size.x + enemy_spawn_margin, randf_range(0.0, viewport_size.y))
		2:
			return Vector2(randf_range(0.0, viewport_size.x), viewport_size.y + enemy_spawn_margin)
		_:
			return Vector2(-enemy_spawn_margin, randf_range(0.0, viewport_size.y))

func _perform_player_attack() -> void:
	var mouse_position := get_global_mouse_position()
	var hit_enemy := _find_enemy_at_position(mouse_position)
	if hit_enemy != null:
		hit_enemy.receive_player_damage(_player_damage)
		_spawn_click_feedback(mouse_position, true)
	else:
		_spawn_click_feedback(mouse_position, false)

func _find_enemy_at_position(screen_position: Vector2) -> GameTestEnemy:
	var children := enemy_layer.get_children()
	for index in range(children.size() - 1, -1, -1):
		var enemy := children[index] as GameTestEnemy
		if enemy != null and enemy.is_point_inside_enemy(screen_position):
			return enemy
	return null

func _find_enemy_near_position(screen_position: Vector2, radius: float) -> GameTestEnemy:
	var best_enemy: GameTestEnemy
	var best_distance: float = INF
	for enemy in _get_live_enemies():
		var distance := _get_enemy_center(enemy).distance_to(screen_position)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	return best_enemy

func _get_enemies_in_radius(screen_position: Vector2, radius: float) -> Array[GameTestEnemy]:
	var hits: Array[GameTestEnemy] = []
	for enemy in _get_live_enemies():
		if _get_enemy_center(enemy).distance_to(screen_position) <= radius + _get_enemy_radius(enemy):
			hits.append(enemy)
	return hits

func _get_live_enemies() -> Array[GameTestEnemy]:
	var enemies: Array[GameTestEnemy] = []
	for child in enemy_layer.get_children():
		var enemy := child as GameTestEnemy
		if enemy != null:
			enemies.append(enemy)
	return enemies

func _trigger_lightning_burst() -> void:
	var mouse_position := get_global_mouse_position()
	for i in range(_lightning_count):
		var strike_point := mouse_position + _random_point_in_circle(_lightning_area_radius)
		var tween := create_tween()
		tween.tween_interval(LIGHTNING_STRIKE_STAGGER * i)
		tween.tween_callback(Callable(self, "_resolve_lightning_strike").bind(strike_point))

func _resolve_lightning_strike(strike_point: Vector2) -> void:
	var hit_enemy := _find_enemy_near_position(strike_point, LIGHTNING_STRIKE_RADIUS)
	if hit_enemy != null:
		hit_enemy.receive_player_damage(_lightning_damage)
	_spawn_lightning_feedback(strike_point, hit_enemy != null)

func _trigger_snowball() -> void:
	var tower_center := _get_tower_center()
	var target_position := get_global_mouse_position()
	var travel_distance: float = tower_center.distance_to(target_position)
	var projectile := Panel.new()
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(18.0, 18.0)
	projectile.pivot_offset = projectile.size * 0.5
	projectile.global_position = tower_center - projectile.size * 0.5
	projectile.scale = Vector2(0.62, 0.62)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.95, 1.0, 0.98)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	projectile.add_theme_stylebox_override("panel", style)
	effect_layer.add_child(projectile)

	var distance_factor: float = clampf(travel_distance / 260.0, 0.0, 1.0)
	var peak_scale: Vector2 = Vector2.ONE * (1.28 + distance_factor * 0.28)
	var end_scale: Vector2 = Vector2.ONE * 0.68

	var move_tween := create_tween()
	move_tween.tween_property(projectile, "global_position", target_position - projectile.size * 0.5, SNOWBALL_PROJECTILE_DURATION)
	move_tween.finished.connect(_on_snowball_hit.bind(projectile, target_position))

	var scale_tween := create_tween()
	scale_tween.tween_property(projectile, "scale", peak_scale, SNOWBALL_PROJECTILE_DURATION * 0.5)
	scale_tween.tween_property(projectile, "scale", end_scale, SNOWBALL_PROJECTILE_DURATION * 0.5)

func _on_snowball_hit(projectile: Panel, target_position: Vector2) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()

	var enemies := _get_enemies_in_radius(target_position, SNOWBALL_IMPACT_RADIUS)
	for enemy in enemies:
		enemy.receive_player_damage(_snowball_damage)

	_spawn_snowball_impact_feedback(target_position)
	_spawn_slow_field(target_position)

func _spawn_slow_field(center: Vector2) -> void:
	var field := Panel.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.size = Vector2(_snowball_field_radius * 2.0, _snowball_field_radius * 2.0)
	field.pivot_offset = field.size * 0.5
	field.global_position = center - field.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.53, 0.82, 1.0, 0.28)
	style.corner_radius_top_left = 96
	style.corner_radius_top_right = 96
	style.corner_radius_bottom_right = 96
	style.corner_radius_bottom_left = 96
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.88, 0.97, 1.0, 0.7)
	field.add_theme_stylebox_override("panel", style)
	effect_layer.add_child(field)

	_active_slow_fields.append({
		"node": field,
		"center": center,
		"radius": _snowball_field_radius,
		"remaining": _snowball_field_duration,
		"tick_remaining": 0.0
	})

func _apply_slow_field(field: Dictionary) -> void:
	var center: Vector2 = field.get("center", Vector2.ZERO)
	var radius: float = float(field.get("radius", SNOWBALL_FIELD_RADIUS))
	for enemy in _get_live_enemies():
		if _get_enemy_center(enemy).distance_to(center) <= radius + _get_enemy_radius(enemy):
			enemy.apply_slow(_snowball_slow_factor, SNOWBALL_FIELD_TICK + 0.08)

func _refresh_blades() -> void:
	if not _blades_unlocked:
		_clear_blades()
		return

	if _blade_nodes.size() == _blade_count:
		for blade in _blade_nodes:
			blade.size = Vector2(_blade_size, _blade_size * 0.38)
			blade.pivot_offset = blade.size * 0.5
		return

	_clear_blades()
	for _i in range(_blade_count):
		var blade := Panel.new()
		blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blade.size = Vector2(_blade_size, _blade_size * 0.38)
		blade.pivot_offset = blade.size * 0.5

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.95, 0.95, 0.98, 0.96)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_right = 3
		style.corner_radius_bottom_left = 3
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.56, 0.66, 0.78, 0.9)
		blade.add_theme_stylebox_override("panel", style)

		_blade_host.add_child(blade)
		_blade_nodes.append(blade)

func _clear_blades() -> void:
	for blade in _blade_nodes:
		if is_instance_valid(blade):
			blade.queue_free()
	_blade_nodes.clear()

func _spawn_click_feedback(screen_position: Vector2, hit_target: bool) -> void:
	var marker := Panel.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = Vector2(22.0, 22.0)
	marker.pivot_offset = marker.size * 0.5
	marker.global_position = screen_position - marker.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.93, 0.75, 0.95) if hit_target else Color(1.0, 1.0, 1.0, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.4, 0.28, 1.0) if hit_target else Color(0.15, 0.18, 0.18, 0.9)
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_right = 32
	style.corner_radius_bottom_left = 32
	marker.add_theme_stylebox_override("panel", style)

	effect_layer.add_child(marker)

	var tween := create_tween()
	tween.parallel().tween_property(marker, "scale", Vector2(1.6, 1.6), click_feedback_duration)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, click_feedback_duration)
	tween.tween_callback(Callable(marker, "queue_free"))

func _spawn_lightning_feedback(screen_position: Vector2, hit_target: bool) -> void:
	var beam := ColorRect.new()
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.color = Color(1.0, 0.95, 0.64, 0.92) if hit_target else Color(0.92, 0.96, 1.0, 0.78)
	beam.size = Vector2(8.0, screen_position.y + 12.0)
	beam.pivot_offset = Vector2(4.0, 0.0)
	beam.global_position = Vector2(screen_position.x - 4.0, -12.0)
	effect_layer.add_child(beam)

	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(34.0, 34.0)
	ring.pivot_offset = ring.size * 0.5
	ring.global_position = screen_position - ring.size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.64, 0.22) if hit_target else Color(0.88, 0.95, 1.0, 0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.83, 0.31, 0.95)
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_right = 40
	style.corner_radius_bottom_left = 40
	ring.add_theme_stylebox_override("panel", style)
	effect_layer.add_child(ring)

	var tween := create_tween()
	tween.parallel().tween_property(beam, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(ring, "scale", Vector2(1.5, 1.5), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(beam, "queue_free"))
	tween.tween_callback(Callable(ring, "queue_free"))

func _spawn_snowball_impact_feedback(screen_position: Vector2) -> void:
	var burst := Panel.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2(42.0, 42.0)
	burst.pivot_offset = burst.size * 0.5
	burst.global_position = screen_position - burst.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.94, 1.0, 0.28)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.99, 1.0, 0.92)
	style.corner_radius_top_left = 42
	style.corner_radius_top_right = 42
	style.corner_radius_bottom_right = 42
	style.corner_radius_bottom_left = 42
	burst.add_theme_stylebox_override("panel", style)
	effect_layer.add_child(burst)

	var tween := create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.8, 1.8), 0.24)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(burst, "queue_free"))

func _spawn_blade_hit_feedback(screen_position: Vector2) -> void:
	var spark := Panel.new()
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.size = Vector2(16.0, 16.0)
	spark.pivot_offset = spark.size * 0.5
	spark.global_position = screen_position - spark.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.97, 1.0, 0.78)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	spark.add_theme_stylebox_override("panel", style)
	effect_layer.add_child(spark)

	var tween := create_tween()
	tween.parallel().tween_property(spark, "scale", Vector2(1.4, 1.4), 0.14)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(spark, "queue_free"))

func _on_enemy_defeated(gold_reward: int) -> void:
	CurrencySystem.add_currency("gold", gold_reward)

func _on_tower_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	_flash_tower_damage()

func _flash_tower_damage() -> void:
	tower_damage_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.parallel().tween_property(tower_damage_flash, "modulate:a", 0.55, 0.07)
	tween.parallel().tween_property(tower_body, "scale", Vector2(1.03, 1.03), 0.07)
	tween.tween_property(tower_damage_flash, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(tower_body, "scale", Vector2.ONE, 0.18)

func _on_tower_died() -> void:
	if _is_game_over:
		return
	_go_to_upgrade_menu()

func _on_end_run_pressed() -> void:
	if _is_game_over:
		return
	_go_to_upgrade_menu()

func _go_to_upgrade_menu() -> void:
	_is_game_over = true
	TransitionManager.change_scene("UpgradeMenu", "iris_circle", {
		"data": _build_upgrade_payload()
	})

func _get_tower_center() -> Vector2:
	var tower_rect := tower_body.get_global_rect()
	return tower_rect.position + tower_rect.size * 0.5

func _build_upgrade_payload() -> Dictionary:
	return {
		"gold": CurrencySystem.get_amount("gold"),
		"player_damage": _player_damage,
		"player_attack_cooldown": _player_attack_cooldown,
		"damage_level": _damage_level,
		"speed_level": _speed_level,
		"elapsed_time_sec": _survived_time_sec,
		"lightning_unlocked": _lightning_unlocked,
		"lightning_damage": _lightning_damage,
		"lightning_count": _lightning_count,
		"lightning_cooldown": _lightning_cooldown,
		"lightning_area_radius": _lightning_area_radius,
		"lightning_damage_level": _lightning_damage_level,
		"lightning_count_level": _lightning_count_level,
		"snowball_unlocked": _snowball_unlocked,
		"snowball_damage": _snowball_damage,
		"snowball_cooldown": _snowball_cooldown,
		"snowball_slow_factor": _snowball_slow_factor,
		"snowball_field_radius": _snowball_field_radius,
		"snowball_field_duration": _snowball_field_duration,
		"snowball_damage_level": _snowball_damage_level,
		"snowball_slow_level": _snowball_slow_level,
		"blades_unlocked": _blades_unlocked,
		"blade_count": _blade_count,
		"blade_size": _blade_size,
		"blade_orbit_radius": _blade_orbit_radius,
		"blade_rotation_speed": _blade_rotation_speed,
		"blade_damage": _blade_damage,
		"blade_count_level": _blade_count_level,
		"blade_size_level": _blade_size_level
	}

func _update_survived_time_label() -> void:
	var total_seconds := int(floor(_survived_time_sec))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	survived_time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _random_point_in_circle(radius: float) -> Vector2:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * radius
	return Vector2.RIGHT.rotated(angle) * distance

func _get_enemy_center(enemy: GameTestEnemy) -> Vector2:
	var rect := enemy.get_global_rect()
	return rect.position + rect.size * 0.5

func _get_enemy_radius(enemy: GameTestEnemy) -> float:
	var rect := enemy.get_global_rect()
	return minf(rect.size.x, rect.size.y) * 0.33
