class_name ExplorationBoard
extends Control

signal log_changed(text: String)
signal loot_found(effect_ids: Array, summary: String)
signal danger_resolved(effect_ids: Array, summary: String)
signal extracted(summary: String)
signal inventory_context_requested()

const CELL_SIZE := 18.0
const MAP_PADDING := 14.0
const PRESSURE_MAX := 100

var selected_option: Dictionary = {}
var weather: Dictionary = {}
var inventory_items: Dictionary = {}
var active_flags: Dictionary = {}
var cells: Dictionary = {}
var current_cell: Vector2i = Vector2i.ZERO
var entrance_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var discovered: Dictionary = {}
var searched_containers: Dictionary = {}
var current_enemy: Dictionary = {}
var active_scene_event: Dictionary = {}
var resolved_scene_events: Dictionary = {}
var active_identification: Dictionary = {}
var exploration_config: Dictionary = {}
var time_pressure := 0
var trace_pressure := 0
var fatigue_pressure := 0
var pack_pressure := 0
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
	_load_exploration_config()

func configure(option: Dictionary, current_weather: Dictionary, current_inventory: Dictionary = {}, current_flags: Dictionary = {}) -> void:
	selected_option = option.duplicate(true)
	weather = current_weather.duplicate(true)
	inventory_items = current_inventory.duplicate(true)
	active_flags = current_flags.duplicate(true)
	cells = _build_map(str(selected_option.get("id", "")), str(selected_option.get("location_id", "field")))
	_load_scene_textures()
	entrance_cell = Vector2i.ZERO
	exit_cell = _find_exit_cell()
	current_cell = entrance_cell
	discovered.clear()
	searched_containers.clear()
	current_enemy.clear()
	active_scene_event.clear()
	resolved_scene_events.clear()
	active_identification.clear()
	_reset_pressure()
	_discover_around(current_cell)
	_enter_cell(current_cell)
	_set_log("%s%s。右上角小地图标出已探明的地形，必须找到出口才能撤离。" % [_intro_text(), _omen_brief()])
	queue_redraw()

func update_context(current_inventory: Dictionary, current_flags: Dictionary) -> void:
	inventory_items = current_inventory.duplicate(true)
	active_flags = current_flags.duplicate(true)
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
	_draw_pressure_panel()
	_draw_status_band()
	if not active_identification.is_empty():
		_draw_identification_panel()

func _draw_scene(board: Rect2) -> void:
	var scene_rect := Rect2(18.0, 18.0, maxf(size.x - 260.0, 360.0), maxf(size.y - 68.0, 220.0))
	var cell_data: Dictionary = cells.get(current_cell, {})
	var scene_type: String = str(cell_data.get("type", "path"))
	draw_rect(scene_rect, _cell_color(cell_data))
	if not _draw_scene_image(scene_rect, str(cell_data.get("image", scene_type))):
		_draw_scene_texture(scene_rect, scene_type)
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(scene_rect, Color(0.0, 0.0, 0.0, 0.36), false, 2.0)

	var font := get_theme_default_font()
	var title := "%s · %s" % [_location_name(), _cell_scene_name(cell_data)]
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 28.0), title, 22, Color(0.98, 0.86, 0.55, 1.0), 4, scene_rect.size.x - 36.0)
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 54.0), _cell_scene_desc(cell_data), 14, Color(0.92, 0.82, 0.58, 1.0), 3, scene_rect.size.x - 36.0)
	_draw_outlined_string(font, scene_rect.position + Vector2(18.0, 78.0), _omen_brief(), 13, Color(0.70, 0.90, 0.72, 1.0), 3, scene_rect.size.x - 36.0)

	if not current_enemy.is_empty():
		var enemy_name := str(current_enemy.get("name", "野兽"))
		var enemy_origin := scene_rect.position + Vector2(scene_rect.size.x * 0.56, scene_rect.size.y * 0.34)
		_draw_hotspot(Rect2(enemy_origin, Vector2(156.0, 54.0)), "藏身绕行", "%s · 稳" % enemy_name, Color(0.36, 0.24, 0.13, 0.90), {"kind": "enemy", "action": "avoid"})
		_draw_hotspot(Rect2(enemy_origin + Vector2(0.0, 62.0), Vector2(156.0, 54.0)), "正面逼退", "%s · 快" % enemy_name, Color(0.56, 0.17, 0.12, 0.90), {"kind": "enemy", "action": "drive"})
		if _can_use_enemy_trap():
			_draw_hotspot(Rect2(enemy_origin + Vector2(0.0, 124.0), Vector2(156.0, 54.0)), "设伏牵制", _enemy_trap_label(enemy_name), Color(0.24, 0.36, 0.18, 0.90), {"kind": "enemy", "action": "trap"})
		return

	if not active_scene_event.is_empty():
		var event_rect := Rect2(scene_rect.position + Vector2(scene_rect.size.x * 0.62, scene_rect.size.y * 0.30), Vector2(156.0, 58.0))
		_draw_hotspot(event_rect, str(active_scene_event.get("verb", "察看")), str(active_scene_event.get("name", "异样")), _scene_event_color(active_scene_event), {
			"kind": "scene_event",
			"event": active_scene_event
		})

	var containers: Array = cell_data.get("containers", [])
	var positions: Array[Vector2] = [
		Vector2(scene_rect.size.x * 0.18, scene_rect.size.y * 0.42),
		Vector2(scene_rect.size.x * 0.52, scene_rect.size.y * 0.58),
		Vector2(scene_rect.size.x * 0.34, scene_rect.size.y * 0.74)
	]
	for index in containers.size():
		var container: Dictionary = containers[index]
		var key := _container_key(current_cell, str(container.get("id", "")))
		var label := "已搜过" if searched_containers.has(key) else _container_label(container)
		var pos: Vector2 = scene_rect.position + positions[index % positions.size()]
		var rect := Rect2(pos, Vector2(142.0, 54.0))
		_draw_hotspot(rect, "搜寻", label, _container_color(container), {
			"kind": "container",
			"container": container,
			"key": key
		})

	if current_cell == exit_cell:
		var exit_rect := Rect2(scene_rect.position + Vector2(scene_rect.size.x - 164.0, scene_rect.size.y - 70.0), Vector2(142.0, 50.0))
		_draw_hotspot(exit_rect, "撤离", "回村结算", Color(0.23, 0.42, 0.28, 0.92), {"kind": "extract"})

func _draw_scene_texture(rect: Rect2, scene_type: String) -> void:
	match scene_type:
		"hut":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.28), Vector2(rect.size.x * 0.56, rect.size.y * 0.42)), Color(0.16, 0.10, 0.06, 0.86))
			draw_line(rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.28), rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.10), Color(0.34, 0.25, 0.15, 0.80), 6.0)
		"road":
			for idx in range(6):
				var y := rect.position.y + rect.size.y * 0.34 + idx * 24.0
				draw_line(Vector2(rect.position.x + 20.0, y), Vector2(rect.position.x + rect.size.x - 26.0, y + 18.0), Color(0.42, 0.32, 0.20, 0.30), 3.0)
		"village":
			for idx in range(4):
				draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.12 + idx * 96.0, rect.size.y * 0.40), Vector2(70.0, 52.0)), Color(0.18, 0.12, 0.08, 0.78))
		"stove":
			draw_circle(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.58), 54.0, Color(0.20, 0.09, 0.04, 0.92))
			draw_circle(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.58), 30.0, Color(0.62, 0.27, 0.08, 0.54))
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
	for cell_variant in cells.values():
		var cell_data: Dictionary = cell_variant
		var image_key: String = str(cell_data.get("image", ""))
		var image_path: String = str(cell_data.get("image_path", ""))
		if image_key.is_empty() or image_path.is_empty() or _scene_textures.has(image_key):
			continue
		_scene_textures[image_key] = _load_texture_from_file(image_path)

