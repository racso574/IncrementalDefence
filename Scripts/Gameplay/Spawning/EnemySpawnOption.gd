extends Resource
class_name EnemySpawnOption

@export var enemy_scene: PackedScene
@export_range(0.0, 1000.0, 0.01, "or_greater") var weight: float = 1.0
