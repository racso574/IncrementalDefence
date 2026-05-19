extends Control

const EnemyTrackerScript = preload("res://Scripts/Gameplay/EnemyTracker.gd")
const RuntimeScenePoolScript = preload("res://Scripts/Gameplay/Pooling/RuntimeScenePool.gd")
const RuntimeNodePoolScript = preload("res://Scripts/Gameplay/Pooling/RuntimeNodePool.gd")
const RuntimeVisualFactoryScript = preload("res://Scripts/Gameplay/Visuals/RuntimeVisualFactory.gd")
const PlayerVisualRuntimeScript = preload("res://Scripts/Gameplay/Visuals/PlayerVisualRuntime.gd")

const LIGHTNING_STRIKE_RADIUS: float = 28.0
const LIGHTNING_STRIKE_STAGGER: float = 0.08
const SNOWBALL_PROJECTILE_DURATION: float = 0.4
const SNOWBALL_IMPACT_RADIUS: float = 28.0
const SNOWBALL_FIELD_TICK: float = 0.15
const BLADE_DAMAGE_INTERVAL: float = 0.35
const PROJECTILE_HIT_INTERVAL: float = 0.12
const RICOCHET_HIT_INTERVAL: float = 0.14
const BOOMERANG_RETURN_THRESHOLD: float = 18.0
const ACID_DROP_FALL_DURATION: float = 0.26
const LASER_BEAM_OVERSCAN: float = 18.0
const FLAMETHROWER_VISUAL_ALPHA: float = 0.28

@export var starting_gold: int = 250
@export var default_player_attack_cooldown: float = 0.5
@export var default_player_damage: int = 1
@export var click_feedback_duration: float = 0.16
@export_range(1, 5000, 1, "or_greater") var max_active_enemy_cap: int = 500

@onready var tower_health: HealthController = $TowerAnchor/TowerWrap/TowerBody/HealthController
@onready var tower_body: Panel = $TowerAnchor/TowerWrap/TowerBody
@onready var tower_damage_flash: ColorRect = $TowerAnchor/TowerWrap/TowerBody/DamageFlash
@onready var enemy_wave_spawner: EnemyWaveSpawner = $EnemyWaveSpawner
@onready var enemy_layer: Control = $EnemyLayer
@onready var effect_layer: Control = $EffectLayer
@onready var top_right_hud: Panel = $TopRightHud
@onready var survived_time_label: Label = $TopRightHud/TimeLabel
@onready var end_run_button: Button = $BottomRightHud/EndRunButton

var _run_state: Dictionary = {}
var _timers: Dictionary = {}
var _blade_rotation: float = 0.0
var _is_game_over: bool = false
var _survived_time_sec: float = 0.0
var _peak_active_enemy_count: int = 0
var _peak_visible_enemy_count: int = 0

var _blade_hit_cooldowns: Dictionary = {}
var _active_slow_fields: Array = []
var _active_projectiles: Array = []
var _active_boomerangs: Array = []
var _active_chain_arrows: Array = []
var _active_acid_puddles: Array = []
var _active_lasers: Array = []
var _active_ricochets: Array = []

var _enemy_tracker: EnemyTrackerScript
var _runtime_scene_pool: RuntimeScenePoolScript
var _runtime_node_pool: RuntimeNodePoolScript
var _runtime_visual_factory: RuntimeVisualFactoryScript
var _player_visual_runtime: PlayerVisualRuntimeScript

func _ready() -> void:
	randomize()
	_enemy_tracker = EnemyTrackerScript.new()
	_enemy_tracker.name = "EnemyTracker"
	_enemy_tracker.max_active_enemy_cap = max_active_enemy_cap
	add_child(_enemy_tracker)

	_runtime_scene_pool = RuntimeScenePoolScript.new()
	_runtime_scene_pool.name = "RuntimeScenePool"
	add_child(_runtime_scene_pool)

	_runtime_node_pool = RuntimeNodePoolScript.new()
	_runtime_node_pool.name = "RuntimeNodePool"
	add_child(_runtime_node_pool)

	_runtime_visual_factory = RuntimeVisualFactoryScript.new()
	_runtime_visual_factory.name = "RuntimeVisualFactory"
	add_child(_runtime_visual_factory)
	_runtime_visual_factory.setup(effect_layer, _runtime_node_pool)

	_player_visual_runtime = PlayerVisualRuntimeScript.new()
	_player_visual_runtime.name = "PlayerVisualRuntime"
	add_child(_player_visual_runtime)
	_player_visual_runtime.setup(effect_layer, _runtime_visual_factory)

	_run_state = PlayerAbilityConfig.merge_run_state(
		ScenesManager.consume_payload(),
		starting_gold,
		default_player_damage,
		default_player_attack_cooldown
	)
	_survived_time_sec = _stat_float("elapsed_time_sec")
	CurrencySystem.set_amount("gold", _stat_int("gold", starting_gold))
	_reset_timers()

	tower_health.damaged.connect(_on_tower_damaged)
	tower_health.died.connect(_on_tower_died)
	end_run_button.pressed.connect(_on_end_run_pressed)
	enemy_wave_spawner.enemy_spawned.connect(_on_enemy_spawned)
	enemy_wave_spawner.set_runtime_services(_enemy_tracker, _runtime_scene_pool, _runtime_visual_factory)
	enemy_wave_spawner.reset_spawner()
	enemy_wave_spawner.start_spawning()

	top_right_hud.custom_minimum_size = Vector2(220.0, 108.0)
	top_right_hud.offset_bottom = 130.0
	survived_time_label.offset_bottom = -8.0
	survived_time_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	survived_time_label.add_theme_font_size_override("font_size", 18)

	tower_damage_flash.modulate.a = 0.0
	_update_survived_time_label()
	_refresh_blades()
	_sync_tower_aura_visual()
	_sync_flamethrower_visual(Vector2.ZERO, false)

