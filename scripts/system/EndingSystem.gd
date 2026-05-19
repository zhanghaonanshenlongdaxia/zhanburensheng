class_name EndingSystem
extends RefCounted

var _app: App
var _config_path := "res://configs/gameplay/ending_config.json"

func _init(app: App) -> void:
	_app = app

func check_ending() -> Dictionary:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var condition_system: ConditionSystem = _app.architecture.get_system(&"condition")
	var config: Dictionary = config_service.load_json(_config_path)
	for ending_variant in config.get("endings", []):
		var ending: Dictionary = ending_variant
		if condition_system.check_all(ending.get("conditions", [])):
			return ending
	return {}
