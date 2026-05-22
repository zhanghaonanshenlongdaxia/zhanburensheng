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
const CONTACT_ROW_HEIGHT := 20.0
const TOWN_TASK_IDS: Array[String] = [
	"grocer_supply",
	"grocer_debt_grain",
	"doctor_delivery",
	"doctor_cold_house",
	"peddler_appraisal",
	"peddler_buyer_probe",
	"tea_warning",
	"tea_bridge_watch",
	"porter_ferry_note",
	"porter_hidden_work",
	"watchman_hush",
	"tenant_work_crew",
	"hunter_patrol_crew",
	"refugee_road_crew",
	"fake_seed_probe",
	"bribe_yamen",
	"constable_pressure",
	"neutralize_wang_dahu",
	"villager_uprising"
]

var selected_option: Dictionary = {}
var cells: Dictionary = {}
var current_cell: Vector2i = Vector2i.ZERO
var entrance_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var discovered: Dictionary = {}
var item_defs: Dictionary = {}
var inventory_items: Dictionary = {}
var relation_model: RefCounted
var active_flags: Dictionary = {}
var player_stats: Dictionary = {}
var resolved_task_steps: Dictionary = {}
var _hotspots: Array[Dictionary] = []
var _map_rects: Dictionary = {}
var _last_log: String = ""
var _town_background_textures: Dictionary = {}
var _town_npc_textures: Dictionary = {}
var _contact_scroll_offset := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 330.0)
	_load_town_assets()

func configure(option: Dictionary, defs: Dictionary, items: Dictionary, relations: RefCounted = null, flags: Dictionary = {}, stats: Dictionary = {}) -> void:
	selected_option = option.duplicate(true)
	relation_model = relations
	active_flags = flags.duplicate(true)
	player_stats = stats.duplicate(true)
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

func update_runtime_state(flags: Dictionary, stats: Dictionary, items: Dictionary = {}) -> void:
	active_flags = flags.duplicate(true)
	player_stats = stats.duplicate(true)
	if not items.is_empty():
		inventory_items = items.duplicate(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _contact_panel_rect().has_point(pos):
				var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll_contacts(direction * CONTACT_ROW_HEIGHT)
				accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
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
	var background_texture: Texture2D = _town_background_textures.get(scene_type, null) as Texture2D
	if background_texture == null:
		background_texture = _town_background_textures.get("street", null) as Texture2D
	if background_texture != null:
		_draw_cover_texture(background_texture, scene_rect)
	else:
		_draw_town_texture(scene_rect, scene_type)
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(scene_rect.position, Vector2(scene_rect.size.x, 84.0)), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(scene_rect.position + Vector2(0.0, scene_rect.size.y - 88.0), Vector2(scene_rect.size.x, 88.0)), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.38), false, 2.0)

	var font := get_theme_default_font()
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 30.0), "乡镇 · %s" % _scene_name(scene_type), 22, Color(0.98, 0.86, 0.55, 1.0), 4, scene_rect.size.x - 36.0)
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 58.0), _scene_desc(scene_type), 14, Color(0.90, 0.80, 0.60, 1.0), 3, scene_rect.size.x - 36.0)

	_draw_scene_npc_portraits(scene_rect, scene_type)

	match scene_type:
		"grocer":
			var food_cost := 2 if _npc_relation("grocer") >= 2 or _has_flag("deduced_support_network") else 3
			if _npc_relation("grocer") >= 3 and _has_flag("deduced_support_network"):
				food_cost = 1
			_draw_shop_hotspot(scene_rect, "买粗粮", "粮食 +1，花费 %d 铜钱" % food_cost, {"kind": "buy", "item_id": "food", "cost": food_cost}, 0)
			_draw_shop_hotspot(scene_rect, "买干薯根", "山薯根 +1，花费 4 铜钱", {"kind": "buy", "item_id": "dry_tuber", "cost": 4}, 1)
			_draw_shop_hotspot(scene_rect, "和掌柜闲谈", _npc_hotspot_body("grocer", "粮价又涨了，村里人迟早撑不住。"), {"kind": "npc", "npc_id": "grocer"}, 2)
			_draw_npc_task_hotspot(scene_rect, "grocer_supply", "grocer", 3)
			_draw_npc_task_hotspot(scene_rect, "grocer_debt_grain", "grocer", 4)
		"apothecary":
			var herb_cost := 4 if _npc_relation("doctor") >= 2 or _has_flag("deduced_support_network") else 5
			_draw_shop_hotspot(scene_rect, "买药草", "药草 +1，花费 %d 铜钱" % herb_cost, {"kind": "buy", "item_id": "herb", "cost": herb_cost}, 0)
			_draw_shop_hotspot(scene_rect, "问郎中", _npc_hotspot_body("doctor", "打听药材行情"), {"kind": "npc", "npc_id": "doctor"}, 1)
			_draw_npc_task_hotspot(scene_rect, "doctor_delivery", "doctor", 2)
			_draw_npc_task_hotspot(scene_rect, "doctor_cold_house", "doctor", 3)
		"pawn":
			var sellables: Array = _sellable_items()
			if sellables.is_empty():
				_draw_shop_hotspot(scene_rect, "货郎回收", _npc_hotspot_body("peddler", "你身上没有能出手的战利品"), {"kind": "npc", "npc_id": "peddler"}, 0)
				_draw_npc_task_hotspot(scene_rect, "peddler_appraisal", "peddler", 1)
				_draw_npc_task_hotspot(scene_rect, "peddler_buyer_probe", "peddler", 2)
			else:
				for index in mini(sellables.size(), 4):
					var entry: Dictionary = sellables[index]
					var value := _sell_value(entry)
					_draw_shop_hotspot(scene_rect, "卖 %s" % _item_label(entry), "换 %d 铜钱" % value, {"kind": "sell", "item_id": str(entry.get("id", "")), "value": value}, index)
				_draw_npc_task_hotspot(scene_rect, "peddler_appraisal", "peddler", mini(sellables.size(), 4))
				_draw_npc_task_hotspot(scene_rect, "peddler_buyer_probe", "peddler", mini(sellables.size() + 1, 5))
		"tea":
			_draw_shop_hotspot(scene_rect, "听闲话", _npc_hotspot_body("tea_oldman", "打听里正和贾三坡的动向"), {"kind": "npc", "npc_id": "tea_oldman"}, 0)
			_draw_shop_hotspot(scene_rect, "找脚夫", _npc_hotspot_body("porter", "问去河对岸的路"), {"kind": "npc", "npc_id": "porter"}, 1)
			_draw_shop_hotspot(scene_rect, "敷衍贾三坡", _npc_hotspot_body("jia_sanpo", "他正竖着耳朵听谁家欠债"), {"kind": "npc", "npc_id": "jia_sanpo"}, 2)
			_draw_npc_task_hotspot(scene_rect, "tea_warning", "tea_oldman", 3)
			_draw_npc_task_hotspot(scene_rect, "porter_ferry_note", "porter", 4)
			_draw_npc_task_hotspot(scene_rect, "watchman_hush", "tea_oldman", 5)
			_draw_npc_task_hotspot(scene_rect, "tea_bridge_watch", "tea_oldman", 6)
			_draw_npc_task_hotspot(scene_rect, "porter_hidden_work", "porter", 7)
		"village_yard":
			_draw_land_grab_hotspots(scene_rect, scene_type)
		"seed_market":
			_draw_land_grab_hotspots(scene_rect, scene_type)
		"tavern":
			_draw_shop_hotspot(scene_rect, "看住王大虎", _npc_hotspot_body("wang_dahu", "他正倚在酒缸旁，和衙役熟得很"), {"kind": "npc", "npc_id": "wang_dahu"}, 0)
			_draw_land_grab_hotspots(scene_rect, scene_type)
		"yamen":
			_draw_shop_hotspot(scene_rect, "拜会刘捕头", _npc_hotspot_body("constable", "门口差役只认银钱和熟脸"), {"kind": "npc", "npc_id": "constable"}, 0)
			_draw_land_grab_hotspots(scene_rect, scene_type)
		"back_alley", "sick_house", "old_bridge", "ferry", "tenant_field", "hunter_woodline", "refugee_lane", "ancestral_hall", "seed_store", "tavern_backroom", "yamen_archive":
			_draw_task_target_hotspots(scene_rect, scene_type)
		_:
			_draw_shop_hotspot(scene_rect, "观察街面", "记住人流和退路", {"kind": "npc", "line": "街上人来人往。你低着头走，没人把你和村里的落魄泼皮联系起来。"}, 0)

	if current_cell == exit_cell:
		_draw_shop_hotspot(scene_rect, "离镇返村", "结束今日城镇外出", {"kind": "extract"}, 4)

