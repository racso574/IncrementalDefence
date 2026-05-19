extends Node
class_name PlayerVisualRuntime

const RuntimeVisualFactoryScript = preload("res://Scripts/Gameplay/Visuals/RuntimeVisualFactory.gd")

var _effect_layer: Control
var _visual_factory: RuntimeVisualFactoryScript
var _blade_host: Control
var _blade_nodes: Array[Panel] = []
var _tower_aura_visual: Panel
var _flamethrower_visual: Polygon2D

func setup(effect_layer: Control, visual_factory: RuntimeVisualFactoryScript) -> void:
	_effect_layer = effect_layer
	_visual_factory = visual_factory
	if _effect_layer == null or _visual_factory == null:
		return
	if _blade_host == null:
		_blade_host = Control.new()
		_blade_host.name = "BladeHost"
		_blade_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blade_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_effect_layer.add_child(_blade_host)

func release_runtime_node(node: Node) -> void:
	if _visual_factory != null:
		_visual_factory.release_node(node)
	elif node != null and is_instance_valid(node):
		node.queue_free()

func register_tween(node: Node, tween: Tween) -> void:
	if _visual_factory != null:
		_visual_factory.register_tween(node, tween)

func sync_tower_aura(center: Vector2, radius: float, enabled: bool) -> void:
	if not enabled:
		if _tower_aura_visual != null:
			_tower_aura_visual.visible = false
		return

	if _tower_aura_visual == null:
		_tower_aura_visual = _visual_factory.acquire_circle_panel(
			"player_tower_aura",
			radius,
			Color(1.0, 0.5, 0.28, 0.12),
			Color(1.0, 0.72, 0.46, 0.9),
			2
		)
	else:
		_visual_factory.configure_circle_panel(
			_tower_aura_visual,
			radius,
			Color(1.0, 0.5, 0.28, 0.12),
			Color(1.0, 0.72, 0.46, 0.9),
			2
		)
	_tower_aura_visual.global_position = center - _tower_aura_visual.size * 0.5
	_tower_aura_visual.visible = true

func sync_flamethrower(center: Vector2, direction: Vector2, is_active: bool, range_value: float, half_width: float, alpha: float) -> void:
	if _flamethrower_visual == null:
		_flamethrower_visual = Polygon2D.new()
		_flamethrower_visual.color = Color(1.0, 0.52, 0.18, alpha)
		_effect_layer.add_child(_flamethrower_visual)

	if not is_active:
		_flamethrower_visual.visible = false
		return

	_flamethrower_visual.color = Color(1.0, 0.52, 0.18, alpha)
	_flamethrower_visual.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(range_value, -half_width),
		Vector2(range_value, half_width)
	])
	_flamethrower_visual.global_position = center
	_flamethrower_visual.rotation = direction.angle()
	_flamethrower_visual.visible = true

func sync_blades(blade_centers: Array[Vector2], blade_angles: Array[float], blade_size: Vector2, enabled: bool) -> void:
	if not enabled or blade_centers.is_empty():
		clear_blades()
		return

	while _blade_nodes.size() > blade_centers.size():
		var blade_to_release: Panel = _blade_nodes.pop_back()
		release_runtime_node(blade_to_release)

	while _blade_nodes.size() < blade_centers.size():
		var blade := _visual_factory.acquire_panel(
			"player_blade",
			blade_size,
			Color(0.95, 0.95, 0.98, 0.96),
			Color(0.56, 0.66, 0.78, 0.9),
			1,
			3,
			_blade_host
		)
		_blade_nodes.append(blade)

	for i in range(blade_centers.size()):
		var blade: Panel = _blade_nodes[i]
		_visual_factory.configure_panel(
			blade,
			blade_size,
			Color(0.95, 0.95, 0.98, 0.96),
			Color(0.56, 0.66, 0.78, 0.9),
			1,
			3
		)
		blade.rotation = blade_angles[i]
		blade.global_position = blade_centers[i] - blade.size * 0.5

func clear_blades() -> void:
	for blade in _blade_nodes:
		if is_instance_valid(blade):
			release_runtime_node(blade)
	_blade_nodes.clear()

