class_name FortuneSelectionModel
extends RefCounted

var options: Array = []
var selected_option: Dictionary = {}

func set_options(new_options: Array) -> void:
	options = new_options
	selected_option = {}

func select_by_index(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	selected_option = options[index]
