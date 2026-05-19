class_name PlayerModel
extends RefCounted

var stat_defs: Dictionary = {}
var stats: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	stat_defs.clear()
	stats.clear()
	for entry in config.get("stats", []):
		var stat_id: String = entry.get("id", "")
		if stat_id.is_empty():
			continue
		stat_defs[stat_id] = entry
		stats[stat_id] = entry.get("default", 0)

func get_stat(stat_id: String, default_value: int = 0) -> int:
	return int(stats.get(stat_id, default_value))

func set_stat(stat_id: String, value: int) -> void:
	if not stat_defs.has(stat_id):
		stats[stat_id] = value
		return
	var entry: Dictionary = stat_defs[stat_id]
	var min_value: int = int(entry.get("min", -999999))
	var max_value: int = int(entry.get("max", 999999))
	stats[stat_id] = clamp(value, min_value, max_value)

func apply_stat_delta(stat_id: String, delta: int) -> void:
	set_stat(stat_id, get_stat(stat_id) + delta)

func get_display_value_map(order: Array) -> Array:
	var result: Array = []
	for stat_id_variant in order:
		var stat_id: String = str(stat_id_variant)
		var entry: Dictionary = stat_defs.get(stat_id, {})
		result.append({
			"id": stat_id,
			"name": entry.get("name", stat_id),
			"value": get_stat(stat_id)
		})
	return result