func _process(delta: float) -> void:
	if _is_game_over:
		return

	_survived_time_sec += delta
	_update_survived_time_label()

	_update_basic_attack(delta)
	_update_lightning(delta)
	_update_snowball(delta)
	_update_slow_fields(delta)
	_update_blades(delta)
	_update_projectile_weapon(delta)
	_update_active_projectiles(delta)
	_update_boomerang_weapon(delta)
	_update_active_boomerangs(delta)
	_update_chain_arrow_weapon(delta)
	_update_active_chain_arrows(delta)
	_update_tower_aura(delta)
	_update_acid_rain(delta)
	_update_acid_puddles(delta)
	_update_laser(delta)
	_update_active_lasers(delta)
	_update_map_clear(delta)
	_update_flamethrower(delta)
	_update_ricochet_weapon(delta)
	_update_active_ricochets(delta)

func _reset_timers() -> void:
	_timers = {
		"tick": _stat_float("player_attack_cooldown", default_player_attack_cooldown),
		"lightning": _stat_float("lightning_cooldown", 2.4),
		"snowball": _stat_float("snowball_cooldown", 3.1),
		"projectile": _stat_float("projectile_cooldown", 1.0),
		"boomerang": _stat_float("boomerang_cooldown", 1.8),
		"chain_arrow": _stat_float("chain_arrow_cooldown", 2.0),
		"tower_aura": 0.0,
		"acid_rain": _stat_float("acid_rain_cooldown", 4.0),
		"laser": _stat_float("laser_cooldown", 6.0),
		"map_clear": _stat_float("map_clear_cooldown", 16.0),
		"flamethrower": 0.0,
		"ricochet": _stat_float("ricochet_cooldown", 1.7)
	}

func _stat_bool(key: String, fallback: bool = false) -> bool:
	return bool(_run_state.get(key, fallback))

func _stat_int(key: String, fallback: int = 0) -> int:
	return int(_run_state.get(key, fallback))

func _stat_float(key: String, fallback: float = 0.0) -> float:
	return float(_run_state.get(key, fallback))

func _get_valid_enemy_ref(data: Dictionary, key: String) -> GameTestEnemy:
	var enemy_ref: Variant = data.get(key, null)
	if enemy_ref == null:
		return null
	if not is_instance_valid(enemy_ref):
		return null
	var enemy: GameTestEnemy = enemy_ref as GameTestEnemy
	if enemy == null or enemy.is_defeated():
		return null
	return enemy

func _tick_timer(key: String, delta: float) -> bool:
	var remaining := maxf(float(_timers.get(key, 0.0)) - delta, 0.0)
	_timers[key] = remaining
	return remaining <= 0.0

func _set_timer(key: String, value: float) -> void:
	_timers[key] = maxf(value, 0.0)

func _update_basic_attack(delta: float) -> void:
	if not _tick_timer("tick", delta):
		return
	_set_timer("tick", _stat_float("player_attack_cooldown", default_player_attack_cooldown))
	_perform_player_attack()

func _update_lightning(delta: float) -> void:
	if not _stat_bool("lightning_unlocked"):
		return
	if not _tick_timer("lightning", delta):
		return
	_set_timer("lightning", _stat_float("lightning_cooldown", 2.4))
	_trigger_lightning_burst()

func _update_snowball(delta: float) -> void:
	if not _stat_bool("snowball_unlocked"):
		return
	if not _tick_timer("snowball", delta):
		return
	_set_timer("snowball", _stat_float("snowball_cooldown", 3.1))
	_trigger_snowball()

func _update_slow_fields(delta: float) -> void:
	for i in range(_active_slow_fields.size() - 1, -1, -1):
		var field: Dictionary = _active_slow_fields[i]
		field["remaining"] = float(field.get("remaining", 0.0)) - delta
		field["tick_remaining"] = float(field.get("tick_remaining", 0.0)) - delta

		var field_node := field.get("node", null) as CanvasItem
		if field_node != null:
			field_node.modulate.a = clampf(float(field.get("remaining", 0.0)) / maxf(_stat_float("snowball_field_duration", 1.8), 0.01), 0.15, 0.55)

		if float(field.get("tick_remaining", 0.0)) <= 0.0:
			field["tick_remaining"] = SNOWBALL_FIELD_TICK
			_apply_slow_field(field)

		if float(field.get("remaining", 0.0)) <= 0.0:
			if field_node != null:
				_cleanup_runtime_node(field_node)
			_active_slow_fields.remove_at(i)
		else:
			_active_slow_fields[i] = field

func _update_blades(delta: float) -> void:
	if not _stat_bool("blades_unlocked"):
		_clear_blades()
		return

	_blade_rotation += _stat_float("blade_rotation_speed", 2.6) * delta
	_refresh_blades()

	var mouse_position := get_global_mouse_position()
	var blade_count: int = _stat_int("blade_count", 3)

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

		for i in range(blade_count):
			var angle := _blade_rotation + TAU * float(i) / float(max(blade_count, 1))
			var blade_center := mouse_position + Vector2.RIGHT.rotated(angle) * _stat_float("blade_orbit_radius", 72.0)
			var hit_radius := _stat_float("blade_size", 18.0) * 0.55 + enemy_radius
			if blade_center.distance_to(enemy_center) <= hit_radius:
				enemy.receive_player_damage(_stat_int("blade_damage", 1))
				_spawn_blade_hit_feedback(blade_center)
				_blade_hit_cooldowns[enemy_id] = BLADE_DAMAGE_INTERVAL
				break

