extends Node
class_name EnemyTracker

var max_active_enemy_cap: int = -1
var wave_active_enemy_cap: int = -1
var _active_enemies: Dictionary = {}
var _cache_frame: int = -1
var _cached_live_enemies: Array[GameTestEnemy] = []
var _cached_visible_enemies: Array[GameTestEnemy] = []
var _enemy_rect_cache: Dictionary = {}
var _enemy_center_cache: Dictionary = {}
var _enemy_radius_cache: Dictionary = {}
var _enemy_visible_cache: Dictionary = {}

func clear() -> void:
	_active_enemies.clear()
	_invalidate_cache()

func register_enemy(enemy: GameTestEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_defeated():
		return
	_active_enemies[enemy.get_instance_id()] = enemy
	_invalidate_cache()

func unregister_enemy(enemy: GameTestEnemy) -> void:
	if enemy == null:
		return
	_active_enemies.erase(enemy.get_instance_id())
	_invalidate_cache()

func get_live_enemies(only_visible: bool = false) -> Array[GameTestEnemy]:
	_ensure_frame_cache()
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	var result: Array[GameTestEnemy] = []
	result.append_array(source)
	return result

func get_live_enemy_count(only_visible: bool = false) -> int:
	_ensure_frame_cache()
	return _cached_visible_enemies.size() if only_visible else _cached_live_enemies.size()

func is_at_capacity() -> bool:
	if max_active_enemy_cap < 0:
		return false
	return get_live_enemy_count() >= max_active_enemy_cap

func is_at_wave_capacity() -> bool:
	if wave_active_enemy_cap < 0:
		return false
	return get_live_enemy_count() >= wave_active_enemy_cap

func can_spawn_more() -> bool:
	return not is_at_capacity() and not is_at_wave_capacity()

func find_enemy_at_position(screen_position: Vector2) -> GameTestEnemy:
	_ensure_frame_cache()
	var best_enemy: GameTestEnemy
	var highest_index: int = -1
	for enemy in _cached_live_enemies:
		if not _get_cached_rect(enemy).has_point(screen_position):
			continue
		if enemy.get_index() >= highest_index:
			highest_index = enemy.get_index()
			best_enemy = enemy
	return best_enemy

func find_nearest_enemy_to_position(screen_position: Vector2, radius: float = INF, excluded_ids: Dictionary = {}, only_visible: bool = false) -> GameTestEnemy:
	_ensure_frame_cache()
	var best_enemy: GameTestEnemy
	var best_distance: float = radius
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	for enemy in source:
		var enemy_id: int = enemy.get_instance_id()
		if excluded_ids.has(enemy_id):
			continue
		var distance: float = get_enemy_center(enemy).distance_to(screen_position)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	return best_enemy

func find_enemy_colliding(screen_position: Vector2, radius: float, only_visible: bool = false) -> GameTestEnemy:
	_ensure_frame_cache()
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	for enemy in source:
		if get_enemy_center(enemy).distance_to(screen_position) <= radius + get_enemy_radius(enemy):
			return enemy
	return null

func get_enemies_in_radius(screen_position: Vector2, radius: float, only_visible: bool = false) -> Array[GameTestEnemy]:
	_ensure_frame_cache()
	var hits: Array[GameTestEnemy] = []
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	for enemy in source:
		if get_enemy_center(enemy).distance_to(screen_position) <= radius + get_enemy_radius(enemy):
			hits.append(enemy)
	return hits

func get_enemies_along_segment(start: Vector2, end: Vector2, radius: float, only_visible: bool = false) -> Array[GameTestEnemy]:
	_ensure_frame_cache()
	var hits: Array[GameTestEnemy] = []
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	for enemy in source:
		var enemy_center: Vector2 = get_enemy_center(enemy)
		if _distance_to_segment(enemy_center, start, end) <= radius + get_enemy_radius(enemy):
			hits.append(enemy)
	return hits

func get_enemies_in_cone(origin: Vector2, direction: Vector2, distance: float, half_width: float, only_visible: bool = false) -> Array[GameTestEnemy]:
	_ensure_frame_cache()
	var hits: Array[GameTestEnemy] = []
	var normal := Vector2(-direction.y, direction.x)
	var cone_points := PackedVector2Array([
		origin,
		origin + direction * distance + normal * half_width,
		origin + direction * distance - normal * half_width
	])
	var source: Array[GameTestEnemy] = _cached_visible_enemies if only_visible else _cached_live_enemies
	for enemy in source:
		if Geometry2D.is_point_in_polygon(get_enemy_center(enemy), cone_points):
			hits.append(enemy)
	return hits

func get_enemy_center(enemy: GameTestEnemy) -> Vector2:
	_ensure_frame_cache()
	var enemy_id: int = enemy.get_instance_id()
	if _enemy_center_cache.has(enemy_id):
		return _enemy_center_cache[enemy_id]
	var rect: Rect2 = enemy.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5
	_enemy_rect_cache[enemy_id] = rect
	_enemy_center_cache[enemy_id] = center
	_enemy_radius_cache[enemy_id] = minf(rect.size.x, rect.size.y) * 0.33
	_enemy_visible_cache[enemy_id] = _get_viewport_visible_rect().intersects(rect)
	return center

func get_enemy_radius(enemy: GameTestEnemy) -> float:
	_ensure_frame_cache()
	var enemy_id: int = enemy.get_instance_id()
	if _enemy_radius_cache.has(enemy_id):
		return _enemy_radius_cache[enemy_id]
	_get_cached_rect(enemy)
	return float(_enemy_radius_cache.get(enemy_id, 0.0))

func is_enemy_visible(enemy: GameTestEnemy) -> bool:
	_ensure_frame_cache()
	var enemy_id: int = enemy.get_instance_id()
	if _enemy_visible_cache.has(enemy_id):
		return bool(_enemy_visible_cache[enemy_id])
	_get_cached_rect(enemy)
	return bool(_enemy_visible_cache.get(enemy_id, false))

func _ensure_frame_cache() -> void:
	var current_frame: int = Engine.get_process_frames()
	if _cache_frame == current_frame:
		return

	_cache_frame = current_frame
	_cached_live_enemies.clear()
	_cached_visible_enemies.clear()
	_enemy_rect_cache.clear()
	_enemy_center_cache.clear()
	_enemy_radius_cache.clear()
	_enemy_visible_cache.clear()

	var stale_ids: Array[int] = []
	var viewport_rect: Rect2 = _get_viewport_visible_rect()
	for enemy_id_ref in _active_enemies.keys():
		var enemy_id: int = int(enemy_id_ref)
		var enemy_ref: Variant = _active_enemies[enemy_id]
		if enemy_ref == null or not is_instance_valid(enemy_ref):
			stale_ids.append(enemy_id)
			continue
		var enemy: GameTestEnemy = enemy_ref as GameTestEnemy
		if enemy == null or enemy.is_defeated():
			stale_ids.append(enemy_id)
			continue

		var rect: Rect2 = enemy.get_global_rect()
		var center: Vector2 = rect.position + rect.size * 0.5
		var radius: float = minf(rect.size.x, rect.size.y) * 0.33
		var is_visible: bool = viewport_rect.intersects(rect)

		_enemy_rect_cache[enemy_id] = rect
		_enemy_center_cache[enemy_id] = center
		_enemy_radius_cache[enemy_id] = radius
		_enemy_visible_cache[enemy_id] = is_visible
		_cached_live_enemies.append(enemy)
		if is_visible:
			_cached_visible_enemies.append(enemy)

	for enemy_id in stale_ids:
		_active_enemies.erase(enemy_id)

func _invalidate_cache() -> void:
	_cache_frame = -1
	_cached_live_enemies.clear()
	_cached_visible_enemies.clear()
	_enemy_rect_cache.clear()
	_enemy_center_cache.clear()
	_enemy_radius_cache.clear()
	_enemy_visible_cache.clear()

func _get_cached_rect(enemy: GameTestEnemy) -> Rect2:
	var enemy_id: int = enemy.get_instance_id()
	if _enemy_rect_cache.has(enemy_id):
		return _enemy_rect_cache[enemy_id]
	var rect: Rect2 = enemy.get_global_rect()
	_enemy_rect_cache[enemy_id] = rect
	_enemy_center_cache[enemy_id] = rect.position + rect.size * 0.5
	_enemy_radius_cache[enemy_id] = minf(rect.size.x, rect.size.y) * 0.33
	_enemy_visible_cache[enemy_id] = _get_viewport_visible_rect().intersects(rect)
	return rect

func _get_viewport_visible_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	return viewport.get_visible_rect()

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(segment_start)
	var progress := clampf((point - segment_start).dot(segment) / length_sq, 0.0, 1.0)
	var closest_point := segment_start + segment * progress
	return point.distance_to(closest_point)
