class_name ActionResolveSystem
extends RefCounted

var _app: App
var _event_config_path := "res://configs/events/outdoor_event_pool.json"

func _init(app: App) -> void:
	_app = app

func resolve_selected_action(selected_option: Dictionary, exploration_action: String = "follow_omen") -> Dictionary:
	if selected_option.is_empty():
		return {}
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var condition_system: ConditionSystem = _app.architecture.get_system(&"condition")
	var effect_system: EffectSystem = _app.architecture.get_system(&"effect")
	var weather_model: WeatherModel = _app.architecture.get_model(&"weather")
	if exploration_action == "withdraw":
		var withdraw_effects: Array = effect_system.apply_effects(["lose_suspicion_small"])
		return {
			"title": selected_option.get("omen_title", selected_option.get("title", "未知行动")),
			"result_text": "你把今日卦象压在心里，没有贸然出门。屋外风声过去，少了几分被人盯上的风险，但这道机缘也随天色散了。",
			"weather_name": weather_model.get_weather_name(),
			"exploration_action": exploration_action,
			"effects": withdraw_effects
		}
	var config: Dictionary = config_service.load_json(_event_config_path)
	var candidates: Array = []
	for event_data in config.get("events", []):
		if not _matches_option(event_data, selected_option):
			continue
		if not _matches_location(event_data, selected_option):
			continue
		if not condition_system.check_all(event_data.get("conditions", [])):
			continue
		candidates.append(event_data)
	if candidates.is_empty():
		var fallback_effects: Array = effect_system.apply_effects(["lose_stamina_small"])
		return {
			"title": selected_option.get("omen_title", selected_option.get("title", "未知行动")),
			"result_text": "你循着卦象所指找了半日，却只在风里绕了个空。今日没有明显收获，还白白耗了些体力。",
			"weather_name": weather_model.get_weather_name(),
			"exploration_action": exploration_action,
			"effects": fallback_effects
		}
	if exploration_action == "cautious_search" and randi_range(1, 100) > _cautious_success_chance(selected_option):
		var cautious_effects: Array = effect_system.apply_effects(["lose_stamina_small"])
		return {
			"title": selected_option.get("omen_title", selected_option.get("title", "未知行动")),
			"result_text": "你只在外围试探，没有踏进卦象最深处。一路看见些痕迹，却没敢追到底，最后只带着疲惫回了村。",
			"weather_name": weather_model.get_weather_name(),
			"exploration_action": exploration_action,
			"effects": cautious_effects
		}
	var picked: Dictionary = _pick_by_weight(candidates)
	var effect_ids: Array = picked.get("effects", [])
	if exploration_action == "cautious_search":
		effect_ids = _limit_cautious_effects(effect_ids)
	var applied_effects: Array = effect_system.apply_effects(effect_ids)
	return {
		"title": selected_option.get("omen_title", selected_option.get("title", "未知行动")),
		"event_id": picked.get("id", ""),
		"event_name": picked.get("name", ""),
		"result_text": _format_exploration_result(str(picked.get("result_text", "")), exploration_action),
		"weather_name": weather_model.get_weather_name(),
		"exploration_action": exploration_action,
		"effects": applied_effects
	}

func _cautious_success_chance(selected_option: Dictionary) -> int:
	var risk_desc: String = str(selected_option.get("risk_desc", ""))
	if risk_desc.contains("高风险"):
		return 45
	if risk_desc.contains("中风险"):
		return 60
	return 75

func _limit_cautious_effects(effect_ids: Array) -> Array:
	var result: Array = []
	for effect_id_variant in effect_ids:
		var effect_id: String = str(effect_id_variant)
		if effect_id.begins_with("gain_") or effect_id == "lose_stamina_small":
			result.append(effect_id)
	return result

func _format_exploration_result(result_text: String, exploration_action: String) -> String:
	if exploration_action == "cautious_search":
		return "你没有完全照卦象深入，只在外围慢慢摸索。%s" % result_text
	return "你照着卦象所指一路寻去。%s" % result_text

func _matches_option(event_data: Dictionary, selected_option: Dictionary) -> bool:
	var option_ids: Array = event_data.get("option_ids", [])
	if option_ids.is_empty():
		return true
	return str(selected_option.get("id", "")) in option_ids

func _matches_location(event_data: Dictionary, selected_option: Dictionary) -> bool:
	var location_ids: Array = event_data.get("location_ids", [])
	if location_ids.is_empty():
		return true
	return str(selected_option.get("location_id", "")) in location_ids

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
