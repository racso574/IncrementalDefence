@tool
extends Control
class_name EnemyWaveSpawner

signal enemy_spawned(enemy: GameTestEnemy)
signal wave_changed(wave_index: int, wave_name: String)

const BASIC_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemy.tscn")
const BRUTE_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemyBrute.tscn")
const RANGED_ENEMY_SCENE := preload("res://Scenes/Gameplay/GameTestEnemyRanged.tscn")

const SPAWN_CHAIN_LEFT := "left"
const SPAWN_CHAIN_RIGHT := "right"

@export var enemy_spawn_margin: float = 90.0
@export var default_ring_radius: float = 160.0
@export var top_bottom_banned_half_width: float = 120.0
@export var blocked_retry_interval: float = 0.12
@export var show_editor_preview: bool = true
@export_range(0, 12, 1, "or_greater") var boundary_preview_count: int = 4
@export_range(5.0, 180.0, 1.0, "or_greater") var preview_step_degrees: float = 20.0
@export_range(0.0, 64.0, 0.5, "or_greater") var boundary_preview_inset: float = 3.0
@export var wave_set: EnemyWaveSet
var waves: Array[EnemyWaveDefinition] = []

@export_node_path("Control") var play_area_path: NodePath
@export_node_path("Control") var tower_body_path: NodePath
@export_node_path("Node") var tower_health_path: NodePath
@export_node_path("Control") var enemy_layer_path: NodePath
@export_node_path("Control") var effect_layer_path: NodePath

@onready var _play_area: Control = get_node_or_null(play_area_path) as Control
@onready var _tower_body: Control = get_node_or_null(tower_body_path) as Control
@onready var _tower_health: HealthController = get_node_or_null(tower_health_path) as HealthController
@onready var _enemy_layer: Control = get_node_or_null(enemy_layer_path) as Control
@onready var _effect_layer: Control = get_node_or_null(effect_layer_path) as Control

var _spawn_timer: float = 0.0
var _current_wave_index: int = 0
var _current_wave_elapsed: float = 0.0
var _is_running: bool = false
var _active_enemies: Dictionary = {}

func _enter_tree() -> void:
	_request_preview_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_internal(true)
	set_notify_transform(true)
	_resolve_scene_references()
	_sync_waves_from_resources()
	if waves.is_empty():
		waves = _build_default_waves()
	reset_spawner()
	_request_preview_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if show_editor_preview:
			_request_preview_redraw()
		return
	if not _is_running or waves.is_empty():
		return
	if _tower_health == null or _tower_body == null or _enemy_layer == null:
		return

	_current_wave_elapsed += delta
	_advance_wave_if_needed()

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	var wave: EnemyWaveDefinition = _get_current_wave()
	if wave == null or not wave.has_spawn_options():
		_spawn_timer = blocked_retry_interval
		return

	if _is_wave_at_maximum(wave):
		_spawn_timer = blocked_retry_interval
		return

	_spawn_enemy_for_wave(wave)
	_spawn_timer = _get_next_spawn_interval(wave)

func start_spawning() -> void:
	_is_running = true

func stop_spawning() -> void:
	_is_running = false

func reset_spawner() -> void:
	_sync_waves_from_resources()
	_current_wave_index = 0
	_current_wave_elapsed = 0.0
	_spawn_timer = 0.0
	_active_enemies.clear()
	if not waves.is_empty():
		var wave: EnemyWaveDefinition = _get_current_wave()
		wave_changed.emit(_current_wave_index, wave.wave_name)
	_request_preview_redraw()

func get_active_enemy_count() -> int:
	return _active_enemies.size()

func get_current_wave_index() -> int:
	return _current_wave_index

