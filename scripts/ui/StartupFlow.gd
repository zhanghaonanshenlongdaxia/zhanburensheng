class_name StartupFlow
extends Control

signal finished()

enum FlowMode { SPLASH, TITLE, PROLOGUE, EXITING }

const SPLASH_DURATION := 2.25
const EXIT_DURATION := 0.75
const TITLE_BACKGROUND_PATH := "res://assets/generated/startup/title_ink_v1.jpg"

var mode: FlowMode = FlowMode.SPLASH
var mode_time := 0.0
var splash_index := 0
var story_index := 0
var _start_button_rect := Rect2()
var _story_button_rect := Rect2()
var _title_texture: Texture2D
var _story_textures: Array[Texture2D] = []
var _completed := false

var splash_cards: Array[Dictionary] = [
	{
		"title": "SHENLONG WORKS",
		"subtitle": "出品 / A survival divination tale",
		"mark": "SL"
	},
	{
		"title": "QGF GAME FRAMEWORK",
		"subtitle": "玩法框架 / Data driven gameplay flow",
		"mark": "QG"
	},
	{
		"title": "GODOT ENGINE",
		"subtitle": "运行技术 / Godot 4.3",
		"mark": "GD"
	},
	{
		"title": "DOUBAO SEEDREAM",
		"subtitle": "美术管线 / Concept art pipeline",
		"mark": "AI"
	}
]

var story_pages: Array[Dictionary] = [
	{
		"title": "债期压门",
		"text": "村口雾气还没散，债主的眼线已经在路上。你欠下的不是一笔账，而是一段越来越短的活路。",
		"image": "res://assets/generated/startup/story_debt_notice.jpg",
		"tag": "活下去，先别被债拖死。"
	},
	{
		"title": "铜钱落案",
		"text": "卦象不会替你还债，也不会替你挡灾。它只会指出哪里有机会，哪里藏着代价。",
		"image": "res://assets/generated/startup/story_divination_table.jpg",
		"tag": "吉凶只是方向，选择才是命。"
	},
	{
		"title": "清点家当",
		"text": "粮食、草药、旧刀、铜钱，每一样都可能救命，也可能在明天之前消耗殆尽。",
		"image": "res://assets/generated/startup/story_meager_supplies.jpg",
		"tag": "背包不是仓库，是活命的底线。"
	},
	{
		"title": "小黑山",
		"text": "山路、洞穴、溪谷、悬崖，各有能搜到的东西，也各有会咬住你的危险。",
		"image": "res://assets/generated/startup/story_black_mountain.jpg",
		"tag": "进去要搜，出来更要活着出来。"
	},
	{
		"title": "镇上交易",
		"text": "你可以卖掉药材换粮，也可以向郎中买药，或从闲谈里听出下一条线索。",
		"image": "res://assets/generated/startup/story_town_trade.jpg",
		"tag": "人情、物价、口风，都是资源。"
	},
	{
		"title": "线索成网",
		"text": "每次探索都会留下痕迹。等线索分叉成网，你要自己判断哪条路能还债，哪条路会吞人。",
		"image": "res://assets/generated/startup/story_clue_board.jpg",
		"tag": "把散乱的线，拧成你的生路。"
	}
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_to_viewport()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_fit_to_viewport)
	_title_texture = _load_texture_from_file(TITLE_BACKGROUND_PATH)
	for page in story_pages:
		_story_textures.append(_load_texture_from_file(str(page.get("image", TITLE_BACKGROUND_PATH))))
	set_process(true)

