class_name ExplorationBoard
extends Control

signal log_changed(text: String)
signal loot_found(effect_ids: Array, summary: String)
signal danger_resolved(effect_ids: Array, summary: String)
signal extracted(summary: String)

const CELL_SIZE := 18.0
const MAP_PADDING := 14.0

var selected_option: Dictionary = {}
var weather: Dictionary = {}
var cells: Dictionary = {}
var current_cell: Vector2i = Vector2i.ZERO
var entrance_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var discovered: Dictionary = {}
var searched_containers: Dictionary = {}
var current_enemy: Dictionary = {}
var active_identification: Dictionary = {}
var _hotspots: Array[Dictionary] = []
var _map_rects: Dictionary = {}
var _identification_button_rect: Rect2 = Rect2()
var _scene_textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_log: String = ""

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 320.0)
	_load_scene_textures()

func configure(option: Dictionary, current_weather: Dictionary) -> void:
	selected_option = option.duplicate(true)
	weather = current_weather.duplicate(true)
	cells = _build_map(str(selected_option.get("location_id", "field")))
	entrance_cell = Vector2i.ZERO
	exit_cell = _find_exit_cell()
	current_cell = entrance_cell
	discovered.clear()
	searched_containers.clear()
	current_enemy.clear()
	active_identification.clear()
	_discover_around(current_cell)
	_enter_cell(current_cell)
	_set_log("你按卦象来到%s入口。右上角小地图标出已探明的地形，必须找到出口才能撤离。" % _location_name())
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		if not active_identification.is_empty():
			if _identification_button_rect.has_point(pos):
				_advance_identification()
				accept_event()
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
	var board: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(board, Color(0.045, 0.039, 0.033, 1.0))
	draw_rect(board, Color(0.70, 0.48, 0.22, 0.30), false, 1.0)
	_draw_scene(board)
	_draw_minimap()
	_draw_status_band()
	if not active_identification.is_empty():
		_draw_identification_panel()

func _draw_scene(board: Rect2) -> void:
	var scene_rect := Rect2(18.0, 18.0, maxf(size.x - 260.0, 360.0), maxf(size.y - 68.0, 220.0))
	var cell_data: Dictionary = cells.get(current_cell, {})
	var scene_type: String = str(cell_data.get("type", "path"))
	draw_rect(scene_rect, _scene_color(scene_type))
	if not _draw_scene_image(scene_rect, scene_type):
		_draw_scene_texture(scene_rect, scene_type)
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.36), false, 2.0)

	var font := get_theme_default_font()
	var title := "%s · %s" % [_location_name(), _scene_name(scene_type)]
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 28.0), title, 22, Color(0.98, 0.86, 0.55, 1.0), 4, scene_rect.size.x - 36.0)
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 54.0), _scene_desc(scene_type), 14, Color(0.92, 0.82, 0.58, 1.0), 3, scene_rect.size.x - 36.0)

	if not current_enemy.is_empty():
		var enemy_rect := Rect2(scene_rect.position + Vector2(scene_rect.size.x * 0.58, scene_rect.size.y * 0.42), Vector2(150.0, 58.0))
		_draw_hotspot(enemy_rect, "应对威胁", str(current_enemy.get("name", "野兽")), Color(0.56, 0.17, 0.12, 0.88), {"kind": "enemy"})
		return

	var containers: Array = cell_data.get("containers", [])
	var positions: Array[Vector2] = [
		Vector2(scene_rect.size.x * 0.18, scene_rect.size.y * 0.42),
		Vector2(scene_rect.size.x * 0.52, scene_rect.size.y * 0.58),
		Vector2(scene_rect.size.x * 0.34, scene_rect.size.y * 0.74)
	]
	for index in containers.size():
		var container: Dictionary = containers[index]
		var key := _container_key(current_cell, str(container.get("id", "")))
		var label := "已搜过" if searched_containers.has(key) else str(container.get("name", "可疑处"))
		var pos: Vector2 = scene_rect.position + positions[index % positions.size()]
		var rect := Rect2(pos, Vector2(142.0, 54.0))
		_draw_hotspot(rect, "搜寻", label, _container_color(str(container.get("rarity", "common"))), {
			"kind": "container",
			"container": container,
			"key": key
		})

	if current_cell == exit_cell:
		var exit_rect := Rect2(scene_rect.position + Vector2(scene_rect.size.x - 164.0, scene_rect.size.y - 70.0), Vector2(142.0, 50.0))
		_draw_hotspot(exit_rect, "撤离", "回村结算", Color(0.23, 0.42, 0.28, 0.92), {"kind": "extract"})

