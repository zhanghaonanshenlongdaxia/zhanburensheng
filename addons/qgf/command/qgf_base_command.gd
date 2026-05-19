class_name QGFBaseCommand
extends RefCounted

var owner: Node

func _init(app_owner: Node) -> void:
	owner = app_owner

func get_architecture() -> RefCounted:
	if owner == null:
		return null
	return owner.get("architecture") as RefCounted

func execute(_payload: Dictionary = {}) -> Variant:
	return null
