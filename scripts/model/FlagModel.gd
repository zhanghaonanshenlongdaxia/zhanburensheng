class_name FlagModel
extends RefCounted

var flag_defs: Dictionary = {}
var flags: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	flag_defs.clear()
	flags.clear()
	for entry in config.get("flags", []):
		var flag_id: String = entry.get("id", "")
		if flag_id.is_empty():
			continue
		flag_defs[flag_id] = entry
		flags[flag_id] = bool(entry.get("default", false))

func get_flag(flag_id: String, default_value: bool = false) -> bool:
	return bool(flags.get(flag_id, default_value))

func set_flag(flag_id: String, value: bool) -> void:
	flags[flag_id] = value

func get_display_entries() -> Array:
	var result: Array = []
	for flag_id in flag_defs.keys():
		var entry: Dictionary = flag_defs.get(flag_id, {})
		if not get_flag(flag_id):
			continue
		result.append({
			"id": flag_id,
			"name": entry.get("name", flag_id),
			"value": "是"
		})
	return result