func _process(delta: float) -> void:
	mode_time += delta
	if mode == FlowMode.SPLASH and mode_time >= SPLASH_DURATION:
		splash_index += 1
		mode_time = 0.0
		if splash_index >= splash_cards.size():
			mode = FlowMode.TITLE
	if mode == FlowMode.EXITING and mode_time >= EXIT_DURATION:
		_finish()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if mode == FlowMode.SPLASH:
			_enter_title()
		elif mode == FlowMode.TITLE:
			_enter_story()
		elif mode == FlowMode.PROLOGUE:
			_advance_story()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var pos: Vector2 = mouse_event.position
		if mode == FlowMode.SPLASH:
			_enter_title()
		elif mode == FlowMode.TITLE and _start_button_rect.has_point(pos):
			_enter_story()
		elif mode == FlowMode.PROLOGUE and _story_button_rect.has_point(pos):
			_advance_story()
		accept_event()

func _draw() -> void:
	match mode:
		FlowMode.SPLASH:
			_draw_splash()
		FlowMode.TITLE:
			_draw_title()
		FlowMode.PROLOGUE:
			_draw_story()
		FlowMode.EXITING:
			_draw_story()
			var alpha := clampf(mode_time / EXIT_DURATION, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, alpha))

func _enter_title() -> void:
	mode = FlowMode.TITLE
	mode_time = 0.0

func _enter_story() -> void:
	mode = FlowMode.PROLOGUE
	mode_time = 0.0
	story_index = 0

func _advance_story() -> void:
	story_index += 1
	mode_time = 0.0
	if story_index >= story_pages.size():
		mode = FlowMode.EXITING

func _draw_splash() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.006, 0.005, 0.004, 1.0))
	_draw_splash_ornaments()
	_draw_film_grain(0.055)
	_draw_letterbox()
	_draw_thin_frame(Rect2(size * 0.5 - Vector2(230.0, 112.0), Vector2(460.0, 224.0)), Color(0.72, 0.55, 0.30, 0.28))

	var card: Dictionary = splash_cards[min(splash_index, splash_cards.size() - 1)]
	var alpha := _splash_alpha()
	var center := size * 0.5
	_draw_emblem(center + Vector2(0.0, -44.0), str(card.get("mark", "")), Color(0.86, 0.70, 0.42, alpha))
	var font := get_theme_default_font()
	_draw_centered(font, center + Vector2(0.0, 48.0), str(card.get("title", "")), 26, Color(0.90, 0.82, 0.66, alpha), 3, 560.0)
	_draw_centered(font, center + Vector2(0.0, 78.0), str(card.get("subtitle", "")), 13, Color(0.62, 0.57, 0.48, alpha), 2, 620.0)
	_draw_splash_progress(alpha)
	_draw_centered(font, Vector2(size.x * 0.5, size.y - 44.0), "按任意键跳过片头", 12, Color(0.50, 0.45, 0.36, minf(alpha, 0.62)), 2, 220.0)

func _draw_title() -> void:
	_draw_cinematic_background(_title_texture, 0.30)
	_draw_letterbox()
	_draw_title_ornaments()
	var font := get_theme_default_font()
	var title_y := size.y * 0.32
	_draw_centered(font, Vector2(size.x * 0.5, title_y), "占卜人生", 64, Color(0.98, 0.86, 0.58, 1.0), 7, 660.0)
	_draw_centered(font, Vector2(size.x * 0.5, title_y + 62.0), "在生存、怀疑与债务之间，为自己占一条活路。", 16, Color(0.82, 0.74, 0.58, 1.0), 4, 680.0)
	_start_button_rect = Rect2(Vector2(size.x * 0.5 - 102.0, size.y * 0.67), Vector2(204.0, 48.0))
	_draw_button(_start_button_rect, "点击入局", true)
	_draw_centered(font, Vector2(size.x * 0.5, size.y - 42.0), "一切抉择都会留下痕迹", 12, Color(0.58, 0.50, 0.36, 0.90), 2, 260.0)

