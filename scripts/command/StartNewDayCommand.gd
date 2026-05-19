class_name StartNewDayCommand
extends BaseCommand

func execute(_payload: Dictionary = {}) -> Variant:
	var day_model: DayCycleModel = app.architecture.get_model(&"day_cycle")
	day_model.set_phase("morning")
	var weather_system: WeatherSystem = app.architecture.get_system(&"weather")
	var fortune_system: FortuneSystem = app.architecture.get_system(&"fortune")
	var weather_data: Dictionary = weather_system.roll_today_weather()
	var fortune_options: Array = fortune_system.generate_daily_options(3)
	app.architecture.event_bus.publish(&"day_started", {
		"day": day_model.current_day,
		"phase": day_model.current_phase,
		"weather": weather_data,
		"options": fortune_options
	})
	return true
