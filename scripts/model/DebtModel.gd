class_name DebtModel
extends RefCounted

var debt_data: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	debt_data = config.get("debt", {}).duplicate(true)

func get_value(key: String, default_value: int = 0) -> int:
	return int(debt_data.get(key, default_value))

func set_value(key: String, value: int) -> void:
	debt_data[key] = max(value, 0)

func apply_delta(key: String, delta: int) -> void:
	set_value(key, get_value(key) + delta)

func get_display_entries() -> Array:
	return [
		{
			"id": "current",
			"name": "欠债",
			"value": get_value("current")
		},
		{
			"id": "due_day",
			"name": "催债日",
			"value": get_value("due_day")
		}
	]
