class_name QGFAsyncLoadService
extends RefCounted

func request(path: String, type_hint: String = "", use_sub_threads: bool = false) -> Error:
	return ResourceLoader.load_threaded_request(path, type_hint, use_sub_threads)

func request_scene(path: String) -> Error:
	return request(path, "PackedScene")

func get_status(path: String, progress: Array = []) -> ResourceLoader.ThreadLoadStatus:
	return ResourceLoader.load_threaded_get_status(path, progress)

func get_scene_status(path: String, progress: Array = []) -> ResourceLoader.ThreadLoadStatus:
	return get_status(path, progress)

func get_loaded(path: String) -> Resource:
	return ResourceLoader.load_threaded_get(path)

func get_loaded_scene(path: String) -> Resource:
	return get_loaded(path)