func _perform_player_attack() -> void:
	var mouse_position := get_global_mouse_position()
	var hit_enemy := _find_enemy_at_position(mouse_position)
	if hit_enemy != null:
		hit_enemy.receive_player_damage(_stat_int("player_damage", default_player_damage))
		_spawn_click_feedback(mouse_position, true)
	else:
		_spawn_click_feedback(mouse_position, false)

func _update_projectile_weapon(delta: float) -> void:
	if not _stat_bool("projectile_unlocked"):
		return
	if not _tick_timer("projectile", delta):
		return
	_set_timer("projectile", _stat_float("projectile_cooldown", 1.0))
	_spawn_projectile()

func _spawn_projectile() -> void:
	var origin := _get_tower_center()
	var target_mode := _stat_int("projectile_target_mode", PlayerAbilityConfig.TargetMode.MOUSE)
	var target_enemy: GameTestEnemy
	var direction := Vector2.UP
	if target_mode == PlayerAbilityConfig.TargetMode.NEAREST_ENEMY:
		target_enemy = _find_nearest_enemy_to_position(origin, INF, {}, true)
		if target_enemy == null:
			return
		direction = (_get_enemy_center(target_enemy) - origin).normalized()
	else:
		direction = (get_global_mouse_position() - origin).normalized()
	if direction == Vector2.ZERO:
		return

	var radius := _stat_float("projectile_radius", 9.0)
	var node := _player_visual_runtime.spawn_projectile(origin, radius)

	_active_projectiles.append({
		"node": node,
		"position": origin,
		"direction": direction,
		"speed": _stat_float("projectile_speed", 580.0),
		"damage": _stat_int("projectile_damage", 3),
		"radius": radius,
		"remaining_pierces": _stat_int("projectile_piercing", 1),
		"hit_ids": {},
		"mode": target_mode,
		"target_enemy": target_enemy,
		"remaining": 2.4
	})