func _advance_wave_if_needed() -> void:
	var wave: EnemyWaveDefinition = _get_current_wave()
	if wave == null:
		return
	if wave.duration_sec <= 0.0:
		return
	if _current_wave_elapsed < wave.duration_sec:
		return
	if _current_wave_index >= waves.size() - 1:
		_current_wave_elapsed = wave.duration_sec
		return

	_current_wave_index += 1
	_current_wave_elapsed = 0.0
	_spawn_timer = 0.0
	var next_wave: EnemyWaveDefinition = _get_current_wave()
	wave_changed.emit(_current_wave_index, next_wave.wave_name)

func _spawn_enemy_for_wave(wave: EnemyWaveDefinition) -> void:
	var enemy: GameTestEnemy = _instantiate_wave_enemy(wave)
	if enemy == null:
		return

	var spawn_context: Dictionary = _build_spawn_context(enemy)
	var spawn_center: Vector2 = spawn_context["spawn_center"]
	var target_center: Vector2 = spawn_context["target_center"]

	_enemy_layer.add_child(enemy)
	enemy.setup(_tower_health, spawn_center, target_center, _effect_layer)
	enemy.set_meta("spawn_context", spawn_context)
	_active_enemies[enemy.get_instance_id()] = enemy
	enemy.tree_exited.connect(_on_spawned_enemy_exited.bind(enemy.get_instance_id()))
	enemy_spawned.emit(enemy)

func _instantiate_wave_enemy(wave: EnemyWaveDefinition) -> GameTestEnemy:
	var total_weight: float = 0.0
	for option in wave.spawn_options:
		if option != null and option.enemy_scene != null and option.weight > 0.0:
			total_weight += option.weight

	if total_weight <= 0.0:
		return null

	var roll: float = randf() * total_weight
	var cursor: float = 0.0
	for option in wave.spawn_options:
		if option == null or option.enemy_scene == null or option.weight <= 0.0:
			continue
		cursor += option.weight
		if roll <= cursor:
			return option.enemy_scene.instantiate() as GameTestEnemy

	for index in range(wave.spawn_options.size() - 1, -1, -1):
		var fallback_option: EnemySpawnOption = wave.spawn_options[index]
		if fallback_option != null and fallback_option.enemy_scene != null and fallback_option.weight > 0.0:
			return fallback_option.enemy_scene.instantiate() as GameTestEnemy
	return null

func _get_next_spawn_interval(wave: EnemyWaveDefinition) -> float:
	var progress_ratio: float = _get_wave_progress_ratio(wave)
	var below_minimum: bool = _active_enemies.size() < wave.min_alive
	return wave.get_spawn_interval(progress_ratio, below_minimum)

func _get_wave_progress_ratio(wave: EnemyWaveDefinition) -> float:
	if wave.duration_sec <= 0.0:
		return 1.0
	return clampf(_current_wave_elapsed / wave.duration_sec, 0.0, 1.0)

func _is_wave_at_maximum(wave: EnemyWaveDefinition) -> bool:
	return wave.max_alive >= 0 and _active_enemies.size() >= wave.max_alive

func _get_current_wave() -> EnemyWaveDefinition:
	if waves.is_empty():
		return null
	return waves[clampi(_current_wave_index, 0, waves.size() - 1)]

func _get_spawn_rect() -> Rect2:
	var play_area_rect: Rect2 = _get_play_area_global_rect()
	return Rect2(
		play_area_rect.position - Vector2.ONE * enemy_spawn_margin,
		play_area_rect.size + Vector2.ONE * enemy_spawn_margin * 2.0
	)

