extends Node
class_name ScenesManager

@export var scenes_root: String = "res://Scenes"
@export var use_subfolder_keys: bool = false

enum CacheMode { NONE, ON_DEMAND, PRELOAD_ALL }
@export var cache_mode: CacheMode = CacheMode.ON_DEMAND

# Tipado para evitar Variant warnings
var _paths: Dictionary[String, String] = {}          # key -> path
var _cache: Dictionary[String, PackedScene] = {}     # key -> PackedScene

var _payload: Variant = null
var _current_key: String = ""
var _previous_key: String = ""

signal scene_changed(old_key: String, new_key: String)

func _ready() -> void:
	index_scenes()
	if cache_mode == CacheMode.PRELOAD_ALL:
		_preload_all()

func index_scenes() -> void:
	_paths.clear()
	_cache.clear()
	_current_key = ""
	_previous_key = ""
	_scan_dir(scenes_root)
	_sync_current_from_tree()

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
	_change(key, true, data)

func reload_current() -> void:
	_sync_current_from_tree()
	if _current_key == "":
		return
	_change(_current_key, false, _payload)

func back() -> void:
	_sync_current_from_tree()
	if _previous_key == "":
		return
	_change(_previous_key, true, _payload)

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
	_sync_current_from_tree()

	var old_key: String = _current_key

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
		_previous_key = old_key

	_current_key = key

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

func _sync_current_from_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var scene_path: String = tree.current_scene.scene_file_path.strip_edges()
	if scene_path == "":
		return

	var key: String = _key_from_path(scene_path)
	if key != "":
		_current_key = key

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

func _key_from_path(path: String) -> String:
	for key: String in _paths.keys():
		if _paths[key] == path:
			return key
	return ""