func _load_texture_from_file(path: String) -> Texture2D:
	var imported_texture: Texture2D = load(path) as Texture2D
	if imported_texture != null:
		return imported_texture
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
		var fill := _cell_color(cells[cell])
		if cell == current_cell:
			fill = Color(0.92, 0.76, 0.34, 1.0)
		elif cell == entrance_cell:
			fill = Color(0.26, 0.44, 0.30, 1.0)
		elif cell == exit_cell:
			fill = Color(0.55, 0.30, 0.18, 1.0)
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
	_draw_outlined_string(font, map_origin + Vector2(0.0, 132.0), "点击相邻格移动，橙色为当前位置。", 12, Color(0.78, 0.72, 0.58, 1.0), 3, 190.0)

func _draw_pressure_panel() -> void:
	var panel_origin := Vector2(size.x - 214.0, 176.0)
	var panel_rect := Rect2(panel_origin + Vector2(-8.0, -8.0), Vector2(198.0, 108.0))
	draw_rect(panel_rect, Color(0.025, 0.022, 0.018, 0.78))
	draw_rect(panel_rect, Color(0.78, 0.54, 0.26, 0.28), false, 1.0)
	var font := get_theme_default_font()
	_draw_outlined_string(font, panel_origin + Vector2(0.0, 12.0), "探索压力", 14, Color(0.94, 0.84, 0.60, 1.0), 3, 160.0)
	_draw_pressure_bar(panel_origin + Vector2(0.0, 25.0), "天色", time_pressure, Color(0.86, 0.58, 0.30, 1.0))
	_draw_pressure_bar(panel_origin + Vector2(0.0, 45.0), "踪迹", trace_pressure, Color(0.68, 0.38, 0.30, 1.0))
	_draw_pressure_bar(panel_origin + Vector2(0.0, 65.0), "劳累", fatigue_pressure, Color(0.44, 0.62, 0.48, 1.0))
	_draw_pressure_bar(panel_origin + Vector2(0.0, 85.0), "行囊", pack_pressure, Color(0.78, 0.65, 0.40, 1.0))

func _draw_pressure_bar(origin: Vector2, label: String, value: int, color: Color) -> void:
	var font := get_theme_default_font()
	_draw_outlined_string(font, origin + Vector2(0.0, 10.0), label, 11, Color(0.82, 0.78, 0.66, 1.0), 2, 34.0)
	var bar_rect := Rect2(origin + Vector2(38.0, 1.0), Vector2(104.0, 9.0))
	draw_rect(bar_rect, Color(0.11, 0.095, 0.075, 1.0))
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clampf(float(value) / float(PRESSURE_MAX), 0.0, 1.0), bar_rect.size.y)), color)
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
	_draw_outlined_string(font, origin + Vector2(150.0, 10.0), "%d" % value, 11, Color(0.88, 0.82, 0.68, 1.0), 2, 36.0)

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
	if not current_enemy.is_empty():
		_set_log("眼前的威胁还没处理，贸然挪步只会把动静闹大。")
		return
	if not discovered.has(cell):
		return
	var delta := cell - current_cell
	if abs(delta.x) + abs(delta.y) != 1:
		return
	var next_cell_data: Dictionary = cells.get(cell, {})
	_apply_movement_pressure(next_cell_data)
	current_cell = cell
	_discover_around(cell)
	_enter_cell(cell)
	queue_redraw()

func _enter_cell(cell: Vector2i) -> void:
	current_enemy.clear()
	active_scene_event.clear()
	var cell_data: Dictionary = cells.get(cell, {})
	var enemies: Array = cell_data.get("enemies", [])
	var enemy_chance := _entry_enemy_chance(cell_data)
	if not enemies.is_empty() and _rng.randi_range(1, 100) <= enemy_chance:
		current_enemy = enemies[_rng.randi_range(0, enemies.size() - 1)]
		_set_log("你踏入%s，惊动了%s。%s" % [_cell_scene_name(cell_data), str(current_enemy.get("name", "野兽")), _pressure_hint()])
	elif _maybe_spawn_scene_event(cell, cell_data):
		_set_log("你来到%s，%s。%s" % [_cell_scene_name(cell_data), str(active_scene_event.get("hint", "附近有些异样")), _pressure_hint()])
	else:
		_set_log("你来到%s，四下寻找卦象里的痕迹。%s" % [_cell_scene_name(cell_data), _pressure_hint()])

func _activate_hotspot(hotspot: Dictionary) -> void:
	match str(hotspot.get("kind", "")):
		"container":
			_search_container(hotspot)
		"enemy":
			_resolve_enemy(str(hotspot.get("action", "avoid")))
		"scene_event":
			_resolve_scene_event(hotspot)
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
	_apply_search_pressure(container)
	var table: Array = container.get("loot", [])
	var picked: Dictionary = _pick_loot(container, table)
	if picked.is_empty():
		picked = {"name": "空痕", "effects": [], "text": "你仔细辨认了一阵，只确认这里没有值得带走的东西。"}
	active_identification = {
		"step": 0,
		"required": _identify_steps_for_loot(picked),
		"picked": picked,
		"container_name": str(container.get("name", "可疑处")),
		"container": container
	}
	_set_log("你从%s里翻出一件东西，需要先辨认成色。%s" % [str(container.get("name", "可疑处")), _search_pressure_hint(container)])
	queue_redraw()

func _pick_loot(container: Dictionary, table: Array) -> Dictionary:
	if _should_force_bad_search(container):
		var bad_entry := _pick_bad_loot(table)
		if not bad_entry.is_empty():
			return bad_entry
	var roll := _rng.randi_range(1, 100)
	var cursor := 0
	for entry_variant in table:
		var entry: Dictionary = entry_variant
		cursor += int(entry.get("chance", 0))
		if roll <= cursor:
			return entry
	return {}

func _should_force_bad_search(container: Dictionary) -> bool:
	var chance := int(float(time_pressure) * 0.08) + int(float(trace_pressure) * 0.12) + int(float(fatigue_pressure) * 0.10)
	chance += int(float(pack_pressure) * 0.08)
	match _container_risk(container):
		"high":
			chance += 12
		"medium":
			chance += 7
		"tiring":
			chance += 4
		_:
			chance += 1
	if _is_favored_container(container):
		chance -= 8
	if _is_forbidden_container(container):
		chance += 12
	return _rng.randi_range(1, 100) <= clampi(chance, 0, 55)

func _pick_bad_loot(table: Array) -> Dictionary:
	var bad_entries: Array[Dictionary] = []
	for entry_variant in table:
		var entry: Dictionary = entry_variant
		if _is_bad_loot(entry):
			bad_entries.append(entry)
	if bad_entries.is_empty():
		return {}
	return bad_entries[_rng.randi_range(0, bad_entries.size() - 1)]