func _update_active_projectiles(delta: float) -> void:
	for i in range(_active_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _active_projectiles[i]
		projectile["remaining"] = float(projectile.get("remaining", 0.0)) - delta
		var position: Vector2 = projectile.get("position", Vector2.ZERO)
		var direction: Vector2 = projectile.get("direction", Vector2.UP)

		position += direction * float(projectile.get("speed", 0.0)) * delta
		projectile["position"] = position

		var node := projectile.get("node", null) as Control
		if node != null:
			node.global_position = position - node.size * 0.5
			node.rotation = direction.angle()

		if float(projectile.get("remaining", 0.0)) <= 0.0 or _is_outside_play_bounds(position, 64.0):
			_cleanup_runtime_node(node)
			_active_projectiles.remove_at(i)
			continue

		var hit_ids: Dictionary = projectile.get("hit_ids", {})
		var remaining_pierces: int = int(projectile.get("remaining_pierces", 1))
		var did_hit: bool = false
		for enemy in _get_enemies_in_radius(position, float(projectile.get("radius", 0.0))):
			var enemy_id := enemy.get_instance_id()
			if hit_ids.has(enemy_id):
				continue
			hit_ids[enemy_id] = true
			enemy.receive_player_damage(int(projectile.get("damage", 0)))
			remaining_pierces -= 1
			did_hit = true
			_spawn_projectile_hit_feedback(position, Color(1.0, 0.76, 0.28, 0.92))
			if remaining_pierces <= 0:
				break

		projectile["hit_ids"] = hit_ids
		projectile["remaining_pierces"] = remaining_pierces
		if did_hit and remaining_pierces <= 0:
			_cleanup_runtime_node(node)
			_active_projectiles.remove_at(i)
			continue

		_active_projectiles[i] = projectile

func _update_boomerang_weapon(delta: float) -> void:
	if not _stat_bool("boomerang_unlocked"):
		return
	if not _tick_timer("boomerang", delta):
		return
	_set_timer("boomerang", _stat_float("boomerang_cooldown", 1.8))
	_spawn_boomerang()

func _spawn_boomerang() -> void:
	var origin := _get_tower_center()
	var target_mode := _stat_int("boomerang_target_mode", PlayerAbilityConfig.TargetMode.MOUSE)
	var direction := Vector2.ZERO
	if target_mode == PlayerAbilityConfig.TargetMode.NEAREST_ENEMY:
		var target_enemy := _find_nearest_enemy_to_position(origin, INF, {}, true)
		if target_enemy != null:
			direction = (_get_enemy_center(target_enemy) - origin).normalized()
	else:
		direction = (get_global_mouse_position() - origin).normalized()
	if direction == Vector2.ZERO:
		return

	var radius := _stat_float("boomerang_radius", 12.0)
	var node := _player_visual_runtime.spawn_boomerang(origin, radius)

	_active_boomerangs.append({
		"node": node,
		"position": origin,
		"direction": direction,
		"speed": _stat_float("boomerang_speed", 420.0),
		"damage": _stat_int("boomerang_damage", 2),
		"radius": radius,
		"max_distance": _stat_float("boomerang_distance", 240.0),
		"distance_travelled": 0.0,
		"returning": false,
		"outbound_hit_ids": {},
		"return_hit_ids": {}
	})

func _update_active_boomerangs(delta: float) -> void:
	for i in range(_active_boomerangs.size() - 1, -1, -1):
		var boomerang: Dictionary = _active_boomerangs[i]
		var position: Vector2 = boomerang.get("position", Vector2.ZERO)
		var direction: Vector2 = boomerang.get("direction", Vector2.UP)
		var speed: float = float(boomerang.get("speed", 0.0))
		var travel_step: float = speed * delta
		if bool(boomerang.get("returning", false)):
			var return_direction := (_get_tower_center() - position).normalized()
			if return_direction == Vector2.ZERO:
				return_direction = Vector2.UP
			direction = return_direction
		else:
			boomerang["distance_travelled"] = float(boomerang.get("distance_travelled", 0.0)) + travel_step
			if float(boomerang.get("distance_travelled", 0.0)) >= float(boomerang.get("max_distance", 0.0)):
				boomerang["returning"] = true
		position += direction * travel_step
		boomerang["position"] = position
		boomerang["direction"] = direction

		var node := boomerang.get("node", null) as Control
		if node != null:
			node.global_position = position - node.size * 0.5
			node.rotation = direction.angle() + PI * 0.5

		var hit_key := "return_hit_ids" if bool(boomerang.get("returning", false)) else "outbound_hit_ids"
		var hit_ids: Dictionary = boomerang.get(hit_key, {})
		for enemy in _get_enemies_in_radius(position, float(boomerang.get("radius", 0.0))):
			var enemy_id := enemy.get_instance_id()
			if hit_ids.has(enemy_id):
				continue
			hit_ids[enemy_id] = true
			enemy.receive_player_damage(int(boomerang.get("damage", 0)))
			_spawn_projectile_hit_feedback(position, Color(0.86, 0.9, 1.0, 0.86))
		boomerang[hit_key] = hit_ids

		if bool(boomerang.get("returning", false)) and position.distance_to(_get_tower_center()) <= BOOMERANG_RETURN_THRESHOLD:
			_cleanup_runtime_node(node)
			_active_boomerangs.remove_at(i)
			continue

		_active_boomerangs[i] = boomerang

func _update_chain_arrow_weapon(delta: float) -> void:
	if not _stat_bool("chain_arrow_unlocked"):
		return
	if not _tick_timer("chain_arrow", delta):
		return
	_set_timer("chain_arrow", _stat_float("chain_arrow_cooldown", 2.0))
	_spawn_chain_arrow()

func _spawn_chain_arrow() -> void:
	var origin := _get_tower_center()
	var target_enemy := _find_nearest_enemy_to_position(origin, INF, {}, true)
	if target_enemy == null:
		return

	var radius := _stat_float("chain_arrow_radius", 10.0)
	var node := _player_visual_runtime.spawn_chain_arrow(origin, radius)

	_active_chain_arrows.append({
		"node": node,
		"position": origin,
		"radius": radius,
		"speed": _stat_float("chain_arrow_speed", 620.0),
		"damage": _stat_int("chain_arrow_damage", 2),
		"remaining_targets": _stat_int("chain_arrow_targets", 4),
		"search_radius": _stat_float("chain_arrow_search_radius", 220.0),
		"visited_ids": {},
		"target_enemy": target_enemy
	})

func _update_active_chain_arrows(delta: float) -> void:
	for i in range(_active_chain_arrows.size() - 1, -1, -1):
		var arrow: Dictionary = _active_chain_arrows[i]
		var target_enemy: GameTestEnemy = _get_valid_enemy_ref(arrow, "target_enemy")
		var visited_ids: Dictionary = arrow.get("visited_ids", {})
		if target_enemy == null or not is_instance_valid(target_enemy):
			target_enemy = _find_nearest_enemy_to_position(
				arrow.get("position", Vector2.ZERO),
				float(arrow.get("search_radius", 0.0)),
				visited_ids,
				true
			)
			arrow["target_enemy"] = target_enemy
		if target_enemy == null:
			_cleanup_runtime_node(arrow.get("node", null) as Node)
			_active_chain_arrows.remove_at(i)
			continue

		var position: Vector2 = arrow.get("position", Vector2.ZERO)
		var target_center := _get_enemy_center(target_enemy)
		var direction := (target_center - position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.UP
		position += direction * float(arrow.get("speed", 0.0)) * delta
		arrow["position"] = position

		var node := arrow.get("node", null) as Control
		if node != null:
			node.rotation = direction.angle()
			node.global_position = position - node.pivot_offset

		if position.distance_to(target_center) <= float(arrow.get("radius", 0.0)) + _get_enemy_radius(target_enemy) + 6.0:
			target_enemy.receive_player_damage(int(arrow.get("damage", 0)))
			_spawn_chain_hit_feedback(target_center)
			visited_ids[target_enemy.get_instance_id()] = true
			arrow["visited_ids"] = visited_ids
			arrow["remaining_targets"] = int(arrow.get("remaining_targets", 0)) - 1
			if int(arrow.get("remaining_targets", 0)) <= 0:
				_cleanup_runtime_node(node)
				_active_chain_arrows.remove_at(i)
				continue

			var next_target := _find_nearest_enemy_to_position(
				target_center,
				float(arrow.get("search_radius", 0.0)),
				visited_ids,
				true
			)
			arrow["target_enemy"] = next_target
			if next_target == null:
				_cleanup_runtime_node(node)
				_active_chain_arrows.remove_at(i)
				continue

		_active_chain_arrows[i] = arrow

func _update_tower_aura(delta: float) -> void:
	_sync_tower_aura_visual()
	if not _stat_bool("tower_aura_unlocked"):
		return
	if not _tick_timer("tower_aura", delta):
		return
	_set_timer("tower_aura", _stat_float("tower_aura_tick_interval", 0.45))
	for enemy in _get_enemies_in_radius(_get_tower_center(), _stat_float("tower_aura_radius", 120.0)):
		enemy.receive_player_damage(_stat_int("tower_aura_damage", 1))

func _sync_tower_aura_visual() -> void:
	_player_visual_runtime.sync_tower_aura(
		_get_tower_center(),
		_stat_float("tower_aura_radius", 120.0),
		_stat_bool("tower_aura_unlocked")
	)

func _update_acid_rain(delta: float) -> void:
	if not _stat_bool("acid_rain_unlocked"):
		return
	if not _tick_timer("acid_rain", delta):
		return
	_set_timer("acid_rain", _stat_float("acid_rain_cooldown", 4.0))
	_trigger_acid_rain()

func _trigger_acid_rain() -> void:
	for _i in range(_stat_int("acid_rain_drop_count", 3)):
		var target_position := _get_random_screen_position(32.0)
		var drop := _player_visual_runtime.spawn_acid_drop(target_position)

		var tween := create_tween()
		tween.tween_property(drop, "global_position", target_position - drop.size * 0.5, ACID_DROP_FALL_DURATION)
		tween.finished.connect(_on_acid_drop_landed.bind(drop, target_position))
		_player_visual_runtime.register_tween(drop, tween)

func _on_acid_drop_landed(drop: ColorRect, target_position: Vector2) -> void:
	if is_instance_valid(drop):
		_cleanup_runtime_node(drop)
	_spawn_acid_puddle(target_position)

func _spawn_acid_puddle(center: Vector2) -> void:
	var radius := _stat_float("acid_rain_puddle_radius", 56.0)
	var puddle := _player_visual_runtime.spawn_acid_puddle(center, radius)

	_active_acid_puddles.append({
		"node": puddle,
		"center": center,
		"radius": radius,
		"remaining": _stat_float("acid_rain_puddle_duration", 2.2),
		"tick_remaining": 0.0
	})

func _update_acid_puddles(delta: float) -> void:
	for i in range(_active_acid_puddles.size() - 1, -1, -1):
		var puddle: Dictionary = _active_acid_puddles[i]
		puddle["remaining"] = float(puddle.get("remaining", 0.0)) - delta
		puddle["tick_remaining"] = float(puddle.get("tick_remaining", 0.0)) - delta

		var puddle_node := puddle.get("node", null) as CanvasItem
		if puddle_node != null:
			puddle_node.modulate.a = clampf(
				float(puddle.get("remaining", 0.0)) / maxf(_stat_float("acid_rain_puddle_duration", 2.2), 0.01),
				0.12,
				0.44
			)

		if float(puddle.get("tick_remaining", 0.0)) <= 0.0:
			puddle["tick_remaining"] = _stat_float("acid_rain_tick_interval", 0.30)
			for enemy in _get_enemies_in_radius(
				puddle.get("center", Vector2.ZERO),
				float(puddle.get("radius", 0.0))
			):
				enemy.receive_player_damage(_stat_int("acid_rain_damage", 1))

		if float(puddle.get("remaining", 0.0)) <= 0.0:
			_cleanup_runtime_node(puddle_node)
			_active_acid_puddles.remove_at(i)
		else:
			_active_acid_puddles[i] = puddle

func _update_laser(delta: float) -> void:
	if not _stat_bool("laser_unlocked"):
		return
	if not _tick_timer("laser", delta):
		return
	_set_timer("laser", _stat_float("laser_cooldown", 6.0))
	_trigger_laser()

func _trigger_laser() -> void:
	var aim_info := _resolve_tower_target_info(_stat_int("laser_target_mode", PlayerAbilityConfig.TargetMode.NEAREST_ENEMY))
	var direction: Vector2 = aim_info.get("direction", Vector2.ZERO)
	if direction == Vector2.ZERO:
		return

	var origin := _get_tower_center()
	var range_value := get_viewport_rect().size.length() + LASER_BEAM_OVERSCAN * 2.0
	var end := origin + direction * range_value
	var hit_radius := _stat_float("laser_width", 34.0) * 0.5
	for enemy in _get_enemies_along_segment(origin, end, hit_radius):
		enemy.eliminate(true, false)

	var beam := _player_visual_runtime.spawn_laser(
		origin,
		range_value + LASER_BEAM_OVERSCAN,
		_stat_float("laser_width", 34.0),
		direction
	)

	_active_lasers.append({
		"node": beam,
		"remaining": _stat_float("laser_duration", 0.22),
		"duration": _stat_float("laser_duration", 0.22)
	})

func _update_active_lasers(delta: float) -> void:
	for i in range(_active_lasers.size() - 1, -1, -1):
		var laser: Dictionary = _active_lasers[i]
		laser["remaining"] = float(laser.get("remaining", 0.0)) - delta
		var node := laser.get("node", null) as CanvasItem
		if node != null:
			node.modulate.a = clampf(
				float(laser.get("remaining", 0.0)) / maxf(float(laser.get("duration", 0.22)), 0.01),
				0.0,
				0.78
			)
		if float(laser.get("remaining", 0.0)) <= 0.0:
			_cleanup_runtime_node(node)
			_active_lasers.remove_at(i)
		else:
			_active_lasers[i] = laser

func _update_map_clear(delta: float) -> void:
	if not _stat_bool("map_clear_unlocked"):
		return
	if not _tick_timer("map_clear", delta):
		return
	_set_timer("map_clear", _stat_float("map_clear_cooldown", 16.0))
	_trigger_map_clear()

func _trigger_map_clear() -> void:
	for enemy in _get_live_enemies(true):
		enemy.eliminate(false, false)

	var wipe := _player_visual_runtime.spawn_map_clear_wipe()

	var tween := create_tween()
	tween.parallel().tween_property(wipe, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(_player_visual_runtime, "release_runtime_node").bind(wipe))
	_player_visual_runtime.register_tween(wipe, tween)

func _update_flamethrower(delta: float) -> void:
	if not _stat_bool("flamethrower_unlocked"):
		_sync_flamethrower_visual(Vector2.ZERO, false)
		return

	var aim_info := _resolve_tower_target_info(_stat_int("flamethrower_target_mode", PlayerAbilityConfig.TargetMode.MOUSE))
	var direction: Vector2 = aim_info.get("direction", Vector2.ZERO)
	var is_active := direction != Vector2.ZERO
	_sync_flamethrower_visual(direction, is_active)

	if not is_active:
		return
	if not _tick_timer("flamethrower", delta):
		return
	_set_timer("flamethrower", _stat_float("flamethrower_tick_interval", 0.18))

	var origin := _get_tower_center()
	for enemy in _get_enemies_in_cone(
		origin,
		direction,
		_stat_float("flamethrower_range", 230.0),
		_stat_float("flamethrower_width", 42.0) * 0.5
	):
		enemy.receive_player_damage(_stat_int("flamethrower_damage", 1))

func _sync_flamethrower_visual(direction: Vector2, is_active: bool) -> void:
	_player_visual_runtime.sync_flamethrower(
		_get_tower_center(),
		direction,
		is_active,
		_stat_float("flamethrower_range", 230.0),
		_stat_float("flamethrower_width", 42.0) * 0.5,
		FLAMETHROWER_VISUAL_ALPHA
	)

func _update_ricochet_weapon(delta: float) -> void:
	if not _stat_bool("ricochet_unlocked"):
		return
	if not _tick_timer("ricochet", delta):
		return
	_set_timer("ricochet", _stat_float("ricochet_cooldown", 1.7))
	_spawn_ricochet_projectile()

func _spawn_ricochet_projectile() -> void:
	var origin := _get_tower_center()
	var target_mode := _stat_int("ricochet_target_mode", PlayerAbilityConfig.TargetMode.MOUSE)
	var direction := Vector2.ZERO
	if target_mode == PlayerAbilityConfig.TargetMode.RANDOM_DIRECTION:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		direction = (get_global_mouse_position() - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP

	var radius := _stat_float("ricochet_radius", 9.0)
	var node := _player_visual_runtime.spawn_ricochet(origin, radius)

	_active_ricochets.append({
		"node": node,
		"position": origin,
		"velocity": direction * _stat_float("ricochet_speed", 500.0),
		"damage": _stat_int("ricochet_damage", 1),
		"radius": radius,
		"remaining_bounces": _stat_int("ricochet_bounces", 4),
		"hit_cooldowns": {}
	})

func _update_active_ricochets(delta: float) -> void:
	var bounds := get_viewport_rect().size
	for i in range(_active_ricochets.size() - 1, -1, -1):
		var ricochet: Dictionary = _active_ricochets[i]
		var position: Vector2 = ricochet.get("position", Vector2.ZERO)
		var velocity: Vector2 = ricochet.get("velocity", Vector2.ZERO)
		position += velocity * delta
		var radius: float = float(ricochet.get("radius", 0.0))

		var bounced: bool = false
		if position.x - radius <= 0.0:
			position.x = radius
			velocity.x = absf(velocity.x)
			bounced = true
		elif position.x + radius >= bounds.x:
			position.x = bounds.x - radius
			velocity.x = -absf(velocity.x)
			bounced = true

		if position.y - radius <= 0.0:
			position.y = radius
			velocity.y = absf(velocity.y)
			bounced = true
		elif position.y + radius >= bounds.y:
			position.y = bounds.y - radius
			velocity.y = -absf(velocity.y)
			bounced = true

		if bounced:
			ricochet["remaining_bounces"] = int(ricochet.get("remaining_bounces", 0)) - 1
			if int(ricochet.get("remaining_bounces", 0)) < 0:
				_cleanup_runtime_node(ricochet.get("node", null) as Node)
				_active_ricochets.remove_at(i)
				continue

		ricochet["position"] = position
		ricochet["velocity"] = velocity

		var node := ricochet.get("node", null) as Control
		if node != null:
			node.global_position = position - node.size * 0.5
			node.rotation += delta * 7.0

		var hit_cooldowns: Dictionary = ricochet.get("hit_cooldowns", {})
		var cooldown_keys := hit_cooldowns.keys()
		for enemy_id in cooldown_keys:
			hit_cooldowns[enemy_id] = maxf(float(hit_cooldowns[enemy_id]) - delta, 0.0)
		for enemy in _get_enemies_in_radius(position, radius):
			var enemy_id := enemy.get_instance_id()
			if float(hit_cooldowns.get(enemy_id, 0.0)) > 0.0:
				continue
			enemy.receive_player_damage(int(ricochet.get("damage", 0)))
			hit_cooldowns[enemy_id] = RICOCHET_HIT_INTERVAL
			_spawn_projectile_hit_feedback(position, Color(0.74, 0.92, 1.0, 0.86))
		ricochet["hit_cooldowns"] = hit_cooldowns
		_active_ricochets[i] = ricochet

func _trigger_lightning_burst() -> void:
	var mouse_position := get_global_mouse_position()
	for i in range(_stat_int("lightning_count", 3)):
		var strike_point := mouse_position + _random_point_in_circle(_stat_float("lightning_area_radius", 96.0))
		var tween := create_tween()
		tween.tween_interval(LIGHTNING_STRIKE_STAGGER * i)
		tween.tween_callback(Callable(self, "_resolve_lightning_strike").bind(strike_point))

func _resolve_lightning_strike(strike_point: Vector2) -> void:
	var hit_enemy := _find_enemy_near_position(strike_point, LIGHTNING_STRIKE_RADIUS)
	if hit_enemy != null:
		hit_enemy.receive_player_damage(_stat_int("lightning_damage", 2))
	_spawn_lightning_feedback(strike_point, hit_enemy != null)

func _trigger_snowball() -> void:
	var tower_center := _get_tower_center()
	var target_position := get_global_mouse_position()
	if _stat_int("snowball_target_mode", PlayerAbilityConfig.TargetMode.MOUSE) == PlayerAbilityConfig.TargetMode.NEAREST_ENEMY:
		var target_enemy := _find_nearest_enemy_to_position(tower_center, INF, {}, true)
		if target_enemy == null:
			return
		target_position = _get_enemy_center(target_enemy)
	var travel_distance: float = tower_center.distance_to(target_position)
	var projectile := _player_visual_runtime.spawn_snowball_projectile(tower_center)

	var distance_factor: float = clampf(travel_distance / 260.0, 0.0, 1.0)
	var peak_scale: Vector2 = Vector2.ONE * (1.28 + distance_factor * 0.28)
	var end_scale: Vector2 = Vector2.ONE * 0.68

	var move_tween := create_tween()
	move_tween.tween_property(projectile, "global_position", target_position - projectile.size * 0.5, SNOWBALL_PROJECTILE_DURATION)
	move_tween.finished.connect(_on_snowball_hit.bind(projectile, target_position))
	_player_visual_runtime.register_tween(projectile, move_tween)

	var scale_tween := create_tween()
	scale_tween.tween_property(projectile, "scale", peak_scale, SNOWBALL_PROJECTILE_DURATION * 0.5)
	scale_tween.tween_property(projectile, "scale", end_scale, SNOWBALL_PROJECTILE_DURATION * 0.5)
	_player_visual_runtime.register_tween(projectile, scale_tween)

func _on_snowball_hit(projectile: Panel, target_position: Vector2) -> void:
	if is_instance_valid(projectile):
		_cleanup_runtime_node(projectile)

	var enemies := _get_enemies_in_radius(target_position, SNOWBALL_IMPACT_RADIUS)
	for enemy in enemies:
		enemy.receive_player_damage(_stat_int("snowball_damage", 2))

	_spawn_snowball_impact_feedback(target_position)
	_spawn_slow_field(target_position)

func _spawn_slow_field(center: Vector2) -> void:
	var radius := _stat_float("snowball_field_radius", 66.0)
	var field := _player_visual_runtime.spawn_slow_field(center, radius)

	_active_slow_fields.append({
		"node": field,
		"center": center,
		"radius": radius,
		"remaining": _stat_float("snowball_field_duration", 1.8),
		"tick_remaining": 0.0
	})

func _apply_slow_field(field: Dictionary) -> void:
	var center: Vector2 = field.get("center", Vector2.ZERO)
	var radius: float = float(field.get("radius", 66.0))
	for enemy in _get_live_enemies():
		if _get_enemy_center(enemy).distance_to(center) <= radius + _get_enemy_radius(enemy):
			enemy.apply_slow(_stat_float("snowball_slow_factor", 0.70), SNOWBALL_FIELD_TICK + 0.08)

func _refresh_blades() -> void:
	if not _stat_bool("blades_unlocked"):
		_clear_blades()
		return

	var mouse_position := get_global_mouse_position()
	var blade_count: int = _stat_int("blade_count", 3)
	var blade_size := Vector2(_stat_float("blade_size", 18.0), _stat_float("blade_size", 18.0) * 0.38)
	var blade_centers: Array[Vector2] = []
	var blade_angles: Array[float] = []
	for i in range(blade_count):
		var angle := _blade_rotation + TAU * float(i) / float(max(blade_count, 1))
		blade_angles.append(angle + PI * 0.5)
		blade_centers.append(mouse_position + Vector2.RIGHT.rotated(angle) * _stat_float("blade_orbit_radius", 72.0))
	_player_visual_runtime.sync_blades(blade_centers, blade_angles, blade_size, true)

func _clear_blades() -> void:
	_player_visual_runtime.clear_blades()

func _find_enemy_at_position(screen_position: Vector2) -> GameTestEnemy:
	return _enemy_tracker.find_enemy_at_position(screen_position)

func _find_enemy_near_position(screen_position: Vector2, radius: float) -> GameTestEnemy:
	return _find_nearest_enemy_to_position(screen_position, radius)

func _find_nearest_enemy_to_position(screen_position: Vector2, radius: float = INF, excluded_ids: Dictionary = {}, only_visible: bool = false) -> GameTestEnemy:
	return _enemy_tracker.find_nearest_enemy_to_position(screen_position, radius, excluded_ids, only_visible)

func _find_enemy_colliding(screen_position: Vector2, radius: float) -> GameTestEnemy:
	return _enemy_tracker.find_enemy_colliding(screen_position, radius)

func _get_enemies_in_radius(screen_position: Vector2, radius: float) -> Array[GameTestEnemy]:
	return _enemy_tracker.get_enemies_in_radius(screen_position, radius)

func _get_enemies_along_segment(start: Vector2, end: Vector2, radius: float) -> Array[GameTestEnemy]:
	return _enemy_tracker.get_enemies_along_segment(start, end, radius)

func _get_enemies_in_cone(origin: Vector2, direction: Vector2, distance: float, half_width: float) -> Array[GameTestEnemy]:
	return _enemy_tracker.get_enemies_in_cone(origin, direction, distance, half_width, true)

func _get_live_enemies(only_visible: bool = false) -> Array[GameTestEnemy]:
	return _enemy_tracker.get_live_enemies(only_visible)

func _resolve_tower_target_info(target_mode: int) -> Dictionary:
	var origin := _get_tower_center()
	match target_mode:
		PlayerAbilityConfig.TargetMode.NEAREST_ENEMY:
			var target_enemy := _find_nearest_enemy_to_position(origin, INF, {}, true)
			if target_enemy == null:
				return {"direction": Vector2.ZERO, "enemy": null}
			return {
				"direction": (_get_enemy_center(target_enemy) - origin).normalized(),
				"enemy": target_enemy
			}
		PlayerAbilityConfig.TargetMode.RANDOM_DIRECTION:
			return {
				"direction": Vector2.RIGHT.rotated(randf() * TAU),
				"enemy": null
			}
		_:
			var mouse_direction := (get_global_mouse_position() - origin).normalized()
			return {
				"direction": mouse_direction if mouse_direction != Vector2.ZERO else Vector2.UP,
				"enemy": null
			}

func _get_tower_center() -> Vector2:
	var tower_rect := tower_body.get_global_rect()
	return tower_rect.position + tower_rect.size * 0.5

func _is_enemy_visible(enemy: GameTestEnemy) -> bool:
	return _enemy_tracker.is_enemy_visible(enemy)

func _get_random_screen_position(inset: float = 0.0) -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(
		randf_range(inset, maxf(size.x - inset, inset)),
		randf_range(inset, maxf(size.y - inset, inset))
	)

func _is_outside_play_bounds(position: Vector2, margin: float = 0.0) -> bool:
	var bounds := get_viewport_rect().size
	return position.x < -margin or position.y < -margin or position.x > bounds.x + margin or position.y > bounds.y + margin

func _cleanup_runtime_node(node: Node) -> void:
	_player_visual_runtime.release_runtime_node(node)

func _spawn_click_feedback(screen_position: Vector2, hit_target: bool) -> void:
	_player_visual_runtime.spawn_click_feedback(screen_position, hit_target, click_feedback_duration)

func _spawn_lightning_feedback(screen_position: Vector2, hit_target: bool) -> void:
	_player_visual_runtime.spawn_lightning_feedback(screen_position, hit_target)

func _spawn_snowball_impact_feedback(screen_position: Vector2) -> void:
	_player_visual_runtime.spawn_snowball_impact_feedback(screen_position)

func _spawn_blade_hit_feedback(screen_position: Vector2) -> void:
	_player_visual_runtime.spawn_blade_hit_feedback(screen_position)

func _spawn_projectile_hit_feedback(screen_position: Vector2, fill_color: Color) -> void:
	_player_visual_runtime.spawn_projectile_hit_feedback(screen_position, fill_color)

func _spawn_chain_hit_feedback(screen_position: Vector2) -> void:
	_player_visual_runtime.spawn_chain_hit_feedback(screen_position)

func _on_enemy_defeated(gold_reward: int) -> void:
	CurrencySystem.add_currency("gold", gold_reward)

func _on_enemy_spawned(enemy: GameTestEnemy) -> void:
	if not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
	if not enemy.child_enemy_spawned.is_connected(_on_enemy_spawned):
		enemy.child_enemy_spawned.connect(_on_enemy_spawned)

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
	enemy_wave_spawner.stop_spawning()
	TransitionManager.change_scene("AbilitiesDebugMenu", "iris_circle", {
		"data": _build_upgrade_payload()
	})

func _build_upgrade_payload() -> Dictionary:
	var payload: Dictionary = _run_state.duplicate(true)
	payload["gold"] = CurrencySystem.get_amount("gold")
	payload["elapsed_time_sec"] = _survived_time_sec
	return payload

func _update_survived_time_label() -> void:
	var total_seconds := int(floor(_survived_time_sec))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	var active_enemy_count := _enemy_tracker.get_live_enemy_count()
	var visible_enemy_count := _enemy_tracker.get_live_enemy_count(true)
	_peak_active_enemy_count = maxi(_peak_active_enemy_count, active_enemy_count)
	_peak_visible_enemy_count = maxi(_peak_visible_enemy_count, visible_enemy_count)
	survived_time_label.text = "Time: %02d:%02d\nEnemies: %d (%d visible)\nPeak: %d (%d visible)\nFPS: %d" % [
		minutes,
		seconds,
		active_enemy_count,
		visible_enemy_count,
		_peak_active_enemy_count,
		_peak_visible_enemy_count,
		Engine.get_frames_per_second()
	]

func _random_point_in_circle(radius: float) -> Vector2:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * radius
	return Vector2.RIGHT.rotated(angle) * distance

func _get_enemy_center(enemy: GameTestEnemy) -> Vector2:
	return _enemy_tracker.get_enemy_center(enemy)

func _get_enemy_radius(enemy: GameTestEnemy) -> float:
	return _enemy_tracker.get_enemy_radius(enemy)
