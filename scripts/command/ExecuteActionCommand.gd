class_name ExecuteActionCommand
extends BaseCommand

func execute(payload: Dictionary = {}) -> Variant:
	var fortune_model: FortuneSelectionModel = app.architecture.get_model(&"fortune")
	var action_system: ActionResolveSystem = app.architecture.get_system(&"action_resolve")
	var selected_option: Dictionary = fortune_model.selected_option
	var exploration_action: String = str(payload.get("exploration_action", "follow_omen"))
	var result: Dictionary = action_system.resolve_selected_action(selected_option, exploration_action)
	app.architecture.event_bus.publish(&"action_resolved", result)
	app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/ResolveDayCommand.gd"))
	return result
