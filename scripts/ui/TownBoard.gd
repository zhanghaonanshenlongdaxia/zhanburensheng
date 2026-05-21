class_name TownBoard
extends Control

signal log_changed(text: String)
signal buy_requested(item_id: String, cost: int, summary: String)
signal sell_requested(item_id: String, value: int, summary: String)
signal contact_unlocked(effect_ids: Array, summary: String)
signal task_started(task_id: String, summary: String)
signal task_completed(task_id: String, effect_ids: Array, summary: String)
signal extracted(summary: String)

const CELL_SIZE := 18.0

var selected_option: Dictionary = {}
var cells: Dictionary = {}
var current_cell: Vector2i = Vector2i.ZERO
var entrance_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var discovered: Dictionary = {}
var item_defs: Dictionary = {}
var inventory_items: Dictionary = {}
var relation_model: RefCounted
var resolved_task_steps: Dictionary = {}
var _hotspots: Array[Dictionary] = []
var _map_rects: Dictionary = {}
var _last_log: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 330.0)

func configure(option: Dictionary, defs: Dictionary, items: Dictionary, relations: RefCounted = null) -> void:
	selected_option = option.duplicate(true)
	relation_model = relations
	update_inventory(defs, items)
	cells = _town_map()
	entrance_cell = Vector2i.ZERO
	exit_cell = Vector2i(3, 0)
	current_cell = entrance_cell
	discovered.clear()
	resolved_task_steps.clear()
	_discover_around(current_cell)
	_set_log("你主动来到镇口。镇上人多眼杂，买卖和打听消息都要避着熟人。")
	queue_redraw()

func update_inventory(defs: Dictionary, items: Dictionary) -> void:
	item_defs = defs
	inventory_items = items.duplicate(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		for cell_variant in _map_rects.keys():
			var cell: Vector2i = cell_variant
			var rect: Rect2 = _map_rects[cell]
			if rect.has_point(pos):
				_try_move_to(cell)
				accept_event()
				return
		for hotspot in _hotspots:
			var hotspot_rect: Rect2 = hotspot.get("rect", Rect2())
			if hotspot_rect.has_point(pos):
				_activate_hotspot(hotspot)
				accept_event()
				return

func _draw() -> void:
	_hotspots.clear()
	_map_rects.clear()
	var board := Rect2(Vector2.ZERO, size)
	draw_rect(board, Color(0.043, 0.036, 0.030, 1.0))
	draw_rect(board, Color(0.70, 0.48, 0.22, 0.30), false, 1.0)
	_draw_scene()
	_draw_minimap()
	_draw_contact_panel()
	_draw_status_band()

func _draw_scene() -> void:
	var scene_rect := Rect2(18.0, 18.0, maxf(size.x - 260.0, 360.0), maxf(size.y - 68.0, 220.0))
	var cell_data: Dictionary = cells.get(current_cell, {})
	var scene_type: String = str(cell_data.get("type", "street"))
	draw_rect(scene_rect, _scene_color(scene_type))
	_draw_town_texture(scene_rect, scene_type)
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.38), false, 2.0)

	var font := get_theme_default_font()
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 30.0), "乡镇 · %s" % _scene_name(scene_type), 22, Color(0.98, 0.86, 0.55, 1.0), 4, scene_rect.size.x - 36.0)
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 58.0), _scene_desc(scene_type), 14, Color(0.90, 0.80, 0.60, 1.0), 3, scene_rect.size.x - 36.0)

	match scene_type:
		"grocer":
			var food_cost := 2 if _npc_relation("grocer") >= 2 else 3
			_draw_shop_hotspot(scene_rect, "买粗粮", "粮食 +1，花费 %d 铜钱" % food_cost, {"kind": "buy", "item_id": "food", "cost": food_cost}, 0)
			_draw_shop_hotspot(scene_rect, "买干薯根", "山薯根 +1，花费 4 铜钱", {"kind": "buy", "item_id": "dry_tuber", "cost": 4}, 1)
			_draw_shop_hotspot(scene_rect, "和掌柜闲谈", _npc_hotspot_body("grocer", "粮价又涨了，村里人迟早撑不住。"), {"kind": "npc", "npc_id": "grocer"}, 2)
			_draw_npc_task_hotspot(scene_rect, "grocer_supply", "grocer", 3)
		"apothecary":
			var herb_cost := 4 if _npc_relation("doctor") >= 2 else 5
			_draw_shop_hotspot(scene_rect, "买药草", "药草 +1，花费 %d 铜钱" % herb_cost, {"kind": "buy", "item_id": "herb", "cost": herb_cost}, 0)
			_draw_shop_hotspot(scene_rect, "问郎中", _npc_hotspot_body("doctor", "打听药材行情"), {"kind": "npc", "npc_id": "doctor"}, 1)
			_draw_npc_task_hotspot(scene_rect, "doctor_delivery", "doctor", 2)
		"pawn":
			var sellables: Array = _sellable_items()
			if sellables.is_empty():
				_draw_shop_hotspot(scene_rect, "货郎回收", _npc_hotspot_body("peddler", "你身上没有能出手的战利品"), {"kind": "npc", "npc_id": "peddler"}, 0)
				_draw_npc_task_hotspot(scene_rect, "peddler_appraisal", "peddler", 1)
			else:
				for index in mini(sellables.size(), 4):
					var entry: Dictionary = sellables[index]
					var value := _sell_value(entry)
					_draw_shop_hotspot(scene_rect, "卖 %s" % _item_label(entry), "换 %d 铜钱" % value, {"kind": "sell", "item_id": str(entry.get("id", "")), "value": value}, index)
				_draw_npc_task_hotspot(scene_rect, "peddler_appraisal", "peddler", mini(sellables.size(), 4))
		"tea":
			_draw_shop_hotspot(scene_rect, "听闲话", _npc_hotspot_body("tea_oldman", "打听里正和贾三坡的动向"), {"kind": "npc", "npc_id": "tea_oldman"}, 0)
			_draw_shop_hotspot(scene_rect, "找脚夫", _npc_hotspot_body("porter", "问去河对岸的路"), {"kind": "npc", "npc_id": "porter"}, 1)
			_draw_npc_task_hotspot(scene_rect, "tea_warning", "tea_oldman", 2)
			_draw_npc_task_hotspot(scene_rect, "porter_ferry_note", "porter", 3)
		"back_alley", "sick_house", "old_bridge", "ferry":
			_draw_task_target_hotspots(scene_rect, scene_type)
		_:
			_draw_shop_hotspot(scene_rect, "观察街面", "记住人流和退路", {"kind": "npc", "line": "街上人来人往。你低着头走，没人把你和村里的落魄泼皮联系起来。"}, 0)

	if current_cell == exit_cell:
		_draw_shop_hotspot(scene_rect, "离镇返村", "结束今日城镇外出", {"kind": "extract"}, 4)

