extends RefCounted
class_name PlayerAbilityConfig

enum TargetMode { MOUSE, NEAREST_ENEMY, RANDOM_DIRECTION }

static func build_default_run_state(base_gold: int = 250, tick_damage: int = 1, tick_cooldown: float = 0.5) -> Dictionary:
	return {
		"gold": base_gold,
		"elapsed_time_sec": 0.0,
		"player_damage": tick_damage,
		"player_attack_cooldown": tick_cooldown,
		"lightning_unlocked": false,
		"lightning_damage": 2,
		"lightning_count": 3,
		"lightning_cooldown": 2.4,
		"lightning_area_radius": 96.0,
		"snowball_unlocked": false,
		"snowball_damage": 2,
		"snowball_cooldown": 3.1,
		"snowball_slow_factor": 0.70,
		"snowball_field_radius": 66.0,
		"snowball_field_duration": 1.8,
		"snowball_target_mode": TargetMode.MOUSE,
		"blades_unlocked": false,
		"blade_count": 3,
		"blade_size": 18.0,
		"blade_orbit_radius": 72.0,
		"blade_rotation_speed": 2.6,
		"blade_damage": 1,
		"projectile_unlocked": false,
		"projectile_damage": 3,
		"projectile_cooldown": 1.0,
		"projectile_speed": 580.0,
		"projectile_radius": 9.0,
		"projectile_piercing": 1,
		"projectile_target_mode": TargetMode.MOUSE,
		"boomerang_unlocked": false,
		"boomerang_damage": 2,
		"boomerang_cooldown": 1.8,
		"boomerang_speed": 420.0,
		"boomerang_radius": 12.0,
		"boomerang_distance": 240.0,
		"boomerang_target_mode": TargetMode.MOUSE,
		"chain_arrow_unlocked": false,
		"chain_arrow_damage": 2,
		"chain_arrow_cooldown": 2.0,
		"chain_arrow_speed": 620.0,
		"chain_arrow_radius": 10.0,
		"chain_arrow_targets": 4,
		"chain_arrow_search_radius": 220.0,
		"tower_aura_unlocked": false,
		"tower_aura_damage": 1,
		"tower_aura_tick_interval": 0.45,
		"tower_aura_radius": 120.0,
		"acid_rain_unlocked": false,
		"acid_rain_damage": 1,
		"acid_rain_cooldown": 4.0,
		"acid_rain_drop_count": 3,
		"acid_rain_puddle_radius": 56.0,
		"acid_rain_puddle_duration": 2.2,
		"acid_rain_tick_interval": 0.30,
		"laser_unlocked": false,
		"laser_cooldown": 6.0,
		"laser_duration": 0.22,
		"laser_width": 34.0,
		"laser_target_mode": TargetMode.NEAREST_ENEMY,
		"map_clear_unlocked": false,
		"map_clear_cooldown": 16.0,
		"flamethrower_unlocked": false,
		"flamethrower_damage": 1,
		"flamethrower_tick_interval": 0.18,
		"flamethrower_range": 230.0,
		"flamethrower_width": 42.0,
		"flamethrower_target_mode": TargetMode.MOUSE,
		"ricochet_unlocked": false,
		"ricochet_damage": 1,
		"ricochet_cooldown": 1.7,
		"ricochet_speed": 500.0,
		"ricochet_radius": 9.0,
		"ricochet_bounces": 4,
		"ricochet_target_mode": TargetMode.MOUSE
	}

static func merge_run_state(payload: Variant, base_gold: int = 250, tick_damage: int = 1, tick_cooldown: float = 0.5) -> Dictionary:
	var state: Dictionary = build_default_run_state(base_gold, tick_damage, tick_cooldown)
	if typeof(payload) != TYPE_DICTIONARY:
		return state

	for key in state.keys():
		if payload.has(key):
			state[key] = payload[key]
	return state

static func get_target_mode_label(mode: int) -> String:
	match mode:
		TargetMode.NEAREST_ENEMY:
			return "Auto"
		TargetMode.RANDOM_DIRECTION:
			return "Random"
		_:
			return "Mouse"

static func cycle_target_mode(current_mode: int, allowed_modes: Array[int]) -> int:
	if allowed_modes.is_empty():
		return current_mode

	var current_index: int = allowed_modes.find(current_mode)
	if current_index == -1:
		return allowed_modes[0]
	return allowed_modes[(current_index + 1) % allowed_modes.size()]
