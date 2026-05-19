class_name QGFEventBus
extends RefCounted

var _listeners: Dictionary = {}
var _once_listeners: Dictionary = {}

func subscribe(event_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		push_warning("QGFEventBus.subscribe received an invalid callable for %s." % event_name)
		return
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	var listeners: Array = _listeners[event_name]
	if listeners.has(callback):
		return
	listeners.append(callback)

func subscribe_once(event_name: StringName, callback: Callable) -> void:
	subscribe(event_name, callback)
	if not _once_listeners.has(event_name):
		_once_listeners[event_name] = []
	var listeners: Array = _once_listeners[event_name]
	if not listeners.has(callback):
		listeners.append(callback)

func unsubscribe(event_name: StringName, callback: Callable) -> void:
	if _listeners.has(event_name):
		var listeners: Array = _listeners[event_name]
		listeners.erase(callback)
		if listeners.is_empty():
			_listeners.erase(event_name)
	if _once_listeners.has(event_name):
		var once_listeners: Array = _once_listeners[event_name]
		once_listeners.erase(callback)
		if once_listeners.is_empty():
			_once_listeners.erase(event_name)

func publish(event_name: StringName, payload: Variant = null) -> void:
	if not _listeners.has(event_name):
		return
	var listeners: Array = (_listeners[event_name] as Array).duplicate()
	for callback_variant in listeners:
		var callback: Callable = callback_variant
		if callback.is_valid():
			callback.call(payload)
		if _once_listeners.has(event_name) and (_once_listeners[event_name] as Array).has(callback):
			unsubscribe(event_name, callback)

func clear(event_name: StringName = &"") -> void:
	if event_name == &"":
		_listeners.clear()
		_once_listeners.clear()
		return
	_listeners.erase(event_name)
	_once_listeners.erase(event_name)

func listener_count(event_name: StringName) -> int:
	return (_listeners.get(event_name, []) as Array).size()
