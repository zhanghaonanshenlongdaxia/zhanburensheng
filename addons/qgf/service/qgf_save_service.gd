class_name QGFSaveService
extends RefCounted

var save_dir: String = "user://saves"

func save_json(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	var path: String = _slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

func load_json(slot: String, default_value: Dictionary = {}) -> Dictionary:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return default_value
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: %s" % path)
		return default_value
	var json: JSON = JSON.new()
	var error: int = json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		push_error("Failed to parse save file: %s" % path)
		return default_value
	return json.data

func delete_save(slot: String) -> bool:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(path) == OK

func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_dir.trim_suffix("/"), slot]