func _draw_scene_texture(rect: Rect2, scene_type: String) -> void:
	match scene_type:
		"slope":
			for idx in range(7):
				draw_line(rect.position + Vector2(20.0 + idx * 60.0, rect.size.y - 34.0), rect.position + Vector2(88.0 + idx * 60.0, rect.size.y * 0.34), Color(0.34, 0.29, 0.21, 0.55), 3.0)
		"cave":
			draw_circle(rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.54), 64.0, Color(0.018, 0.017, 0.016, 0.78))
			draw_arc(rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.54), 66.0, PI, TAU, 24, Color(0.45, 0.37, 0.24, 0.55), 3.0)
		"cliff":
			draw_line(rect.position + Vector2(rect.size.x * 0.62, 18.0), rect.position + Vector2(rect.size.x * 0.45, rect.size.y - 24.0), Color(0.62, 0.58, 0.50, 0.55), 5.0)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.65, 0.0), Vector2(rect.size.x * 0.35, rect.size.y)), Color(0.02, 0.018, 0.017, 0.42))
		"creek":
			var points := PackedVector2Array([
				rect.position + Vector2(rect.size.x * 0.15, 0.0),
				rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.30),
				rect.position + Vector2(rect.size.x * 0.36, rect.size.y * 0.62),
				rect.position + Vector2(rect.size.x * 0.70, rect.size.y)
			])
			draw_polyline(points, Color(0.25, 0.48, 0.54, 0.80), 20.0)
			draw_polyline(points, Color(0.74, 0.85, 0.82, 0.45), 3.0)
		"thicket":
			for idx in range(12):
				var x := rect.position.x + 28.0 + idx * 38.0
				draw_line(Vector2(x, rect.position.y + rect.size.y - 28.0), Vector2(x - 12.0, rect.position.y + 86.0 + float(idx % 3) * 16.0), Color(0.26, 0.44, 0.24, 0.72), 4.0)
		_:
			for idx in range(9):
				var y := rect.position.y + rect.size.y * 0.28 + idx * 18.0
				draw_line(Vector2(rect.position.x + 18.0, y), Vector2(rect.position.x + rect.size.x - 22.0, y + 8.0), Color(0.43, 0.34, 0.22, 0.24), 2.0)

func _load_scene_textures() -> void:
	_scene_textures = {
		"path": _load_texture_from_file("res://assets/generated/exploration/mountain_path_v1.jpg"),
		"slope": _load_texture_from_file("res://assets/generated/exploration/mountain_slope_v1.jpg"),
		"cave": _load_texture_from_file("res://assets/generated/exploration/cave_entrance_v1.jpg"),
		"cliff": _load_texture_from_file("res://assets/generated/exploration/cliff_edge_v1.jpg"),
		"creek": _load_texture_from_file("res://assets/generated/exploration/creek_v1.jpg"),
		"thicket": _load_texture_from_file("res://assets/generated/exploration/thicket_v1.jpg")
	}

func _load_texture_from_file(path: String) -> Texture2D:
	var image_path: String = path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
	var image: Image = Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _draw_scene_image(rect: Rect2, scene_type: String) -> bool:
	var texture: Texture2D = _scene_textures.get(scene_type, null) as Texture2D
	if texture == null:
		texture = _scene_textures.get("path", null) as Texture2D
	if texture == null:
		return false
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
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
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 18.0)), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 34.0), Vector2(rect.size.x, 34.0)), Color(0.0, 0.0, 0.0, 0.30))
	return true

func _draw_hotspot(rect: Rect2, verb: String, label: String, color: Color, data: Dictionary) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color(0.96, 0.72, 0.36, 0.48), false, 1.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, rect.position + Vector2(10.0, 20.0), verb, 12, Color(0.98, 0.88, 0.62, 1.0), 3, rect.size.x - 20.0)
	_draw_outlined_string(font, rect.position + Vector2(10.0, 40.0), label, 15, Color(0.95, 0.92, 0.80, 1.0), 3, rect.size.x - 20.0)
	var hotspot := data.duplicate(true)
	hotspot["rect"] = rect
	_hotspots.append(hotspot)

