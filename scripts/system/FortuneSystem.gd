class_name FortuneSystem
extends RefCounted

var _app: App
var _fortune_config_path := "res://configs/gameplay/fortune_pool.json"

func _init(app: App) -> void:
	_app = app

func generate_daily_options(count: int = 3) -> Array:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var condition_system: ConditionSystem = _app.architecture.get_system(&"condition")
	var fortune_model: FortuneSelectionModel = _app.architecture.get_model(&"fortune")
	var option_unlock_model: OptionUnlockModel = _app.architecture.get_model(&"option_unlock")
	var weather_model: WeatherModel = _app.architecture.get_model(&"weather")
	var config: Dictionary = config_service.load_json(_fortune_config_path)
	var all_options: Array = config.get("options", [])
	var blocked_locations: Array = weather_model.get_blocked_locations()
	var filtered: Array = []
	for option in all_options:
		var option_id: String = option.get("id", "")
		var location_id: String = option.get("location_id", "")
		if location_id == "town":
			continue
		if not option_unlock_model.is_unlocked(option_id, true):
			continue
		if location_id in blocked_locations:
			continue
		if not condition_system.check_all(option.get("conditions", [])):
			continue
		var weighted_option: Dictionary = option.duplicate(true)
		weighted_option["runtime_weight"] = _calculate_option_weight(weighted_option, condition_system)
		if int(weighted_option.get("runtime_weight", 0)) <= 0:
			continue
		filtered.append(weighted_option)
	var result: Array = _pick_weighted_options(filtered, count)
	fortune_model.set_options(result)
	return result

func _calculate_option_weight(option: Dictionary, condition_system: ConditionSystem) -> int:
	var weight: int = int(option.get("base_weight", 1))
	for modifier_variant in option.get("weight_modifiers", []):
		var modifier: Dictionary = modifier_variant
		if condition_system.check_all(modifier.get("conditions", [])):
			weight += int(modifier.get("delta", 0))
	return maxi(weight, 0)

func _pick_weighted_options(options: Array, count: int) -> Array:
	var pool: Array = options.duplicate(true)
	var result: Array = []
	while result.size() < count and not pool.is_empty():
		var picked: Dictionary = _pick_single_weighted(pool)
		if picked.is_empty():
			break
		result.append(picked)
		for index in range(pool.size()):
			if str(pool[index].get("id", "")) == str(picked.get("id", "")):
				pool.remove_at(index)
				break
	return result

func _pick_single_weighted(options: Array) -> Dictionary:
	var total_weight: int = 0
	for option_variant in options:
		var option: Dictionary = option_variant
		total_weight += int(option.get("runtime_weight", option.get("base_weight", 1)))
	if total_weight <= 0:
		return {}
	var roll: int = randi_range(1, total_weight)
	var cursor: int = 0
	for option_variant in options:
		var option: Dictionary = option_variant
		cursor += int(option.get("runtime_weight", option.get("base_weight", 1)))
		if roll <= cursor:
			option.erase("runtime_weight")
			return option
	return {}
