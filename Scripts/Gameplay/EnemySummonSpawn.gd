extends Resource
class_name EnemySummonSpawn

@export var enemy_scene: PackedScene
@export_range(1, 16, 1, "or_greater") var count: int = 1
@export_range(0.0, 180.0, 1.0, "or_greater") var arc_degrees: float = 24.0
@export_range(-180.0, 180.0, 1.0) var angle_offset_degrees: float = 0.0
@export_range(0.0, 128.0, 1.0, "or_greater") var spawn_radius: float = 20.0