func _draw_story() -> void:
	var story_texture := _get_story_texture(story_index)
	_draw_cinematic_background(story_texture, 0.52)
	_draw_letterbox()
	var page: Dictionary = story_pages[clampi(story_index, 0, story_pages.size() - 1)]
	var content_rect := _get_story_content_rect()
	_draw_story_paper(content_rect)

	var font := get_theme_default_font()
	if content_rect.size.x < 680.0:
		var image_rect := Rect2(content_rect.position + Vector2(16.0, 16.0), Vector2(content_rect.size.x - 32.0, content_rect.size.y * 0.43))
		_draw_image_panel(image_rect, story_texture)
		var title_pos := Vector2(content_rect.position.x + 24.0, image_rect.end.y + 32.0)
		var text_rect := Rect2(title_pos + Vector2(0.0, 30.0), Vector2(content_rect.size.x - 48.0, 150.0))
		_draw_outlined_string(font, title_pos, str(page.get("title", "")), 28, Color(0.96, 0.84, 0.58, 1.0), 5, text_rect.size.x)
		_draw_multiline(font, text_rect.position, str(page.get("text", "")), 16, Color(0.84, 0.78, 0.64, 1.0), 4, text_rect.size.x, 28.0)
	else:
		var image_rect := Rect2(content_rect.position + Vector2(22.0, 22.0), Vector2(516.0, content_rect.size.y - 44.0))
		_draw_image_panel(image_rect, story_texture)
		var caption_rect := Rect2(content_rect.position + Vector2(562.0, 56.0), Vector2(content_rect.size.x - 602.0, 246.0))
		_draw_caption_box(caption_rect, page)
	_draw_story_footer(content_rect, page)
	_story_button_rect = Rect2(content_rect.position + Vector2(content_rect.size.x - 180.0, content_rect.size.y - 58.0), Vector2(136.0, 40.0))
	_draw_button(_story_button_rect, "开始求生" if story_index == story_pages.size() - 1 else "继续", true)

func _draw_cinematic_background(texture: Texture2D, darkness: float) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.018, 0.016, 0.014, 1.0))
	if texture != null:
		_draw_cover_texture(texture, rect)
	draw_rect(rect, Color(0.0, 0.0, 0.0, darkness))
	_draw_film_grain(0.035)
	var top_fade := Rect2(0.0, 0.0, size.x, size.y * 0.24)
	var bottom_fade := Rect2(0.0, size.y * 0.72, size.x, size.y * 0.28)
	draw_rect(top_fade, Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(bottom_fade, Color(0.0, 0.0, 0.0, 0.38))

func _draw_image_panel(rect: Rect2, texture: Texture2D) -> void:
	draw_rect(rect, Color(0.045, 0.038, 0.030, 1.0))
	if texture != null:
		_draw_cover_texture(texture, rect)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.10))
	draw_rect(rect, Color(0.92, 0.68, 0.34, 0.56), false, 1.0)
	for idx in range(5):
		var y := rect.position.y + rect.size.y * (0.25 + float(idx) * 0.13)
		draw_line(Vector2(rect.position.x + 22.0, y), Vector2(rect.end.x - 22.0, y + 8.0), Color(0.92, 0.74, 0.42, 0.08), 1.0)

