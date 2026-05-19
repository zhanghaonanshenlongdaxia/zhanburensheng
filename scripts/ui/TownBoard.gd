class_name TownBoard
extends Control

signal log_changed(text: String)
signal buy_requested(item_id: String, cost: int, summary: String)
signal sell_requested(item_id: String, value: int, summary: String)
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
var _hotspots: Array[Dictionary] = []
var _map_rects: Dictionary = {}
var _last_log: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 330.0)

func configure(option: Dictionary, defs: Dictionary, items: Dictionary) -> void:
	selected_option = option.duplicate(true)
	update_inventory(defs, items)
	cells = _town_map()
	entrance_cell = Vector2i.ZERO
	exit_cell = Vector2i(3, 0)
	current_cell = entrance_cell
	discovered.clear()
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
			_draw_shop_hotspot(scene_rect, "买粗粮", "粮食 +1，花费 3 铜钱", {"kind": "buy", "item_id": "food", "cost": 3}, 0)
			_draw_shop_hotspot(scene_rect, "买干薯根", "山薯根 +1，花费 4 铜钱", {"kind": "buy", "item_id": "dry_tuber", "cost": 4}, 1)
			_draw_shop_hotspot(scene_rect, "和掌柜闲谈", "粮价又涨了，村里人迟早撑不住。", {"kind": "npc", "line": "掌柜压低声音说：荒年粮贵，有钱也别一次买太多，容易被人盯上。"}, 2)
		"apothecary":
			_draw_shop_hotspot(scene_rect, "买药草", "药草 +1，花费 5 铜钱", {"kind": "buy", "item_id": "herb", "cost": 5}, 0)
			_draw_shop_hotspot(scene_rect, "问郎中", "打听药材行情", {"kind": "npc", "line": "郎中捻着胡子：山里若见紫芝、山参，别在村口出手，去后巷找熟人。"}, 1)
		"pawn":
			var sellables: Array = _sellable_items()
			if sellables.is_empty():
				_draw_shop_hotspot(scene_rect, "货郎回收", "你身上没有能出手的战利品", {"kind": "npc", "line": "货郎扫了一眼你的包袱：空手来，空手回，倒也安全。"}, 0)
			else:
				for index in mini(sellables.size(), 4):
					var entry: Dictionary = sellables[index]
					_draw_shop_hotspot(scene_rect, "卖 %s" % _item_label(entry), "换 %d 铜钱" % int(entry.get("sell_value", 1)), {"kind": "sell", "item_id": str(entry.get("id", "")), "value": int(entry.get("sell_value", 1))}, index)
		"tea":
			_draw_shop_hotspot(scene_rect, "听闲话", "打听里正和贾三坡的动向", {"kind": "npc", "line": "茶棚老人说：王怀安最近催得急，谁家突然有钱，谁家就先遭殃。"}, 0)
			_draw_shop_hotspot(scene_rect, "找脚夫", "问去河对岸的路", {"kind": "npc", "line": "脚夫说：河对岸有零活，但别走夜路，最近有人在桥下翻包袱。"}, 1)
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
			_set_log(str(hotspot.get("line", "对方摇头，没有多说。")))
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
	_set_log("你来到%s。" % _scene_name(str(cell_data.get("type", "street"))))
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
		Vector2i(3, 0): {"type": "gate"}
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
		_:
			return Color(0.12, 0.09, 0.06, 1.0)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.015, 0.012, 0.010, 0.92)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _set_log(text: String) -> void:
	_last_log = text
	log_changed.emit(text)
