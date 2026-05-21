class_name ClueBoard
extends Control

signal deduction_requested(effect_ids: Array, summary: String)

const NODE_RADIUS := 26.0

var flags: Dictionary = {}
var selected_branch := 0
var _node_rects: Array[Dictionary] = []
var _detail_scroll := 0.0
var _deduction_rect := Rect2()

var branches: Array[Dictionary] = [
	{
		"title": "旧物暗线",
		"hint": "残玉、货郎、旧物买家串成一条暗财路。",
		"angle": -155.0,
		"color": Color(0.78, 0.57, 0.28, 1.0),
		"deduction_flag": "deduced_old_goods_line",
		"deduction_required": 2,
		"deduction_title": "整理暗价门路",
		"deduction_text": "你把残玉、货郎和买家暗号接起来，确认旧物可以走暗价。",
		"deduction_effects": ["mark_peddler_old_goods_contact", "mark_deduced_old_goods_line"],
		"nodes": [
			{"id": "jade_buyer_clue", "name": "残玉买家", "hidden": "玉扣去向？", "text": "有人愿意收残玉，价格比村口明面买卖更高。"},
			{"id": "met_jade_buyer", "name": "见过买家", "hidden": "买家身份？", "text": "买家不是普通货郎，见面地点和时辰都避人。"},
			{"id": "peddler_old_goods_contact", "name": "货郎暗线", "hidden": "旧物中人？", "text": "游货郎能挡闲话，也能帮旧物问暗价。"}
		]
	},
	{
		"title": "旧井夜路",
		"hint": "废井、守夜人、夜市销赃互相咬合。",
		"angle": -92.0,
		"color": Color(0.56, 0.58, 0.78, 1.0),
		"deduction_flag": "deduced_old_well_route",
		"deduction_required": 3,
		"deduction_title": "推断旧井藏路",
		"deduction_text": "你把井边绳结、守夜人口风和夜市去处对上，旧井深处可以试探。",
		"deduction_effects": ["mark_old_well_line", "unlock_old_well_cache", "mark_deduced_old_well_route"],
		"nodes": [
			{"id": "old_well_clue", "name": "废井暗藏", "hidden": "村后废井？", "text": "旧井边有人留下绳结和藏物痕迹。"},
			{"id": "old_well_watchman_deal", "name": "压住口风", "hidden": "守夜人口风？", "text": "守夜人只认暗号，不认你的脸，旧井夜路暂时稳住。"},
			{"id": "old_well_line", "name": "接上夜路", "hidden": "夜路入口？", "text": "旧井夜路能摸高值旧物，但怀疑也会跟着涨。"},
			{"id": "black_market_fence_line", "name": "夜市暗线", "hidden": "销货去处？", "text": "高值旧物能快速变现，但夜市热度会反噬。"},
			{"id": "market_heat_cooled", "name": "压下风声", "hidden": "避风手段？", "text": "热度高时先避风头，能让夜市线不至于立刻烧身。"}
		]
	},
	{
		"title": "村镇互助",
		"hint": "粮铺、郎中、村人信任能组成低风险补给网。",
		"angle": -28.0,
		"color": Color(0.48, 0.74, 0.45, 1.0),
		"deduction_flag": "deduced_support_network",
		"deduction_required": 3,
		"deduction_title": "串起互助人情",
		"deduction_text": "你把村人、粮铺和郎中的口风理清，补给网开始成形。",
		"deduction_effects": ["mark_support_network_built", "unlock_errand_route", "mark_deduced_support_network"],
		"nodes": [
			{"id": "earned_villager_trust", "name": "村人信任", "hidden": "村口人情？", "text": "有人愿意替你说话，风险比暗市低。"},
			{"id": "villager_aid_line", "name": "互助门路", "hidden": "跑腿门路？", "text": "村里小事能换粮钱，也能慢慢攒可信度。"},
			{"id": "grocer_grain_contact", "name": "粮铺后门", "hidden": "暗粮线？", "text": "缺粮时可走粮铺后门，少在明面露财。"},
			{"id": "doctor_medicine_contact", "name": "郎中药路", "hidden": "压寒方？", "text": "寒症拖久会坏底子，郎中线能稳定处理。"},
			{"id": "support_network_built", "name": "互助网成形", "hidden": "稳定补给？", "text": "粮药和人情连成网，适合稳住局面。"}
		]
	},
	{
		"title": "债务动向",
		"hint": "催债人、人脉和渡口消息决定何时还、何时躲。",
		"angle": 34.0,
		"color": Color(0.80, 0.50, 0.37, 1.0),
		"deduction_flag": "deduced_debt_timing",
		"deduction_required": 2,
		"deduction_title": "判断催债节奏",
		"deduction_text": "你把催债人的脚步和茶棚消息对上，知道哪天该还，哪天该躲。",
		"deduction_effects": ["mark_tea_debt_contact", "mark_deduced_debt_timing"],
		"nodes": [
			{"id": "met_collector", "name": "见过催债人", "hidden": "催债眼线？", "text": "债主的人已经露过面，拖久会更难躲。"},
			{"id": "tea_debt_contact", "name": "茶棚债讯", "hidden": "债主动向？", "text": "茶棚老人知道债主先问谁、何时上门。"},
			{"id": "porter_ferry_contact", "name": "渡口零活", "hidden": "渡口人脉？", "text": "脚夫能给稳定小钱，也可能带来河对岸消息。"},
			{"id": "repaid_debt_once", "name": "还过一笔", "hidden": "还债节奏？", "text": "还过一笔后，债主口风会变，但期限仍在。"}
		]
	},
	{
		"title": "坟地旧藏",
		"hint": "荒坟、旧藏和军中遗物有高收益，也更招眼。",
		"angle": 98.0,
		"color": Color(0.70, 0.63, 0.48, 1.0),
		"deduction_flag": "deduced_grave_cache",
		"deduction_required": 2,
		"deduction_title": "拼出荒坟旧藏",
		"deduction_text": "纸灰地名、埋藏痕迹和军中遗物连成一处，荒坟深处有东西。",
		"deduction_effects": ["unlock_graveyard_follow_clue", "mark_deduced_grave_cache"],
		"nodes": [
			{"id": "saw_graveyard_cache", "name": "坟地旧藏", "hidden": "纸灰地名？", "text": "纸灰和旧记号指向荒坟深处。"},
			{"id": "found_hidden_stash", "name": "真正钱袋", "hidden": "埋藏位置？", "text": "旧藏里有真东西，但留下痕迹也会惹疑。"},
			{"id": "soldier_relic_clue", "name": "军中遗物", "hidden": "逃兵私印？", "text": "军中遗物收益高，来路也最难解释。"}
		]
	},
	{
		"title": "猎户门路",
		"hint": "山林生计、猎具和设伏能改善探索收益。",
		"angle": 160.0,
		"color": Color(0.52, 0.68, 0.42, 1.0),
		"deduction_flag": "deduced_hunter_route",
		"deduction_required": 1,
		"deduction_title": "照册布下猎路",
		"deduction_text": "你照着残弓册重新看山林痕迹，猎户设伏的路子能用了。",
		"deduction_effects": ["mark_hunter_trap_line", "mark_deduced_hunter_route"],
		"nodes": [
			{"id": "studied_bow_manual", "name": "残弓册", "hidden": "旧猎册？", "text": "读过残弓册后，山林痕迹更容易辨认。"},
			{"id": "hunter_trap_line", "name": "猎户设伏", "hidden": "设伏门路？", "text": "密林肉食线更稳，遇兽时多一条处理办法。"}
		]
	}
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(840.0, 500.0)

func set_flags(new_flags: Dictionary) -> void:
	flags = new_flags.duplicate(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var direction := -1.0 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			_detail_scroll = clampf(_detail_scroll + direction * 26.0, 0.0, _detail_max_scroll())
			queue_redraw()
			accept_event()
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if _deduction_rect.has_point(mouse_event.position):
			var branch: Dictionary = branches[clampi(selected_branch, 0, branches.size() - 1)]
			if _can_deduce(branch):
				var effects: Array = branch.get("deduction_effects", [])
				deduction_requested.emit(effects, str(branch.get("deduction_text", "")))
			accept_event()
			return
		for entry in _node_rects:
			var rect: Rect2 = entry.get("rect", Rect2())
			if rect.has_point(mouse_event.position):
				selected_branch = int(entry.get("branch", 0))
				_detail_scroll = 0.0
				queue_redraw()
				accept_event()
				return

func _draw() -> void:
	_node_rects.clear()
	_deduction_rect = Rect2()
	var board := Rect2(Vector2.ZERO, size)
	draw_rect(board, Color(0.030, 0.027, 0.024, 1.0))
	draw_rect(board, Color(0.76, 0.56, 0.28, 0.55), false, 1.0)

	var graph_rect := Rect2(Vector2(16.0, 16.0), Vector2(size.x * 0.62 - 24.0, size.y - 32.0))
	var detail_rect := Rect2(Vector2(graph_rect.end.x + 16.0, 16.0), Vector2(size.x - graph_rect.end.x - 32.0, size.y - 32.0))
	_draw_graph(graph_rect)
	_draw_detail(detail_rect)

func _draw_graph(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var center := rect.position + rect.size * 0.5
	draw_circle(center, 46.0, Color(0.09, 0.065, 0.040, 0.96))
	draw_circle(center, 48.0, Color(0.86, 0.64, 0.32, 0.42), false, 2.0)
	_draw_outlined_string(font, center + Vector2(-38.0, 5.0), "债与活路", 16, Color(0.97, 0.85, 0.58, 1.0), 3, 90.0)

	var max_radius := minf(rect.size.x, rect.size.y) * 0.42
	for branch_index in branches.size():
		var branch: Dictionary = branches[branch_index]
		var angle := deg_to_rad(float(branch.get("angle", 0.0)))
		var direction := Vector2(cos(angle), sin(angle))
		var color: Color = branch.get("color", Color(0.78, 0.58, 0.34, 1.0))
		var nodes: Array = branch.get("nodes", [])
		var previous := center
		for node_index in nodes.size():
			var t := float(node_index + 1) / float(nodes.size() + 1)
			var pos := center + direction * lerpf(82.0, max_radius, t)
			draw_line(previous, pos, Color(color.r, color.g, color.b, 0.34), 3.0)
			previous = pos
			var node: Dictionary = nodes[node_index]
			var active := _has_clue(str(node.get("id", "")))
			var fill := Color(color.r, color.g, color.b, 0.90) if active else Color(0.12, 0.105, 0.085, 0.96)
			var border := color if active else Color(0.42, 0.34, 0.22, 0.72)
			if branch_index == selected_branch:
				draw_circle(pos, NODE_RADIUS + 5.0, Color(color.r, color.g, color.b, 0.18))
			draw_circle(pos, NODE_RADIUS, fill)
			draw_circle(pos, NODE_RADIUS, border, false, 2.0)
			var label := str(node.get("name", "")) if active else str(node.get("hidden", "未知线索"))
			var label_pos := pos + Vector2(-50.0, NODE_RADIUS + 16.0)
			if direction.y > 0.35:
				label_pos = pos + Vector2(-50.0, -NODE_RADIUS - 8.0)
			_draw_outlined_string(font, label_pos, label, 11, Color(0.90, 0.82, 0.62, 1.0) if active else Color(0.58, 0.52, 0.42, 1.0), 2, 100.0)
			_node_rects.append({
				"branch": branch_index,
				"node": node_index,
				"rect": Rect2(pos - Vector2(NODE_RADIUS, NODE_RADIUS), Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0))
			})

		var label_anchor := center + direction * (max_radius + 34.0)
		_draw_outlined_string(font, label_anchor + Vector2(-58.0, 4.0), str(branch.get("title", "")), 14, color, 3, 116.0)

func _draw_detail(rect: Rect2) -> void:
	var font := get_theme_default_font()
	draw_rect(rect, Color(0.046, 0.039, 0.032, 0.96))
	draw_rect(rect, Color(0.70, 0.50, 0.25, 0.46), false, 1.0)
	var branch: Dictionary = branches[clampi(selected_branch, 0, branches.size() - 1)]
	var color: Color = branch.get("color", Color(0.78, 0.58, 0.34, 1.0))
	_draw_outlined_string(font, rect.position + Vector2(16.0, 28.0), str(branch.get("title", "")), 22, color, 4, rect.size.x - 32.0)
	_draw_outlined_string(font, rect.position + Vector2(16.0, 52.0), str(branch.get("hint", "")), 13, Color(0.74, 0.68, 0.54, 1.0), 3, rect.size.x - 32.0)
	var nodes: Array = branch.get("nodes", [])
	var found := _found_count(branch)
	_draw_outlined_string(font, rect.position + Vector2(16.0, 78.0), "已掌握 %d/%d" % [found, nodes.size()], 13, Color(0.92, 0.80, 0.55, 1.0), 3, rect.size.x - 32.0)

	_draw_deduction_box(rect, branch, color)

	var list_top := rect.position.y + 166.0
	var list_height := rect.size.y - 184.0
	var list_bottom := list_top + list_height
	var list_view_rect := Rect2(Vector2(rect.position.x + 12.0, list_top), Vector2(rect.size.x - 24.0, list_height))
	_detail_scroll = clampf(_detail_scroll, 0.0, _detail_max_scroll())
	draw_rect(list_view_rect, Color(0.018, 0.015, 0.012, 0.42))
	draw_rect(list_view_rect, Color(0.58, 0.42, 0.22, 0.28), false, 1.0)
	var y := list_top - _detail_scroll
	for node_variant in nodes:
		var node: Dictionary = node_variant
		var active := _has_clue(str(node.get("id", "")))
		var row_rect := Rect2(Vector2(rect.position.x + 14.0, y), Vector2(rect.size.x - 28.0, 74.0))
		if row_rect.position.y >= list_top and row_rect.end.y <= list_bottom:
			draw_rect(row_rect, Color(color.r, color.g, color.b, 0.15) if active else Color(0.08, 0.070, 0.056, 0.90))
			draw_rect(row_rect, Color(color.r, color.g, color.b, 0.55) if active else Color(0.30, 0.24, 0.16, 0.65), false, 1.0)
			var title := str(node.get("name", "")) if active else str(node.get("hidden", "未知线索"))
			var body := str(node.get("text", "")) if active else "尚未收集。先留意相关地点、人脉或物件，等线索补足后再判断。"
			_draw_outlined_string(font, row_rect.position + Vector2(12.0, 22.0), title, 14, Color(0.96, 0.86, 0.62, 1.0) if active else Color(0.62, 0.55, 0.43, 1.0), 3, row_rect.size.x - 24.0)
			_draw_outlined_string(font, row_rect.position + Vector2(12.0, 46.0), body, 12, Color(0.84, 0.78, 0.64, 1.0) if active else Color(0.56, 0.50, 0.40, 1.0), 2, row_rect.size.x - 24.0)
		y += 82.0
	draw_rect(Rect2(rect.position.x + 1.0, rect.position.y + 158.0, rect.size.x - 2.0, 8.0), Color(0.046, 0.039, 0.032, 0.96))
	draw_rect(Rect2(rect.position.x + 1.0, list_bottom, rect.size.x - 2.0, maxf(rect.end.y - list_bottom - 1.0, 1.0)), Color(0.046, 0.039, 0.032, 0.96))
	draw_rect(list_view_rect, Color(0.58, 0.42, 0.22, 0.28), false, 1.0)

	var max_scroll := _detail_max_scroll()
	if max_scroll > 0.0:
		var track := Rect2(Vector2(rect.end.x - 9.0, list_top + 2.0), Vector2(3.0, list_height - 4.0))
		var content_height := _detail_content_height()
		var thumb_height := maxf(28.0, track.size.y * track.size.y / maxf(content_height, 1.0))
		var thumb_y := track.position.y + (_detail_scroll / max_scroll) * (track.size.y - thumb_height)
		draw_rect(track, Color(0.11, 0.095, 0.075, 0.90))
		draw_rect(Rect2(Vector2(track.position.x, thumb_y), Vector2(track.size.x, thumb_height)), Color(0.82, 0.62, 0.32, 0.90))

func _detail_content_height() -> float:
	if branches.is_empty():
		return 0.0
	var branch: Dictionary = branches[clampi(selected_branch, 0, branches.size() - 1)]
	return float((branch.get("nodes", []) as Array).size()) * 82.0

func _detail_max_scroll() -> float:
	var detail_height := maxf(size.y - 216.0, 1.0)
	return maxf(0.0, _detail_content_height() - detail_height)

func _has_clue(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))

func _draw_deduction_box(rect: Rect2, branch: Dictionary, color: Color) -> void:
	var font := get_theme_default_font()
	_deduction_rect = Rect2(rect.position + Vector2(14.0, 104.0), Vector2(rect.size.x - 28.0, 46.0))
	var deduced := _is_deduced(branch)
	var can_deduce := _can_deduce(branch)
	var fill := Color(color.r, color.g, color.b, 0.22) if can_deduce else Color(0.08, 0.070, 0.056, 0.92)
	if deduced:
		fill = Color(0.055, 0.072, 0.045, 0.94)
	draw_rect(_deduction_rect, fill)
	draw_rect(_deduction_rect, Color(color.r, color.g, color.b, 0.66) if can_deduce else Color(0.34, 0.27, 0.17, 0.78), false, 1.0)

	var title := str(branch.get("deduction_title", "整理推断"))
	var required := _required_count(branch)
	var found := _found_count(branch)
	var status := "已推断" if deduced else ("可推断" if can_deduce else "还需线索 %d/%d" % [found, required])
	var status_color := Color(0.78, 0.96, 0.60, 1.0) if deduced else (Color(0.98, 0.84, 0.48, 1.0) if can_deduce else Color(0.64, 0.58, 0.46, 1.0))
	_draw_outlined_string(font, _deduction_rect.position + Vector2(12.0, 19.0), title, 14, Color(0.94, 0.84, 0.62, 1.0), 3, _deduction_rect.size.x - 110.0)
	_draw_outlined_string(font, _deduction_rect.position + Vector2(_deduction_rect.size.x - 92.0, 19.0), status, 12, status_color, 3, 84.0)
	if can_deduce:
		_draw_outlined_string(font, _deduction_rect.position + Vector2(12.0, 38.0), "点击整理，线索会转化为可用门路。", 11, Color(0.82, 0.75, 0.58, 1.0), 2, _deduction_rect.size.x - 24.0)
	elif deduced:
		_draw_outlined_string(font, _deduction_rect.position + Vector2(12.0, 38.0), str(branch.get("deduction_text", "")), 11, Color(0.74, 0.84, 0.58, 1.0), 2, _deduction_rect.size.x - 24.0)

func _found_count(branch: Dictionary) -> int:
	var found := 0
	for node_variant in branch.get("nodes", []):
		var node: Dictionary = node_variant
		if _has_clue(str(node.get("id", ""))):
			found += 1
	return found

func _required_count(branch: Dictionary) -> int:
	var nodes: Array = branch.get("nodes", [])
	return clampi(int(branch.get("deduction_required", nodes.size())), 1, max(1, nodes.size()))

func _deduction_flag(branch: Dictionary) -> String:
	return str(branch.get("deduction_flag", ""))

func _is_deduced(branch: Dictionary) -> bool:
	var flag_id := _deduction_flag(branch)
	return not flag_id.is_empty() and _has_clue(flag_id)

func _can_deduce(branch: Dictionary) -> bool:
	return not _is_deduced(branch) and _found_count(branch) >= _required_count(branch)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.012, 0.010, 0.008, 0.94)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
