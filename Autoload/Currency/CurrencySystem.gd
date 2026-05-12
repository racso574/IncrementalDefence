extends Node

const CURRENCY_START_AMOUNTS := {
	"gold": 0,
	"silver": 0,
	"bronze": 0
}

signal currency_changed(currency_id: String, new_amount: int, delta: int)

func _ready() -> void:
	_ensure_storage()

func has_currency(currency_id: String) -> bool:
	if currency_id.is_empty():
		return false
	return CURRENCY_START_AMOUNTS.has(currency_id)

func get_amount(currency_id: String) -> int:
	if currency_id.is_empty():
		return 0
	return int(_get_currencies().get(currency_id, 0))

func set_amount(currency_id: String, amount: int) -> void:
	if not _is_currency_id_valid(currency_id):
		return
	_apply_amount(currency_id, maxi(amount, 0))

func add_currency(currency_id: String, amount: int) -> void:
	if not _is_currency_id_valid(currency_id):
		return
	if amount < 0:
		push_warning("CurrencySystem.add_currency no acepta cantidades negativas.")
		return
	_apply_amount(currency_id, get_amount(currency_id) + amount)

func remove_currency(currency_id: String, amount: int) -> void:
	if not _is_currency_id_valid(currency_id):
		return
	if amount < 0:
		push_warning("CurrencySystem.remove_currency no acepta cantidades negativas.")
		return
	_apply_amount(currency_id, maxi(get_amount(currency_id) - amount, 0))

func spend_currency(currency_id: String, amount: int) -> bool:
	if not _is_currency_id_valid(currency_id):
		return false
	if amount < 0:
		push_warning("CurrencySystem.spend_currency no acepta cantidades negativas.")
		return false

	var current_amount := get_amount(currency_id)
	if current_amount < amount:
		return false

	_apply_amount(currency_id, current_amount - amount)
	return true

func _is_currency_id_valid(currency_id: String) -> bool:
	if currency_id.is_empty():
		push_warning("CurrencySystem requiere un currency_id no vacio.")
		return false
	if not CURRENCY_START_AMOUNTS.has(currency_id):
		push_warning("CurrencySystem: currency_id no registrada: %s" % currency_id)
		return false
	return true

func _ensure_storage() -> Dictionary:
	if SaveSystem.data == null:
		SaveSystem.load_slot(SaveSystem.slot)

	if typeof(SaveSystem.data.state) != TYPE_DICTIONARY:
		SaveSystem.data.state = {}

	if typeof(SaveSystem.data.state.get("currencies", null)) != TYPE_DICTIONARY:
		SaveSystem.data.state["currencies"] = {}

	var currencies: Dictionary = SaveSystem.data.state["currencies"]
	for currency_id in CURRENCY_START_AMOUNTS.keys():
		if not currencies.has(currency_id):
			currencies[currency_id] = int(CURRENCY_START_AMOUNTS[currency_id])

	return currencies

func _get_currencies() -> Dictionary:
	return _ensure_storage()

func _apply_amount(currency_id: String, new_amount: int) -> void:
	var currencies := _get_currencies()
	var previous_amount := int(currencies.get(currency_id, 0))
	var final_amount: int = maxi(new_amount, 0)
	if previous_amount == final_amount:
		return

	currencies[currency_id] = final_amount
	currency_changed.emit(currency_id, final_amount, final_amount - previous_amount)