func _is_bad_loot(entry: Dictionary) -> bool:
	var effects: Array = entry.get("effects", [])
	if effects.is_empty():
		return true
	for effect_variant in effects:
		var effect_id := str(effect_variant)
		if effect_id.begins_with("lose_") or effect_id.begins_with("gain_suspicion") or effect_id.begins_with("gain_attention") or effect_id.begins_with("mark_cold"):
			return true
	return false

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
	var container: Dictionary = active_identification.get("container", {})
	var effect_ids: Array = picked.get("effects", [])
	var text := "鉴定：%s。%s" % [str(picked.get("name", "未知物")), str(picked.get("text", ""))]
	var pack_delta := _loot_pack_pressure(picked)
	if pack_delta > 0:
		pack_pressure = clampi(pack_pressure + pack_delta, 0, PRESSURE_MAX)
		text = "%s\n%s" % [text, _pack_gain_text(pack_delta)]
	active_identification.clear()
	var ambush_text := _maybe_trigger_search_ambush(container)
	if not ambush_text.is_empty():
		text = "%s\n%s" % [text, ambush_text]
	_set_log(text)
	loot_found.emit(effect_ids, text)
	queue_redraw()

func _resolve_enemy(action: String = "avoid") -> void:
	if current_enemy.is_empty():
		return
	var name := str(current_enemy.get("name", "野兽"))
	var roll := _rng.randi_range(1, 100)
	var effect_ids: Array = []
	var text := ""
	var avoid_chance := _enemy_avoid_chance(current_enemy)
	var injury_chance := _enemy_injury_chance(current_enemy, avoid_chance)
	match action:
		"drive":
			_add_pressure(2, 8, 6)
			var drive_success := clampi(58 + (_enemy_tool_bonus() / 2) - int(float(fatigue_pressure) * 0.08), 18, 86)
			if roll <= drive_success:
				effect_ids = ["lose_stamina_small", "gain_attention_small"]
				text = "你抓起石块和断枝正面逼退%s，动静不小，但很快打开了路。%s" % [name, _enemy_tool_hint()]
			else:
				effect_ids = ["lose_stamina_medium", "lose_health_small", "gain_attention_small"]
				if _has_equipped("old_hunter_knife") or _has_equipped("black_iron_shortblade"):
					effect_ids = ["lose_stamina_medium", "gain_attention_small"]
					text = "%s扑近时，你用手中兵刃顶开一线，没被咬实，但动静传得很远。" % name
				else:
					text = "%s被激怒后猛冲过来，你硬退几步才脱身，身上添了伤。" % name
		"trap":
			_add_pressure(7, 3, 5)
			var trap_success := clampi(44 + _enemy_tool_bonus() - int(float(time_pressure) * 0.06), 15, 90)
			if roll <= trap_success:
				effect_ids = ["gain_meat_small"]
				if name == "山君" or name == "黑熊":
					effect_ids = ["gain_stamina_tiny"]
					text = "你照弓谱借地势设了个假口，%s被牵开片刻。你没敢贪，只趁机稳住气息离开。" % name
				else:
					text = "你照弓谱和旧猎刀的路数布了个急套，%s被牵住，你顺手得了些肉食。" % name
			elif roll <= trap_success + 22:
				effect_ids = ["lose_stamina_small"]
				text = "你设伏慢了半拍，只够把%s引偏。没受伤，但这一番折腾很耗体力。" % name
			else:
				effect_ids = ["lose_stamina_medium", "lose_health_small"]
				text = "伏点没压住，%s反从侧面冲出，你被迫翻滚避开，擦出一身伤。" % name
		_:
			_add_pressure(6, -2, 7)
			if roll <= avoid_chance:
				effect_ids = ["lose_stamina_small"]
				text = "你压低身形绕开%s，耗了些体力，总算没被缠上。%s" % [name, _enemy_tool_hint()]
			elif roll <= injury_chance:
				effect_ids = ["lose_stamina_medium", "lose_health_small"]
				if _has_equipped("old_hunter_knife") or _has_equipped("black_iron_shortblade"):
					effect_ids = ["lose_stamina_medium"]
					text = "%s突然扑近，你用手中兵刃逼出一线退路，没被咬实，但体力耗得很厉害。" % name
				else:
					text = "%s突然扑近，你勉强脱身，但身上添了伤。" % name
			else:
				effect_ids = ["lose_stamina_medium", "gain_attention_small"]
				text = "你弄出不小动静才逼退%s，这动静可能会被人记住。%s" % [name, _enemy_tool_hint()]
	current_enemy.clear()
	_set_log(text)
	danger_resolved.emit(effect_ids, text)
	queue_redraw()

func _maybe_spawn_scene_event(cell: Vector2i, cell_data: Dictionary) -> bool:
	if cell == entrance_cell:
		return false
	if resolved_scene_events.has(_scene_event_cell_key(cell)):
		return false
	var candidates := _scene_event_candidates(cell_data)
	if candidates.is_empty():
		return false
	var chance := 22 + int(float(time_pressure) * 0.08) + int(float(trace_pressure) * 0.10) + int(float(fatigue_pressure) * 0.06)
	match str(cell_data.get("type", "path")):
		"cave", "cliff", "thicket":
			chance += 5
		"creek":
			chance += 3
	if _rng.randi_range(1, 100) > clampi(chance, 8, 52):
		return false
	active_scene_event = candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	active_scene_event["cell"] = cell
	return true

func _resolve_scene_event(hotspot: Dictionary) -> void:
	var event: Dictionary = hotspot.get("event", active_scene_event)
	if event.is_empty():
		return
	var cell: Vector2i = event.get("cell", current_cell)
	resolved_scene_events[_scene_event_cell_key(cell)] = true
	active_scene_event.clear()
	var outcome := _pick_scene_event_outcome(event)
	var pressure: Array = outcome.get("pressure", [])
	if pressure.size() >= 3:
		_add_pressure(int(pressure[0]), int(pressure[1]), int(pressure[2]))
	var effect_ids: Array = outcome.get("effects", [])
	var text := str(outcome.get("text", "你处理了这处异样，继续赶路。"))
	if bool(outcome.get("spawn_enemy", false)):
		var enemies: Array = cells.get(current_cell, {}).get("enemies", [])
		if not enemies.is_empty():
			current_enemy = enemies[_rng.randi_range(0, enemies.size() - 1)]
			text = "%s\n%s被动静引来，得先处理威胁。" % [text, str(current_enemy.get("name", "野兽"))]
	_set_log(text)
	danger_resolved.emit(effect_ids, text)
	queue_redraw()

func _pick_scene_event_outcome(event: Dictionary) -> Dictionary:
	var outcomes: Array = event.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	var total := 0
	for outcome_variant in outcomes:
		var outcome: Dictionary = outcome_variant
		total += int(outcome.get("chance", 0))
	if total <= 0:
		return outcomes[0]
	var roll := _rng.randi_range(1, total)
	var cursor := 0
	for outcome_variant in outcomes:
		var outcome: Dictionary = outcome_variant
		cursor += int(outcome.get("chance", 0))
		if roll <= cursor:
			return outcome
	return outcomes.back()