func _draw_minimap() -> void:
	var map_origin := Vector2(size.x - 214.0, 20.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, map_origin + Vector2(0.0, -4.0), "小地图", 16, Color(0.94, 0.84, 0.60, 1.0), 3, 160.0)
	for cell_variant in cells.keys():
		var cell: Vector2i = cell_variant
		if not discovered.has(cell):
			continue
		var pos := map_origin + Vector2(float(cell.x + 3) * CELL_SIZE, float(cell.y + 3) * CELL_SIZE)
		var rect := Rect2(pos, Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0))
		_map_rects[cell] = rect
		var fill := _scene_color(str(cells[cell].get("type", "path")))
		if cell == current_cell:
			fill = Color(0.92, 0.76, 0.34, 1.0)
		elif cell == entrance_cell:
			fill = Color(0.26, 0.44, 0.30, 1.0)
		elif cell == exit_cell:
			fill = Color(0.55, 0.30, 0.18, 1.0)
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
	_draw_outlined_string(font, map_origin + Vector2(0.0, 132.0), "点击相邻格移动，橙色为当前位置。", 12, Color(0.78, 0.72, 0.58, 1.0), 3, 190.0)

func _draw_status_band() -> void:
	var rect := Rect2(18.0, size.y - 42.0, maxf(size.x - 36.0, 0.0), 28.0)
	draw_rect(rect, Color(0.025, 0.023, 0.020, 0.74))
	var font := get_theme_default_font()
	_draw_outlined_string(font, rect.position + Vector2(10.0, 19.0), _last_log, 13, Color(0.86, 0.82, 0.70, 1.0), 3, rect.size.x - 20.0)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.015, 0.012, 0.010, 0.92)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

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
	_enter_cell(cell)
	queue_redraw()

func _enter_cell(cell: Vector2i) -> void:
	current_enemy.clear()
	var cell_data: Dictionary = cells.get(cell, {})
	var enemies: Array = cell_data.get("enemies", [])
	if not enemies.is_empty() and _rng.randi_range(1, 100) <= int(cell_data.get("enemy_chance", 35)):
		current_enemy = enemies[_rng.randi_range(0, enemies.size() - 1)]
		_set_log("你踏入%s，惊动了%s。" % [_scene_name(str(cell_data.get("type", "path"))), str(current_enemy.get("name", "野兽"))])
	else:
		_set_log("你来到%s，四下寻找卦象里的痕迹。" % _scene_name(str(cell_data.get("type", "path"))))

func _activate_hotspot(hotspot: Dictionary) -> void:
	match str(hotspot.get("kind", "")):
		"container":
			_search_container(hotspot)
		"enemy":
			_resolve_enemy()
		"extract":
			extracted.emit(_build_extract_summary())

func _search_container(hotspot: Dictionary) -> void:
	var key: String = str(hotspot.get("key", ""))
	if searched_containers.has(key):
		_set_log("这里已经被你翻过一遍。")
		queue_redraw()
		return
	var container: Dictionary = hotspot.get("container", {})
	searched_containers[key] = true
	var roll := _rng.randi_range(1, 100)
	var table: Array = container.get("loot", [])
	var picked: Dictionary = {}
	var cursor := 0
	for entry_variant in table:
		var entry: Dictionary = entry_variant
		cursor += int(entry.get("chance", 0))
		if roll <= cursor:
			picked = entry
			break
	if picked.is_empty():
		picked = {"name": "空痕", "effects": [], "text": "你仔细辨认了一阵，只确认这里没有值得带走的东西。"}
	active_identification = {
		"step": 0,
		"required": _identify_steps_for_loot(picked),
		"picked": picked,
		"container_name": str(container.get("name", "可疑处"))
	}
	_set_log("你从%s里翻出一件东西，需要先辨认成色。" % str(container.get("name", "可疑处")))
	queue_redraw()

