class_name QGFPoolService
extends RefCounted

var _pools: Dictionary = {}

func warm_pool(key: StringName, scene: PackedScene, count: int, owner: Node) -> void:
	if _pools.has(key):
		return
	if scene == null or owner == null:
		push_error("QGFPoolService.warm_pool requires a scene and owner.")
		return
	var items: Array[Node] = []
	for _i in count:
		var instance: Node = scene.instantiate()
		_deactivate(instance)
		owner.add_child(instance)
		items.append(instance)
	_pools[key] = {
		"scene": scene,
		"items": items
	}

func acquire(key: StringName, owner: Node) -> Node:
	if not _pools.has(key):
		push_warning("QGFPoolService.acquire missing pool: %s" % key)
		return null
	var pool: Dictionary = _pools[key]
	var items: Array = pool.get("items", [])
	for item_variant in items:
		var item: Node = item_variant
		if item != null and not bool(item.get_meta(&"_qgf_pool_active", false)):
			_activate(item)
			return item
	var scene: PackedScene = pool["scene"]
	var instance: Node = scene.instantiate()
	owner.add_child(instance)
	items.append(instance)
	pool["items"] = items
	_activate(instance)
	return instance

func release(_key: StringName, node: Node) -> void:
	if node == null:
		return
	_deactivate(node)

func clear(key: StringName = &"") -> void:
	if key == &"":
		_pools.clear()
		return
	_pools.erase(key)

func _activate(node: Node) -> void:
	node.set_meta(&"_qgf_pool_active", true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	elif node is Node3D:
		(node as Node3D).visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT

func _deactivate(node: Node) -> void:
	node.set_meta(&"_qgf_pool_active", false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	elif node is Node3D:
		(node as Node3D).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
