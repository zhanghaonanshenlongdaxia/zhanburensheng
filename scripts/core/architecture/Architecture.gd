class_name Architecture
extends "res://addons/qgf/core/qgf_architecture.gd"

const EventBusScript := preload("res://scripts/core/architecture/EventBus.gd")
const CommandDispatcherScript := preload("res://scripts/core/architecture/CommandDispatcher.gd")

var app: App

func _init(owner: App) -> void:
	super(owner)
	app = owner
	event_bus = EventBusScript.new()
	command_dispatcher = CommandDispatcherScript.new(owner)