func _draw_town_texture(rect: Rect2, scene_type: String) -> void:
	match scene_type:
		"grocer":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.35), Vector2(rect.size.x * 0.50, rect.size.y * 0.34)), Color(0.18, 0.12, 0.07, 0.86))
			for idx in range(4):
				draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.20 + idx * 48.0, rect.size.y * 0.47), Vector2(30.0, 34.0)), Color(0.46, 0.34, 0.17, 0.78))
		"apothecary":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.30), Vector2(rect.size.x * 0.55, rect.size.y * 0.42)), Color(0.11, 0.16, 0.10, 0.86))
			for idx in range(5):
				draw_circle(rect.position + Vector2(rect.size.x * 0.22 + idx * 38.0, rect.size.y * 0.52), 10.0, Color(0.38, 0.58, 0.28, 0.75))
		"pawn":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.34), Vector2(rect.size.x * 0.60, rect.size.y * 0.32)), Color(0.16, 0.13, 0.10, 0.88))
			draw_line(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.45), rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.45), Color(0.70, 0.54, 0.25, 0.48), 3.0)
		"tea":
			for idx in range(3):
				draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.17 + idx * 96.0, rect.size.y * 0.47), Vector2(60.0, 22.0)), Color(0.22, 0.15, 0.09, 0.82))
			draw_line(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.34), rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.30), Color(0.62, 0.48, 0.24, 0.56), 5.0)
		"back_alley":
			for idx in range(5):
				draw_line(rect.position + Vector2(rect.size.x * 0.20 + idx * 54.0, rect.size.y * 0.25), rect.position + Vector2(rect.size.x * 0.14 + idx * 50.0, rect.size.y * 0.82), Color(0.20, 0.16, 0.11, 0.68), 5.0)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.54, rect.size.y * 0.38), Vector2(82.0, 58.0)), Color(0.12, 0.08, 0.05, 0.82))
		"sick_house":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.32), Vector2(rect.size.x * 0.48, rect.size.y * 0.36)), Color(0.10, 0.13, 0.09, 0.86))
			draw_circle(rect.position + Vector2(rect.size.x * 0.30, rect.size.y * 0.50), 12.0, Color(0.34, 0.45, 0.25, 0.58))
			draw_line(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.32), rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.18), Color(0.34, 0.25, 0.14, 0.72), 5.0)
		"old_bridge", "ferry":
			var water := PackedVector2Array([
				rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.70),
				rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.58),
				rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.64),
				rect.position + Vector2(rect.size.x * 0.94, rect.size.y * 0.50)
			])
			draw_polyline(water, Color(0.16, 0.31, 0.34, 0.78), 18.0)
			draw_line(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.48), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.40), Color(0.34, 0.24, 0.13, 0.84), 9.0)
		"gate":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.28), Vector2(rect.size.x * 0.12, rect.size.y * 0.48)), Color(0.18, 0.13, 0.09, 0.92))
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.28), Vector2(rect.size.x * 0.12, rect.size.y * 0.48)), Color(0.18, 0.13, 0.09, 0.92))
			draw_line(rect.position + Vector2(rect.size.x * 0.17, rect.size.y * 0.28), rect.position + Vector2(rect.size.x * 0.69, rect.size.y * 0.28), Color(0.42, 0.30, 0.15, 0.88), 8.0)
		_:
			for idx in range(7):
				var y := rect.position.y + rect.size.y * 0.36 + idx * 20.0
				draw_line(Vector2(rect.position.x + 24.0, y), Vector2(rect.position.x + rect.size.x - 28.0, y + 10.0), Color(0.35, 0.27, 0.17, 0.28), 2.0)

