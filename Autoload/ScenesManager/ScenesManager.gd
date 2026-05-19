extends Node

const SCENE_REGISTRY := {
	"Menu": "res://Scenes/Menu.tscn",
	"Game": "res://Scenes/Game.tscn",
	"GameTest": "res://Scenes/GameTest.tscn",
	"Options": "res://Scenes/Options.tscn",
	"UpgradeMenu": "res://Scenes/UpgradeMenu.tscn",
	"AbilitiesDebugMenu": "res://Scenes/AbilitiesDebugMenu.tscn"
}

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
	for key in SCENE_REGISTRY.keys():
		var scene_path: String = String(SCENE_REGISTRY[key])
		if not ResourceLoader.exists(scene_path):
			push_error("ScenesManager: no existe la escena registrada '" + key + "' -> " + scene_path)
			continue
		_paths[String(key)] = scene_path
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
		push_error("ScenesManager: no existe la escena registrada '" + key + "'.")
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

func _key_from_path(path: String) -> String:
	for key: String in _paths.keys():
		if _paths[key] == path:
			return key
	return ""
