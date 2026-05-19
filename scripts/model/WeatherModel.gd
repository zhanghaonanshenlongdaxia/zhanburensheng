class_name WeatherModel
extends RefCounted

var current_weather: Dictionary = {}

func set_weather(weather_data: Dictionary) -> void:
	current_weather = weather_data.duplicate(true)

func get_weather_id() -> String:
	return str(current_weather.get("id", ""))

func get_weather_name() -> String:
	return str(current_weather.get("name", "未知"))

func get_tags() -> Array:
	return current_weather.get("tags", [])

func get_blocked_locations() -> Array:
	return current_weather.get("blocked_locations", [])
