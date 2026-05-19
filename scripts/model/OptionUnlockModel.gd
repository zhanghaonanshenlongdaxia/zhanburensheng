class_name OptionUnlockModel
extends RefCounted

var option_states: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	option_states.clear()
	for entry in config.get("options", []):
		var option_id: String = entry.get("id", "")
		if option_id.is_empty():
			continue
		option_states[option_id] = bool(entry.get("unlocked", false))

func is_unlocked(option_id: String, default_value: bool = true) -> bool:
	return bool(option_states.get(option_id, default_value))

func set_unlocked(option_id: String, unlocked: bool) -> void:
	option_states[option_id] = unlocked