func _build_spawn_context(enemy: GameTestEnemy) -> Dictionary:
	var tower_center: Vector2 = _get_tower_center()
	var spawn_rect: Rect2 = _get_spawn_rect()
	var chains: Dictionary = _build_spawn_chains(spawn_rect)
	var left_length: float = float(chains[SPAWN_CHAIN_LEFT]["total_length"])
	var right_length: float = float(chains[SPAWN_CHAIN_RIGHT]["total_length"])
	if left_length <= 0.0 and right_length <= 0.0:
		var fallback_direction := Vector2.UP
		var target_radius := enemy.get_preferred_ring_radius(default_ring_radius)
		return {
			"spawn_center": tower_center,
			"target_center": tower_center + fallback_direction * target_radius,
			"target_direction": fallback_direction,
			"target_angle": -PI * 0.5,
			"chain_progress": 0.0,
			"chain_side": SPAWN_CHAIN_LEFT,
			"ring_radius": target_radius
		}

	var chain_side: String = _pick_spawn_chain(chains)
	var sample: Dictionary = _sample_spawn_from_chain(chains[chain_side], chain_side)
	var target_radius: float = enemy.get_preferred_ring_radius(default_ring_radius)
	var target_direction: Vector2 = sample["target_direction"]
	return {
		"spawn_center": sample["spawn_center"],
		"target_center": tower_center + target_direction * target_radius,
		"target_direction": target_direction,
		"target_angle": sample["target_angle"],
		"chain_progress": sample["chain_progress"],
		"chain_side": chain_side,
		"ring_radius": target_radius
	}

func _build_spawn_chains(spawn_rect: Rect2) -> Dictionary:
	var left_x: float = spawn_rect.position.x
	var right_x: float = spawn_rect.position.x + spawn_rect.size.x
	var top_y: float = spawn_rect.position.y
	var bottom_y: float = spawn_rect.position.y + spawn_rect.size.y
	var play_area_rect: Rect2 = _get_play_area_global_rect()
	var tower_center: Vector2 = _get_tower_center()
	var banned_min_x: float = clampf(tower_center.x - top_bottom_banned_half_width, left_x, right_x)
	var banned_max_x: float = clampf(tower_center.x + top_bottom_banned_half_width, left_x, right_x)
	if banned_min_x > banned_max_x:
		var swap_value: float = banned_min_x
		banned_min_x = banned_max_x
		banned_max_x = swap_value

	return {
		SPAWN_CHAIN_LEFT: _build_spawn_chain([
			Vector2(banned_min_x, top_y),
			Vector2(left_x, top_y),
			Vector2(left_x, bottom_y),
			Vector2(banned_min_x, bottom_y)
		], play_area_rect, SPAWN_CHAIN_LEFT),
		SPAWN_CHAIN_RIGHT: _build_spawn_chain([
			Vector2(banned_max_x, top_y),
			Vector2(right_x, top_y),
			Vector2(right_x, bottom_y),
			Vector2(banned_max_x, bottom_y)
		], play_area_rect, SPAWN_CHAIN_RIGHT)
	}

func _build_spawn_chain(points: Array[Vector2], play_area_rect: Rect2, chain_side: String) -> Dictionary:
	var segments: Array[Dictionary] = []
	var offset: float = 0.0
	for index in range(points.size() - 1):
		var point_from: Vector2 = points[index]
		var point_to: Vector2 = points[index + 1]
		var length: float = point_from.distance_to(point_to)
		if length <= 0.0:
			continue
		segments.append({
			"point_from": point_from,
			"point_to": point_to,
			"offset": offset,
			"length": length
		})
		offset += length

	return {
		"chain_side": chain_side,
		"segments": segments,
		"total_length": offset,
		"play_area_rect": play_area_rect,
		"start_point": points.front(),
		"end_point": points.back()
	}

func _pick_spawn_chain(chains: Dictionary) -> String:
	var left_length: float = float(chains[SPAWN_CHAIN_LEFT]["total_length"])
	var right_length: float = float(chains[SPAWN_CHAIN_RIGHT]["total_length"])
	if left_length <= 0.0:
		return SPAWN_CHAIN_RIGHT
	if right_length <= 0.0:
		return SPAWN_CHAIN_LEFT
	return SPAWN_CHAIN_LEFT if randf() < 0.5 else SPAWN_CHAIN_RIGHT