func _draw_splash_ornaments() -> void:
	var font := get_theme_default_font()
	var left := Rect2(42.0, 122.0, 182.0, size.y - 244.0)
	var right := Rect2(size.x - 224.0, 122.0, 182.0, size.y - 244.0)
	var top := Rect2(size.x * 0.5 - 170.0, 78.0, 340.0, 54.0)
	for rect in [left, right, top]:
		draw_rect(rect, Color(0.09, 0.066, 0.038, 0.24))
		draw_rect(rect, Color(0.72, 0.52, 0.25, 0.30), false, 1.0)
		_draw_corner_marks(rect, Color(0.95, 0.70, 0.34, 0.28), 24.0)
	for idx in range(8):
		var y := left.position.y + 38.0 + float(idx) * 44.0
		draw_line(Vector2(left.position.x + 34.0, y), Vector2(left.end.x - 34.0, y + 12.0), Color(0.72, 0.52, 0.25, 0.16), 1.0)
		draw_line(Vector2(right.position.x + 34.0, y + 12.0), Vector2(right.end.x - 34.0, y), Color(0.72, 0.52, 0.25, 0.16), 1.0)
	_draw_centered(font, top.get_center() + Vector2(0.0, 5.0), "OPENING ROLL", 13, Color(0.58, 0.50, 0.38, 0.52), 2, top.size.x)
	_draw_vertical_text(font, Vector2(left.position.x + 52.0, left.position.y + 60.0), "乾坤未定", 19, Color(0.80, 0.62, 0.36, 0.34))
	_draw_vertical_text(font, Vector2(right.position.x + 52.0, right.position.y + 60.0), "入局求生", 19, Color(0.80, 0.62, 0.36, 0.34))
	for idx in range(11):
		var p := Vector2(size.x * (0.18 + float(idx) * 0.064), size.y * (0.20 + float(idx % 3) * 0.18))
		draw_circle(p, 2.0, Color(0.84, 0.62, 0.30, 0.14))
		if idx > 0:
			var prev := Vector2(size.x * (0.18 + float(idx - 1) * 0.064), size.y * (0.20 + float((idx - 1) % 3) * 0.18))
			draw_line(prev, p, Color(0.84, 0.62, 0.30, 0.055), 1.0)

func _draw_title_ornaments() -> void:
	var frame := Rect2(36.0, 54.0, size.x - 72.0, size.y - 108.0)
	_draw_corner_marks(frame, Color(0.94, 0.68, 0.32, 0.52), 44.0)
	draw_rect(Rect2(frame.position.x, frame.position.y, frame.size.x, 1.0), Color(0.94, 0.68, 0.32, 0.20))
	draw_rect(Rect2(frame.position.x, frame.end.y, frame.size.x, 1.0), Color(0.94, 0.68, 0.32, 0.20))
	var seal_center := Vector2(size.x * 0.5, size.y * 0.53)
	draw_circle(seal_center, 54.0, Color(0.80, 0.18, 0.12, 0.10))
	draw_circle(seal_center, 46.0, Color(0.85, 0.42, 0.18, 0.18), false, 2.0)
	for idx in range(7):
		var x := size.x * 0.5 - 210.0 + float(idx) * 70.0
		draw_line(Vector2(x, size.y * 0.57), Vector2(x + 32.0, size.y * 0.57), Color(0.92, 0.70, 0.36, 0.25), 1.0)

func _draw_story_paper(rect: Rect2) -> void:
	draw_rect(rect, Color(0.035, 0.030, 0.023, 0.97))
	draw_rect(rect, Color(0.16, 0.11, 0.055, 0.34))
	draw_rect(rect, Color(0.84, 0.60, 0.30, 0.54), false, 1.0)
	_draw_corner_marks(rect, Color(0.94, 0.68, 0.32, 0.46), 28.0)
	for idx in range(10):
		var x := rect.position.x + 26.0 + float(idx) * (rect.size.x - 52.0) / 9.0
		draw_line(Vector2(x, rect.position.y + 12.0), Vector2(x + 22.0, rect.end.y - 12.0), Color(0.90, 0.68, 0.34, 0.035), 1.0)

func _draw_caption_box(rect: Rect2, page: Dictionary) -> void:
	var font := get_theme_default_font()
	draw_rect(rect, Color(0.010, 0.009, 0.007, 0.72))
	draw_rect(rect, Color(0.86, 0.62, 0.30, 0.34), false, 1.0)
	_draw_outlined_string(font, rect.position + Vector2(18.0, 34.0), str(page.get("title", "")), 33, Color(0.98, 0.84, 0.56, 1.0), 5, rect.size.x - 36.0)
	_draw_multiline(font, rect.position + Vector2(18.0, 84.0), str(page.get("text", "")), 17, Color(0.88, 0.80, 0.64, 1.0), 4, rect.size.x - 36.0, 31.0)
	var tag_rect := Rect2(rect.position + Vector2(18.0, rect.size.y - 58.0), Vector2(rect.size.x - 36.0, 32.0))
	draw_rect(tag_rect, Color(0.22, 0.13, 0.045, 0.86))
	draw_rect(tag_rect, Color(0.92, 0.68, 0.34, 0.42), false, 1.0)
	_draw_centered(font, tag_rect.get_center() + Vector2(0.0, 5.0), str(page.get("tag", "")), 13, Color(0.94, 0.82, 0.58, 1.0), 3, tag_rect.size.x - 10.0)

