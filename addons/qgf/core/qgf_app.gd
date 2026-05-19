class_name QGFApp
extends Node

const QGFArchitectureScript := preload("res://addons/qgf/core/qgf_architecture.gd")

var architecture: RefCounted

func _ready() -> void:
	add_to_group("app")
	architecture = create_architecture()
	register_services()
	register_models()
	register_systems()
	call_deferred("start_app")

func create_architecture() -> RefCounted:
	return QGFArchitectureScript.new(self)

func register_services() -> void:
	pass

func register_models() -> void:
	pass

func register_systems() -> void:
	pass

func start_app() -> void:
	pass
