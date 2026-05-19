class_name SelectFortuneCommand
extends BaseCommand

func execute(payload: Dictionary = {}) -> Variant:
	var index: int = payload.get("index", -1)
	var fortune_model: FortuneSelectionModel = app.architecture.get_model(&"fortune")
	fortune_model.select_by_index(index)
	app.architecture.event_bus.publish(&"fortune_selected", {
		"selected": fortune_model.selected_option
	})
	return fortune_model.selected_option