func _draw_identification_panel() -> void:
	var panel_size := Vector2(minf(size.x - 80.0, 460.0), 190.0)
	var panel_rect := Rect2((size - panel_size) * 0.5, panel_size)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.42))
	draw_rect(panel_rect, Color(0.055, 0.047, 0.038, 0.98))
	draw_rect(panel_rect, Color(0.88, 0.64, 0.32, 0.62), false, 2.0)

	var picked: Dictionary = active_identification.get("picked", {})
	var step: int = int(active_identification.get("step", 0))
	var required: int = maxi(int(active_identification.get("required", 1)), 1)
	var rarity_id: String = _rarity_from_loot(picked)
	var font := get_theme_default_font()
	_draw_outlined_string(font, panel_rect.position + Vector2(18.0, 30.0), "物品鉴定", 20, Color(0.96, 0.86, 0.60, 1.0), 3, panel_rect.size.x - 36.0)
	_draw_outlined_string(font, panel_rect.position + Vector2(18.0, 60.0), _identification_hint(rarity_id, step, required), 14, Color(0.84, 0.79, 0.66, 1.0), 3, panel_rect.size.x - 36.0)
	draw_rect(Rect2(panel_rect.position + Vector2(18.0, 82.0), Vector2(panel_rect.size.x - 36.0, 8.0)), Color(0.12, 0.10, 0.08, 1.0))
	draw_rect(Rect2(panel_rect.position + Vector2(18.0, 82.0), Vector2((panel_rect.size.x - 36.0) * float(step) / float(required), 8.0)), _rarity_color(rarity_id))

	var unknown_name := "未明物"
	if step >= required - 1:
		unknown_name = _masked_loot_name(str(picked.get("name", "未知物")))
	_draw_outlined_string(font, panel_rect.position + Vector2(18.0, 122.0), unknown_name, 22, _rarity_color(rarity_id), 4, panel_rect.size.x - 36.0)

	_identification_button_rect = Rect2(panel_rect.position + Vector2(panel_rect.size.x - 142.0, panel_rect.size.y - 54.0), Vector2(120.0, 34.0))
	draw_rect(_identification_button_rect, Color(0.27, 0.20, 0.12, 1.0))
	draw_rect(_identification_button_rect, Color(0.92, 0.68, 0.34, 0.70), false, 1.0)
	var button_text := "继续鉴定" if step < required - 1 else "确认收下"
	_draw_outlined_string(font, _identification_button_rect.position + Vector2(16.0, 23.0), button_text, 14, Color(0.96, 0.88, 0.70, 1.0), 3, _identification_button_rect.size.x - 24.0)

func _advance_identification() -> void:
	if active_identification.is_empty():
		return
	var step: int = int(active_identification.get("step", 0)) + 1
	active_identification["step"] = step
	var required: int = maxi(int(active_identification.get("required", 1)), 1)
	if step < required:
		_set_log("你继续辨认这件东西的纹理、气味和重量。")
		queue_redraw()
		return
	var picked: Dictionary = active_identification.get("picked", {})
	var effect_ids: Array = picked.get("effects", [])
	var text := "鉴定：%s。%s" % [str(picked.get("name", "未知物")), str(picked.get("text", ""))]
	active_identification.clear()
	_set_log(text)
	loot_found.emit(effect_ids, text)
	queue_redraw()

func _resolve_enemy() -> void:
	if current_enemy.is_empty():
		return
	var name := str(current_enemy.get("name", "野兽"))
	var roll := _rng.randi_range(1, 100)
	var effect_ids: Array = []
	var text := ""
	if roll <= int(current_enemy.get("avoid_chance", 45)):
		effect_ids = ["lose_stamina_small"]
		text = "你压低身形绕开%s，耗了些体力，总算没被缠上。" % name
	elif roll <= int(current_enemy.get("injury_chance", 78)):
		effect_ids = ["lose_stamina_medium", "lose_health_small"]
		text = "%s突然扑近，你勉强脱身，但身上添了伤。" % name
	else:
		effect_ids = ["lose_stamina_medium", "gain_attention_small"]
		text = "你弄出不小动静才逼退%s，这动静可能会被人记住。" % name
	current_enemy.clear()
	_set_log(text)
	danger_resolved.emit(effect_ids, text)
	queue_redraw()

func _discover_around(cell: Vector2i) -> void:
	discovered[cell] = true
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for dir: Vector2i in dirs:
		var next_cell: Vector2i = cell + dir
		if cells.has(next_cell):
			discovered[next_cell] = true

func _build_extract_summary() -> String:
	return "你从%s的出口撤回村里。今日卦象到此收束，带回多少东西，全看路上搜到了什么。" % _location_name()

