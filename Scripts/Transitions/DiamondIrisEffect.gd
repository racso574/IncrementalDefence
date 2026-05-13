extends TransitionEffectBase

const MIN_RADIUS_PX: float = -4.0
const EXTRA_RADIUS_PX: float = 8.0

@onready var overlay: ColorRect = $Overlay

var _shader_material: ShaderMaterial
var _screen_size: Vector2 = Vector2.ZERO
var _center_px: Vector2 = Vector2.ZERO
var _max_radius_px: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_material()

func _on_configured() -> void:
	_setup_material()
	_screen_size = get_viewport_rect().size
	_center_px = _resolve_center_px()
	_max_radius_px = _compute_max_radius(_center_px, _screen_size) + EXTRA_RADIUS_PX

	_shader_material.set_shader_parameter("screen_size", _screen_size)
	_shader_material.set_shader_parameter("center_px", _center_px)
	_shader_material.set_shader_parameter("radius_px", _max_radius_px)
	_shader_material.set_shader_parameter("feather_px", float(params.get("feather_px", 2.0)))
	_shader_material.set_shader_parameter("tint", params.get("color", Color(0, 0, 0, 1)))
	_shader_material.set_shader_parameter("invert_mask", bool(params.get("invert", false)))
	visible = false

func _play_cover() -> void:
	var is_inverted: bool = bool(params.get("invert", false))
	var from_radius: float = _max_radius_px
	var to_radius: float = MIN_RADIUS_PX
	if is_inverted:
		from_radius = MIN_RADIUS_PX
		to_radius = _max_radius_px

	_shader_material.set_shader_parameter("radius_px", from_radius)

	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_method(_set_radius_px, from_radius, to_radius, get_duration("cover_duration", 0.34))
	tween.finished.connect(_on_cover_tween_finished)

func _play_reveal() -> void:
	var is_inverted: bool = bool(params.get("invert", false))
	var from_radius: float = MIN_RADIUS_PX
	var to_radius: float = _max_radius_px
	if is_inverted:
		from_radius = _max_radius_px
		to_radius = MIN_RADIUS_PX

	_shader_material.set_shader_parameter("radius_px", from_radius)

	var tween := create_tween()
	tween.set_trans(get_tween_trans())
	tween.set_ease(get_tween_ease())
	tween.tween_method(_set_radius_px, from_radius, to_radius, get_duration("reveal_duration", 0.34))
	tween.finished.connect(finish_reveal)

func _setup_material() -> void:
	if _shader_material != null:
		return

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform vec2 center_px = vec2(960.0, 540.0);
uniform float radius_px = 1024.0;
uniform float feather_px = 2.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool invert_mask = false;

void fragment() {
	vec2 pixel_pos = UV * screen_size;
	vec2 delta = abs(pixel_pos - center_px);
	float dist_px = delta.x + delta.y;
	float alpha = smoothstep(radius_px - feather_px, radius_px + feather_px, dist_px);
	if (invert_mask) {
		alpha = 1.0 - alpha;
	}
	COLOR = vec4(tint.rgb, tint.a * alpha);
}
"""

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	overlay.material = _shader_material

func _resolve_center_px() -> Vector2:
	if bool(params.get("random_center", false)):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		return Vector2(
			rng.randf_range(0.15 * _screen_size.x, 0.85 * _screen_size.x),
			rng.randf_range(0.15 * _screen_size.y, 0.85 * _screen_size.y)
		)

	var center_px_value: Variant = params.get("center_px", null)
	if center_px_value is Vector2:
		return center_px_value as Vector2

	var center_uv_value: Variant = params.get("center_uv", Vector2(0.5, 0.5))
	var center_uv := Vector2(0.5, 0.5)
	if center_uv_value is Vector2:
		center_uv = center_uv_value as Vector2
	return Vector2(center_uv.x * _screen_size.x, center_uv.y * _screen_size.y)

func _compute_max_radius(center_px: Vector2, screen_size: Vector2) -> float:
	var corners := [
		Vector2.ZERO,
		Vector2(screen_size.x, 0.0),
		Vector2(0.0, screen_size.y),
		screen_size
	]

	var max_distance: float = 0.0
	for corner in corners:
		var delta: Vector2 = abs(corner - center_px)
		max_distance = maxf(max_distance, delta.x + delta.y)
	return max_distance

func _set_radius_px(value: float) -> void:
	_shader_material.set_shader_parameter("radius_px", value)

func _on_cover_tween_finished() -> void:
	var hold_duration: float = float(params.get("cover_hold_duration", 0.0))
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	finish_cover()
