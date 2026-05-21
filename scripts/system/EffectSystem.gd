class_name EffectSystem
extends RefCounted

var _app: App
var _effect_config_path := "res://configs/tables/effect_table.json"
var _effect_map: Dictionary = {}

func _init(app: App) -> void:
	_app = app
	_refresh_effect_map()

func _refresh_effect_map() -> void:
	_effect_map.clear()
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var config: Dictionary = config_service.load_json(_effect_config_path)
	for effect in config.get("effects", []):
		var effect_id: String = effect.get("id", "")
		if effect_id.is_empty():
			continue
		_effect_map[effect_id] = effect

func apply_effects(effect_ids: Array) -> Array:
	var applied: Array = []
	for effect_id_variant in effect_ids:
		var effect_id: String = str(effect_id_variant)
		var effect: Dictionary = _effect_map.get(effect_id, {})
		if effect.is_empty():
			continue
		_apply_single_effect(effect)
		applied.append(effect)
	return applied

func _apply_single_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	var target_id: String = effect.get("target_id", "")
	var raw_value: Variant = effect.get("value", 0)
	var value: int = int(raw_value)
	match effect_type:
		"stat_delta":
			var player_model: PlayerModel = _app.architecture.get_model(&"player")
			player_model.apply_stat_delta(target_id, value)
		"item_delta":
			var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
			inventory_model.add_item(target_id, value)
		"set_flag":
			var flag_model: FlagModel = _app.architecture.get_model(&"flag")
			flag_model.set_flag(target_id, bool(raw_value))
		"clear_flag":
			var clear_flag_model: FlagModel = _app.architecture.get_model(&"flag")
			clear_flag_model.set_flag(target_id, false)
		"unlock_option":
			var option_unlock_model: OptionUnlockModel = _app.architecture.get_model(&"option_unlock")
			option_unlock_model.set_unlocked(target_id, true)
		"relation_delta":
			var relation_model: RefCounted = _app.architecture.get_model(&"relation")
			relation_model.add_score(target_id, value)
		"debt_delta":
			var debt_model: DebtModel = _app.architecture.get_model(&"debt")
			debt_model.apply_delta(target_id, value)
		"set_phase":
			var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
			day_model.set_phase(str(raw_value))