func _build_map(location_id: String) -> Dictionary:
	match location_id:
		"mountain":
			return _mountain_map()
		"forest":
			return _forest_map()
		"river":
			return _river_map()
		"graveyard":
			return _graveyard_map()
		_:
			return _field_map()

func _mountain_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("slope", [_herb_container("herb_patch")], [_boar()], false, 22),
		Vector2i(2, 0): _cell("cliff", [_old_herb_container()], [], false),
		Vector2i(1, -1): _cell("thicket", [_trace_container(), _herb_container("bush_herb")], [_wolf()], false, 28),
		Vector2i(2, -1): _cell("cave", [_cache_container()], [_bear(), _tiger()], false, 36),
		Vector2i(3, -1): _cell("creek", [_creek_container()], [], true),
		Vector2i(0, 1): _cell("creek", [_creek_container()], [], false),
		Vector2i(1, 1): _cell("path", [_trace_container()], [], false)
	}

func _forest_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_herb_container("forest_herb")], [_wolf()], false, 34),
		Vector2i(2, 0): _cell("thicket", [_trace_container()], [_boar()], false, 38),
		Vector2i(2, -1): _cell("cave", [_cache_container()], [_bear(), _tiger()], false, 30),
		Vector2i(3, -1): _cell("creek", [_creek_container()], [], true)
	}

func _river_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("creek", [_creek_container()], [], false),
		Vector2i(2, 0): _cell("creek", [_cache_container()], [], true),
		Vector2i(1, -1): _cell("thicket", [_herb_container("wet_herb")], [_wolf()], false, 18)
	}

func _graveyard_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_cache_container()], [], false),
		Vector2i(2, 0): _cell("cave", [_cache_container(), _old_herb_container()], [_wolf()], false, 32),
		Vector2i(2, 1): _cell("cliff", [_trace_container()], [], true)
	}

func _field_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_herb_container("field_herb")], [], false),
		Vector2i(2, 0): _cell("creek", [_creek_container()], [], true),
		Vector2i(1, 1): _cell("slope", [_cache_container()], [], false)
	}

func _cell(scene_type: String, containers: Array, enemies: Array, is_exit: bool, enemy_chance: int = 0) -> Dictionary:
	return {
		"type": scene_type,
		"containers": containers,
		"enemies": enemies,
		"exit": is_exit,
		"enemy_chance": enemy_chance
	}

func _herb_container(id: String) -> Dictionary:
	return {
		"id": id,
		"name": "药材丛",
		"rarity": "common",
			"loot": [
			{"chance": 50, "name": "【普通】苦叶草", "effects": ["gain_bitter_leaf", "gain_herb_small"], "text": "叶脉完整，药性尚可。"},
			{"chance": 28, "name": "杂草", "effects": [], "text": "看着像药，揉碎后气味不对。"},
			{"chance": 15, "name": "【优质】赤根草", "effects": ["gain_bloodroot", "gain_herb_small"], "text": "根须泛红，拿去换钱也有人收。"},
			{"chance": 7, "name": "【稀有】小山参", "effects": ["gain_mountain_ginseng"], "text": "根形已经成气候，最好藏起来。"}
		]
	}

func _old_herb_container() -> Dictionary:
	return {
		"id": "old_herb",
		"name": "古老药材丛",
		"rarity": "rare",
			"loot": [
			{"chance": 34, "name": "【优质】赤根草", "effects": ["gain_bloodroot", "gain_herb_small"], "text": "根茎有年头，价值比寻常草药高。"},
			{"chance": 28, "name": "【稀有】小山参", "effects": ["gain_mountain_ginseng"], "text": "没到百年，但已经很难得。"},
			{"chance": 16, "name": "【珍贵】紫芝", "effects": ["gain_purple_lingzhi"], "text": "贴着阴崖长出紫色菌盖，药铺一定想收。"},
			{"chance": 4, "name": "【传说】百年山参", "effects": ["gain_hundred_year_ginseng", "gain_suspicion_small"], "text": "根须完整得吓人，带回村里绝不能露白。"},
			{"chance": 1, "name": "【神话】血芝", "effects": ["gain_blood_reishi", "gain_suspicion_small"], "text": "赤色纹路像血脉一样压在菌盖里。"},
			{"chance": 17, "name": "枯死老根", "effects": [], "text": "外形唬人，里面已经空了。"}
		]
	}