func _draw_story_footer(rect: Rect2, page: Dictionary) -> void:
	var font := get_theme_default_font()
	var page_text := "%02d / %02d" % [story_index + 1, story_pages.size()]
	_draw_centered(font, rect.position + Vector2(rect.size.x - 106.0, rect.size.y - 80.0), page_text, 12, Color(0.62, 0.54, 0.42, 1.0), 2, 120.0)
	var rail := Rect2(rect.position.x + 26.0, rect.end.y - 42.0, maxf(rect.size.x - 236.0, 80.0), 3.0)
	draw_rect(rail, Color(0.38, 0.28, 0.15, 0.50))
	var progress_w := rail.size.x * float(story_index + 1) / float(story_pages.size())
	draw_rect(Rect2(rail.position, Vector2(progress_w, rail.size.y)), Color(0.92, 0.68, 0.34, 0.80))
	if rect.size.x < 680.0:
		_draw_centered(font, rect.position + Vector2(rect.size.x * 0.5, rect.end.y - rect.position.y - 78.0), str(page.get("tag", "")), 12, Color(0.94, 0.82, 0.58, 1.0), 3, rect.size.x - 54.0)

func _draw_corner_marks(rect: Rect2, color: Color, length: float) -> void:
	draw_line(rect.position, rect.position + Vector2(length, 0.0), color, 2.0)
	draw_line(rect.position, rect.position + Vector2(0.0, length), color, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - length, rect.position.y), color, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + length), color, 2.0)
	draw_line(rect.end, rect.end - Vector2(length, 0.0), color, 2.0)
	draw_line(rect.end, rect.end - Vector2(0.0, length), color, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + length, rect.end.y), color, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - length), color, 2.0)

func _draw_vertical_text(font: Font, position: Vector2, text: String, font_size: int, color: Color) -> void:
	for idx in text.length():
		_draw_centered(font, position + Vector2(0.0, float(idx) * float(font_size + 8)), text.substr(idx, 1), font_size, color, 2, 44.0)

func _draw_button(rect: Rect2, text: String, enabled: bool) -> void:
	var bg := Color(0.16, 0.10, 0.045, 0.94) if enabled else Color(0.08, 0.07, 0.06, 0.80)
	var border := Color(0.92, 0.66, 0.30, 0.88) if enabled else Color(0.38, 0.30, 0.20, 0.70)
	draw_rect(rect, bg)
	draw_rect(rect, border, false, 1.5)
	_draw_centered(get_theme_default_font(), rect.get_center() + Vector2(0.0, 5.0), text, 15, Color(0.96, 0.84, 0.58, 1.0), 3, rect.size.x)

func _draw_emblem(center: Vector2, text: String, color: Color) -> void:
	draw_circle(center, 42.0, Color(color.r, color.g, color.b, color.a * 0.08))
	draw_circle(center, 38.0, Color(color.r, color.g, color.b, color.a * 0.72), false, 2.0)
	var points := PackedVector2Array([
		center + Vector2(0.0, -26.0),
		center + Vector2(24.0, 0.0),
		center + Vector2(0.0, 26.0),
		center + Vector2(-24.0, 0.0),
		center + Vector2(0.0, -26.0)
	])
	draw_polyline(points, Color(color.r, color.g, color.b, color.a * 0.52), 2.0)
	_draw_centered(get_theme_default_font(), center + Vector2(0.0, 6.0), text, 17, color, 3, 86.0)

