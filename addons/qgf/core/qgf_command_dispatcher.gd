class_name QGFCommandDispatcher
extends RefCounted

var owner: Node

func _init(app_owner: Node) -> void:
	owner = app_owner

func dispatch(command_script: Script, payload: Dictionary = {}) -> Variant:
	if command_script == null:
		push_error("QGFCommandDispatcher.dispatch received a null command script.")
		return null
	var command: RefCounted = command_script.new(owner) as RefCounted
	if command == null:
		push_error("QGFCommandDispatcher failed to create command: %s" % command_script.resource_path)
		return null
	if not command.has_method("execute"):
		push_error("Command has no execute method: %s" % command_script.resource_path)
		return null
	return command.execute(payload)
