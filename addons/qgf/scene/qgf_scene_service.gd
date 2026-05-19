class_name QGFSceneService
extends RefCounted

const QGFAsyncLoadServiceScript := preload("res://addons/qgf/service/qgf_async_load_service.gd")

var tree: SceneTree
var async_loader: RefCounted

func _init(scene_tree: SceneTree = null, loader: RefCounted = null) -> void:
	tree = scene_tree
	async_loader = loader

func setup(scene_tree: SceneTree, loader: RefCounted = null) -> void:
	tree = scene_tree
	async_loader = loader

func goto_scene(path: String) -> Error:
	if tree == null:
		push_error("QGFSceneService has no SceneTree.")
		return ERR_UNCONFIGURED
	return tree.change_scene_to_file(path)

func request_scene(path: String) -> Error:
	if async_loader == null:
		async_loader = QGFAsyncLoadServiceScript.new()
	return async_loader.request_scene(path)

func take_loaded_scene(path: String) -> PackedScene:
	if async_loader == null:
		return null
	return async_loader.get_loaded_scene(path) as PackedScene

func goto_loaded_scene(path: String) -> Error:
	if tree == null:
		return ERR_UNCONFIGURED
	var scene: PackedScene = take_loaded_scene(path)
	if scene == null:
		return ERR_CANT_OPEN
	return tree.change_scene_to_packed(scene)