func _sample_spawn_from_chain(chain: Dictionary, chain_side: String) -> Dictionary:
	var total_length: float = float(chain["total_length"])
	if total_length <= 0.0:
		var fallback_direction := _get_chain_target_direction(chain_side, 0.0)
		return {
			"spawn_center": Vector2(chain["start_point"]),
			"target_direction": fallback_direction,
			"target_angle": fallback_direction.angle(),
			"chain_progress": 0.0
		}

	var sample_distance: float = randf() * total_length
	return _sample_spawn_from_chain_distance(chain, chain_side, sample_distance)

func _sample_spawn_from_chain_distance(chain: Dictionary, chain_side: String, sample_distance: float) -> Dictionary:
	var total_length: float = float(chain["total_length"])
	var remaining_distance: float = clampf(sample_distance, 0.0, total_length)
	var segments: Array[Dictionary] = chain["segments"]
	for segment in segments:
		var segment_length: float = float(segment["length"])
		if remaining_distance > segment_length:
			remaining_distance -= segment_length
			continue

		var local_progress: float = 0.0
		if segment_length > 0.0:
			local_progress = remaining_distance / segment_length
		var point_from: Vector2 = segment["point_from"]
		var point_to: Vector2 = segment["point_to"]
		var spawn_center: Vector2 = point_from.lerp(point_to, local_progress)
		var chain_progress: float = (float(segment["offset"]) + remaining_distance) / maxf(total_length, 0.0001)
		var target_direction: Vector2 = _get_chain_target_direction(chain_side, chain_progress)
		return {
			"spawn_center": spawn_center,
			"target_direction": target_direction,
			"target_angle": target_direction.angle(),
			"chain_progress": chain_progress
		}

	var fallback_direction := _get_chain_target_direction(chain_side, 1.0)
	return {
		"spawn_center": Vector2(chain["end_point"]),
		"target_direction": fallback_direction,
		"target_angle": fallback_direction.angle(),
		"chain_progress": 1.0
	}

func _get_chain_target_direction(chain_side: String, chain_progress: float) -> Vector2:
	var clamped_progress: float = clampf(chain_progress, 0.0, 1.0)
	var target_angle: float = 0.0
	if chain_side == SPAWN_CHAIN_LEFT:
		target_angle = -PI * 0.5 - clamped_progress * PI
	else:
		target_angle = -PI * 0.5 + clamped_progress * PI
	return Vector2.RIGHT.rotated(target_angle)

func _get_tower_center() -> Vector2:
	var tower_rect: Rect2 = _tower_body.get_global_rect()
	return tower_rect.position + tower_rect.size * 0.5

func _on_spawned_enemy_exited(enemy_id: int) -> void:
	_active_enemies.erase(enemy_id)