func _draw_shop_hotspot(scene_rect: Rect2, title: String, body: String, data: Dictionary, index: int) -> void:
	var cols := 2
	var row := index / cols
	var col := index % cols
	var rect := Rect2(
		scene_rect.position + Vector2(22.0 + col * 220.0, 94.0 + row * 64.0),
		Vector2(196.0, 52.0)
	)
	draw_rect(rect, Color(0.10, 0.17, 0.10, 0.88))
	draw_rect(rect, Color(0.92, 0.68, 0.34, 0.58), false, 1.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, rect.position + Vector2(10.0, 20.0), title, 14, Color(0.96, 0.86, 0.62, 1.0), 3, rect.size.x - 20.0)
	_draw_outlined_string(font, rect.position + Vector2(10.0, 40.0), body, 12, Color(0.82, 0.78, 0.66, 1.0), 3, rect.size.x - 20.0)
	var hotspot := data.duplicate(true)
	hotspot["rect"] = rect
	_hotspots.append(hotspot)

func _draw_npc_task_hotspot(scene_rect: Rect2, task_id: String, npc_id: String, index: int) -> void:
	if _npc_relation(npc_id) < 2:
		return
	if _task_completed(task_id):
		return
	if _task_active(task_id):
		return
	var title := _task_title(task_id)
	var body := _task_body(task_id)
	_draw_shop_hotspot(scene_rect, title, body, {"kind": "task_start", "task_id": task_id}, index)

func _draw_task_target_hotspots(scene_rect: Rect2, scene_type: String) -> void:
	var index := 0
	for task_id in _active_tasks_for_scene(scene_type):
		_draw_shop_hotspot(scene_rect, "交付：%s" % _task_title(task_id), _task_turnin_body(task_id), {"kind": "task_complete", "task_id": task_id}, index)
		index += 1
	if index == 0:
		_draw_shop_hotspot(scene_rect, "查看此处", _scene_idle_action_text(scene_type), {"kind": "npc", "line": _scene_idle_log(scene_type)}, 0)

