class_name QGFThreadService
extends RefCounted

var _threads: Array[Thread] = []

func run_job(callback: Callable) -> Thread:
	if not callback.is_valid():
		push_error("QGFThreadService.run_job received an invalid callable.")
		return null
	var thread: Thread = Thread.new()
	_threads.append(thread)
	thread.start(callback)
	return thread

func wait_all() -> void:
	for thread in _threads:
		if thread != null and thread.is_started():
			thread.wait_to_finish()
	_threads.clear()
