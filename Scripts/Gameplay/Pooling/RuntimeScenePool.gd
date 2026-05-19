extends Node
class_name RuntimeScenePool

const DEFAULT_MAX_PER_SCENE: int = 100
const DEFAULT_PREWARM_PER_SCENE: int = 10

var _available_by_key: Dictionary = {}
var max_per_scene: int = DEFAULT_MAX_PER_SCENE
var prewarm_per_scene: int = DEFAULT_PREWARM_PER_SCENE

func acquire_scene(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		return null

	var key := _get_scene_key(scene)
	var bucket: Array = _available_by_key.get(key, [])
	var node: Node = null
	while not bucket.is_empty():
		var candidate_ref: Variant = bucket.pop_back()
		if candidate_ref != null and is_instance_valid(candidate_ref):
			node = candidate_ref as Node
			break
	_available_by_key[key] = bucket

	if node == null:
		node = scene.instantiate()
		node.set_meta("_runtime_scene_pool_key", key)

	if node.get_parent() == null:
		parent.add_child(node)
	elif node.get_parent() != parent:
		node.reparent(parent, false)

	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node.has_method("on_acquired_from_pool"):
		node.call("on_acquired_from_pool")
	return node

func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	var key := String(node.get_meta("_runtime_scene_pool_key", ""))
	if key.is_empty():
		node.queue_free()
		return

	if node.get_parent() == null:
		add_child(node)
	elif node.get_parent() != self:
		node.reparent(self, false)

	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if node.has_method("on_released_to_pool"):
		node.call("on_released_to_pool")

	var bucket: Array = _available_by_key.get(key, [])
	if bucket.size() >= max_per_scene:
		node.queue_free()
		return
	bucket.append(node)
	_available_by_key[key] = bucket

func prewarm_scene(scene: PackedScene, count: int = 1) -> void:
	if scene == null or count <= 0:
		return

	var key := _get_scene_key(scene)
	var bucket: Array = _available_by_key.get(key, [])
	var missing_count: int = maxi(count - bucket.size(), 0)
	for _i in range(missing_count):
		var node := scene.instantiate()
		node.set_meta("_runtime_scene_pool_key", key)
		add_child(node)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		if node.has_method("on_released_to_pool"):
			node.call("on_released_to_pool")
		bucket.append(node)
	_available_by_key[key] = bucket

func _get_scene_key(scene: PackedScene) -> String:
	if not scene.resource_path.is_empty():
		return scene.resource_path
	return str(scene.get_instance_id())
