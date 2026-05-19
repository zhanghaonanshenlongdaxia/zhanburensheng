class_name StartGameCommand
extends BaseCommand

func execute(_payload: Dictionary = {}) -> Variant:
	app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/StartNewDayCommand.gd"))
	return true