func _cache_container() -> Dictionary:
	return {
		"id": "cache",
		"name": "旧物堆",
		"rarity": "uncommon",
			"loot": [
			{"chance": 25, "name": "【普通】锈铜片", "effects": ["gain_rusty_copper_piece", "gain_money_tiny"], "text": "不像钱，倒还能按铜料卖。"},
			{"chance": 25, "name": "【优质】旧钱串", "effects": ["gain_old_coin_string", "gain_money_small"], "text": "锈蚀不轻，但能看出是旧朝钱。"},
			{"chance": 14, "name": "【稀有】残玉扣", "effects": ["gain_broken_jade_button"], "text": "只剩半片，仍不像村里人用得起的物件。"},
			{"chance": 6, "name": "【珍贵】弯折银簪", "effects": ["gain_silver_hairpin_bent", "gain_suspicion_small"], "text": "能换不少钱，但卖的时候容易惹人追问。"},
			{"chance": 2, "name": "【传说】逃兵私印", "effects": ["gain_soldier_hidden_seal", "gain_suspicion_small"], "text": "这东西可能值钱，也可能要命。"},
			{"chance": 18, "name": "破烂杂物", "effects": [], "text": "翻了半天，只是些没用破片。"},
			{"chance": 10, "name": "藏得较深的小包", "effects": ["gain_money_medium", "gain_suspicion_small"], "text": "值钱，但带回去要藏好。"}
		]
	}

func _creek_container() -> Dictionary:
	return {
		"id": "creek_stones",
		"name": "溪石缝",
		"rarity": "common",
			"loot": [
			{"chance": 30, "name": "【普通】锈铜片", "effects": ["gain_rusty_copper_piece", "gain_money_tiny"], "text": "像是被水冲下来的旧物。"},
			{"chance": 20, "name": "【优质】清露苔", "effects": ["gain_clear_moss", "gain_herb_small"], "text": "湿石背阴处长着一片能退热的苔。"},
			{"chance": 38, "name": "湿滑空石", "effects": ["lose_stamina_small"], "text": "你滑了一下，什么也没捞到。"},
			{"chance": 10, "name": "【稀有】蛇胆", "effects": ["gain_snake_gall"], "text": "石缝边有蛇蜕和一截刚死不久的小蛇。"},
			{"chance": 2, "name": "【神话】古骨令", "effects": ["gain_ancient_bone_token", "gain_suspicion_small"], "text": "非金非玉的骨令卡在溪石深处，纹路看不懂。"}
		]
	}

func _trace_container() -> Dictionary:
	return {
		"id": "trace",
		"name": "可疑痕迹",
		"rarity": "common",
			"loot": [
			{"chance": 45, "name": "新鲜脚印", "effects": [], "text": "你确认了方向，心里更有数。"},
			{"chance": 25, "name": "【普通】野兔皮", "effects": ["gain_rabbit_pelt", "gain_meat_small"], "text": "顺着痕迹摸过去，抓到一点肉食和一张小皮。"},
			{"chance": 8, "name": "【优质】野猪獠牙", "effects": ["gain_boar_tusk", "gain_meat_small"], "text": "乱草里有一截旧獠牙，旁边还留着猎物残肉。"},
			{"chance": 2, "name": "【稀有】旧猎刀", "effects": ["gain_old_hunter_knife"], "text": "半截刀柄埋在泥里，刃口缺了但还能修。"},
			{"chance": 20, "name": "断痕", "effects": ["lose_stamina_small"], "text": "痕迹绕回乱石里，白费不少脚力。"}
		]
	}

func _boar() -> Dictionary:
	return {"name": "大野猪", "avoid_chance": 44, "injury_chance": 82}

func _bear() -> Dictionary:
	return {"name": "黑熊", "avoid_chance": 30, "injury_chance": 76}

func _wolf() -> Dictionary:
	return {"name": "野狼", "avoid_chance": 50, "injury_chance": 84}

func _tiger() -> Dictionary:
	return {"name": "山君", "avoid_chance": 22, "injury_chance": 68}

func _find_exit_cell() -> Vector2i:
	for cell_variant in cells.keys():
		var cell: Vector2i = cell_variant
		if bool(cells[cell].get("exit", false)):
			return cell
	return entrance_cell

func _container_key(cell: Vector2i, id: String) -> String:
	return "%d,%d:%s" % [cell.x, cell.y, id]