func _scene_event_candidates(cell_data: Dictionary) -> Array[Dictionary]:
	var scene_type := str(cell_data.get("type", "path"))
	var candidates: Array[Dictionary] = [
		{
			"id": "fresh_trace",
			"name": "新折枝",
			"verb": "辨路",
			"hint": "路边有一截刚断的新枝，断口还湿着",
			"tone": "good",
			"outcomes": [
				{"chance": 58, "effects": ["lose_suspicion_small"], "pressure": [2, -4, 0], "text": "你顺着折枝确认了来路，脚步放轻，留下的痕迹少了些。"},
				{"chance": 28, "effects": ["gain_stamina_tiny"], "pressure": [1, 0, -4], "text": "折枝旁有块避风石，你短歇片刻，腿脚缓过一点。"},
				{"chance": 14, "effects": [], "pressure": [4, 3, 2], "text": "你盯着断枝看了太久，最后发现只是旧兽径，白白耽误了些时间。"}
			]
		},
		{
			"id": "distant_steps",
			"name": "远处脚步",
			"verb": "听声",
			"hint": "远处像有脚步踩过碎草，时近时远",
			"tone": "danger",
			"outcomes": [
				{"chance": 45, "effects": ["lose_suspicion_small"], "pressure": [3, -6, 1], "text": "你伏低听清方向，绕开了那串脚步，也把自己的踪迹压了下去。"},
				{"chance": 35, "effects": ["gain_attention_small"], "pressure": [3, 5, 2], "text": "你退得急，踩断枯枝，远处那人或那东西似乎停了一下。"},
				{"chance": 20, "effects": ["lose_stamina_small"], "pressure": [5, 2, 5], "text": "你绕了一个大圈才甩开脚步，体力被拖下去一截。"}
			]
		}
	]
	match scene_type:
		"thicket", "slope":
			candidates.append({
				"id": "herb_scent",
				"name": "苦香药气",
				"verb": "寻味",
				"hint": "风里有一缕苦香，像是草药被踩裂后的气味",
				"tone": "good",
				"outcomes": [
					{"chance": 44, "effects": ["gain_bitter_leaf"], "pressure": [4, 2, 3], "text": "你顺着苦香拨开草根，采到一小把苦叶草。"},
					{"chance": 26, "effects": ["gain_herb_small"], "pressure": [5, 2, 4], "text": "你没找到整株药，却收了些能晒干入药的碎叶。"},
					{"chance": 30, "effects": ["lose_stamina_small"], "pressure": [6, 3, 6], "text": "香气把你引进乱藤，钻出来时衣袖被扯破，脚力也耗了。"}
				]
			})
		"creek":
			candidates.append({
				"id": "cold_water",
				"name": "冰冷浅水",
				"verb": "试探",
				"hint": "浅水下有东西反光，但水寒得刺骨",
				"tone": "risk",
				"outcomes": [
					{"chance": 34, "effects": ["gain_rusty_copper_piece", "gain_money_tiny"], "pressure": [6, 2, 4], "text": "你咬牙从浅水里摸出几片锈铜，手指冻得发僵。"},
					{"chance": 28, "effects": ["gain_clear_moss"], "pressure": [5, 2, 3], "text": "你没有贪深水，只刮下石背阴处的清露苔。"},
					{"chance": 38, "effects": ["mark_cold_mild", "lose_stamina_small"], "pressure": [7, 3, 6], "text": "你在水里摸了太久，寒意顺着小腿往上钻，回去得尽快用药压住。"}
				]
			})
		"cave":
			candidates.append({
				"id": "cave_echo",
				"name": "洞中回声",
				"verb": "屏息",
				"hint": "洞里传回两次回声，第二次不像你的脚步",
				"tone": "danger",
				"outcomes": [
					{"chance": 42, "effects": [], "pressure": [4, -3, 1], "text": "你屏住呼吸等回声散尽，判断出洞里有条能避开的侧缝。"},
					{"chance": 34, "effects": ["lose_stamina_small"], "pressure": [7, 5, 6], "text": "你贴着洞壁退开，碎石滚落，虽没出事，却被吓出一身冷汗。"},
					{"chance": 24, "effects": ["gain_attention_small"], "pressure": [5, 8, 3], "spawn_enemy": true, "text": "你刚挪步，洞深处忽然有低响回应。"}
				]
			})
		"cliff":
			candidates.append({
				"id": "loose_ledge",
				"name": "松动崖沿",
				"verb": "攀取",
				"hint": "崖沿有株药草，下面的土却已经松了",
				"tone": "risk",
				"outcomes": [
					{"chance": 28, "effects": ["gain_bloodroot"], "pressure": [8, 3, 7], "text": "你贴着崖面稳住重心，硬是取下那株赤根草。"},
					{"chance": 22, "effects": ["gain_mountain_ginseng"], "pressure": [10, 4, 8], "text": "险处竟藏着一支小山参，你不敢久留，连泥一起收走。"},
					{"chance": 50, "effects": ["lose_stamina_medium", "lose_health_small"], "pressure": [8, 6, 9], "text": "崖土忽然塌了一块，你抓住石缝才没滑下去，手臂被碎石划开。"}
				]
			})
		"road", "village", "hut", "stove":
			candidates.append({
				"id": "stranger_shadow",
				"name": "陌生影子",
				"verb": "靠近",
				"hint": "破墙后晃过一个影子，像人在避你",
				"tone": "risk",
				"outcomes": [
					{"chance": 34, "effects": ["gain_money_tiny"], "pressure": [4, 3, 1], "text": "你没追人，只在墙根捡到几枚被慌乱落下的铜钱。"},
					{"chance": 36, "effects": ["lose_suspicion_small"], "pressure": [4, -5, 2], "text": "你故意走反方向，影子也没再跟上，村里的疑心少了些。"},
					{"chance": 30, "effects": ["gain_attention_small"], "pressure": [5, 6, 2], "text": "你追近半步，那影子立刻跑远，这事多半会被人传出去。"}
				]
			})
		_:
			pass
	if cell_data.get("enemies", []).size() > 0:
		candidates.append({
			"id": "animal_warning",
			"name": "兽类警声",
			"verb": "避险",
			"hint": "草里忽然静了一瞬，像有什么东西正盯着这边",
			"tone": "danger",
			"outcomes": [
				{"chance": 46, "effects": ["lose_stamina_small"], "pressure": [5, 1, 5], "text": "你退到下风处绕行，避开了可能的扑击，但耗了不少脚力。"},
				{"chance": 28, "effects": [], "pressure": [3, -4, 1], "text": "你看懂了草叶倒伏的方向，提前换路，没有留下明显动静。"},
				{"chance": 26, "effects": ["gain_attention_small"], "pressure": [4, 7, 3], "spawn_enemy": true, "text": "你刚想后退，草里的东西已经听见你的动静。"}
			]
		})
	return candidates

func _scene_event_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _scene_event_color(event: Dictionary) -> Color:
	match str(event.get("tone", "risk")):
		"good":
			return Color(0.22, 0.38, 0.24, 0.92)
		"danger":
			return Color(0.47, 0.17, 0.13, 0.92)
		_:
			return Color(0.42, 0.28, 0.13, 0.92)

func _enemy_avoid_chance(enemy: Dictionary) -> int:
	var chance := int(enemy.get("avoid_chance", 45))
	if _has_equipped("old_hunter_knife"):
		chance += 14
	if _has_equipped("black_iron_shortblade"):
		chance += 8
	if _has_flag("studied_bow_manual"):
		chance += 8
	return clampi(chance, 5, 88)

