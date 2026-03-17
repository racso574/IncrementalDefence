extends Node
class_name ScenesManager

@export var scenes_root: String = "res://scenes"
@export var use_subfolder_keys: bool = false

enum CacheMode { NONE, ON_DEMAND, PRELOAD_ALL }
@export var cache_mode: CacheMode = CacheMode.ON_DEMAND

# Tipado para evitar Variant warnings
var _paths: Dictionary[String, String] = {}          # key -> path
var _cache: Dictionary[String, PackedScene] = {}     # key -> PackedScene

var _payload: Variant = null
var _stack: Array[String] = []

signal scene_changed(old_key: String, new_key: String)

func _ready() -> void:
	index_scenes()
	if cache_mode == CacheMode.PRELOAD_ALL:
		_preload_all()

func index_scenes() -> void:
	_paths.clear()
	_cache.clear()
	_stack.clear()
	_scan_dir(scenes_root)

func list_scenes() -> Array[String]:
	var keys: Array[String] = []
	for k: String in _paths.keys():
		keys.append(k)
	keys.sort()
	return keys

func has_scene(key: String) -> bool:
	return _paths.has(key)

# ⚠️ NO uses get_path() porque existe en Node. Cambiamos el nombre:
func get_scene_path(key: String) -> String:
	if not _paths.has(key):
		return ""
	return _paths[key]

func change_to(key: String, data: Variant = null) -> void:
	await _change(key, true, data)

func reload_current() -> void:
	if _stack.is_empty():
		return
	var current: String = _stack.back()
	await _change(current, false, _payload)

func back() -> void:
	if _stack.size() < 2:
		return
	_stack.pop_back()
	var prev: String = _stack.back()
	await _change(prev, false, _payload)

func set_payload(data: Variant) -> void:
	_payload = data

func consume_payload() -> Variant:
	var d: Variant = _payload
	_payload = null
	return d

# -------------------------
# Internals
# -------------------------

func _change(key: String, push_stack: bool, data: Variant) -> void:
	key = key.strip_edges()

	if not _paths.has(key):
		push_error("ScenesManager: no existe la escena '" + key + "'. Escaneado en: " + scenes_root)
		return

	_payload = data

	var old_key: String = ""
	if not _stack.is_empty():
		old_key = _stack.back()

	var err: int = OK
	if cache_mode == CacheMode.NONE:
		var path: String = _paths[key]
		err = get_tree().change_scene_to_file(path)
	else:
		var packed: PackedScene = _get_packed(key)
		if packed == null:
			push_error("ScenesManager: no pude cargar PackedScene para '" + key + "'")
			return
		err = get_tree().change_scene_to_packed(packed)

	if err != OK:
		push_error("ScenesManager: error al cambiar a '" + key + "' (err=" + str(err) + ")")
		return

	if push_stack:
		_stack.append(key)

	scene_changed.emit(old_key, key)

func _get_packed(key: String) -> PackedScene:
	if _cache.has(key):
		return _cache[key]

	var path: String = _paths[key]
	var packed: PackedScene = load(path) as PackedScene
	if packed != null and cache_mode != CacheMode.NONE:
		_cache[key] = packed
	return packed

func _preload_all() -> void:
	for key: String in _paths.keys():
		_get_packed(key)

func _scan_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("ScenesManager: no puedo abrir carpeta: " + dir_path)
		return

	dir.list_dir_begin()
	var name: String = dir.get_next()

	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue

		var full: String = dir_path.path_join(name)

		if dir.current_is_dir():
			_scan_dir(full)
		else:
			if name.get_extension() == "tscn":
				var key: String = _make_key(full, name)
				if _paths.has(key):
					push_warning("ScenesManager: clave duplicada '" + key + "' -> " + full)
				else:
					_paths[key] = full

		name = dir.get_next()

	dir.list_dir_end()

func _make_key(full_path: String, file_name: String) -> String:
	if use_subfolder_keys:
		var rel: String = full_path
		var prefix: String = scenes_root + "/"
		if rel.begins_with(prefix):
			rel = rel.substr(prefix.length())
		rel = rel.trim_suffix(".tscn")
		return rel
	else:
		return file_name.get_basename()
