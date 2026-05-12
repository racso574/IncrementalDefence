extends Node

const CURRENT_VERSION := 1
const DEFAULT_SLOT := 0

var data: SaveData
var slot: int = DEFAULT_SLOT

func _ready() -> void:
	load_slot(DEFAULT_SLOT)

# ---------------- Slots ----------------
func _path_for_slot(s: int) -> String:
	return "user://save_slot_%d.tres" % s

func load_slot(s: int) -> SaveData:
	slot = s
	data = _load_or_create(_path_for_slot(slot))
	return data

func save_slot(s: int = -1) -> void:
	if s != -1:
		slot = s
	_save_to_path(_path_for_slot(slot))

func reset_slot(s: int = -1) -> void:
	if s != -1:
		slot = s
	data = _create_default(slot)
	save_slot(slot)

func slot_exists(s: int) -> bool:
	return ResourceLoader.exists(_path_for_slot(s))

# ---------------- API tipo PlayerPrefs ----------------
func set_setting(key: String, value) -> void:
	data.settings[key] = value

func get_setting(key: String, default_value = null):
	return data.settings.get(key, default_value)

func set_state(key: String, value) -> void:
	data.state[key] = value

func get_state(key: String, default_value = null):
	return data.state.get(key, default_value)

# ---------------- Entidades ----------------
func clear_entities() -> void:
	data.entities.clear()

func add_entity_dict(d: Dictionary) -> void:
	# No imponemos esquema, solo aviso opcional
	if not d.has("type"):
		push_warning("Entidad guardada sin 'type' (permitido): %s" % d)
	data.entities.append(d)

func get_entities() -> Array[Dictionary]:
	return data.entities

# ---------------- Carga / Guardado ----------------
func _load_or_create(path: String) -> SaveData:
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is SaveData:
			var sdata: SaveData = loaded
			_sanitize(sdata, slot)
			return sdata
		push_error("El save existe pero no es SaveData. Creo uno nuevo.")
	var fresh := _create_default(slot)
	_sanitize(fresh, slot)
	return fresh

func _save_to_path(path: String) -> void:
	if data == null:
		push_error("SaveSystem.data es null, no se puede guardar.")
		return

	_sanitize(data, slot)
	_update_meta_before_save(data)

	# Encode para asegurar que lo guardado en dicts/arrays sea estable
	data.settings = SaveCodec.encode(data.settings)
	data.meta = SaveCodec.encode(data.meta)
	data.state = SaveCodec.encode(data.state)
	data.entities = _encode_entities(data.entities)

	data.version = CURRENT_VERSION
	var err := ResourceSaver.save(data, path)
	if err != OK:
		push_error("Error guardando save: %s" % err)

	# Dejar decodificado en RAM para usarlo cómodo
	data.settings = SaveCodec.decode(data.settings)
	data.meta = SaveCodec.decode(data.meta)
	data.state = SaveCodec.decode(data.state)
	data.entities = _decode_entities(data.entities)

# ---------------- Defaults / Saneado / Migración ----------------
func _create_default(s: int) -> SaveData:
	var sd := SaveData.new()
	sd.version = CURRENT_VERSION

	sd.settings = {
		"master_volume": 1.0,
		"fullscreen": false,
		"language": "es"
	}

	var now := int(Time.get_unix_time_from_system())
	sd.meta = {
		"slot": s,
		"created_at_unix": now,
		"updated_at_unix": now,
		"playtime_sec": 0,
		"display_name": ""
	}

	sd.state = {
		"currencies": {
			"gold": 0,
			"silver": 0,
			"bronze": 0
		},
		"wave": 1
	}

	sd.entities = []
	return sd