func _identify_steps_for_loot(loot: Dictionary) -> int:
	match _rarity_from_loot(loot):
		"fine":
			return 2
		"rare":
			return 3
		"precious":
			return 4
		"legendary":
			return 5
		"mythic":
			return 6
		_:
			return 1

func _rarity_from_loot(loot: Dictionary) -> String:
	var name: String = str(loot.get("name", ""))
	if name.begins_with("【神话】"):
		return "mythic"
	if name.begins_with("【传说】"):
		return "legendary"
	if name.begins_with("【珍贵】"):
		return "precious"
	if name.begins_with("【稀有】"):
		return "rare"
	if name.begins_with("【优质】"):
		return "fine"
	return "common"

func _rarity_color(rarity_id: String) -> Color:
	match rarity_id:
		"fine":
			return Color(0.48, 0.80, 0.47, 1.0)
		"rare":
			return Color(0.44, 0.68, 0.92, 1.0)
		"precious":
			return Color(0.72, 0.51, 0.90, 1.0)
		"legendary":
			return Color(0.94, 0.76, 0.35, 1.0)
		"mythic":
			return Color(0.88, 0.35, 0.31, 1.0)
		_:
			return Color(0.91, 0.88, 0.82, 1.0)

func _identification_hint(rarity_id: String, step: int, required: int) -> String:
	var progress_text := "辨识进度 %d/%d" % [step, required]
	match rarity_id:
		"mythic":
			return "%s。纹路异常，像是旧传说里才会出现的东西。" % progress_text
		"legendary":
			return "%s。成色压不住，拿错地方卖会招来麻烦。" % progress_text
		"precious":
			return "%s。质地明显不俗，需要再确认真假。" % progress_text
		"rare":
			return "%s。轮廓已经能看出价值，细节还需辨认。" % progress_text
		"fine":
			return "%s。比寻常物件好一些，先看完整度。" % progress_text
		_:
			return "%s。看着普通，确认能不能用即可。" % progress_text

func _masked_loot_name(name: String) -> String:
	if name.contains("】"):
		var parts := name.split("】", false, 1)
		if parts.size() == 2:
			return "%s】%s？" % [parts[0], parts[1].left(1)]
	return "似乎是%s？" % name.left(1)

func _set_log(text: String) -> void:
	_last_log = text
	log_changed.emit(text)

func _location_name() -> String:
	match str(selected_option.get("location_id", "field")):
		"mountain":
			return "小黑山"
		"forest":
			return "密林"
		"river":
			return "河滩"
		"graveyard":
			return "荒坟"
		_:
			return "村外"

func _scene_name(scene_type: String) -> String:
	match scene_type:
		"slope":
			return "山坡"
		"cave":
			return "洞穴"
		"cliff":
			return "悬崖"
		"creek":
			return "小溪"
		"thicket":
			return "树丛"
		_:
			return "山路"

func _scene_desc(scene_type: String) -> String:
	match scene_type:
		"slope":
			return "斜坡碎石很多，草根间常藏着能用的东西，也容易惊动野物。"
		"cave":
			return "洞口阴冷，像有人或兽短暂停留过，越往里越难看清。"
		"cliff":
			return "崖边风硬，脚下不稳，但险处也更少有人采过。"
		"creek":
			return "溪水冲刷石缝，旧物和草根都可能被卡在浅水里。"
		"thicket":
			return "树丛遮住视线，能藏药草，也能藏正在盯你的东西。"
		_:
			return "山路还算能辨方向，脚印、折枝和兽径都可能是线索。"

func _scene_color(scene_type: String) -> Color:
	match scene_type:
		"slope":
			return Color(0.17, 0.13, 0.08, 1.0)
		"cave":
			return Color(0.055, 0.052, 0.050, 1.0)
		"cliff":
			return Color(0.13, 0.13, 0.12, 1.0)
		"creek":
			return Color(0.065, 0.12, 0.13, 1.0)
		"thicket":
			return Color(0.075, 0.13, 0.075, 1.0)
		_:
			return Color(0.12, 0.09, 0.06, 1.0)

func _container_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.42, 0.30, 0.54, 0.92)
		"uncommon":
			return Color(0.38, 0.30, 0.16, 0.92)
		_:
			return Color(0.18, 0.30, 0.18, 0.90)