func _enemy_injury_chance(enemy: Dictionary, avoid_chance: int) -> int:
	var chance := int(enemy.get("injury_chance", 78))
	if _has_equipped("old_hunter_knife"):
		chance -= 10
	if _has_equipped("black_iron_shortblade"):
		chance -= 14
	if _has_flag("studied_bow_manual"):
		chance -= 6
	return clampi(maxi(chance, avoid_chance + 8), avoid_chance + 1, 96)

func _enemy_tool_hint() -> String:
	var hints: Array[String] = []
	if _has_equipped("old_hunter_knife"):
		hints.append("旧猎刀让野物不敢贴得太死")
	if _has_equipped("black_iron_shortblade"):
		hints.append("黑铁短刃压住了逼近的威胁")
	if _has_flag("studied_bow_manual"):
		hints.append("弓谱里的设伏法帮你看懂了退路")
	return "；".join(hints)

func _enemy_tool_bonus() -> int:
	var bonus := 0
	if _has_equipped("old_hunter_knife"):
		bonus += 14
	if _has_equipped("black_iron_shortblade"):
		bonus += 20
	if _has_flag("studied_bow_manual"):
		bonus += 16
	if _has_flag("hunter_trap_line"):
		bonus += 8
	return bonus

func _can_use_enemy_trap() -> bool:
	return _has_equipped("old_hunter_knife") or _has_equipped("black_iron_shortblade") or _has_flag("studied_bow_manual") or _has_flag("hunter_trap_line")

func _enemy_trap_label(enemy_name: String) -> String:
	if _has_flag("studied_bow_manual") or _has_flag("hunter_trap_line"):
		return "%s · 弓谱" % enemy_name
	if _has_equipped("black_iron_shortblade"):
		return "%s · 短刃" % enemy_name
	return "%s · 猎刀" % enemy_name

func _has_item(item_id: String) -> bool:
	return int(inventory_items.get(item_id, 0)) > 0

func _has_equipped(item_id: String) -> bool:
	return _has_item(item_id) and _has_flag("equip_%s" % item_id)

func _has_flag(flag_id: String) -> bool:
	return bool(active_flags.get(flag_id, false))

func _reset_pressure() -> void:
	time_pressure = 0
	trace_pressure = 0
	fatigue_pressure = 0
	pack_pressure = 0

func _apply_movement_pressure(cell_data: Dictionary) -> void:
	var scene_type := str(cell_data.get("type", "path"))
	var time_delta := 5
	var trace_delta := 2
	var fatigue_delta := 5
	match scene_type:
		"cliff", "cave":
			time_delta = 8
			trace_delta = 3
			fatigue_delta = 8
		"thicket", "slope":
			time_delta = 7
			trace_delta = 4
			fatigue_delta = 7
		"creek":
			time_delta = 7
			trace_delta = 2
			fatigue_delta = 8
		"hut", "stove", "village", "road":
			time_delta = 4
			trace_delta = 1
			fatigue_delta = 3
	if _has_equipped("wolf_pelt_complete") and scene_type in ["creek", "cliff"]:
		fatigue_delta = maxi(fatigue_delta - 3, 1)
	if _has_equipped("tiger_bone") and scene_type in ["thicket", "cave"]:
		trace_delta = maxi(trace_delta - 2, 0)
	if pack_pressure >= 60:
		fatigue_delta += 3
		trace_delta += 2
	elif pack_pressure >= 35:
		fatigue_delta += 2
	_add_pressure(time_delta, trace_delta, fatigue_delta)

func _apply_search_pressure(container: Dictionary) -> void:
	var risk := _container_risk(container)
	var time_delta := int(container.get("search_time", _default_search_time(risk)))
	var trace_delta := int(container.get("trace", _default_search_trace(risk)))
	var fatigue_delta := int(container.get("fatigue", _default_search_fatigue(risk)))
	if _is_favored_container(container):
		time_delta = maxi(time_delta - 3, 2)
		trace_delta = maxi(trace_delta - 3, 0)
	if _is_forbidden_container(container):
		trace_delta += 6
		fatigue_delta += 3
	if _has_equipped("ancient_bone_token") and _container_risk(container) in ["medium", "high"]:
		trace_delta = maxi(trace_delta - 2, 0)
	if pack_pressure >= 60:
		fatigue_delta += 2
	elif pack_pressure >= 35:
		time_delta += 2
	_add_pressure(time_delta, trace_delta, fatigue_delta)

func _add_pressure(time_delta: int, trace_delta: int, fatigue_delta: int) -> void:
	time_pressure = clampi(time_pressure + time_delta, 0, PRESSURE_MAX)
	trace_pressure = clampi(trace_pressure + trace_delta, 0, PRESSURE_MAX)
	fatigue_pressure = clampi(fatigue_pressure + fatigue_delta, 0, PRESSURE_MAX)

func _entry_enemy_chance(cell_data: Dictionary) -> int:
	var base_chance := int(cell_data.get("enemy_chance", 0))
	if base_chance <= 0:
		return 0
	base_chance += int(float(trace_pressure) * 0.24)
	base_chance += int(float(time_pressure) * 0.10)
	base_chance += int(float(pack_pressure) * 0.08)
	if fatigue_pressure >= 70:
		base_chance += 6
	return clampi(base_chance, 0, 88)

func _maybe_trigger_search_ambush(container: Dictionary) -> String:
	if not current_enemy.is_empty():
		return ""
	var cell_data: Dictionary = cells.get(current_cell, {})
	var enemies: Array = cell_data.get("enemies", [])
	if enemies.is_empty():
		return ""
	var chance := int(float(trace_pressure) * 0.16)
	chance += int(float(pack_pressure) * 0.06)
	match _container_risk(container):
		"high":
			chance += 11
		"medium":
			chance += 6
		_:
			chance += 2
	if _is_forbidden_container(container):
		chance += 10
	if _rng.randi_range(1, 100) > clampi(chance, 0, 72):
		return ""
	current_enemy = enemies[_rng.randi_range(0, enemies.size() - 1)]
	return "翻找的动静扩散出去，%s循声逼近，必须先处理威胁。" % str(current_enemy.get("name", "野兽"))

func _pressure_hint() -> String:
	if trace_pressure >= 80:
		return "踪迹太重，附近的活物更容易循声找来。"
	if time_pressure >= 80:
		return "天色压低，继续深入会越来越难脱身。"
	if fatigue_pressure >= 80:
		return "腿脚发沉，之后应对危险会更吃力。"
	if pack_pressure >= 80:
		return "包袱压肩，撤离和应对危险都会变慢。"
	if pack_pressure >= 55:
		return "行囊渐沉，再贪搜会拖慢脚步。"
	return ""

func _search_pressure_hint(container: Dictionary) -> String:
	var parts: Array[String] = []
	if _is_favored_container(container):
		parts.append("此处合卦，搜起来更顺")
	if _is_forbidden_container(container):
		parts.append("这正犯卦忌，踪迹会更重")
	var pressure := _pressure_hint()
	if not pressure.is_empty():
		parts.append(pressure)
	return " ".join(parts)