func _sanitize(sd: SaveData, s: int) -> void:
	if sd.settings == null or typeof(sd.settings) != TYPE_DICTIONARY:
		sd.settings = {}
	if sd.meta == null or typeof(sd.meta) != TYPE_DICTIONARY:
		sd.meta = {}
	if sd.state == null or typeof(sd.state) != TYPE_DICTIONARY:
		sd.state = {}
	if sd.entities == null or typeof(sd.entities) != TYPE_ARRAY:
		sd.entities = []

	# Decodificar por si viene encoded del archivo
	sd.settings = SaveCodec.decode(sd.settings)
	sd.meta = SaveCodec.decode(sd.meta)
	sd.state = SaveCodec.decode(sd.state)
	sd.entities = _decode_entities(sd.entities)

	# Rellenar defaults sin pisar lo existente
	var def := _create_default(s)
	for k in def.settings.keys():
		if not sd.settings.has(k):
			sd.settings[k] = def.settings[k]
	for k in def.meta.keys():
		if not sd.meta.has(k):
			sd.meta[k] = def.meta[k]
	for k in def.state.keys():
		if not sd.state.has(k):
			sd.state[k] = def.state[k]

	if typeof(sd.state.get("currencies", null)) != TYPE_DICTIONARY:
		sd.state["currencies"] = {}

	var currencies: Dictionary = sd.state["currencies"]
	var default_currencies: Dictionary = def.state["currencies"]
	for currency_id in default_currencies.keys():
		if not currencies.has(currency_id):
			currencies[currency_id] = default_currencies[currency_id]


	# Asegurar meta.slot correcto (opcional, útil)
	sd.meta["slot"] = s

	# Limpieza suave: entities deben ser Dictionary
	var cleaned: Array[Dictionary] = []
	for e in sd.entities:
		if typeof(e) == TYPE_DICTIONARY:
			cleaned.append(e)
		else:
			push_warning("Entidad inválida ignorada (no Dictionary): %s" % e)
	sd.entities = cleaned

func _encode_entities(source: Array) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for entry in source:
		var encoded_entry: Variant = SaveCodec.encode(entry)
		if typeof(encoded_entry) == TYPE_DICTIONARY:
			encoded.append(encoded_entry)
		else:
			push_warning("Entidad no codificable ignorada: %s" % entry)
	return encoded

func _decode_entities(source: Array) -> Array[Dictionary]:
	var decoded: Array[Dictionary] = []
	for entry in source:
		var decoded_entry: Variant = SaveCodec.decode(entry)
		if typeof(decoded_entry) == TYPE_DICTIONARY:
			decoded.append(decoded_entry)
		else:
			push_warning("Entidad inválida tras decode ignorada: %s" % entry)
	return decoded

	# Aquí pondrás migraciones reales cuando subas CURRENT_VERSION


func _update_meta_before_save(sd: SaveData) -> void:
	var now := int(Time.get_unix_time_from_system())
	if not sd.meta.has("created_at_unix") or int(sd.meta["created_at_unix"]) == 0:
		sd.meta["created_at_unix"] = now
	sd.meta["updated_at_unix"] = now

# ==========================================================
# Codec universal (encode/decode)
# ==========================================================
class SaveCodec:
	static func encode(value):
		match typeof(value):
			TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				return value

			TYPE_VECTOR2:
				var v: Vector2 = value
				return {"__type": "Vector2", "x": v.x, "y": v.y}

			TYPE_VECTOR3:
				var v3: Vector3 = value
				return {"__type": "Vector3", "x": v3.x, "y": v3.y, "z": v3.z}

			TYPE_COLOR:
				var c: Color = value
				return {"__type": "Color", "r": c.r, "g": c.g, "b": c.b, "a": c.a}

			TYPE_ARRAY:
				var arr: Array = value
				var out: Array = []
				out.resize(arr.size())
				for i in arr.size():
					out[i] = encode(arr[i])
				return out

			TYPE_DICTIONARY:
				var d: Dictionary = value
				var out_d: Dictionary = {}
				for k in d.keys():
					var key = k
					if typeof(key) not in [TYPE_STRING, TYPE_INT]:
						key = str(key)
					out_d[key] = encode(d[k])
				return out_d

			_:
				return {"__type": "Stringified", "value": str(value)}

	static func decode(value):
		match typeof(value):
			TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				return value

			TYPE_ARRAY:
				var arr: Array = value
				var out: Array = []
				out.resize(arr.size())
				for i in arr.size():
					out[i] = decode(arr[i])
				return out

			TYPE_DICTIONARY:
				var d: Dictionary = value
				if d.has("__type") and typeof(d["__type"]) == TYPE_STRING:
					match String(d["__type"]):
						"Vector2":
							return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
						"Vector3":
							return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
						"Color":
							return Color(float(d.get("r", 1.0)), float(d.get("g", 1.0)), float(d.get("b", 1.0)), float(d.get("a", 1.0)))
						"Stringified":
							return d.get("value", "")
						_:
							pass

				var out_d: Dictionary = {}
				for k in d.keys():
					out_d[k] = decode(d[k])
				return out_d

			_:
				return value
