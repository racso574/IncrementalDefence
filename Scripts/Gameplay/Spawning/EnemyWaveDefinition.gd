extends Resource
class_name EnemyWaveDefinition

@export var wave_name: String = ""
@export_range(-1.0, 9999.0, 0.1, "or_greater") var duration_sec: float = 20.0
@export_range(0, 1000, 1, "or_greater") var min_alive: int = 0
@export_range(-1, 1000, 1, "or_greater") var max_alive: int = -1
@export_range(1, 32, 1, "or_greater") var enemies_per_spawn_tick: int = 1
@export_range(0.05, 30.0, 0.01, "or_greater") var start_spawn_interval: float = 1.0
@export_range(0.05, 30.0, 0.01, "or_greater") var end_spawn_interval: float = 1.0
@export_range(0.1, 1.0, 0.01) var catchup_interval_multiplier: float = 0.45
@export var spawn_options: Array[EnemySpawnOption] = []

func get_spawn_interval(progress_ratio: float, is_below_minimum: bool) -> float:
	var interval := lerpf(start_spawn_interval, end_spawn_interval, clampf(progress_ratio, 0.0, 1.0))
	if is_below_minimum:
		interval *= catchup_interval_multiplier
	return maxf(interval, 0.05)

func has_spawn_options() -> bool:
	for option in spawn_options:
		if option != null and option.enemy_scene != null and option.weight > 0.0:
			return true
	return false