func _build_default_waves() -> Array[EnemyWaveDefinition]:
	var normal: EnemySpawnOption = EnemySpawnOption.new()
	normal.enemy_scene = BASIC_ENEMY_SCENE
	normal.weight = 1.0

	var brute: EnemySpawnOption = EnemySpawnOption.new()
	brute.enemy_scene = BRUTE_ENEMY_SCENE
	brute.weight = 1.0

	var ranged: EnemySpawnOption = EnemySpawnOption.new()
	ranged.enemy_scene = RANGED_ENEMY_SCENE
	ranged.weight = 1.0

	var result: Array[EnemyWaveDefinition] = []

	var wave_1: EnemyWaveDefinition = EnemyWaveDefinition.new()
	wave_1.wave_name = "Opening"
	wave_1.duration_sec = 24.0
	wave_1.min_alive = 2
	wave_1.max_alive = 5
	wave_1.start_spawn_interval = 1.35
	wave_1.end_spawn_interval = 1.10
	wave_1.catchup_interval_multiplier = 0.45
	wave_1.spawn_options = [normal]
	result.append(wave_1)

	var wave_2: EnemyWaveDefinition = EnemyWaveDefinition.new()
	wave_2.wave_name = "Pressure"
	wave_2.duration_sec = 26.0
	wave_2.min_alive = 3
	wave_2.max_alive = 7
	wave_2.start_spawn_interval = 1.20
	wave_2.end_spawn_interval = 0.95
	wave_2.catchup_interval_multiplier = 0.42
	wave_2.spawn_options = [_clone_spawn_option(normal, 0.8), _clone_spawn_option(brute, 0.2)]
	result.append(wave_2)

	var wave_3: EnemyWaveDefinition = EnemyWaveDefinition.new()
	wave_3.wave_name = "Mix"
	wave_3.duration_sec = 30.0
	wave_3.min_alive = 4
	wave_3.max_alive = 9
	wave_3.start_spawn_interval = 1.05
	wave_3.end_spawn_interval = 0.82
	wave_3.catchup_interval_multiplier = 0.38
	wave_3.spawn_options = [
		_clone_spawn_option(normal, 0.58),
		_clone_spawn_option(brute, 0.24),
		_clone_spawn_option(ranged, 0.18)
	]
	result.append(wave_3)

	var wave_4: EnemyWaveDefinition = EnemyWaveDefinition.new()
	wave_4.wave_name = "Swarm"
	wave_4.duration_sec = 34.0
	wave_4.min_alive = 5
	wave_4.max_alive = 12
	wave_4.start_spawn_interval = 0.92
	wave_4.end_spawn_interval = 0.66
	wave_4.catchup_interval_multiplier = 0.34
	wave_4.spawn_options = [
		_clone_spawn_option(normal, 0.44),
		_clone_spawn_option(brute, 0.24),
		_clone_spawn_option(ranged, 0.32)
	]
	result.append(wave_4)

	var wave_5: EnemyWaveDefinition = EnemyWaveDefinition.new()
	wave_5.wave_name = "Endless"
	wave_5.duration_sec = -1.0
	wave_5.min_alive = 6
	wave_5.max_alive = -1
	wave_5.start_spawn_interval = 0.72
	wave_5.end_spawn_interval = 0.46
	wave_5.catchup_interval_multiplier = 0.30
	wave_5.spawn_options = [
		_clone_spawn_option(normal, 0.38),
		_clone_spawn_option(brute, 0.24),
		_clone_spawn_option(ranged, 0.38)
	]
	result.append(wave_5)

	return result

func _clone_spawn_option(source: EnemySpawnOption, weight: float) -> EnemySpawnOption:
	var option: EnemySpawnOption = EnemySpawnOption.new()
	option.enemy_scene = source.enemy_scene
	option.weight = weight
	return option

