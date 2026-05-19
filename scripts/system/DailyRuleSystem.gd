class_name DailyRuleSystem
extends RefCounted

var _app: App
var _config_path := "res://configs/gameplay/daily_rules.json"

func _init(app: App) -> void:
	_app = app

func apply_daily_rules() -> Array:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var condition_system: ConditionSystem = _app.architecture.get_system(&"condition")
	var effect_system: EffectSystem = _app.architecture.get_system(&"effect")
	var config: Dictionary = config_service.load_json(_config_path)
	var results: Array = []
	for rule_variant in config.get("rules", []):
		var rule: Dictionary = rule_variant
		if not condition_system.check_all(rule.get("conditions", [])):
			continue
		var applied_effects: Array = effect_system.apply_effects(rule.get("effects", []))
		results.append({
			"id": rule.get("id", ""),
			"name": rule.get("name", ""),
			"effects": applied_effects
		})
	return results