func spawn_projectile(origin: Vector2, radius: float) -> Panel:
	var node := _visual_factory.acquire_circle_panel(
		"player_projectile",
		radius,
		Color(1.0, 0.88, 0.44, 0.96),
		Color(1.0, 0.62, 0.18, 0.96),
		1
	)
	node.global_position = origin - node.size * 0.5
	return node

func spawn_boomerang(origin: Vector2, radius: float) -> Panel:
	var node := _visual_factory.acquire_capsule_panel(
		"player_boomerang",
		Vector2(radius * 2.6, radius * 1.05),
		Color(0.93, 0.93, 0.98, 0.98),
		Color(0.58, 0.68, 0.82, 0.92),
		1
	)
	node.global_position = origin - node.size * 0.5
	return node

func spawn_chain_arrow(origin: Vector2, radius: float) -> ColorRect:
	var node := _visual_factory.acquire_color_rect(
		"player_chain_arrow",
		Vector2(radius * 2.8, radius * 0.6),
		Color(0.96, 0.85, 0.56, 0.94),
		Vector2(0.0, radius * 0.3),
		true
	)
	node.global_position = origin - node.pivot_offset
	return node

func spawn_ricochet(origin: Vector2, radius: float) -> Panel:
	var node := _visual_factory.acquire_circle_panel(
		"player_ricochet",
		radius,
		Color(0.78, 0.96, 1.0, 0.94),
		Color(0.42, 0.7, 0.96, 0.92),
		1
	)
	node.global_position = origin - node.size * 0.5
	return node

func spawn_snowball_projectile(origin: Vector2) -> Panel:
	var projectile := _visual_factory.acquire_panel(
		"player_snowball_projectile",
		Vector2(18.0, 18.0),
		Color(0.86, 0.95, 1.0, 0.98),
		Color.TRANSPARENT,
		0,
		24
	)
	projectile.global_position = origin - projectile.size * 0.5
	projectile.scale = Vector2(0.62, 0.62)
	return projectile

func spawn_slow_field(center: Vector2, radius: float) -> Panel:
	var field := _visual_factory.acquire_circle_panel(
		"player_snowball_field",
		radius,
		Color(0.53, 0.82, 1.0, 0.28),
		Color(0.88, 0.97, 1.0, 0.7),
		2
	)
	field.global_position = center - field.size * 0.5
	return field

func spawn_acid_drop(target_position: Vector2) -> ColorRect:
	var drop := _visual_factory.acquire_color_rect(
		"player_acid_drop",
		Vector2(10.0, 28.0),
		Color(0.62, 1.0, 0.56, 0.92)
	)
	drop.global_position = Vector2(target_position.x - drop.size.x * 0.5, -drop.size.y)
	return drop

func spawn_acid_puddle(center: Vector2, radius: float) -> Panel:
	var puddle := _visual_factory.acquire_circle_panel(
		"player_acid_puddle",
		radius,
		Color(0.54, 0.96, 0.52, 0.18),
		Color(0.78, 1.0, 0.76, 0.82),
		2
	)
	puddle.global_position = center - puddle.size * 0.5
	return puddle

func spawn_laser(origin: Vector2, range_value: float, width: float, direction: Vector2) -> ColorRect:
	var beam := _visual_factory.acquire_color_rect(
		"player_laser_beam",
		Vector2(range_value, width),
		Color(1.0, 0.34, 0.22, 0.78),
		Vector2(0.0, width * 0.5),
		true
	)
	beam.global_position = origin - beam.pivot_offset
	beam.rotation = direction.angle()
	return beam

func spawn_map_clear_wipe() -> ColorRect:
	var wipe := _visual_factory.acquire_color_rect(
		"player_map_clear_wipe",
		Vector2.ZERO,
		Color(1.0, 0.96, 0.92, 0.28),
		Vector2.ZERO,
		true
	)
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return wipe

func spawn_click_feedback(screen_position: Vector2, hit_target: bool, duration: float) -> void:
	var marker := _visual_factory.acquire_panel(
		"feedback_click_marker",
		Vector2(22.0, 22.0),
		Color(1.0, 0.93, 0.75, 0.95) if hit_target else Color(1.0, 1.0, 1.0, 0.7),
		Color(1.0, 0.4, 0.28, 1.0) if hit_target else Color(0.15, 0.18, 0.18, 0.9),
		2,
		32
	)
	marker.global_position = screen_position - marker.size * 0.5

	var tween := create_tween()
	tween.parallel().tween_property(marker, "scale", Vector2(1.6, 1.6), duration)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "release_runtime_node").bind(marker))
	_visual_factory.register_tween(marker, tween)

