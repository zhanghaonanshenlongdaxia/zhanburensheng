class_name NpcEventSystem
extends RefCounted

var _app: App
var _config_path := "res://configs/events/npc_event_pool.json"

func _init(app: App) -> void:
	_app = app

func trigger_random_event() -> Dictionary:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var condition_system: ConditionSystem = _app.architecture.get_system(&"condition")
	var effect_system: EffectSystem = _app.architecture.get_system(&"effect")
	var config: Dictionary = config_service.load_json(_config_path)
	var candidates: Array = []
	for event_variant in config.get("events", []):
		var event_data: Dictionary = event_variant
		if condition_system.check_all(event_data.get("conditions", [])):
			candidates.append(event_data)
	if candidates.is_empty():
		return {}
	var picked: Dictionary = _pick_by_weight(candidates)
	var applied_effects: Array = effect_system.apply_effects(picked.get("effects", []))
	return {
		"event_id": picked.get("id", ""),
		"name": picked.get("name", ""),
		"result_text": picked.get("result_text", ""),
		"effects": applied_effects
	}

func _pick_by_weight(candidates: Array) -> Dictionary:
	var total_weight: int = 0
	for event_data in candidates:
		total_weight += int(event_data.get("weight", 1))
	if total_weight <= 0:
		return candidates[0]
	var roll: int = randi_range(1, total_weight)
	var cursor: int = 0
	for event_data in candidates:
		cursor += int(event_data.get("weight", 1))
		if roll <= cursor:
			return event_data
	return candidates[0]