func _draw_minimap() -> void:
	var map_origin := Vector2(size.x - 214.0, 20.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, map_origin + Vector2(0.0, -4.0), "镇图", 16, Color(0.94, 0.84, 0.60, 1.0), 3, 160.0)
	for cell_variant in cells.keys():
		var cell: Vector2i = cell_variant
		if not discovered.has(cell):
			continue
		var pos := map_origin + Vector2(float(cell.x + 2) * CELL_SIZE, float(cell.y + 3) * CELL_SIZE)
		var rect := Rect2(pos, Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0))
		_map_rects[cell] = rect
		var fill := _scene_color(str(cells[cell].get("type", "street")))
		if cell == current_cell:
			fill = Color(0.92, 0.76, 0.34, 1.0)
		elif cell == exit_cell:
			fill = Color(0.28, 0.52, 0.32, 1.0)
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
	_draw_outlined_string(font, map_origin + Vector2(0.0, 132.0), "点击相邻格移动，绿色为返村出口。", 12, Color(0.78, 0.72, 0.58, 1.0), 3, 190.0)

func _draw_contact_panel() -> void:
	var panel_origin := Vector2(size.x - 214.0, 176.0)
	var panel_rect := Rect2(panel_origin + Vector2(-8.0, -8.0), Vector2(198.0, 92.0))
	draw_rect(panel_rect, Color(0.025, 0.022, 0.018, 0.78))
	draw_rect(panel_rect, Color(0.78, 0.54, 0.26, 0.28), false, 1.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, panel_origin + Vector2(0.0, 12.0), "镇上人脉", 14, Color(0.94, 0.84, 0.60, 1.0), 3, 160.0)
	var entries: Array[String] = []
	for npc_id in ["grocer", "doctor", "peddler", "tea_oldman", "porter"]:
		var score := _npc_relation(npc_id)
		if score > 0:
			entries.append("%s %s" % [_npc_name(npc_id), _npc_relation_label(score)])
	if entries.is_empty():
		entries.append("还没人真正认得你")
	for index in mini(entries.size(), 4):
		_draw_outlined_string(font, panel_origin + Vector2(0.0, 34.0 + float(index) * 15.0), entries[index], 12, Color(0.82, 0.78, 0.66, 1.0), 2, 180.0)
	var task_text := _active_task_panel_text()
	if not task_text.is_empty():
		_draw_outlined_string(font, panel_origin + Vector2(0.0, 78.0), task_text, 11, Color(0.90, 0.74, 0.42, 1.0), 2, 180.0)

func _draw_status_band() -> void:
	var rect := Rect2(18.0, size.y - 42.0, maxf(size.x - 36.0, 0.0), 28.0)
	draw_rect(rect, Color(0.025, 0.023, 0.020, 0.74))
	var font := get_theme_default_font()
	_draw_outlined_string(font, rect.position + Vector2(10.0, 19.0), _last_log, 13, Color(0.86, 0.82, 0.70, 1.0), 3, rect.size.x - 20.0)

func _activate_hotspot(hotspot: Dictionary) -> void:
	match str(hotspot.get("kind", "")):
		"buy":
			var item_id := str(hotspot.get("item_id", ""))
			var cost := int(hotspot.get("cost", 0))
			buy_requested.emit(item_id, cost, "你向商铺买下%s，花费%d铜钱。" % [_item_name(item_id), cost])
		"sell":
			var sell_id := str(hotspot.get("item_id", ""))
			var value := int(hotspot.get("value", 0))
			sell_requested.emit(sell_id, value, "你把%s压低声音卖给货郎，换得%d铜钱。" % [_item_name(sell_id), value])
		"npc":
			_talk_to_npc(str(hotspot.get("npc_id", "")))
			queue_redraw()
		"task_start":
			_start_task(str(hotspot.get("task_id", "")))
			queue_redraw()
		"task_complete":
			_complete_task(str(hotspot.get("task_id", "")))
			queue_redraw()
		"extract":
			extracted.emit("你从镇口离开，趁天色未暗赶回村里。")

func _try_move_to(cell: Vector2i) -> void:
	if cell == current_cell:
		return
	if not discovered.has(cell):
		return
	var delta := cell - current_cell
	if abs(delta.x) + abs(delta.y) != 1:
		return
	current_cell = cell
	_discover_around(cell)
	var cell_data: Dictionary = cells.get(cell, {})
	var scene_type := str(cell_data.get("type", "street"))
	var task_step_text := _maybe_resolve_task_step(scene_type)
	if task_step_text.is_empty():
		_set_log("你来到%s。" % _scene_name(scene_type))
	else:
		_set_log(task_step_text)
	queue_redraw()

