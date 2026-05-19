extends Node
class_name RuntimeNodePool

const DEFAULT_MAX_PER_KEY: int = 160

var _available_by_key: Dictionary = {}
var max_per_key: int = DEFAULT_MAX_PER_KEY

func acquire_node(pool_key: String, parent: Node, factory: Callable) -> Node:
	if pool_key.is_empty() or parent == null or not factory.is_valid():
		return null

	var bucket: Array = _available_by_key.get(pool_key, [])
	var node: Node = null
	while not bucket.is_empty():
		var candidate_ref: Variant = bucket.pop_back()
		if candidate_ref != null and is_instance_valid(candidate_ref):
			node = candidate_ref as Node
			break
	_available_by_key[pool_key] = bucket

	if node == null:
		var created_ref: Variant = factory.call()
		node = created_ref as Node
		if node == null:
			return null
		node.set_meta("_runtime_node_pool_key", pool_key)

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

	var pool_key := String(node.get_meta("_runtime_node_pool_key", ""))
	if pool_key.is_empty():
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

	var bucket: Array = _available_by_key.get(pool_key, [])
	if bucket.size() >= max_per_key:
		node.queue_free()
		return
	bucket.append(node)
	_available_by_key[pool_key] = bucket