func _load_town_assets() -> void:
	for id in ["gate", "street", "grocer", "apothecary", "pawn", "tea", "back_alley", "sick_house", "old_bridge", "ferry", "village_yard", "seed_market", "tavern", "yamen"]:
		_town_background_textures[id] = _load_texture_from_file("res://assets/generated/town/backgrounds/%s.jpg" % id)
	for id in ["grocer", "doctor", "peddler", "tea_oldman", "porter", "jia_sanpo", "constable", "wang_dahu"]:
		_town_npc_textures[id] = _load_texture_from_file("res://assets/generated/town/npcs/%s.jpg" % id)

func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported_texture: Texture2D = ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image_path: String = path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(image_path):
		return null
	var image: Image = Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _draw_cover_texture(texture: Texture2D, rect: Rect2) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	var texture_aspect := texture_size.x / texture_size.y
	var target_aspect := rect.size.x / maxf(rect.size.y, 1.0)
	if texture_aspect > target_aspect:
		var source_width := texture_size.y * target_aspect
		source_rect.position.x = (texture_size.x - source_width) * 0.5
		source_rect.size.x = source_width
	else:
		var source_height := texture_size.x / target_aspect
		source_rect.position.y = (texture_size.y - source_height) * 0.5
		source_rect.size.y = source_height
	draw_texture_rect_region(texture, rect, source_rect)

func _draw_scene_npc_portraits(scene_rect: Rect2, scene_type: String) -> void:
	var npc_ids := _scene_npc_ids(scene_type)
	if npc_ids.is_empty():
		return
	var font := get_theme_default_font()
	var icon_size := 54.0
	var gap := 8.0
	var total_width := float(npc_ids.size()) * icon_size + float(maxi(npc_ids.size() - 1, 0)) * gap
	var start := scene_rect.position + Vector2(scene_rect.size.x - total_width - 18.0, 20.0)
	for index in npc_ids.size():
		var npc_id: String = npc_ids[index]
		var texture: Texture2D = _town_npc_textures.get(npc_id, null) as Texture2D
		var rect := Rect2(start + Vector2(float(index) * (icon_size + gap), 0.0), Vector2(icon_size, icon_size))
		draw_rect(rect.grow(3.0), Color(0.03, 0.025, 0.02, 0.82))
		if texture != null:
			_draw_cover_texture(texture, rect)
		else:
			draw_rect(rect, Color(0.18, 0.13, 0.08, 0.92))
		draw_rect(rect, Color(0.96, 0.72, 0.36, 0.56), false, 1.0)
		_draw_outlined_string(font, rect.position + Vector2(0.0, icon_size + 15.0), _npc_name(npc_id), 11, Color(0.92, 0.82, 0.62, 1.0), 2, icon_size + 18.0)