func spawn_lightning_feedback(screen_position: Vector2, hit_target: bool) -> void:
	var beam := _visual_factory.acquire_color_rect(
		"feedback_lightning_beam",
		Vector2(8.0, screen_position.y + 12.0),
		Color(1.0, 0.95, 0.64, 0.92) if hit_target else Color(0.92, 0.96, 1.0, 0.78),
		Vector2(4.0, 0.0),
		true
	)
	beam.global_position = Vector2(screen_position.x - 4.0, -12.0)

	var ring := _visual_factory.acquire_panel(
		"feedback_lightning_ring",
		Vector2(34.0, 34.0),
		Color(1.0, 0.95, 0.64, 0.22) if hit_target else Color(0.88, 0.95, 1.0, 0.18),
		Color(1.0, 0.83, 0.31, 0.95),
		2,
		40
	)
	ring.global_position = screen_position - ring.size * 0.5

	var beam_tween := create_tween()
	beam_tween.tween_property(beam, "modulate:a", 0.0, 0.16)
	beam_tween.tween_callback(Callable(self, "release_runtime_node").bind(beam))
	_visual_factory.register_tween(beam, beam_tween)

	var ring_tween := create_tween()
	ring_tween.parallel().tween_property(ring, "scale", Vector2(1.5, 1.5), 0.18)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	ring_tween.tween_callback(Callable(self, "release_runtime_node").bind(ring))
	_visual_factory.register_tween(ring, ring_tween)

func spawn_snowball_impact_feedback(screen_position: Vector2) -> void:
	var burst := _visual_factory.acquire_panel(
		"feedback_snowball_burst",
		Vector2(42.0, 42.0),
		Color(0.82, 0.94, 1.0, 0.28),
		Color(0.95, 0.99, 1.0, 0.92),
		2,
		42
	)
	burst.global_position = screen_position - burst.size * 0.5

	var tween := create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.8, 1.8), 0.24)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(self, "release_runtime_node").bind(burst))
	_visual_factory.register_tween(burst, tween)

func spawn_blade_hit_feedback(screen_position: Vector2) -> void:
	var spark := _visual_factory.acquire_panel(
		"feedback_blade_hit",
		Vector2(16.0, 16.0),
		Color(0.94, 0.97, 1.0, 0.78),
		Color.TRANSPARENT,
		0,
		20
	)
	spark.global_position = screen_position - spark.size * 0.5

	var tween := create_tween()
	tween.parallel().tween_property(spark, "scale", Vector2(1.4, 1.4), 0.14)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(self, "release_runtime_node").bind(spark))
	_visual_factory.register_tween(spark, tween)

func spawn_projectile_hit_feedback(screen_position: Vector2, fill_color: Color) -> void:
	var spark := _visual_factory.acquire_panel(
		"feedback_projectile_hit",
		Vector2(18.0, 18.0),
		fill_color,
		Color.TRANSPARENT,
		0,
		20
	)
	spark.global_position = screen_position - spark.size * 0.5

	var tween := create_tween()
	tween.parallel().tween_property(spark, "scale", Vector2(1.55, 1.55), 0.16)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(self, "release_runtime_node").bind(spark))
	_visual_factory.register_tween(spark, tween)

func spawn_chain_hit_feedback(screen_position: Vector2) -> void:
	var ring := _visual_factory.acquire_panel(
		"feedback_chain_hit",
		Vector2(26.0, 26.0),
		Color(1.0, 0.9, 0.58, 0.18),
		Color(1.0, 0.85, 0.58, 0.92),
		2,
		32
	)
	ring.global_position = screen_position - ring.size * 0.5

	var tween := create_tween()
	tween.parallel().tween_property(ring, "scale", Vector2(1.7, 1.7), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(self, "release_runtime_node").bind(ring))
	_visual_factory.register_tween(ring, tween)