func _discover_around(cell: Vector2i) -> void:
	discovered[cell] = true
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for dir: Vector2i in dirs:
		var next_cell: Vector2i = cell + dir
		if cells.has(next_cell):
			discovered[next_cell] = true

func _build_extract_summary() -> String:
	var template: Dictionary = _current_template()
	var extract_text: String = str(template.get("extract_text", ""))
	if not extract_text.is_empty():
		return "%s%s" % [extract_text, _pack_extract_suffix()]
	return "你从%s的出口撤回村里。今日卦象到此收束，带回多少东西，全看路上搜到了什么。%s" % [_location_name(), _pack_extract_suffix()]

func _pack_extract_suffix() -> String:
	if pack_pressure >= 75:
		return " 包袱重得勒肩，幸好赶在拖不动前撤了出来。"
	if pack_pressure >= 45:
		return " 包袱有些沉，你一路都在压着脚步。"
	if pack_pressure > 0:
		return " 包里有些收获，还不至于拖慢撤离。"
	return ""

func _build_map(option_id: String, location_id: String) -> Dictionary:
	var template_map: Dictionary = _build_template_map(option_id)
	if not template_map.is_empty():
		return template_map
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

func _build_template_map(option_id: String) -> Dictionary:
	var templates: Dictionary = exploration_config.get("templates", {})
	if not templates.has(option_id):
		return {}
	var template: Dictionary = templates.get(option_id, {})
	var result: Dictionary = {}
	for cell_variant in template.get("cells", []):
		var cell_config: Dictionary = cell_variant
		var position := Vector2i(int(cell_config.get("x", 0)), int(cell_config.get("y", 0)))
		var containers: Array = []
		for container_id_variant in cell_config.get("containers", []):
			var container_id: String = str(container_id_variant)
			containers.append(_container_from_config(container_id))
		var enemies: Array = []
		for enemy_id_variant in cell_config.get("enemies", []):
			var enemy_id: String = str(enemy_id_variant)
			enemies.append(_enemy_from_config(enemy_id))
		result[position] = {
			"type": str(cell_config.get("type", "path")),
			"name": str(cell_config.get("name", "")),
			"desc": str(cell_config.get("desc", "")),
			"image": str(cell_config.get("image", "")),
			"image_path": str(cell_config.get("image_path", "")),
			"containers": containers,
			"enemies": enemies,
			"exit": bool(cell_config.get("exit", false)),
			"enemy_chance": int(cell_config.get("enemy_chance", 0)),
			"color": str(cell_config.get("color", ""))
		}
	return result

func _container_from_config(container_id: String) -> Dictionary:
	var containers: Dictionary = exploration_config.get("containers", {})
	var source: Dictionary = containers.get(container_id, {})
	if source.is_empty():
		return _trace_container()
	var result: Dictionary = source.duplicate(true)
	result["id"] = container_id
	return result

func _enemy_from_config(enemy_id: String) -> Dictionary:
	var enemies: Dictionary = exploration_config.get("enemies", {})
	var source: Dictionary = enemies.get(enemy_id, {})
	if source.is_empty():
		return _wolf()
	return source.duplicate(true)

func _mountain_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("slope", [_herb_container("herb_patch")], [_boar()], false, 22),
		Vector2i(2, 0): _cell("cliff", [_old_herb_container()], [], false),
		Vector2i(1, -1): _cell("thicket", [_trace_container(), _herb_container("bush_herb")], [_wolf()], false, 28),
		Vector2i(2, -1): _cell("cave", [_cache_container()], [_bear(), _tiger()], false, 36),
		Vector2i(3, -1): _cell("creek", [_creek_container()], [], true),
		Vector2i(0, 1): _cell("creek", [_creek_container()], [], false),
		Vector2i(1, 1): _cell("path", [_trace_container()], [], false),
		Vector2i(2, 1): _cell("cliff", [_eagle_nest_container()], [_wolf()], false, 20)
	}

func _forest_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_herb_container("forest_herb")], [_wolf()], false, 34),
		Vector2i(2, 0): _cell("thicket", [_trace_container()], [_boar()], false, 38),
		Vector2i(2, -1): _cell("cave", [_cache_container()], [_bear(), _tiger()], false, 30),
		Vector2i(3, -1): _cell("creek", [_creek_container()], [], true),
		Vector2i(1, 1): _cell("thicket", [_snare_container()], [_wolf()], false, 24),
		Vector2i(2, 1): _cell("slope", [_fallen_tree_container()], [_boar()], false, 26)
	}

func _river_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("creek", [_creek_container()], [], false),
		Vector2i(2, 0): _cell("creek", [_cache_container()], [], true),
		Vector2i(1, -1): _cell("thicket", [_herb_container("wet_herb")], [_wolf()], false, 18),
		Vector2i(2, -1): _cell("creek", [_reed_pool_container()], [], false),
		Vector2i(0, 1): _cell("road", [_fisher_basket_container()], [], false)
	}

func _graveyard_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_cache_container()], [], false),
		Vector2i(2, 0): _cell("cave", [_cache_container(), _old_herb_container()], [_wolf()], false, 32),
		Vector2i(2, 1): _cell("cliff", [_trace_container()], [], true),
		Vector2i(1, -1): _cell("path", [_burnt_paper_container()], [], false),
		Vector2i(3, 0): _cell("cave", [_sealed_jar_container()], [_wolf()], false, 28)
	}

func _field_map() -> Dictionary:
	return {
		Vector2i(0, 0): _cell("path", [_trace_container()], [], false),
		Vector2i(1, 0): _cell("thicket", [_herb_container("field_herb")], [], false),
		Vector2i(2, 0): _cell("creek", [_creek_container()], [], true),
		Vector2i(1, 1): _cell("slope", [_cache_container()], [], false),
		Vector2i(0, 1): _cell("hut", [_abandoned_hut_container()], [], false),
		Vector2i(2, 1): _cell("road", [_market_trace_container()], [], false)
	}

