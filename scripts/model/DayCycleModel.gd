class_name DayCycleModel
extends RefCounted

var current_day: int = 1
var current_phase: String = "morning"
var max_day: int = 30
var phase_defs: Dictionary = {}

func setup_from_config(config: Dictionary) -> void:
	phase_defs.clear()
	for entry in config.get("phases", []):
		var phase_id: String = entry.get("id", "")
		if phase_id.is_empty():
			continue
		phase_defs[phase_id] = entry
	if not phase_defs.has(current_phase) and not phase_defs.is_empty():
		current_phase = str(phase_defs.keys()[0])

func next_day() -> void:
	current_day += 1
	current_phase = "morning"

func set_phase(phase: String) -> void:
	current_phase = phase
