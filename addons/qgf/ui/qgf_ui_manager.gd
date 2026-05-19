class_name QGFUIManager
extends RefCounted

var layers: Dictionary = {}
var opened: Dictionary = {}

func register_layer(key: StringName, layer: Node) -> void:
	layers[key] = layer

func open(path: String, layer_key: StringName = &"ui", payload: Variant = null) -> Node:
	var layer: Node = layers.get(layer_key)
	if layer == null:
		push_error("QGFUIManager missing layer: %s" % layer_key)
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("QGFUIManager failed to load: %s" % path)
		return null
	var node: Node = scene.instantiate()
	layer.add_child(node)
	opened[path] = node
	if node.has_method("open"):
		node.open(payload)
	return node

func get_opened(path: String) -> Node:
	return opened.get(path)

func close(path: String) -> void:
	var node: Node = opened.get(path)
	if node == null:
		return
	if node.has_method("close"):
		node.close()
	node.queue_free()
	opened.erase(path)

func close_all() -> void:
	for path in opened.keys():
		var node: Node = opened[path]
		if node != null:
			node.queue_free()
	opened.clear()