func _scene_npc_ids(scene_type: String) -> Array[String]:
	match scene_type:
		"grocer":
			return ["grocer"]
		"apothecary", "sick_house":
			return ["doctor"]
		"pawn", "back_alley":
			return ["peddler"]
		"tea":
			return ["tea_oldman", "porter", "jia_sanpo"]
		"tavern":
			return ["wang_dahu"]
		"yamen":
			return ["constable"]
		"ferry":
			return ["porter"]
		"old_bridge":
			return ["tea_oldman"]
		_:
			return []

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
	var cols := 3 if scene_rect.size.x >= 620.0 else 2
	var row := index / cols
	var col := index % cols
	var gap := 10.0
	var rect_width := minf(196.0, (scene_rect.size.x - 44.0 - float(cols - 1) * gap) / float(cols))
	var rect := Rect2(
		scene_rect.position + Vector2(22.0 + float(col) * (rect_width + gap), 90.0 + float(row) * 56.0),
		Vector2(rect_width, 48.0)
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
	if not _task_available(task_id):
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

func _draw_land_grab_hotspots(scene_rect: Rect2, scene_type: String) -> void:
	if not _has_flag("land_grab_started"):
		_draw_shop_hotspot(scene_rect, "观察街面", "还债前，里正夺地的线头尚未露出来", {"kind": "npc", "line": "你看了半晌，只觉得镇上今日仍旧照常做买卖。"}, 1)
		return
	if _draw_active_task_return_hotspots(scene_rect, scene_type):
		return
	match scene_type:
		"village_yard":
			_draw_shop_hotspot(scene_rect, "雇佃户修沟", "花 18 铜钱，民心 +24，佃户 +18", {
				"kind": "task_start",
				"task_id": "tenant_work_crew"
			}, 0)
			_draw_shop_hotspot(scene_rect, "请猎户巡夜", "花 18 铜钱，民心 +24，猎户 +18", {
				"kind": "task_start",
				"task_id": "hunter_patrol_crew"
			}, 1)
			_draw_shop_hotspot(scene_rect, "雇流民补路", "花 18 铜钱，民心 +24，流民 +18", {
				"kind": "task_start",
				"task_id": "refugee_road_crew"
			}, 2)
			_draw_shop_hotspot(scene_rect, "借假种子鼓动村民", "民心 70，三类人各 18，先处理王大虎或衙门", {
				"kind": "task_start",
				"task_id": "villager_uprising",
				"min_gratitude": 70,
				"min_stats": {"tenant_support": 18, "hunter_support": 18, "refugee_support": 18},
				"require_flags": ["fake_seed_proof", "lizheng_son_neutralized"],
				"forbid_flags": ["lizheng_killed"]
			}, 3)
			_draw_shop_hotspot(scene_rect, "夜入里正宅", "最差路线：暗杀留田，怀疑大涨", {
				"kind": "effects",
				"task_id": "assassinate_lizheng",
				"forbid_flags": ["lizheng_killed"],
				"effect_ids": ["mark_lizheng_assassinated", "mark_lizheng_killed", "gain_suspicion_small", "gain_suspicion_small", "lose_health_small"],
				"summary": "你趁夜翻进王怀安后宅。刀落得很快，天也黑得很久。地暂时保住了，可这件事没有证据、没有众人，只有你一个人背着血味离开。"
			}, 4)
		"seed_market":
			_draw_shop_hotspot(scene_rect, "查假种子", "翻种袋、对口供，取得导火索", {
				"kind": "task_start",
				"task_id": "fake_seed_probe",
				"require_flags": ["land_deed_clue"],
				"forbid_flags": ["fake_seed_proof"]
			}, 1)
		"tavern":
			_draw_shop_hotspot(scene_rect, "摆平王大虎", "需已打点衙役或刘捕头撑腰", {
				"kind": "task_start",
				"task_id": "neutralize_wang_dahu",
				"require_flags": ["lizheng_son_pressure"],
				"require_any_flags": ["yamen_bribed", "constable_protection"],
				"forbid_flags": ["lizheng_son_neutralized"]
			}, 1)
		"yamen":
			_draw_shop_hotspot(scene_rect, "重金打点衙役", "花 18 铜钱，禁止王大虎借衙门拿人", {
				"kind": "task_start",
				"task_id": "bribe_yamen",
				"min_money": 18,
				"forbid_flags": ["yamen_bribed"]
			}, 1)
			_draw_shop_hotspot(scene_rect, "请刘捕头压案", "刘捕头关系 3，压住王大虎黑状", {
				"kind": "task_start",
				"task_id": "constable_pressure",
				"min_relation": {"constable": 3},
				"forbid_flags": ["constable_protection"]
			}, 2)
		_:
			_draw_shop_hotspot(scene_rect, "观察夺地风声", "王怀安的线头不在这里", {"kind": "npc", "line": "你听到的都是碎话，真正能推进夺地主线的地方在村场、种市、酒馆和衙门。"}, 1)

func _draw_active_task_return_hotspots(scene_rect: Rect2, scene_type: String) -> bool:
	var tasks := _active_tasks_for_scene(scene_type)
	if tasks.is_empty():
		return false
	for index in tasks.size():
		var task_id := tasks[index]
		var body := _task_turnin_body(task_id) if _task_steps_ready(task_id) else _task_missing_step_text(task_id)
		_draw_shop_hotspot(scene_rect, "交付：%s" % _task_title(task_id), body, {"kind": "task_complete", "task_id": task_id}, index)
	return true

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
	var panel_rect := _contact_panel_rect()
	var panel_origin := panel_rect.position + Vector2(8.0, 8.0)
	draw_rect(panel_rect, Color(0.025, 0.022, 0.018, 0.78))
	draw_rect(panel_rect, Color(0.78, 0.54, 0.26, 0.28), false, 1.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, panel_origin + Vector2(0.0, 12.0), "镇上人脉", 14, Color(0.94, 0.84, 0.60, 1.0), 3, 160.0)
	var task_text := _active_task_panel_text()
	var entries := _contact_entries()
	var list_top := panel_origin.y + 28.0
	var list_bottom := panel_rect.end.y - (42.0 if not task_text.is_empty() else 24.0)
	var list_height := maxf(list_bottom - list_top, CONTACT_ROW_HEIGHT)
	_contact_scroll_offset = clampf(_contact_scroll_offset, 0.0, _contact_max_scroll(entries, list_height))
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var entry_y := list_top + float(index) * CONTACT_ROW_HEIGHT - _contact_scroll_offset
		if entry_y < list_top or entry_y + CONTACT_ROW_HEIGHT > list_bottom:
			continue
		var npc_id := str(entry.get("npc_id", ""))
		if not npc_id.is_empty():
			var texture: Texture2D = _town_npc_textures.get(npc_id, null) as Texture2D
			var icon_rect := Rect2(Vector2(panel_origin.x, entry_y + 1.0), Vector2(14.0, 14.0))
			draw_rect(icon_rect.grow(1.0), Color(0.04, 0.032, 0.025, 0.92))
			if texture != null:
				_draw_cover_texture(texture, icon_rect)
			draw_rect(icon_rect, Color(0.90, 0.66, 0.32, 0.45), false, 1.0)
		var text_x := 20.0 if not npc_id.is_empty() else 0.0
		_draw_outlined_string(font, Vector2(panel_origin.x + text_x, entry_y + 14.0), str(entry.get("text", "")), 12, Color(0.82, 0.78, 0.66, 1.0), 2, panel_rect.size.x - 18.0 - text_x)
	var max_scroll := _contact_max_scroll(entries, list_height)
	if max_scroll > 0.0:
		var track := Rect2(Vector2(panel_rect.end.x - 7.0, list_top), Vector2(3.0, list_height))
		var thumb_height := maxf(18.0, list_height * list_height / (float(entries.size()) * CONTACT_ROW_HEIGHT))
		var thumb_y := list_top + (_contact_scroll_offset / max_scroll) * (list_height - thumb_height)
		draw_rect(track, Color(0.11, 0.095, 0.075, 0.82))
		draw_rect(Rect2(Vector2(track.position.x, thumb_y), Vector2(track.size.x, thumb_height)), Color(0.82, 0.62, 0.32, 0.86))
	if not task_text.is_empty():
		_draw_outlined_string(font, Vector2(panel_origin.x, panel_rect.end.y - 14.0), task_text, 11, Color(0.90, 0.74, 0.42, 1.0), 2, panel_rect.size.x - 16.0)

func _contact_panel_rect() -> Rect2:
	var top := 190.0
	var bottom := size.y - 52.0
	var height := maxf(bottom - top, 112.0)
	return Rect2(Vector2(size.x - 222.0, top - 8.0), Vector2(214.0, height))

func _contact_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for npc_id in ["grocer", "doctor", "peddler", "tea_oldman", "porter", "jia_sanpo", "constable", "wang_dahu"]:
		var score := _npc_relation(npc_id)
		if score > 0:
			entries.append({
				"npc_id": npc_id,
				"text": "%s %s" % [_npc_name(npc_id), _npc_relation_label(score)]
			})
	if entries.is_empty():
		entries.append({
			"npc_id": "",
			"text": "还没人真正认得你"
		})
	return entries

func _contact_max_scroll(entries: Array, list_height: float) -> float:
	return maxf(0.0, float(entries.size()) * CONTACT_ROW_HEIGHT - list_height)

func _scroll_contacts(delta: float) -> void:
	var panel_rect := _contact_panel_rect()
	var task_text := _active_task_panel_text()
	var list_height := maxf(panel_rect.size.y - (78.0 if not task_text.is_empty() else 60.0), CONTACT_ROW_HEIGHT)
	_contact_scroll_offset = clampf(_contact_scroll_offset + delta, 0.0, _contact_max_scroll(_contact_entries(), list_height))
	queue_redraw()

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
			var npc_id := str(hotspot.get("npc_id", ""))
			if npc_id.is_empty() and hotspot.has("line"):
				_set_log(str(hotspot.get("line", "")))
			else:
				_talk_to_npc(npc_id)
			queue_redraw()
		"task_start":
			var blocked := _effect_hotspot_block_reason(hotspot)
			if not blocked.is_empty():
				_set_log(blocked)
				queue_redraw()
				return
			_start_task(str(hotspot.get("task_id", "")))
			queue_redraw()
		"task_complete":
			_complete_task(str(hotspot.get("task_id", "")))
			queue_redraw()
		"effects":
			_activate_effect_hotspot(hotspot)
			queue_redraw()
		"extract":
			extracted.emit("你从镇口离开，趁天色未暗赶回村里。")

func _activate_effect_hotspot(hotspot: Dictionary) -> void:
	var blocked := _effect_hotspot_block_reason(hotspot)
	if not blocked.is_empty():
		_set_log(blocked)
		return
	var effects: Array = hotspot.get("effect_ids", [])
	var summary := str(hotspot.get("summary", "你处理完这件事。"))
	_set_log(summary)
	task_completed.emit(str(hotspot.get("task_id", "")), effects, summary)

func _effect_hotspot_block_reason(hotspot: Dictionary) -> String:
	var min_money := int(hotspot.get("min_money", 0))
	if min_money > 0 and int(inventory_items.get("money", 0)) < min_money:
		return "铜钱不够，这件事压不住。"
	var min_gratitude := int(hotspot.get("min_gratitude", 0))
	if min_gratitude > 0 and _player_stat("villager_gratitude") < min_gratitude:
		return "民心还不够，村民不会为了你冒这个险。"
	var min_stats: Dictionary = hotspot.get("min_stats", {})
	for stat_id_variant in min_stats.keys():
		var stat_id := str(stat_id_variant)
		if _player_stat(stat_id) < int(min_stats[stat_id_variant]):
			return "%s还没站到你这边。" % _support_display_name(stat_id)
	var min_relation: Dictionary = hotspot.get("min_relation", {})
	for npc_id_variant in min_relation.keys():
		var npc_id := str(npc_id_variant)
		if _npc_relation(npc_id) < int(min_relation[npc_id_variant]):
			return "%s还没信到这个地步。" % _npc_name(npc_id)
	for flag_variant in hotspot.get("require_flags", []):
		if not _has_flag(str(flag_variant)):
			return "这件事还缺关键线索。"
	var any_flags: Array = hotspot.get("require_any_flags", [])
	if not any_flags.is_empty():
		var matched := false
		for flag_variant in any_flags:
			if _has_flag(str(flag_variant)):
				matched = true
				break
		if not matched:
			return "王大虎和衙门这条路还没处理，村民不敢先动。"
	for flag_variant in hotspot.get("forbid_flags", []):
		if _has_flag(str(flag_variant)):
			return "这条路已经不必再走。"
	return ""

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
		Vector2i(4, 1): {"type": "ferry"},
		Vector2i(0, 1): {"type": "village_yard"},
		Vector2i(1, 1): {"type": "seed_market"},
		Vector2i(4, 0): {"type": "tavern"},
		Vector2i(4, -1): {"type": "yamen"},
		Vector2i(-1, 1): {"type": "tenant_field"},
		Vector2i(-1, 0): {"type": "hunter_woodline"},
		Vector2i(0, 2): {"type": "refugee_lane"},
		Vector2i(1, 2): {"type": "ancestral_hall"},
		Vector2i(2, 2): {"type": "seed_store"},
		Vector2i(5, 0): {"type": "tavern_backroom"},
		Vector2i(5, -1): {"type": "yamen_archive"}
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
	if _has_flag("deduced_old_goods_line"):
		base_value += maxi(1, int(ceil(float(base_value) * 0.15)))
	return base_value

func _talk_to_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		_set_log("对方摇头，没有多说。")
		return
	var score := _npc_relation(npc_id) + _npc_relation_gain(npc_id)
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

func _npc_relation_gain(npc_id: String) -> int:
	if npc_id in ["grocer", "doctor"] and _has_flag("deduced_support_network"):
		return 2
	if npc_id == "peddler" and _has_flag("deduced_old_goods_line"):
		return 2
	if npc_id == "tea_oldman" and (_has_flag("deduced_debt_timing") or _has_flag("deduced_old_well_route")):
		return 2
	if npc_id == "porter" and _has_flag("deduced_debt_timing"):
		return 2
	if npc_id == "constable" and (_has_flag("fake_seed_proof") or _has_flag("land_deed_clue")):
		return 2
	if npc_id == "wang_dahu":
		return 0
	return 1

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
			return "沈守仓"
		"doctor":
			return "周郎中"
		"peddler":
			return "陆算盘"
		"tea_oldman":
			return "韩半盏"
		"porter":
			return "石二橹"
		"jia_sanpo":
			return "贾三坡"
		"constable":
			return "刘捕头"
		"wang_dahu":
			return "王大虎"
		_:
			return "路人"

func _has_flag(flag_id: String) -> bool:
	return bool(active_flags.get(flag_id, false))

func _player_stat(stat_id: String) -> int:
	return int(player_stats.get(stat_id, 0))

func _support_display_name(stat_id: String) -> String:
	match stat_id:
		"tenant_support":
			return "佃户"
		"hunter_support":
			return "猎户"
		"refugee_support":
			return "流民"
		"villager_gratitude":
			return "民心"
		_:
			return stat_id

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
			return "新门路：沈守仓让你认了粮铺后门。暗粮线以后能走，但他的账本也会把人命算进去。"
		"doctor":
			return "新门路：周郎中愿意让你帮忙送药、换药。药路稳了，他的旧错也开始露出边。"
		"peddler":
			return "新门路：陆算盘愿意私下替你问旧物暗价。价钱会变高，人心也会被放上秤。"
		"tea_oldman":
			return "新门路：韩半盏会提前漏出债主动向。他只说半句，剩下半句可能更要命。"
		"porter":
			return "新门路：石二橹给你留了渡口零活。河对岸有钱，也有他一直不敢看的旧水痕。"
		"jia_sanpo":
			return "新门路：贾三坡开始记得你没有当众羞辱他。他的嘴仍脏，但未必只能卖真话。"
		_:
			return ""

func _start_task(task_id: String) -> void:
	if task_id.is_empty() or relation_model == null:
		_set_log("这桩事暂时接不起来。")
		return
	var active_task := _active_task_id()
	if not active_task.is_empty() and active_task != task_id:
		_set_log("你已经接下%s，先完成或撤回再接别的事。" % _task_title(active_task))
		return
	if relation_model.is_task_completed(task_id):
		_set_log("这桩委托已经了结。")
		return
	if not _task_available(task_id):
		_set_log("这桩事还缺一条能接上的线。")
		return
	relation_model.set_task_state(task_id, "active")
	var text := _task_start_text(task_id)
	_set_log(text)
	task_started.emit(task_id, text)

func _active_task_id() -> String:
	if relation_model == null:
		return ""
	for task_id in TOWN_TASK_IDS:
		if relation_model.is_task_active(task_id):
			return task_id
	return ""

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
	if not _task_steps_ready(task_id):
		_set_log(_task_missing_step_text(task_id))
		return
	if not _task_available(task_id):
		_set_log("条件不够，这桩事现在交不了。")
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
		"grocer_debt_grain":
			return "赊粮压债"
		"doctor_delivery":
			return "送急药包"
		"doctor_cold_house":
			return "熬驱寒汤"
		"peddler_appraisal":
			return "试旧物暗价"
		"peddler_buyer_probe":
			return "探残玉买家"
		"tea_warning":
			return "记催债口风"
		"tea_bridge_watch":
			return "桥下守风"
		"porter_ferry_note":
			return "跑渡口口信"
		"porter_hidden_work":
			return "夜渡短工"
		"watchman_hush":
			return "压旧井口风"
		"tenant_work_crew":
			return "雇佃户修沟"
		"hunter_patrol_crew":
			return "请猎户巡夜"
		"refugee_road_crew":
			return "雇流民补路"
		"fake_seed_probe":
			return "查假种子"
		"bribe_yamen":
			return "重金打点"
		"constable_pressure":
			return "请捕头压案"
		"neutralize_wang_dahu":
			return "摆平王大虎"
		"villager_uprising":
			return "祠前起事"
		_:
			return "小委托"

func _task_body(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "去后巷暗仓搬粮，再回来领谢礼"
		"grocer_debt_grain":
			return "去后巷找赊粮账，替掌柜避开催债眼线"
		"doctor_delivery":
			return "去病家门前送药，换药材或治寒方"
		"doctor_cold_house":
			return "去病家熬一锅驱寒汤，顺便学压寒方"
		"peddler_appraisal":
			return "去后巷问暗价，可能引出旧物线"
		"peddler_buyer_probe":
			return "去后巷探残玉买家的口风"
		"tea_warning":
			return "去旧桥看脚印，回忆催债人去向"
		"tea_bridge_watch":
			return "去旧桥听半夜脚步，确认谁在替债主跑腿"
		"porter_ferry_note":
			return "去渡口送口信，回来换工钱"
		"porter_hidden_work":
			return "去渡口搬一趟不挂名的货，钱少但来路干净"
		"watchman_hush":
			return "去旧桥旁认守夜人脚印，把旧井口风压住"
		"tenant_work_crew":
			return "去田边水口盯工，别让里正的人搅散佃户"
		"hunter_patrol_crew":
			return "去林边巡夜点分派猎户，压住黑夜里的脚步"
		"refugee_road_crew":
			return "去流民棚外分工，补路也要压住村里闲话"
		"fake_seed_probe":
			return "去种市后仓翻袋口，找同批瘪种子的证据"
		"bribe_yamen":
			return "去衙门案房递钱，别让王大虎的黑状先落章"
		"constable_pressure":
			return "去案房交证据，请刘捕头把黑状压住"
		"neutralize_wang_dahu":
			return "去酒馆后屋堵住王大虎的衙门熟路"
		"villager_uprising":
			return "去祠前摊开假种子和工钱账，等众人站出来"
		_:
			return "接下这桩小事"

func _task_turnin_body(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "暗仓粮袋已经搬完，找掌柜领谢礼"
		"grocer_debt_grain":
			return "赊粮账和催债眼线都理清了，回掌柜处拿粮"
		"doctor_delivery":
			return "药包送到病家，回郎中处交差"
		"doctor_cold_house":
			return "驱寒汤熬成，回郎中处领药方"
		"peddler_appraisal":
			return "暗价问清，回货郎处交口风"
		"peddler_buyer_probe":
			return "残玉买家的暗号探到了，回货郎处交话"
		"tea_warning":
			return "旧桥脚印看清了，回茶桌复述"
		"tea_bridge_watch":
			return "守风听到的脚步对上了，回茶棚复述"
		"porter_ferry_note":
			return "渡口口信送完，找脚夫结钱"
		"porter_hidden_work":
			return "夜渡短工做完，回脚夫处结钱粮"
		"watchman_hush":
			return "守夜人认了暗号，旧井这条夜路暂时稳住"
		"tenant_work_crew":
			return "水口沟渠修好，佃户拿到当天工钱，也愿意替你说地契和假种子的事。"
		"hunter_patrol_crew":
			return "猎户按约巡过田边和林口，王怀安的人没敢进村场，他们也收下了你的工钱。"
		"refugee_road_crew":
			return "流民把坑洼路面补平，村里闲话没有停，但有人第一次替他们说了句公道话。"
		"fake_seed_probe":
			return "你在种市后仓找到同批瘪种子的旧袋口，又对上借种日期。假种子的证据终于能拿到村民面前。"
		"bribe_yamen":
			return "你把一串沉钱送到衙门边门。衙役没说答应，只把王大虎递来的黑状压到案卷最底下。"
		"constable_pressure":
			return "刘捕头听完假种子和地契疑点，把刀鞘往桌上一按：衙门不能替你杀里正，但也不能让王大虎把黑状当路引。"
		"neutralize_wang_dahu":
			return "你没有动衙役，只把王大虎递黑状的路堵住。他第一次明白，熟路也会被人截断。"
		"villager_uprising":
			return "你把瘪种子、借据和工钱账摊在祠前。火把一支支亮起，村民终于把被王怀安压弯的背挺了起来。"
		_:
			return "交付委托"

func _task_start_text(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "你接下沈守仓的活：把后门压潮粮挪到暗仓，别让前街客人看见。"
		"grocer_debt_grain":
			return "沈守仓低声托你去后巷翻一页赊粮账，找出能帮你避催债眼线的人家。"
		"doctor_delivery":
			return "周郎中把急药包交给你，叮嘱你送到镇边病家，不要多问。"
		"doctor_cold_house":
			return "周郎中让你去病家灶前熬驱寒汤：看火候，也看谁家还肯替你留门。"
		"peddler_appraisal":
			return "陆算盘让你替他试一句暗价，看旧物买家今天收不收货。"
		"peddler_buyer_probe":
			return "陆算盘把残玉暗号拆成半句话，让你去后巷试买家的反应。"
		"tea_warning":
			return "韩半盏让你记住催债人的脚程，回头别说是他讲的。"
		"tea_bridge_watch":
			return "韩半盏让你在旧桥下守一阵：桥面脚步能听出谁在替王怀安跑腿。"
		"porter_ferry_note":
			return "石二橹塞给你一封口信，让你跑完再回来结钱。"
		"porter_hidden_work":
			return "石二橹给你留了一趟夜渡短工，只搬旧麻袋，不问货主名。"
		"watchman_hush":
			return "韩半盏把茶碗推到暗处：旧井边有个守夜人见过绳结，你去旧桥下认清他的脚印，别让他先开口。"
		"tenant_work_crew":
			return "你点了几个佃户去修田边水口。工钱不先给，活也不能散，得亲自盯到沟渠通水。"
		"hunter_patrol_crew":
			return "你请猎户守夜巡田。明面护庄稼，暗里拦王怀安的人，得去林边把巡夜点定下来。"
		"refugee_road_crew":
			return "你把补路的活分给无地流民。村里闲话已经起了，得去流民棚外把工序压稳。"
		"fake_seed_probe":
			return "你接下查假种子的事。种市掌柜不会明说，后仓旧袋口才是能咬住王怀安的东西。"
		"bribe_yamen":
			return "你把沉钱藏进袖里，准备去衙门案房。钱递早了白丢，递晚了王大虎的黑状就落章。"
		"constable_pressure":
			return "刘捕头要看实证。你得把假种子、地契疑点和王大虎递状的口风一起送进案房。"
		"neutralize_wang_dahu":
			return "王大虎今晚在酒馆后屋等衙役喝酒。你要堵的不是他的人，是他递黑状的路。"
		"villager_uprising":
			return "假种子、工钱账和三路人心都备好了。你得去祠前把话说完，让村民自己点火。"
		_:
			return "你接下一桩小委托。"

func _task_complete_text(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "你把压潮粮搬进暗仓，沈守仓给了粮，也多信你一分。"
		"grocer_debt_grain":
			return "你把赊粮账里的门路对上了，沈守仓给你一袋粗粮，也提醒你少从正街露面。"
		"doctor_delivery":
			return "急药送到，周郎中给你一包草药，又教了压寒的方子。"
		"doctor_cold_house":
			return "驱寒汤熬得稳，周郎中给你留了药草，顺手把寒症方子讲透。"
		"peddler_appraisal":
			return "你带回暗价口风，陆算盘给了钱，还透露旧玉有人收。"
		"peddler_buyer_probe":
			return "你带回残玉买家的反应，陆算盘压低声音说：这条线能走，但别走太急。"
		"tea_warning":
			return "你把债主动向记清，韩半盏点点头，让你这两日少走村口。"
		"tea_bridge_watch":
			return "你把桥下脚步和催债时辰对上，韩半盏替你把一段闲话压了下去。"
		"porter_ferry_note":
			return "口信送到，脚夫按约给了工钱，还分你一点干粮。"
		"porter_hidden_work":
			return "你搬完夜渡旧麻袋，脚夫给了钱粮，还告诉你哪条路少碰债主眼线。"
		"watchman_hush":
			return "你在旧桥下拿准守夜人的口风：他只认井绳三结，不认你的脸。旧井夜路暂时可以走。"
		_:
			return "你交付了委托。"

func _task_reward_effects(task_id: String) -> Array:
	if task_id == "grocer_supply" and _has_flag("deduced_support_network"):
		return ["gain_food_medium", "gain_food_small", "mark_grocer_grain_contact"]
	if task_id == "doctor_delivery" and _has_flag("deduced_support_network"):
		return ["gain_herb_small", "gain_health_tiny", "clear_cold_mild", "clear_cold_worse", "mark_doctor_medicine_contact"]
	if task_id == "peddler_appraisal" and _has_flag("deduced_old_goods_line"):
		return ["gain_money_medium", "mark_jade_buyer_clue", "mark_peddler_old_goods_contact"]
	if task_id == "tea_warning" and _has_flag("deduced_debt_timing"):
		return ["lose_suspicion_small", "lose_attention_small", "clear_met_collector", "mark_tea_debt_contact"]
	if task_id == "watchman_hush" and _has_flag("deduced_old_well_route"):
		return ["lose_suspicion_small", "mark_old_well_line", "mark_old_well_watchman_deal", "unlock_old_well_cache", "unlock_night_market_fence"]
	if task_id == "grocer_debt_grain" and _has_flag("deduced_support_network"):
		return ["gain_food_medium", "lose_attention_small", "mark_grocer_grain_contact", "mark_villager_aid_line"]
	if task_id == "doctor_cold_house" and (_has_flag("cold_mild") or _has_flag("cold_worse")):
		return ["gain_herb_small", "clear_cold_mild", "clear_cold_worse", "mark_doctor_medicine_contact"]
	if task_id == "peddler_buyer_probe" and _has_flag("deduced_old_goods_line"):
		return ["mark_jade_buyer_clue", "gain_money_small", "mark_peddler_old_goods_contact"]
	if task_id == "tea_bridge_watch" and _has_flag("deduced_debt_timing"):
		return ["lose_attention_small", "clear_met_collector", "mark_tea_debt_contact"]
	if task_id == "porter_hidden_work" and _has_flag("deduced_debt_timing"):
		return ["gain_money_small", "gain_food_small", "lose_attention_small", "mark_porter_ferry_contact"]
	match task_id:
		"grocer_supply":
			return ["gain_food_medium", "mark_grocer_grain_contact"]
		"grocer_debt_grain":
			return ["gain_food_small", "lose_suspicion_small", "mark_grocer_grain_contact"]
		"doctor_delivery":
			return ["gain_herb_small", "clear_cold_mild", "clear_cold_worse", "mark_doctor_medicine_contact"]
		"doctor_cold_house":
			return ["gain_herb_small", "gain_health_tiny", "mark_doctor_medicine_contact"]
		"peddler_appraisal":
			return ["gain_money_small", "mark_jade_buyer_clue", "mark_peddler_old_goods_contact"]
		"peddler_buyer_probe":
			return ["mark_jade_buyer_clue", "gain_attention_small", "mark_peddler_old_goods_contact"]
		"tea_warning":
			return ["lose_suspicion_small", "clear_met_collector", "mark_tea_debt_contact"]
		"tea_bridge_watch":
			return ["lose_attention_small", "mark_tea_debt_contact"]
		"porter_ferry_note":
			return ["gain_money_small", "gain_food_small", "mark_porter_ferry_contact"]
		"porter_hidden_work":
			return ["gain_money_small", "lose_stamina_small", "mark_porter_ferry_contact"]
		"watchman_hush":
			return ["lose_suspicion_small", "mark_old_well_line", "mark_old_well_watchman_deal", "unlock_old_well_cache", "unlock_night_market_fence"]
		"tenant_work_crew":
			return ["lose_money_large", "mark_villager_work_crew", "gain_villager_gratitude_medium", "gain_villager_gratitude_small", "gain_tenant_support_medium", "lose_suspicion_small"]
		"hunter_patrol_crew":
			return ["lose_money_large", "mark_villager_work_crew", "gain_villager_gratitude_medium", "gain_villager_gratitude_small", "gain_hunter_support_medium", "lose_attention_small"]
		"refugee_road_crew":
			return ["lose_money_large", "mark_villager_work_crew", "gain_villager_gratitude_medium", "gain_villager_gratitude_small", "gain_refugee_support_medium", "gain_attention_small"]
		"fake_seed_probe":
			return ["mark_fake_seed_proof", "gain_villager_gratitude_medium", "gain_attention_small"]
		"bribe_yamen":
			return ["lose_money_large", "mark_yamen_bribed", "gain_suspicion_small"]
		"constable_pressure":
			return ["mark_constable_protection", "mark_lizheng_plot_exposed", "lose_suspicion_small"]
		"neutralize_wang_dahu":
			return ["mark_lizheng_son_neutralized", "lose_relation_wang_dahu", "lose_suspicion_small"]
		"villager_uprising":
			return ["mark_villagers_rallied", "mark_lizheng_plot_exposed", "mark_lizheng_killed", "gain_attention_medium"]
		_:
			return []

func _maybe_resolve_task_step(scene_type: String) -> String:
	if relation_model == null:
		return ""
	for task_id in _active_step_tasks_for_scene(scene_type):
		var key := "%s:%s" % [task_id, scene_type]
		if resolved_task_steps.has(key):
			continue
		resolved_task_steps[key] = true
		var effects := _task_step_effects(task_id, scene_type)
		var text := _task_step_text(task_id, scene_type)
		if not effects.is_empty():
			task_completed.emit("", effects, text)
		return text
	return ""

func _task_step_effects(task_id: String, scene_type: String = "") -> Array:
	if task_id in ["grocer_supply", "doctor_delivery"] and _has_flag("deduced_support_network"):
		return []
	if task_id == "peddler_appraisal" and _has_flag("deduced_old_goods_line"):
		return ["gain_money_tiny"]
	if task_id == "tea_warning" and _has_flag("deduced_debt_timing"):
		return ["lose_suspicion_small"]
	if task_id == "watchman_hush" and _has_flag("deduced_old_well_route"):
		return ["lose_suspicion_small"]
	if task_id == "grocer_debt_grain" and _has_flag("deduced_support_network"):
		return ["lose_attention_small"]
	if task_id == "doctor_cold_house" and (_has_flag("cold_mild") or _has_flag("cold_worse")):
		return ["gain_health_tiny"]
	if task_id == "peddler_buyer_probe" and _has_flag("deduced_old_goods_line"):
		return ["gain_money_tiny"]
	if task_id == "tea_bridge_watch" and _has_flag("deduced_debt_timing"):
		return ["lose_suspicion_small"]
	if task_id == "porter_hidden_work" and _has_flag("deduced_debt_timing"):
		return ["lose_attention_small"]
	match task_id:
		"grocer_supply":
			return ["lose_stamina_small"]
		"grocer_debt_grain":
			return ["gain_attention_small"]
		"doctor_delivery":
			return ["lose_stamina_small"]
		"doctor_cold_house":
			return ["lose_stamina_small"]
		"peddler_appraisal":
			return ["gain_attention_small"]
		"peddler_buyer_probe":
			return ["gain_suspicion_small"]
		"tea_warning":
			return ["lose_suspicion_small"]
		"tea_bridge_watch":
			return ["lose_stamina_small"]
		"porter_ferry_note":
			return ["mark_cold_mild"]
		"porter_hidden_work":
			return ["lose_stamina_small"]
		"watchman_hush":
			return ["gain_attention_small"]
		"tenant_work_crew":
			return ["lose_stamina_small"]
		"hunter_patrol_crew":
			return ["lose_stamina_small"]
		"refugee_road_crew":
			return ["gain_attention_small"]
		"fake_seed_probe":
			if scene_type == "tea":
				return ["gain_attention_small"]
			return ["gain_suspicion_small"]
		"bribe_yamen":
			return ["gain_suspicion_small"]
		"constable_pressure":
			return ["lose_suspicion_small"]
		"neutralize_wang_dahu":
			return ["gain_attention_small"]
		"villager_uprising":
			if scene_type == "refugee_lane":
				return ["gain_villager_gratitude_small"]
			return ["gain_attention_medium"]
		_:
			return []

func _task_step_text(task_id: String, scene_type: String = "") -> String:
	match task_id:
		"grocer_supply":
			return "你钻进后巷暗仓搬压潮粮，粮袋潮重，肩膀很快发酸。"
		"grocer_debt_grain":
			return "你在后巷翻到几户赊粮账，知道谁能替你挡一次催债闲话，也知道这事不能让外人看见。"
		"doctor_delivery":
			return "你把急药包送到病家门前，屋内咳声压得人心口发闷。"
		"doctor_cold_house":
			return "你守着病家小灶熬汤，热气蒸得眼眶发酸，寒意却也被压下去一点。"
		"peddler_appraisal":
			return "你在后巷替货郎问暗价，对方没露面，却有人记住了你的身形。"
		"peddler_buyer_probe":
			return "你把残玉暗号说到一半就停住，对方没有接话，却把秤砣往暗处推了推。"
		"tea_warning":
			return "你在旧桥看清催债人的脚印，确认他们今天绕了远路。"
		"tea_bridge_watch":
			return "你蹲在旧桥下听了半晌，木板上的脚步一重一轻，正是王怀安跑腿常走的步子。"
		"porter_ferry_note":
			return "你踩着渡口湿泥送口信，冷水灌进鞋里，寒意往上爬。"
		"porter_hidden_work":
			return "你在渡口搬了一趟旧麻袋，货不重，水汽却直往袖口里钻。"
		"watchman_hush":
			return "你绕到旧桥桥洞下等人，听见桥面有脚步停了一瞬。"
		"tenant_work_crew":
			return "你站在田边水口盯了一下午。里正的人几次来问是谁给的工钱，佃户没散，但你也累得肩背发沉。"
		"hunter_patrol_crew":
			return "你跟猎户沿林边定巡夜点，草丛里有陌生脚印。猎户没说怕，只把弓弦重新绷紧。"
		"refugee_road_crew":
			return "你在流民棚外分石料和泥土。村里有人骂你把外人引进村，更多人却看见路面真被填平。"
		"fake_seed_probe":
			if scene_type == "tea":
				return "你路过茶棚时听见两桌人压低声音说种子。有人提到镇后仓昨夜换过袋口，也有人提醒你别让王怀安的人看见。"
			return "你翻进种市后仓，指尖摸到一排旧袋口。掌柜咳了一声，像是在提醒你别让巡街看见。"
		"bribe_yamen":
			return "你在衙门案房外等到灯影偏斜，袖里的铜钱沉得发烫，来往差役都像在看你的手。"
		"constable_pressure":
			return "你把证据按顺序摆在案房长桌上。刘捕头没有立刻接话，只把王大虎的黑状抽出来压在刀鞘下。"
		"neutralize_wang_dahu":
			return "酒馆后屋酒味呛人，王大虎的笑声很响。等他发现衙门那条路被压住，脸色才一点点沉下去。"
		"villager_uprising":
			if scene_type == "refugee_lane":
				return "你经过流民棚路时，几个补过路的人默默跟了上来。他们没有喊口号，只把锹扛在肩上。"
			return "祠前人越聚越多。佃户站在账前，猎户守在门口，流民举着修路的锹，没人再肯先退。"
		_:
			return ""

func _active_tasks_for_scene(scene_type: String) -> Array[String]:
	var result: Array[String] = []
	if relation_model == null:
		return result
	for task_id in TOWN_TASK_IDS:
		if relation_model.is_task_active(task_id) and _task_target_scene(task_id) == scene_type:
			result.append(task_id)
	return result

func _active_step_tasks_for_scene(scene_type: String) -> Array[String]:
	var result: Array[String] = []
	if relation_model == null:
		return result
	for task_id in TOWN_TASK_IDS:
		if relation_model.is_task_active(task_id) and scene_type in _task_step_scenes(task_id):
			result.append(task_id)
	return result

func _task_steps_ready(task_id: String) -> bool:
	for scene_type in _task_required_step_scenes(task_id):
		if not resolved_task_steps.has("%s:%s" % [task_id, scene_type]):
			return false
	return true

func _task_missing_step_text(task_id: String) -> String:
	var missing: Array[String] = []
	for scene_type in _task_required_step_scenes(task_id):
		if not resolved_task_steps.has("%s:%s" % [task_id, scene_type]):
			missing.append(_scene_name(scene_type))
	if missing.is_empty():
		return "这桩事还差最后确认。"
	return "还没办完，先去%s。" % "、".join(missing)

func _task_step_scenes(task_id: String) -> Array[String]:
	match task_id:
		"tenant_work_crew":
			return ["tenant_field"]
		"hunter_patrol_crew":
			return ["hunter_woodline"]
		"refugee_road_crew":
			return ["refugee_lane"]
		"fake_seed_probe":
			return ["tea", "seed_store"]
		"bribe_yamen", "constable_pressure":
			return ["yamen_archive"]
		"neutralize_wang_dahu":
			return ["tavern_backroom"]
		"villager_uprising":
			return ["refugee_lane", "ancestral_hall"]
		_:
			var target := _task_target_scene(task_id)
			return [] if target.is_empty() else [target]

func _task_required_step_scenes(task_id: String) -> Array[String]:
	match task_id:
		"fake_seed_probe":
			return ["seed_store"]
		"villager_uprising":
			return ["ancestral_hall"]
		_:
			return _task_step_scenes(task_id)

func _task_target_scene(task_id: String) -> String:
	match task_id:
		"grocer_supply", "grocer_debt_grain", "peddler_appraisal", "peddler_buyer_probe":
			return "back_alley"
		"doctor_delivery", "doctor_cold_house":
			return "sick_house"
		"tea_warning", "tea_bridge_watch", "watchman_hush":
			return "old_bridge"
		"porter_ferry_note", "porter_hidden_work":
			return "ferry"
		"tenant_work_crew", "hunter_patrol_crew", "refugee_road_crew":
			return "village_yard"
		"fake_seed_probe":
			return "seed_market"
		"bribe_yamen", "constable_pressure":
			return "yamen"
		"neutralize_wang_dahu":
			return "tavern"
		"villager_uprising":
			return "ancestral_hall"
		_:
			return ""

func _active_task_panel_text() -> String:
	if relation_model == null:
		return ""
	for task_id in TOWN_TASK_IDS:
		if relation_model.is_task_active(task_id):
			var next_target := _task_target_scene(task_id) if _task_steps_ready(task_id) else _first_missing_step_scene(task_id)
			return "委托：%s -> %s" % [_task_title(task_id), _scene_name(next_target)]
	return ""

func _first_missing_step_scene(task_id: String) -> String:
	for scene_type in _task_required_step_scenes(task_id):
		if not resolved_task_steps.has("%s:%s" % [task_id, scene_type]):
			return scene_type
	return _task_target_scene(task_id)

func _task_available(task_id: String) -> bool:
	if task_id == "watchman_hush":
		return (_has_flag("old_well_clue") or _has_flag("old_well_line")) and not _has_flag("old_well_watchman_deal")
	if task_id == "grocer_debt_grain":
		return _has_flag("deduced_support_network") or _has_flag("grocer_grain_contact") or _has_flag("met_collector")
	if task_id == "doctor_cold_house":
		return _has_flag("cold_mild") or _has_flag("cold_worse") or _has_flag("cold_severe") or _has_flag("doctor_medicine_contact")
	if task_id == "peddler_buyer_probe":
		return _has_flag("deduced_old_goods_line") or _has_flag("jade_buyer_clue") or _has_flag("peddler_old_goods_contact")
	if task_id == "tea_bridge_watch":
		return _has_flag("deduced_debt_timing") or _has_flag("met_collector") or _has_flag("tea_debt_contact")
	if task_id == "porter_hidden_work":
		return _has_flag("unlocked_errand_route") or _has_flag("porter_ferry_contact") or _has_flag("deduced_debt_timing")
	if task_id in ["tenant_work_crew", "hunter_patrol_crew", "refugee_road_crew"]:
		return _has_flag("land_grab_started") and int(inventory_items.get("money", 0)) >= 18
	if task_id == "fake_seed_probe":
		return _has_flag("land_deed_clue") and not _has_flag("fake_seed_proof")
	if task_id == "bribe_yamen":
		return _has_flag("land_grab_started") and int(inventory_items.get("money", 0)) >= 18 and not _has_flag("yamen_bribed")
	if task_id == "constable_pressure":
		return _npc_relation("constable") >= 3 and not _has_flag("constable_protection")
	if task_id == "neutralize_wang_dahu":
		return _has_flag("lizheng_son_pressure") and (_has_flag("yamen_bribed") or _has_flag("constable_protection")) and not _has_flag("lizheng_son_neutralized")
	if task_id == "villager_uprising":
		return _has_flag("fake_seed_proof") and _has_flag("lizheng_son_neutralized") and _player_stat("villager_gratitude") >= 70 and _player_stat("tenant_support") >= 18 and _player_stat("hunter_support") >= 18 and _player_stat("refugee_support") >= 18 and not _has_flag("lizheng_killed")
	return true

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
			if _has_flag("grocer_opened_hidden_granary"):
				return "沈守仓袖口还沾着仓灰：账本我自己认，粮先让他们吃。人饿到最后，算盘再响也没人听。"
			if score >= 4:
				return "沈守仓盯着后院那道落锁的门：我爹当年开仓救人，第二天被债主吊在梁上。所以我每一粒粮都要算清，可不是我天生舍不得。"
			if score >= 3:
				return "沈守仓把算盘往里推了推：你若真缺粮，明早走后门，我给你留一小袋压潮的，便宜些。"
			if score >= 2:
				return "沈守仓认出你，低声说：别一口气买太多，王怀安的人最近盯着谁家有余粮。"
			return "沈守仓压低声音说：荒年粮贵，有钱也别一次买太多，容易被人盯上。"
		"doctor":
			if _has_flag("doctor_spent_last_medicine"):
				return "周郎中咳得比病人还重：药不是给死人浪费的，所以我得先让活人撑过今晚。你别看我，我还没死。"
			if score >= 4:
				return "周郎中把药箱合上：我曾救过一个恶人，后来他害死三户人。自那以后，我先问人值不值得救，再问病能不能救。"
			if score >= 3:
				return "周郎中把药纸折好：寒症拖久会伤底子，清露苔、苦叶草都能先压一压，紫芝别轻易卖给外行。"
			if score >= 2:
				return "周郎中捻着胡子：山里若见紫芝、山参，别在村口出手，去后巷找熟人。"
			return "周郎中扫了眼你的脸色：脸白、肩沉，像是亏了气力，药能救急，饭才养人。"
		"peddler":
			if _has_flag("peddler_bought_escape_route"):
				return "陆算盘笑得还是滑：我收了他们的钱，说把你卖了。可价钱够买三条退路，亏本买卖我这辈子只做这一回。"
			if _has_flag("peddler_sold_you_out"):
				return "陆算盘避开你的眼：穷人手里只剩算盘时，先算活命，再算良心。你最好离我远些。"
			if score >= 4:
				return "陆算盘指尖拨着空秤盘：我怕穷，怕到夜里一闭眼就听见铜钱落地。没钱的人，连说不的价都没有。"
			if score >= 3:
				return "陆算盘把秤砣往你这边挪了半寸：旧玉、私印这类东西别摆出来，我能替你问暗价。"
			if score >= 2:
				return "陆算盘笑了一下：你带来的东西不像寻常农户捡的，我压价，但也替你挡闲话。"
			return "陆算盘扫了一眼你的包袱：空手来，空手回，倒也安全。"
		"tea_oldman":
			if _has_flag("tea_oldman_read_full_ledger"):
				return "韩半盏把茶盏扣在桌上：半句话害人，半本账也害人。今日我把全账念完，欠谁的命，也该算到我头上。"
			if _has_flag("old_well_clue") and score >= 2:
				return "韩半盏把茶沫拨到碗边：旧井那事别在桌上说。你若真要摸这条夜路，先去旧桥认守夜人的鞋印。"
			if score >= 4:
				return "韩半盏只倒半盏茶：当年债簿能成局，是我替他们把半句真话藏起来。人听不全，就会自己往坑里走。"
			if score >= 3:
				return "韩半盏敲敲桌沿：王怀安催债前会先找里正问话，你若要还钱，别挑他上门那天。"
			if score >= 2:
				return "韩半盏说：王怀安最近催得急，谁家突然有钱，谁家就先遭殃。"
			return "韩半盏只给你续了半碗淡茶，闲话说到一半便停了。"
		"porter":
			if _has_flag("porter_crossed_debt_ferry"):
				return "石二橹手还在抖，却把船绳系死：我弟当年没渡过去，不该人人都跟他一样。今日船翻了，也先送你过河。"
			if score >= 4:
				return "石二橹看着河面：我弟就是夜里渡人时死的。水里一声都没留，所以我收钱才撑船，不收人情。"
			if score >= 3:
				return "石二橹说：河对岸缺送信的人，你若能跑两趟，既有钱，也能少被村里人看见。"
			if score >= 2:
				return "石二橹说：河对岸有零活，但别走夜路，最近有人在桥下翻包袱。"
			return "石二橹看你一眼：问路可以，问活计得让人先知道你靠不靠得住。"
		"jia_sanpo":
			if _has_flag("jia_sanpo_false_tip"):
				return "贾三坡揉着被打青的嘴角：我卖了个假消息，价钱不低。你别谢我，我娘当年要是遇见一个肯装糊涂的人，也许能活。"
			if _has_flag("jia_sanpo_became_informer"):
				return "贾三坡笑得很薄：我先开口，就没人逼我跪下。你若觉得脏，就别走我走过的路。"
			if score >= 3:
				return "贾三坡把瓜子壳吐到脚边：我娘就是被债逼死的。后来我懂了，先把别人卖出去，自己就能少挨一顿。"
			if score >= 2:
				return "贾三坡讪笑着凑近：你也别总躲我，我嘴碎归嘴碎，谁给我半块饼，我记得比债主清楚。"
			return "贾三坡斜着眼打量你：听说你最近常出村？我就随口问问，别这么看我。"
		"constable":
			if _has_flag("constable_protection"):
				return "刘捕头把案卷扣上：王大虎那张黑状我压着，但你要拿出能让众人信的证据。衙门不能替你杀里正。"
			if score >= 3:
				return "刘捕头看完你记下的种袋口供：若王大虎借衙役拿人，我能压一阵。但你别让我压空话。"
			if score >= 2:
				return "刘捕头没有赶你走，只问：假种子是谁借出去的？地契是谁先翻的？说事，别喊冤。"
			return "刘捕头站在廊下，眼神像刀背：欠债、还债、夺地，都不是一句可怜能讲清的。"
		"wang_dahu":
			if _has_flag("lizheng_son_neutralized"):
				return "王大虎避开你的眼。他在酒馆和衙门都有人，可两头路都被堵住后，嗓门也没先前响了。"
			if _has_flag("lizheng_son_pressure"):
				return "王大虎拿酒碗磕着桌沿：还债还得这么快？你钱路不干净吧。等衙门问你，看你还嘴硬不硬。"
			return "王大虎倚在酒缸旁，身边坐着两个衙役。他还没盯上你，但这条路迟早会挡到面前。"
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
		"tenant_field":
			return "田边水口"
		"hunter_woodline":
			return "林边巡点"
		"refugee_lane":
			return "流民棚路"
		"ancestral_hall":
			return "祠前空地"
		"seed_store":
			return "种市后仓"
		"tavern_backroom":
			return "酒馆后屋"
		"yamen_archive":
			return "衙门案房"
		"village_yard":
			return "村场工地"
		"seed_market":
			return "种市后棚"
		"tavern":
			return "大酒馆"
		"yamen":
			return "衙门廊下"
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
		"tenant_field":
			return "沟渠、水口和地租账都在这里，佃户最怕被里正秋后算账。"
		"hunter_woodline":
			return "林边能看见进村小路，猎户的弓和王家的脚印都藏在夜色里。"
		"refugee_lane":
			return "棚路泥泞，流民靠短工吃饭，也最容易被栽赃成偷种子的人。"
		"ancestral_hall":
			return "祠前能聚人，也能散人。证据、工钱账和胆气都得在这里摊开。"
		"seed_store":
			return "后仓堆着旧种袋，袋口的灰和瘪籽能对上王怀安借种的日期。"
		"tavern_backroom":
			return "后屋酒味很重，王大虎常在这里递话、请酒、把黑状塞进衙门路。"
		"yamen_archive":
			return "案房灯低，黑状和证据都压在纸下，走错一步就是衙门拿人。"
		"village_yard":
			return "这里能雇村民做工。真正的民心不是施舍，是让人靠手艺挣到活路。"
		"seed_market":
			return "种袋堆在棚后，瘪籽、旧袋口和借据都可能成为点燃村怒的证据。"
		"tavern":
			return "王大虎常在这里替酒馆镇场，也在这里请衙役喝酒递黑状。"
		"yamen":
			return "堂口讲规矩，廊下讲人情。你不能杀衙役，只能打点或找刘捕头压案。"
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
		"tenant_field":
			return Color(0.12, 0.13, 0.065, 1.0)
		"hunter_woodline":
			return Color(0.065, 0.12, 0.075, 1.0)
		"refugee_lane":
			return Color(0.13, 0.105, 0.075, 1.0)
		"ancestral_hall":
			return Color(0.16, 0.105, 0.065, 1.0)
		"seed_store":
			return Color(0.15, 0.12, 0.075, 1.0)
		"tavern_backroom":
			return Color(0.18, 0.07, 0.045, 1.0)
		"yamen_archive":
			return Color(0.09, 0.085, 0.075, 1.0)
		"village_yard":
			return Color(0.16, 0.13, 0.075, 1.0)
		"seed_market":
			return Color(0.15, 0.11, 0.065, 1.0)
		"tavern":
			return Color(0.17, 0.075, 0.045, 1.0)
		"yamen":
			return Color(0.10, 0.095, 0.08, 1.0)
		_:
			return Color(0.12, 0.09, 0.06, 1.0)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.015, 0.012, 0.010, 0.92)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _set_log(text: String) -> void:
	_last_log = text
	log_changed.emit(text)