func _sync_waves_from_resources() -> void:
	if wave_set != null and not wave_set.waves.is_empty():
		waves = wave_set.waves.duplicate()

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_preview:
		return
	_resolve_scene_references()
	if _tower_body == null or _play_area == null:
		return

	var overlay_origin: Vector2 = get_global_rect().position
	var tower_center_global: Vector2 = _get_tower_center()
	var tower_center: Vector2 = tower_center_global - overlay_origin
	var spawn_rect_global: Rect2 = _get_spawn_rect()
	var spawn_rect: Rect2 = Rect2(spawn_rect_global.position - overlay_origin, spawn_rect_global.size)

	draw_rect(spawn_rect, Color(0.25, 0.9, 0.45, 0.04), false, 2.0)
	draw_arc(tower_center, default_ring_radius, 0.0, TAU, 96, Color(1.0, 0.55, 0.18, 0.85), 2.0)

	var banned_min_x: float = tower_center.x - top_bottom_banned_half_width
	var banned_max_x: float = tower_center.x + top_bottom_banned_half_width
	var top_y: float = spawn_rect.position.y
	var bottom_y: float = spawn_rect.position.y + spawn_rect.size.y
	draw_line(Vector2(banned_min_x, top_y), Vector2(banned_max_x, top_y), Color(0.95, 0.18, 0.18, 0.95), 4.0)
	draw_line(Vector2(banned_min_x, bottom_y), Vector2(banned_max_x, bottom_y), Color(0.95, 0.18, 0.18, 0.95), 4.0)

	var chains: Dictionary = _build_spawn_chains(spawn_rect_global)
	for chain in chains.values():
		var segments: Array[Dictionary] = chain["segments"]
		for segment in segments:
			draw_line(
				Vector2(segment["point_from"]) - overlay_origin,
				Vector2(segment["point_to"]) - overlay_origin,
				Color(0.3, 0.95, 0.45, 0.95),
				3.0
			)

	for chain_side in [SPAWN_CHAIN_LEFT, SPAWN_CHAIN_RIGHT]:
		var preview_distances: Array[float] = _build_chain_preview_distances(chains[chain_side])
		var used_keys: Dictionary = {}
		for sample_distance in preview_distances:
			var sample_key: int = int(round(sample_distance * 100.0))
			if used_keys.has(sample_key):
				continue
			used_keys[sample_key] = true
			var sample: Dictionary = _sample_spawn_from_chain_distance(chains[chain_side], chain_side, sample_distance)
			var spawn_center_global: Vector2 = sample["spawn_center"]
			var target_direction: Vector2 = sample["target_direction"]
			var target_center_global: Vector2 = tower_center_global + target_direction * default_ring_radius
			var spawn_center: Vector2 = spawn_center_global - overlay_origin
			var target_center: Vector2 = target_center_global - overlay_origin
			draw_line(spawn_center, target_center, Color(1.0, 0.9, 0.2, 0.95), 2.0)
			draw_circle(spawn_center, 4.0, Color(1.0, 0.95, 0.45, 0.95))
			draw_circle(target_center, 3.0, Color(1.0, 0.78, 0.25, 0.95))

func _build_chain_preview_distances(chain: Dictionary) -> Array[float]:
	var distances: Array[float] = []
	var total_length: float = float(chain["total_length"])
	if total_length <= 0.0:
		return distances

	var inset_distance: float = boundary_preview_inset
	var step_distance: float = maxf(preview_step_degrees, 1.0)
	for index in range(boundary_preview_count):
		var local_distance: float = inset_distance + float(index) * step_distance
		local_distance = minf(local_distance, total_length)
		distances.append(local_distance)
		distances.append(maxf(total_length - local_distance, 0.0))

	var guide_angle_step: float = deg_to_rad(maxf(preview_step_degrees, 1.0))
	var guide_count: int = int(floor(PI / guide_angle_step))
	for index in range(guide_count + 1):
		var chain_progress: float = float(index) / float(max(guide_count, 1))
		distances.append(chain_progress * total_length)

	return distances

func _resolve_scene_references() -> void:
	if _play_area == null and not play_area_path.is_empty():
		_play_area = get_node_or_null(play_area_path) as Control
	if _tower_body == null and not tower_body_path.is_empty():
		_tower_body = get_node_or_null(tower_body_path) as Control
	if _tower_health == null and not tower_health_path.is_empty():
		_tower_health = get_node_or_null(tower_health_path) as HealthController
	if _enemy_layer == null and not enemy_layer_path.is_empty():
		_enemy_layer = get_node_or_null(enemy_layer_path) as Control
	if _effect_layer == null and not effect_layer_path.is_empty():
		_effect_layer = get_node_or_null(effect_layer_path) as Control

func _get_play_area_global_rect() -> Rect2:
	if _play_area != null:
		return _play_area.get_global_rect()
	return get_global_rect()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_INTERNAL_PROCESS:
			if Engine.is_editor_hint() and show_editor_preview:
				_request_preview_redraw()
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED:
			if Engine.is_editor_hint() and show_editor_preview:
				_request_preview_redraw()

func _request_preview_redraw() -> void:
	if is_inside_tree():
		queue_redraw()