func _draw_splash_progress(alpha: float) -> void:
	var segment_w := 34.0
	var gap := 8.0
	var total_w := float(splash_cards.size()) * segment_w + float(splash_cards.size() - 1) * gap
	var x := size.x * 0.5 - total_w * 0.5
	var y := size.y - 76.0
	for idx in splash_cards.size():
		var rect := Rect2(x + float(idx) * (segment_w + gap), y, segment_w, 2.0)
		var color := Color(0.78, 0.58, 0.30, 0.20)
		if idx < splash_index:
			color = Color(0.78, 0.58, 0.30, 0.72)
		elif idx == splash_index:
			color = Color(0.92, 0.74, 0.42, alpha)
		draw_rect(rect, color)

func _draw_letterbox() -> void:
	var bar_h := maxf(46.0, size.y * 0.075)
	draw_rect(Rect2(0.0, 0.0, size.x, bar_h), Color(0.0, 0.0, 0.0, 0.92))
	draw_rect(Rect2(0.0, size.y - bar_h, size.x, bar_h), Color(0.0, 0.0, 0.0, 0.92))

func _draw_thin_frame(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.035))
	draw_rect(rect, color, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(56.0, 0.0), Color(color.r, color.g, color.b, color.a * 1.8), 2.0)
	draw_line(rect.position, rect.position + Vector2(0.0, 56.0), Color(color.r, color.g, color.b, color.a * 1.8), 2.0)
	draw_line(rect.end, rect.end - Vector2(56.0, 0.0), Color(color.r, color.g, color.b, color.a * 1.8), 2.0)
	draw_line(rect.end, rect.end - Vector2(0.0, 56.0), Color(color.r, color.g, color.b, color.a * 1.8), 2.0)

func _draw_film_grain(alpha: float) -> void:
	for idx in range(90):
		var x := fposmod(float(idx * 137), maxf(size.x, 1.0))
		var y := fposmod(float(idx * 71), maxf(size.y, 1.0))
		draw_rect(Rect2(x, y, 1.0 + float(idx % 2), 1.0), Color(0.95, 0.82, 0.55, alpha * (0.4 + float(idx % 5) * 0.15)))

func _draw_cover_texture(texture: Texture2D, rect: Rect2) -> void:
	var texture_size := texture.get_size()
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

func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported_texture: Texture2D = ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image_path := path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _get_story_texture(index: int) -> Texture2D:
	if index >= 0 and index < _story_textures.size():
		return _story_textures[index]
	return _title_texture

func _get_story_content_rect() -> Rect2:
	var width := clampf(size.x - 64.0, 320.0, 900.0)
	var height := clampf(size.y - 118.0, 330.0, 430.0)
	return Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _finish() -> void:
	if _completed:
		return
	_completed = true
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()

func _splash_alpha() -> float:
	var fade_in := clampf(mode_time / 0.42, 0.0, 1.0)
	var fade_out := clampf((SPLASH_DURATION - mode_time) / 0.48, 0.0, 1.0)
	return minf(fade_in, fade_out)

func _draw_centered(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int, width: float) -> void:
	var pos := Vector2(position.x - width * 0.5, position.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline_size, Color(0.01, 0.008, 0.006, color.a * 0.95))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int, width: float) -> void:
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, Color(0.01, 0.008, 0.006, color.a * 0.95))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw_multiline(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int, width: float, line_height: float) -> void:
	var lines := _wrap_text(font, text, font_size, width)
	for index in lines.size():
		_draw_outlined_string(font, position + Vector2(0.0, float(index) * line_height), lines[index], font_size, color, outline_size, width)

func _wrap_text(font: Font, text: String, font_size: int, width: float) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	for character in text:
		var candidate := current + character
		if not current.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
			result.append(current)
			current = character
		else:
			current = candidate
	if not current.is_empty():
		result.append(current)
	return result
