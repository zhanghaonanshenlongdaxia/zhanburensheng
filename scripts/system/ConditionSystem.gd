class_name ConditionSystem
extends RefCounted

var _app: App

func _init(app: App) -> void:
	_app = app

func check_all(conditions: Array) -> bool:
	for condition_variant in conditions:
		var condition: Dictionary = condition_variant
		if not check_condition(condition):
			return false
	return true

func check_condition(condition: Dictionary) -> bool:
	var condition_type: String = condition.get("type", "")
	match condition_type:
		"all_of":
			return check_all(condition.get("conditions", []))
		"any_of":
			return _check_any(condition.get("conditions", []))
		"not":
			return not check_condition(condition.get("condition", {}))
		_:
			pass
	var target_id: String = condition.get("target_id", "")
	var operator: String = condition.get("operator", "==")
	var expected_variant: Variant = condition.get("value", 0)
	if condition_type == "weather_tag_compare":
		var tagged_weather_model: WeatherModel = _app.architecture.get_model(&"weather")
		return _compare_bool(str(expected_variant) in tagged_weather_model.get_tags(), operator, true)
	if condition_type == "location_tag_compare":
		return _compare_bool(_has_location_tag(target_id, str(expected_variant)), operator, true)
	var actual_variant: Variant = 0
	match condition_type:
		"stat_compare":
			var player_model: PlayerModel = _app.architecture.get_model(&"player")
			actual_variant = player_model.get_stat(target_id)
		"item_compare":
			var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
			actual_variant = inventory_model.get_amount(target_id)
		"flag_compare":
			var flag_model: FlagModel = _app.architecture.get_model(&"flag")
			actual_variant = flag_model.get_flag(target_id)
		"debt_compare":
			var debt_model: DebtModel = _app.architecture.get_model(&"debt")
			actual_variant = debt_model.get_value(target_id)
		"day_compare":
			var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
			actual_variant = day_model.current_day if target_id == "current_day" else day_model.max_day
		"phase_compare":
			var phase_day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
			actual_variant = phase_day_model.current_phase
		"weather_compare":
			var weather_model: WeatherModel = _app.architecture.get_model(&"weather")
			actual_variant = weather_model.get_weather_id()
		_:
			return false
	if actual_variant is bool or expected_variant is bool:
		return _compare_bool(bool(actual_variant), operator, bool(expected_variant))
	if actual_variant is String or expected_variant is String:
		return _compare_string(str(actual_variant), operator, str(expected_variant))
	return _compare(int(actual_variant), operator, int(expected_variant))

func _compare(actual_value: int, operator: String, expected_value: int) -> bool:
	match operator:
		">":
			return actual_value > expected_value
		">=":
			return actual_value >= expected_value
		"<":
			return actual_value < expected_value
		"<=":
			return actual_value <= expected_value
		"!=":
			return actual_value != expected_value
	return actual_value == expected_value

func _compare_string(actual_value: String, operator: String, expected_value: String) -> bool:
	if operator == "!=":
		return actual_value != expected_value
	return actual_value == expected_value

func _compare_bool(actual_value: bool, operator: String, expected_value: bool) -> bool:
	if operator == "!=":
		return actual_value != expected_value
	return actual_value == expected_value

func _check_any(conditions: Array) -> bool:
	for condition_variant in conditions:
		var condition: Dictionary = condition_variant
		if check_condition(condition):
			return true
	return false

func _has_location_tag(location_id: String, tag: String) -> bool:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var config: Dictionary = config_service.get_cached("res://configs/tables/location_table.json")
	for location_variant in config.get("locations", []):
		var location: Dictionary = location_variant
		if str(location.get("id", "")) != location_id:
			continue
		return tag in location.get("tags", [])
	return false
