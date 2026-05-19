class_name QGFArchitecture
extends RefCounted

const QGFEventBusScript := preload("res://addons/qgf/core/qgf_event_bus.gd")
const QGFCommandDispatcherScript := preload("res://addons/qgf/core/qgf_command_dispatcher.gd")

var owner: Node
var event_bus: RefCounted
var command_dispatcher: RefCounted
var models: Dictionary = {}
var systems: Dictionary = {}
var services: Dictionary = {}

func _init(app_owner: Node) -> void:
	owner = app_owner
	event_bus = QGFEventBusScript.new()
	command_dispatcher = QGFCommandDispatcherScript.new(app_owner)

func register_model(key: StringName, model: RefCounted) -> void:
	models[key] = model

func get_model(key: StringName) -> Variant:
	return models.get(key)

func require_model(key: StringName) -> RefCounted:
	return _require_from(models, key, "model")

func register_system(key: StringName, system: RefCounted) -> void:
	systems[key] = system

func get_system(key: StringName) -> Variant:
	return systems.get(key)

func require_system(key: StringName) -> RefCounted:
	return _require_from(systems, key, "system")

func register_service(key: StringName, service: RefCounted) -> void:
	services[key] = service

func get_service(key: StringName) -> Variant:
	return services.get(key)

func require_service(key: StringName) -> RefCounted:
	return _require_from(services, key, "service")

func unregister_model(key: StringName) -> void:
	models.erase(key)

func unregister_system(key: StringName) -> void:
	systems.erase(key)

func unregister_service(key: StringName) -> void:
	services.erase(key)

func clear_runtime() -> void:
	models.clear()
	systems.clear()
	services.clear()
	event_bus.clear()

func _require_from(registry: Dictionary, key: StringName, kind: String) -> RefCounted:
	var value: Variant = registry.get(key)
	if value == null:
		push_error("QGFArchitecture missing %s: %s" % [kind, key])
		return null
	return value as RefCounted
