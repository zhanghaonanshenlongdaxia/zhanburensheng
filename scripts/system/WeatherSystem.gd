class_name WeatherSystem
extends RefCounted

var _app: App
var _weather_config_path := "res://configs/tables/weather_table.json"

func _init(app: App) -> void:
	_app = app

func roll_today_weather() -> Dictionary:
	var config_service: ConfigService = _app.architecture.get_service(&"config")
	var weather_model: WeatherModel = _app.architecture.get_model(&"weather")
	var config: Dictionary = config_service.load_json(_weather_config_path)
	var list: Array = config.get("weathers", [])
	if list.is_empty():
		return {}
	var result: Dictionary = list[int(randi() % list.size())]
	weather_model.set_weather(result)
	return result
