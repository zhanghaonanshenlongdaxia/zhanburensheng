class_name QGFConfigService
extends RefCounted

var _cache: Dictionary = {}

func preload_configs(paths: Array[String]) -> void:
	for path in paths:
		load_json(path)

func load_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("Config file not found: %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open config file: %s" % path)
		return null
	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: int = json.parse(content)
	if error != OK:
		push_error("Failed to parse config file: %s. Error line: %d" % [path, json.get_error_line()])
		return null
	var data: Variant = json.data
	_cache[path] = data
	return data

func get_cached(path: String, default_value: Variant = null) -> Variant:
	return _cache.get(path, default_value)

func has(path: String) -> bool:
	return _cache.has(path)

func clear(path: String = "") -> void:
	if path.is_empty():
		_cache.clear()
		return
	_cache.erase(path)
