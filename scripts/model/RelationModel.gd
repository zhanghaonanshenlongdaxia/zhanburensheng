class_name RelationModel
extends RefCounted

var npc_scores: Dictionary = {}
var unlocked_contacts: Dictionary = {}
var task_states: Dictionary = {}

func get_score(npc_id: String) -> int:
	return int(npc_scores.get(npc_id, 0))

func set_score(npc_id: String, value: int) -> void:
	npc_scores[npc_id] = clampi(value, 0, 5)

func add_score(npc_id: String, delta: int) -> int:
	var value := get_score(npc_id) + delta
	set_score(npc_id, value)
	return get_score(npc_id)

func has_unlocked_contact(npc_id: String) -> bool:
	return bool(unlocked_contacts.get(npc_id, false))

func set_contact_unlocked(npc_id: String, value: bool = true) -> void:
	unlocked_contacts[npc_id] = value

func get_task_state(task_id: String) -> String:
	return str(task_states.get(task_id, ""))

func set_task_state(task_id: String, state: String) -> void:
	task_states[task_id] = state

func is_task_active(task_id: String) -> bool:
	return get_task_state(task_id) == "active"

func is_task_completed(task_id: String) -> bool:
	return get_task_state(task_id) == "completed"

func get_display_entries() -> Array:
	var result: Array = []
	for npc_id in npc_scores.keys():
		var score := get_score(str(npc_id))
		if score <= 0:
			continue
		result.append({
			"id": str(npc_id),
			"name": _npc_name(str(npc_id)),
			"value": _relation_label(score)
		})
	return result

func _npc_name(npc_id: String) -> String:
	match npc_id:
		"grocer":
			return "粮铺掌柜"
		"doctor":
			return "周郎中"
		"peddler":
			return "游货郎"
		"tea_oldman":
			return "茶棚老人"
		"porter":
			return "码头脚夫"
		_:
			return npc_id

func _relation_label(score: int) -> String:
	if score >= 4:
		return "托付"
	if score >= 3:
		return "可信"
	if score >= 2:
		return "熟络"
	return "面熟"
