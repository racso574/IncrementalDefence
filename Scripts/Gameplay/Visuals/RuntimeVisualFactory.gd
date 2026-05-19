extends Node
class_name RuntimeVisualFactory

const RuntimeNodePoolScript = preload("res://Scripts/Gameplay/Pooling/RuntimeNodePool.gd")

var _effect_layer: Control
var _node_pool: RuntimeNodePoolScript

func setup(effect_layer: Control, node_pool: RuntimeNodePoolScript) -> void:
	_effect_layer = effect_layer
	_node_pool = node_pool

func acquire_panel(
	pool_key: String,
	size: Vector2,
	fill_color: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = 0,
	parent: Node = null
) -> Panel:
	var panel: Panel = _acquire_node(pool_key, parent, Callable(self, "_build_panel_node")) as Panel
	if panel == null:
		return null
	configure_panel(panel, size, fill_color, border_color, border_width, corner_radius)
	return panel

func acquire_circle_panel(
	pool_key: String,
	radius: float,
	fill_color: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	parent: Node = null
) -> Panel:
	return acquire_panel(
		pool_key,
		Vector2.ONE * radius * 2.0,
		fill_color,
		border_color,
		border_width,
		int(radius),
		parent
	)

func acquire_capsule_panel(
	pool_key: String,
	size: Vector2,
	fill_color: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	parent: Node = null
) -> Panel:
	return acquire_panel(
		pool_key,
		size,
		fill_color,
		border_color,
		border_width,
		int(size.y * 0.5),
		parent
	)

func acquire_color_rect(
	pool_key: String,
	size: Vector2,
	fill_color: Color,
	pivot_offset: Vector2 = Vector2.ZERO,
	use_custom_pivot: bool = false,
	parent: Node = null
) -> ColorRect:
	var rect: ColorRect = _acquire_node(pool_key, parent, Callable(self, "_build_color_rect_node")) as ColorRect
	if rect == null:
		return null
	configure_color_rect(rect, size, fill_color, pivot_offset, use_custom_pivot)
	return rect

func configure_panel(panel: Panel, size: Vector2, fill_color: Color, border_color: Color, border_width: int, corner_radius: int) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = size
	panel.pivot_offset = size * 0.5
	var style: StyleBoxFlat = _get_or_create_panel_style(panel)
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

func configure_circle_panel(panel: Panel, radius: float, fill_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	configure_panel(panel, Vector2.ONE * radius * 2.0, fill_color, border_color, border_width, int(radius))

func configure_capsule_panel(panel: Panel, size: Vector2, fill_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	configure_panel(panel, size, fill_color, border_color, border_width, int(size.y * 0.5))

func configure_color_rect(rect: ColorRect, size: Vector2, fill_color: Color, pivot_offset: Vector2 = Vector2.ZERO, use_custom_pivot: bool = false) -> void:
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = fill_color
	rect.size = size
	rect.pivot_offset = pivot_offset if use_custom_pivot else size * 0.5

func register_tween(node: Node, tween: Tween) -> void:
	if node == null or tween == null or not is_instance_valid(node):
		return
	var tween_refs: Array = node.get_meta("_runtime_tweens", [])
	tween_refs.append(tween)
	node.set_meta("_runtime_tweens", tween_refs)

func create_runtime_tween() -> Tween:
	return create_tween()

func release_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_runtime_tweens(node)
	if _node_pool != null and not String(node.get_meta("_runtime_node_pool_key", "")).is_empty():
		_node_pool.release(node)
		return
	node.queue_free()

func _acquire_node(pool_key: String, parent: Node, factory: Callable) -> Node:
	var target_parent: Node = _effect_layer if parent == null else parent
	if target_parent == null:
		return null

	var node: Node
	if _node_pool != null:
		node = _node_pool.acquire_node(pool_key, target_parent, factory)
	else:
		var created_ref: Variant = factory.call()
		node = created_ref as Node
		if node == null:
			return null
		target_parent.add_child(node)

	_reset_runtime_node_state(node)
	return node

func _build_panel_node() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _build_color_rect_node() -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _reset_runtime_node_state(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_runtime_tweens(node)
	if node is CanvasItem:
		var canvas_item: CanvasItem = node as CanvasItem
		canvas_item.visible = true
		canvas_item.modulate = Color.WHITE
		canvas_item.scale = Vector2.ONE
		canvas_item.rotation = 0.0
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.anchor_left = 0.0
		control.anchor_top = 0.0
		control.anchor_right = 0.0
		control.anchor_bottom = 0.0
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0

func _kill_runtime_tweens(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tween_refs: Array = node.get_meta("_runtime_tweens", [])
	for tween_ref in tween_refs:
		var tween: Tween = tween_ref as Tween
		if tween != null:
			tween.kill()
	node.set_meta("_runtime_tweens", [])

func _get_or_create_panel_style(panel: Panel) -> StyleBoxFlat:
	if panel.has_theme_stylebox_override("panel"):
		var existing_style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if existing_style != null:
			return existing_style
	var style := StyleBoxFlat.new()
	panel.add_theme_stylebox_override("panel", style)
	return style