func _discover_around(cell: Vector2i) -> void:
	discovered[cell] = true
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for dir: Vector2i in dirs:
		var next_cell := cell + dir
		if cells.has(next_cell):
			discovered[next_cell] = true

func _town_map() -> Dictionary:
	return {
		Vector2i(0, 0): {"type": "gate"},
		Vector2i(1, 0): {"type": "street"},
		Vector2i(1, -1): {"type": "grocer"},
		Vector2i(2, -1): {"type": "apothecary"},
		Vector2i(2, 0): {"type": "pawn"},
		Vector2i(2, 1): {"type": "tea"},
		Vector2i(3, 0): {"type": "gate"},
		Vector2i(1, -2): {"type": "back_alley"},
		Vector2i(3, -1): {"type": "sick_house"},
		Vector2i(3, 1): {"type": "old_bridge"},
		Vector2i(4, 1): {"type": "ferry"}
	}

func _sellable_items() -> Array:
	var result: Array = []
	for item_id_variant in inventory_items.keys():
		var item_id := str(item_id_variant)
		var amount := int(inventory_items.get(item_id, 0))
		if amount <= 0:
			continue
		var definition: Dictionary = item_defs.get(item_id, {})
		if str(definition.get("group", "resource")) == "resource":
			continue
		var entry := definition.duplicate(true)
		entry["id"] = item_id
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sell_value", 0)) > int(b.get("sell_value", 0))
	)
	return result

func _sell_value(entry: Dictionary) -> int:
	var base_value := int(entry.get("sell_value", 1))
	if _npc_relation("peddler") >= 2:
		base_value += maxi(1, int(ceil(float(base_value) * 0.20)))
	return base_value

func _talk_to_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		_set_log("对方摇头，没有多说。")
		return
	var score := _npc_relation(npc_id) + 1
	if relation_model != null:
		relation_model.set_score(npc_id, score)
	var line := _npc_line(npc_id, _npc_relation(npc_id))
	var unlock_effects := _npc_unlock_effects(npc_id)
	if _npc_relation(npc_id) >= 3 and not unlock_effects.is_empty() and not _contact_unlocked(npc_id):
		if relation_model != null:
			relation_model.set_contact_unlocked(npc_id, true)
		line = "%s\n%s" % [line, _npc_unlock_text(npc_id)]
		contact_unlocked.emit(unlock_effects, line)
	_set_log(line)

func _npc_relation(npc_id: String) -> int:
	if relation_model == null:
		return 0
	return relation_model.get_score(npc_id)

func _contact_unlocked(npc_id: String) -> bool:
	return relation_model != null and relation_model.has_unlocked_contact(npc_id)

func _npc_hotspot_body(npc_id: String, fallback: String) -> String:
	var score := _npc_relation(npc_id)
	if score <= 0:
		return fallback
	return "%s：%s" % [_npc_name(npc_id), _npc_relation_label(score)]

func _npc_relation_label(score: int) -> String:
	if score >= 3:
		return "可信"
	if score >= 2:
		return "熟络"
	return "面熟"

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
			return "路人"

func _npc_unlock_effects(npc_id: String) -> Array:
	match npc_id:
		"grocer":
			return ["mark_grocer_grain_contact"]
		"doctor":
			return ["mark_doctor_medicine_contact"]
		"peddler":
			return ["mark_peddler_old_goods_contact"]
		"tea_oldman":
			return ["mark_tea_debt_contact"]
		"porter":
			return ["mark_porter_ferry_contact"]
		_:
			return []

func _npc_unlock_text(npc_id: String) -> String:
	match npc_id:
		"grocer":
			return "新门路：粮铺后门以后可以走暗粮线，次日占卜可能出现。"
		"doctor":
			return "新门路：周郎中愿意让你帮忙送药、换药，次日占卜可能出现。"
		"peddler":
			return "新门路：游货郎愿意私下替你问旧物暗价，次日占卜可能出现。"
		"tea_oldman":
			return "新门路：茶棚老人会提前漏出债主动向，次日占卜可能出现。"
		"porter":
			return "新门路：码头脚夫给你留了渡口零活，次日占卜可能出现。"
		_:
			return ""

func _start_task(task_id: String) -> void:
	if task_id.is_empty() or relation_model == null:
		_set_log("这桩事暂时接不起来。")
		return
	if relation_model.is_task_completed(task_id):
		_set_log("这桩委托已经了结。")
		return
	relation_model.set_task_state(task_id, "active")
	var text := _task_start_text(task_id)
	_set_log(text)
	task_started.emit(task_id, text)

