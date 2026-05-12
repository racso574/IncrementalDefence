extends Label
class_name CurrencyValueLabel

@export var currency_id: String = "gold"
@export var prefix: String = ""
@export var suffix: String = ""
@export var show_currency_name: bool = false
@export var currency_name_separator: String = ": "
@export var animation_duration: float = 0.18

var _displayed_amount: float = 0.0
var _display_tween: Tween

func _ready() -> void:
	CurrencySystem.currency_changed.connect(_on_currency_changed)
	_displayed_amount = float(CurrencySystem.get_amount(currency_id))
	_refresh()

func _refresh() -> void:
	var amount := int(round(_displayed_amount))
	if show_currency_name:
		text = "%s%s%s%d%s" % [
			prefix,
			currency_id.capitalize(),
			currency_name_separator,
			amount,
			suffix
		]
	else:
		text = "%s%d%s" % [prefix, amount, suffix]

func _on_currency_changed(changed_currency_id: String, _new_amount: int, _delta: int) -> void:
	if changed_currency_id != currency_id:
		return
	_animate_to(float(_new_amount))

func _animate_to(target_amount: float) -> void:
	if _display_tween != null:
		_display_tween.kill()

	if animation_duration <= 0.0:
		_displayed_amount = target_amount
		_refresh()
		return

	_display_tween = create_tween()
	_display_tween.tween_method(_set_displayed_amount, _displayed_amount, target_amount, animation_duration)

func _set_displayed_amount(value: float) -> void:
	_displayed_amount = value
	_refresh()
