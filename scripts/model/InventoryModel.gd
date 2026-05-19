class_name InventoryModel
extends RefCounted

var item_defs: Dictionary = {}
var items: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	item_defs.clear()
	items.clear()
	for entry in config.get("items", []):
		var item_id: String = entry.get("id", "")
		if item_id.is_empty():
			continue
		item_defs[item_id] = entry
		items[item_id] = entry.get("default", 0)

func add_item(item_id: String, amount: int) -> void:
	set_amount(item_id, get_amount(item_id) + amount)

func set_amount(item_id: String, value: int) -> void:
	if not item_defs.has(item_id):
		items[item_id] = value
		return
	var entry: Dictionary = item_defs[item_id]
	var min_value: int = int(entry.get("min", 0))
	items[item_id] = max(value, min_value)

func get_amount(item_id: String) -> int:
	return int(items.get(item_id, 0))

func get_display_value_map(order: Array) -> Array:
	var result: Array = []
	for item_id_variant in order:
		var item_id: String = str(item_id_variant)
		var entry: Dictionary = item_defs.get(item_id, {})
		result.append({
			"id": item_id,
			"name": entry.get("name", item_id),
			"value": get_amount(item_id)
		})
	return result