func _complete_task(task_id: String) -> void:
	if task_id.is_empty() or relation_model == null:
		_set_log("这桩事暂时交不了。")
		return
	if not relation_model.is_task_active(task_id):
		_set_log("你还没接下这桩委托。")
		return
	if str(cells.get(current_cell, {}).get("type", "")) != _task_target_scene(task_id):
		_set_log("这桩委托要去%s交付。" % _scene_name(_task_target_scene(task_id)))
		return
	relation_model.set_task_state(task_id, "completed")
	var effects := _task_reward_effects(task_id)
	var text := _task_complete_text(task_id)
	_set_log(text)
	task_completed.emit(task_id, effects, text)

func _task_active(task_id: String) -> bool:
	return relation_model != null and relation_model.is_task_active(task_id)

func _task_completed(task_id: String) -> bool:
	return relation_model != null and relation_model.is_task_completed(task_id)

func _task_title(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "搬压潮粮"
		"doctor_delivery":
			return "送急药包"
		"peddler_appraisal":
			return "试旧物暗价"
		"tea_warning":
			return "记催债口风"
		"porter_ferry_note":
			return "跑渡口口信"
		_:
			return "小委托"

func _task_body(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "去后巷暗仓搬粮，再回来领谢礼"
		"doctor_delivery":
			return "去病家门前送药，换药材或治寒方"
		"peddler_appraisal":
			return "去后巷问暗价，可能引出旧物线"
		"tea_warning":
			return "去旧桥看脚印，回忆催债人去向"
		"porter_ferry_note":
			return "去渡口送口信，回来换工钱"
		_:
			return "接下这桩小事"

func _task_turnin_body(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "暗仓粮袋已经搬完，找掌柜领谢礼"
		"doctor_delivery":
			return "药包送到病家，回郎中处交差"
		"peddler_appraisal":
			return "暗价问清，回货郎处交口风"
		"tea_warning":
			return "旧桥脚印看清了，回茶桌复述"
		"porter_ferry_note":
			return "渡口口信送完，找脚夫结钱"
		_:
			return "交付委托"

func _task_start_text(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "你接下粮铺掌柜的活：把后门压潮粮挪到暗仓，别让前街客人看见。"
		"doctor_delivery":
			return "周郎中把急药包交给你，叮嘱你送到镇边病家，不要多问。"
		"peddler_appraisal":
			return "游货郎让你替他试一句暗价，看旧物买家今天收不收货。"
		"tea_warning":
			return "茶棚老人让你记住催债人的脚程，回头别说是他讲的。"
		"porter_ferry_note":
			return "码头脚夫塞给你一封口信，让你跑完再回来结钱。"
		_:
			return "你接下一桩小委托。"

func _task_complete_text(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "你把压潮粮搬进暗仓，掌柜给了粮，也多信你一分。"
		"doctor_delivery":
			return "急药送到，周郎中给你一包草药，又教了压寒的方子。"
		"peddler_appraisal":
			return "你带回暗价口风，货郎给了钱，还透露旧玉有人收。"
		"tea_warning":
			return "你把债主动向记清，茶棚老人点点头，让你这两日少走村口。"
		"porter_ferry_note":
			return "口信送到，脚夫按约给了工钱，还分你一点干粮。"
		_:
			return "你交付了委托。"

func _task_reward_effects(task_id: String) -> Array:
	match task_id:
		"grocer_supply":
			return ["gain_food_medium", "mark_grocer_grain_contact"]
		"doctor_delivery":
			return ["gain_herb_small", "clear_cold_mild", "clear_cold_worse", "mark_doctor_medicine_contact"]
		"peddler_appraisal":
			return ["gain_money_small", "mark_jade_buyer_clue", "mark_peddler_old_goods_contact"]
		"tea_warning":
			return ["lose_suspicion_small", "clear_met_collector", "mark_tea_debt_contact"]
		"porter_ferry_note":
			return ["gain_money_small", "gain_food_small", "mark_porter_ferry_contact"]
		_:
			return []

func _maybe_resolve_task_step(scene_type: String) -> String:
	if relation_model == null:
		return ""
	for task_id in _active_tasks_for_scene(scene_type):
		var key := "%s:%s" % [task_id, scene_type]
		if resolved_task_steps.has(key):
			continue
		resolved_task_steps[key] = true
		var effects := _task_step_effects(task_id)
		var text := _task_step_text(task_id)
		if not effects.is_empty():
			task_completed.emit("", effects, text)
		return text
	return ""

func _task_step_effects(task_id: String) -> Array:
	match task_id:
		"grocer_supply":
			return ["lose_stamina_small"]
		"doctor_delivery":
			return ["lose_stamina_small"]
		"peddler_appraisal":
			return ["gain_attention_small"]
		"tea_warning":
			return ["lose_suspicion_small"]
		"porter_ferry_note":
			return ["mark_cold_mild"]
		_:
			return []

func _task_step_text(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "你钻进后巷暗仓搬压潮粮，粮袋潮重，肩膀很快发酸。"
		"doctor_delivery":
			return "你把急药包送到病家门前，屋内咳声压得人心口发闷。"
		"peddler_appraisal":
			return "你在后巷替货郎问暗价，对方没露面，却有人记住了你的身形。"
		"tea_warning":
			return "你在旧桥看清催债人的脚印，确认他们今天绕了远路。"
		"porter_ferry_note":
			return "你踩着渡口湿泥送口信，冷水灌进鞋里，寒意往上爬。"
		_:
			return ""

func _active_tasks_for_scene(scene_type: String) -> Array[String]:
	var result: Array[String] = []
	if relation_model == null:
		return result
	for task_id in ["grocer_supply", "doctor_delivery", "peddler_appraisal", "tea_warning", "porter_ferry_note"]:
		if relation_model.is_task_active(task_id) and _task_target_scene(task_id) == scene_type:
			result.append(task_id)
	return result

func _task_target_scene(task_id: String) -> String:
	match task_id:
		"grocer_supply", "peddler_appraisal":
			return "back_alley"
		"doctor_delivery":
			return "sick_house"
		"tea_warning":
			return "old_bridge"
		"porter_ferry_note":
			return "ferry"
		_:
			return ""

func _active_task_panel_text() -> String:
	if relation_model == null:
		return ""
	for task_id in ["grocer_supply", "doctor_delivery", "peddler_appraisal", "tea_warning", "porter_ferry_note"]:
		if relation_model.is_task_active(task_id):
			return "委托：%s -> %s" % [_task_title(task_id), _scene_name(_task_target_scene(task_id))]
	return ""

func _scene_idle_action_text(scene_type: String) -> String:
	match scene_type:
		"back_alley":
			return "后巷压着粮味和旧物味，没委托时不宜久留"
		"sick_house":
			return "门里咳声很重，没药包别贸然进门"
		"old_bridge":
			return "桥下水声杂乱，脚印很快会被踩乱"
		"ferry":
			return "渡口泥深水冷，没口信就少踩湿泥"
		_:
			return "此处暂时无事"

func _scene_idle_log(scene_type: String) -> String:
	match scene_type:
		"back_alley":
			return "你在后巷看了一圈，暗仓和纸条都不是能随手碰的东西。"
		"sick_house":
			return "病家门前药味很重，你没有药包，只能退开。"
		"old_bridge":
			return "旧桥下人来人往，没要打听的事，久留反惹眼。"
		"ferry":
			return "渡口冷风贴着水面吹来，你没接活，不想白白湿脚。"
		_:
			return "你观察了一阵，没有发现值得动手的事。"

func _npc_line(npc_id: String, score: int) -> String:
	match npc_id:
		"grocer":
			if score >= 3:
				return "粮铺掌柜把算盘往里推了推：你若真缺粮，明早走后门，我给你留一小袋压潮的，便宜些。"
			if score >= 2:
				return "粮铺掌柜认出你，低声说：别一口气买太多，王怀安的人最近盯着谁家有余粮。"
			return "粮铺掌柜压低声音说：荒年粮贵，有钱也别一次买太多，容易被人盯上。"
		"doctor":
			if score >= 3:
				return "周郎中把药纸折好：寒症拖久会伤底子，清露苔、苦叶草都能先压一压，紫芝别轻易卖给外行。"
			if score >= 2:
				return "周郎中捻着胡子：山里若见紫芝、山参，别在村口出手，去后巷找熟人。"
			return "周郎中扫了眼你的脸色：脸白、肩沉，像是亏了气力，药能救急，饭才养人。"
		"peddler":
			if score >= 3:
				return "游货郎把秤砣往你这边挪了半寸：旧玉、私印这类东西别摆出来，我能替你问暗价。"
			if score >= 2:
				return "游货郎笑了一下：你带来的东西不像寻常农户捡的，我压价，但也替你挡闲话。"
			return "游货郎扫了一眼你的包袱：空手来，空手回，倒也安全。"
		"tea_oldman":
			if score >= 3:
				return "茶棚老人敲敲桌沿：王怀安催债前会先找里正问话，你若要还钱，别挑他上门那天。"
			if score >= 2:
				return "茶棚老人说：王怀安最近催得急，谁家突然有钱，谁家就先遭殃。"
			return "茶棚老人只给你续了半碗淡茶，闲话说到一半便停了。"
		"porter":
			if score >= 3:
				return "码头脚夫说：河对岸缺送信的人，你若能跑两趟，既有钱，也能少被村里人看见。"
			if score >= 2:
				return "码头脚夫说：河对岸有零活，但别走夜路，最近有人在桥下翻包袱。"
			return "码头脚夫看你一眼：问路可以，问活计得让人先知道你靠不靠得住。"
		_:
			return "对方摇头，没有多说。"

func _item_label(entry: Dictionary) -> String:
	return "%s%s" % [_rarity_prefix(str(entry.get("rarity", "common"))), str(entry.get("name", "未知"))]

func _item_name(item_id: String) -> String:
	var definition: Dictionary = item_defs.get(item_id, {})
	return str(definition.get("name", item_id))

func _rarity_prefix(rarity_id: String) -> String:
	match rarity_id:
		"fine":
			return "【优质】"
		"rare":
			return "【稀有】"
		"precious":
			return "【珍贵】"
		"legendary":
			return "【传说】"
		"mythic":
			return "【神话】"
		_:
			return "【普通】"

func _scene_name(scene_type: String) -> String:
	match scene_type:
		"gate":
			return "镇口"
		"grocer":
			return "杂货铺"
		"apothecary":
			return "药铺"
		"pawn":
			return "货郎摊"
		"tea":
			return "茶棚"
		"back_alley":
			return "后巷暗仓"
		"sick_house":
			return "病家门前"
		"old_bridge":
			return "旧桥脚印"
		"ferry":
			return "河渡口"
		_:
			return "街巷"

func _scene_desc(scene_type: String) -> String:
	match scene_type:
		"gate":
			return "这里是进出乡镇的口子，人多但也最容易脱身。"
		"grocer":
			return "粮袋堆在柜后，掌柜眼尖，买多了难免被记住。"
		"apothecary":
			return "草药味压过了霉味，郎中只认成色和价钱。"
		"pawn":
			return "货郎什么都收，但也什么都压价。"
		"tea":
			return "茶棚是闲话最多的地方，消息和麻烦都从这里流过。"
		"back_alley":
			return "后巷狭窄阴湿，粮铺暗仓和货郎纸条都藏在不见光的地方。"
		"sick_house":
			return "病家门帘半垂，药味和咳声压在屋里，送错药会坏事。"
		"old_bridge":
			return "旧桥下水声杂，催债人的脚印常从这里绕进村路。"
		"ferry":
			return "渡口泥深水冷，脚夫短活多，湿寒也重。"
		_:
			return "街巷窄而杂，适合买卖前先看清退路。"

func _scene_color(scene_type: String) -> Color:
	match scene_type:
		"gate":
			return Color(0.14, 0.10, 0.07, 1.0)
		"grocer":
			return Color(0.17, 0.12, 0.07, 1.0)
		"apothecary":
			return Color(0.08, 0.14, 0.08, 1.0)
		"pawn":
			return Color(0.13, 0.10, 0.08, 1.0)
		"tea":
			return Color(0.16, 0.11, 0.07, 1.0)
		"back_alley":
			return Color(0.10, 0.08, 0.055, 1.0)
		"sick_house":
			return Color(0.075, 0.12, 0.075, 1.0)
		"old_bridge", "ferry":
			return Color(0.065, 0.11, 0.12, 1.0)
		_:
			return Color(0.12, 0.09, 0.06, 1.0)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.015, 0.012, 0.010, 0.92)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _set_log(text: String) -> void:
	_last_log = text
	log_changed.emit(text)