func _cell(scene_type: String, containers: Array, enemies: Array, is_exit: bool, enemy_chance: int = 0) -> Dictionary:
	return {
		"type": scene_type,
		"name": "",
		"desc": "",
		"image": scene_type,
		"image_path": "",
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

func _eagle_nest_container() -> Dictionary:
	return {
		"id": "eagle_nest",
		"name": "崖上旧巢",
		"rarity": "rare",
		"loot": [
			{"chance": 28, "name": "【优质】野禽羽", "effects": ["gain_rabbit_pelt", "gain_money_tiny"], "text": "旧巢里压着完整羽片，货郎会收。"},
			{"chance": 20, "name": "【稀有】小山参", "effects": ["gain_mountain_ginseng"], "text": "巢下石缝里竟卡着一支小山参。"},
			{"chance": 12, "name": "【珍贵】弯折银簪", "effects": ["gain_silver_hairpin_bent", "gain_suspicion_small"], "text": "银簪被叼到巢中，来路多半不干净。"},
			{"chance": 40, "name": "踏空碎石", "effects": ["lose_stamina_medium", "lose_health_small"], "text": "你伸手太深，脚下碎石一滑，手臂被崖壁蹭开。"}
		]
	}

func _snare_container() -> Dictionary:
	return {
		"id": "old_snare",
		"name": "旧绳套",
		"rarity": "uncommon",
		"loot": [
			{"chance": 34, "name": "套中野兔", "effects": ["gain_meat_small", "gain_rabbit_pelt"], "text": "旧绳套还没坏，竟套住一只小兽。"},
			{"chance": 22, "name": "【优质】野猪獠牙", "effects": ["gain_boar_tusk"], "text": "绳套旁有断獠牙，像是野猪挣脱时留下的。"},
			{"chance": 24, "name": "空绳结", "effects": [], "text": "绳结已经松了，附近只有踩乱的草。"},
			{"chance": 20, "name": "绳套反抽", "effects": ["lose_health_small"], "text": "你解绳时被反抽一下，手背火辣辣地疼。"}
		]
	}

func _fallen_tree_container() -> Dictionary:
	return {
		"id": "fallen_tree",
		"name": "倒木根洞",
		"rarity": "uncommon",
		"loot": [
			{"chance": 28, "name": "【普通】苦叶草", "effects": ["gain_bitter_leaf"], "text": "根洞阴处长着苦叶草。"},
			{"chance": 22, "name": "【优质】赤根草", "effects": ["gain_bloodroot"], "text": "树根压住一截赤根草，药性还在。"},
			{"chance": 20, "name": "藏粮小包", "effects": ["gain_food_small", "gain_suspicion_small"], "text": "有人把粗粮藏在根洞里，拿走会惹人疑心。"},
			{"chance": 30, "name": "腐木塌陷", "effects": ["lose_stamina_small"], "text": "腐木踩塌，灰尘呛得你退了出来。"}
		]
	}

func _reed_pool_container() -> Dictionary:
	return {
		"id": "reed_pool",
		"name": "芦苇浅滩",
		"rarity": "uncommon",
		"loot": [
			{"chance": 28, "name": "【优质】清露苔", "effects": ["gain_clear_moss"], "text": "湿石边长着一片清露苔。"},
			{"chance": 22, "name": "【稀有】蛇胆", "effects": ["gain_snake_gall"], "text": "芦根旁有蛇迹，你找到一枚还能入药的蛇胆。"},
			{"chance": 18, "name": "冲来的旧钱", "effects": ["gain_old_coin_string"], "text": "旧钱串被水草缠住，锈得发黑。"},
			{"chance": 32, "name": "湿脚受寒", "effects": ["mark_cold_mild", "lose_stamina_small"], "text": "你踩进冷水，寒意顺着脚心往上爬。"}
		]
	}

func _fisher_basket_container() -> Dictionary:
	return {
		"id": "fisher_basket",
		"name": "破鱼篓",
		"rarity": "common",
		"loot": [
			{"chance": 34, "name": "小鱼干", "effects": ["gain_food_small"], "text": "鱼篓里还有几条晒硬的小鱼，勉强能充饥。"},
			{"chance": 24, "name": "碎铜钱", "effects": ["gain_money_tiny"], "text": "篓底卡着几枚碎铜钱。"},
			{"chance": 18, "name": "【普通】苦叶草", "effects": ["gain_bitter_leaf"], "text": "有人用苦叶草压着鱼腥味。"},
			{"chance": 24, "name": "腥水空篓", "effects": ["lose_stamina_small"], "text": "篓里只有腥水，你翻得一手湿臭。"}
		]
	}

func _burnt_paper_container() -> Dictionary:
	return {
		"id": "burnt_paper",
		"name": "烧残纸灰",
		"rarity": "uncommon",
		"loot": [
			{"chance": 32, "name": "半截暗记", "effects": ["mark_saw_graveyard_cache"], "text": "纸灰里留着半个地名，像是指向荒坟深处。"},
			{"chance": 24, "name": "【普通】锈铜片", "effects": ["gain_rusty_copper_piece"], "text": "纸灰下压着几片锈铜。"},
			{"chance": 16, "name": "【稀有】残玉扣", "effects": ["gain_broken_jade_button", "gain_suspicion_small"], "text": "残玉扣混在纸灰里，像被人急着掩埋。"},
			{"chance": 28, "name": "纸灰迷眼", "effects": ["lose_stamina_small", "gain_suspicion_small"], "text": "风卷纸灰扑面，你咳了半天，还留下明显翻找痕迹。"}
		]
	}

func _sealed_jar_container() -> Dictionary:
	return {
		"id": "sealed_jar",
		"name": "封泥旧罐",
		"rarity": "rare",
		"loot": [
			{"chance": 26, "name": "【优质】旧钱串", "effects": ["gain_old_coin_string", "gain_money_small"], "text": "旧罐里包着一串发黑旧钱。"},
			{"chance": 18, "name": "【稀有】残玉扣", "effects": ["gain_broken_jade_button"], "text": "封泥下藏着半片玉扣。"},
			{"chance": 8, "name": "【传说】逃兵私印", "effects": ["gain_soldier_hidden_seal", "gain_suspicion_small"], "text": "私印压在罐底，沉得不像好东西。"},
			{"chance": 48, "name": "阴湿黑泥", "effects": ["mark_cold_mild", "lose_stamina_small"], "text": "罐里全是阴湿黑泥，寒气和霉味一起扑出来。"}
		]
	}

func _abandoned_hut_container() -> Dictionary:
	return {
		"id": "abandoned_hut",
		"name": "废屋灶角",
		"rarity": "common",
		"loot": [
			{"chance": 30, "name": "半袋粗粮", "effects": ["gain_food_small"], "text": "灶角藏着半袋潮粮，挑一挑还能吃。"},
			{"chance": 22, "name": "旧药包", "effects": ["gain_herb_small"], "text": "药包受潮不轻，但还能救急。"},
			{"chance": 18, "name": "几枚铜钱", "effects": ["gain_money_tiny"], "text": "灶灰里埋着几枚铜钱。"},
			{"chance": 30, "name": "塌灰呛咳", "effects": ["lose_stamina_small"], "text": "灶灰塌了一片，你咳得眼泪都出来了。"}
		]
	}

func _market_trace_container() -> Dictionary:
	return {
		"id": "market_trace",
		"name": "车辙旧痕",
		"rarity": "common",
		"loot": [
			{"chance": 28, "name": "遗落粗粮", "effects": ["gain_food_small"], "text": "车辙边撒落一些粗粮，被泥裹住还没坏。"},
			{"chance": 24, "name": "碎铜钱", "effects": ["gain_money_tiny"], "text": "你在车辙坑里抠出几枚铜钱。"},
			{"chance": 18, "name": "货郎记号", "effects": ["mark_jade_buyer_clue"], "text": "路边刻着货郎暗号，和残玉买家的说法对得上。"},
			{"chance": 30, "name": "白走一段", "effects": ["lose_stamina_small"], "text": "车辙一路绕回旧道，你白走一段。"}
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

func _loot_pack_pressure(loot: Dictionary) -> int:
	var effects: Array = loot.get("effects", [])
	if effects.is_empty():
		return 0
	var pressure := 0
	match _rarity_from_loot(loot):
		"fine":
			pressure += 5
		"rare":
			pressure += 8
		"precious":
			pressure += 12
		"legendary":
			pressure += 18
		"mythic":
			pressure += 24
		_:
			pressure += 3
	for effect_variant in effects:
		var effect_id := str(effect_variant)
		if not effect_id.begins_with("gain_"):
			continue
		if effect_id.contains("money") or effect_id.contains("bitter_leaf") or effect_id.contains("clear_moss"):
			pressure += 1
		elif effect_id.contains("food") or effect_id.contains("meat") or effect_id.contains("pelt"):
			pressure += 4
		elif effect_id.contains("tiger") or effect_id.contains("ginseng") or effect_id.contains("shortblade") or effect_id.contains("seal"):
			pressure += 5
		else:
			pressure += 2
	if _has_equipped("wolf_pelt_complete"):
		pressure = maxi(pressure - 2, 0)
	return clampi(pressure, 0, 30)

func _pack_gain_text(delta: int) -> String:
	if delta >= 18:
		return "这东西压手得很，包袱明显沉了一截。"
	if delta >= 10:
		return "你把东西塞进包里，肩上重量又实了几分。"
	return "包袱多了一点分量。"

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

func _load_exploration_config() -> void:
	var path := "res://configs/gameplay/exploration_templates.json"
	if not FileAccess.file_exists(path):
		exploration_config = {}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		exploration_config = {}
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse exploration template config: %s" % path)
		exploration_config = {}
		return
	exploration_config = json.data if typeof(json.data) == TYPE_DICTIONARY else {}

func _current_template() -> Dictionary:
	var templates: Dictionary = exploration_config.get("templates", {})
	return templates.get(str(selected_option.get("id", "")), {})

func _intro_text() -> String:
	var template: Dictionary = _current_template()
	var intro: String = str(template.get("intro", ""))
	if not intro.is_empty():
		return intro
	return "你按卦象来到%s入口。" % _location_name()

func _omen_brief() -> String:
	var tip := _omen_tip_text()
	var warn := _omen_warn_text()
	if warn.is_empty():
		return "卦象：宜%s" % tip
	return "卦象：宜%s；忌%s" % [tip, warn]

func _omen_tip_text() -> String:
	var template: Dictionary = _current_template()
	var tip := str(template.get("omen_tip", ""))
	if not tip.is_empty():
		return tip
	var gain := str(selected_option.get("omen_gain", "取应得之物"))
	return gain

func _omen_warn_text() -> String:
	var template: Dictionary = _current_template()
	var warn := str(template.get("omen_warn", ""))
	if not warn.is_empty():
		return warn
	return str(selected_option.get("omen_warning", "贪搜恋战"))

func _location_name() -> String:
	var template: Dictionary = _current_template()
	var template_name: String = str(template.get("name", ""))
	if not template_name.is_empty():
		return template_name
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

func _cell_scene_name(cell_data: Dictionary) -> String:
	var configured_name: String = str(cell_data.get("name", ""))
	if not configured_name.is_empty():
		return configured_name
	return _scene_name(str(cell_data.get("type", "path")))

func _cell_scene_desc(cell_data: Dictionary) -> String:
	var configured_desc: String = str(cell_data.get("desc", ""))
	if not configured_desc.is_empty():
		return configured_desc
	return _scene_desc(str(cell_data.get("type", "path")))

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

func _cell_color(cell_data: Dictionary) -> Color:
	var configured_color: String = str(cell_data.get("color", ""))
	if not configured_color.is_empty():
		return Color.html(configured_color)
	return _scene_color(str(cell_data.get("type", "path")))

func _scene_color(scene_type: String) -> Color:
	match scene_type:
		"hut":
			return Color(0.12, 0.075, 0.045, 1.0)
		"road":
			return Color(0.13, 0.10, 0.06, 1.0)
		"village":
			return Color(0.12, 0.08, 0.055, 1.0)
		"stove":
			return Color(0.12, 0.055, 0.035, 1.0)
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

func _container_label(container: Dictionary) -> String:
	var name := str(container.get("name", "可疑处"))
	var tag := _container_risk_label(container)
	if _is_favored_container(container):
		tag = "卦应"
	elif _is_forbidden_container(container):
		tag = "犯忌"
	return "%s · %s" % [name, tag]

func _container_risk_label(container: Dictionary) -> String:
	if _is_forbidden_container(container):
		return "犯忌"
	match _container_risk(container):
		"high":
			return "危险"
		"medium":
			return "惹疑"
		"tiring":
			return "耗力"
		_:
			return "稳妥"

func _container_color(container: Dictionary) -> Color:
	if _is_favored_container(container):
		return Color(0.34, 0.48, 0.28, 0.94)
	if _is_forbidden_container(container):
		return Color(0.58, 0.18, 0.14, 0.94)
	match _container_risk(container):
		"high":
			return Color(0.46, 0.16, 0.12, 0.92)
		"medium":
			return Color(0.42, 0.28, 0.13, 0.92)
		"tiring":
			return Color(0.28, 0.32, 0.18, 0.92)
		_:
			return Color(0.18, 0.30, 0.18, 0.90)

func _container_risk(container: Dictionary) -> String:
	var configured := str(container.get("risk", ""))
	if not configured.is_empty():
		return configured
	var id := str(container.get("id", ""))
	var name := str(container.get("name", ""))
	var text := "%s %s" % [id, name]
	if text.contains("cliff") or text.contains("崖") or text.contains("coffin") or text.contains("棺") or text.contains("soldier") or text.contains("逃兵") or text.contains("broken_stele") or text.contains("断碑"):
		return "high"
	if text.contains("grave") or text.contains("坟") or text.contains("cache") or text.contains("藏") or text.contains("暗") or text.contains("waterlogged") or text.contains("泡水") or text.contains("hunter") or text.contains("猎户"):
		return "medium"
	var danger_score := 0
	for entry_variant in container.get("loot", []):
		var entry: Dictionary = entry_variant
		var effects: Array = entry.get("effects", [])
		for effect_variant in effects:
			var effect_id := str(effect_variant)
			if effect_id.begins_with("lose_health") or effect_id.begins_with("gain_suspicion") or effect_id.begins_with("gain_attention") or effect_id.begins_with("mark_cold"):
				danger_score += 2
			elif effect_id.begins_with("lose_stamina"):
				danger_score += 1
	if danger_score >= 4:
		return "high"
	if danger_score >= 2:
		return "medium"
	if danger_score == 1:
		return "tiring"
	match str(container.get("rarity", "common")):
		"rare":
			return "medium"
		"uncommon":
			return "tiring"
		_:
			return "low"

func _default_search_time(risk: String) -> int:
	match risk:
		"high":
			return 15
		"medium":
			return 12
		"tiring":
			return 10
		_:
			return 8

func _default_search_trace(risk: String) -> int:
	match risk:
		"high":
			return 15
		"medium":
			return 10
		"tiring":
			return 5
		_:
			return 3

func _default_search_fatigue(risk: String) -> int:
	match risk:
		"high":
			return 12
		"medium":
			return 9
		"tiring":
			return 10
		_:
			return 6

func _is_favored_container(container: Dictionary) -> bool:
	return _container_id_in_template_list(container, "favored_containers")

func _is_forbidden_container(container: Dictionary) -> bool:
	return _container_id_in_template_list(container, "forbidden_containers")

func _container_id_in_template_list(container: Dictionary, field: String) -> bool:
	var template: Dictionary = _current_template()
	var container_id := str(container.get("id", ""))
	var container_name := str(container.get("name", ""))
	for value_variant in template.get(field, []):
		var value := str(value_variant)
		if value == container_id or value == container_name:
			return true
	return false
