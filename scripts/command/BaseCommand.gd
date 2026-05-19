class_name BaseCommand
extends "res://addons/qgf/command/qgf_base_command.gd"

var app: App

func _init(owner: App) -> void:
	super(owner)
	app = owner

func execute(_payload: Dictionary = {}) -> Variant:
	return null
