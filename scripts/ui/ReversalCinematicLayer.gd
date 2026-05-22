class_name ReversalCinematicLayer
extends Control

signal finished()

const MUSIC_FADE_SECONDS := 2.8
const LINE_SECONDS := 3.0

var cinematic: Dictionary = {}
var elapsed := 0.0
var _image_texture: Texture2D
var _music_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _skip_rect := Rect2()
var _dismissed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 130
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "ReversalMusic"
	add_child(_music_player)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "ReversalVoice"
	add_child(_voice_player)
	set_process(false)

func play(new_cinematic: Dictionary) -> void:
	cinematic = new_cinematic.duplicate(true)
	elapsed = 0.0
	_dismissed = false
	_image_texture = _load_texture(str(cinematic.get("image_path", "")))
	visible = true
	set_process(true)
	_play_music()
	_play_voice_line(0)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	var lines: Array = cinematic.get("dialogue", [])
	var line_index := _line_index()
	if lines.size() > 0 and is_equal_approx(fmod(elapsed, LINE_SECONDS), 0.0):
		_play_voice_line(line_index)
	if elapsed >= _duration():
		_finish()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		_finish()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if _skip_rect.has_point(mouse_event.position) or elapsed > 1.0:
			_finish()
			accept_event()

func _draw() -> void:
	if not visible:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.005, 0.004, 0.003, 1.0))
	if _image_texture != null:
		_draw_cover_texture(_image_texture, rect)
	else:
		_draw_fallback_illustration(rect)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.18))
	_draw_letterbox()
	_draw_dark_edges()
	_draw_cinematic_text()
	_draw_progress()

func _draw_fallback_illustration(rect: Rect2) -> void:
	var id := str(cinematic.get("id", ""))
	var bg_top := Color(0.09, 0.07, 0.05, 1.0)
	var bg_bottom := Color(0.018, 0.016, 0.014, 1.0)
	draw_rect(rect, bg_bottom)
	for idx in range(12):
		var t := float(idx) / 11.0
		var band := Rect2(rect.position + Vector2(0.0, rect.size.y * t), Vector2(rect.size.x, rect.size.y / 10.0 + 1.0))
		draw_rect(band, bg_top.lerp(bg_bottom, t))
	if id == "grocer_hidden_granary":
		_draw_grocer_fallback(rect)
	else:
		_draw_generic_fallback(rect)
	_draw_film_grain(0.040)

func _draw_grocer_fallback(rect: Rect2) -> void:
	var floor_y := rect.position.y + rect.size.y * 0.73
	draw_rect(Rect2(rect.position.x, floor_y, rect.size.x, rect.size.y - floor_y), Color(0.10, 0.07, 0.045, 1.0))
	for idx in range(7):
		var sack := Rect2(rect.position + Vector2(rect.size.x * 0.10 + idx * 52.0, floor_y - 24.0 - float(idx % 2) * 16.0), Vector2(58.0, 38.0))
		draw_rect(sack, Color(0.36, 0.25, 0.13, 0.76))
		draw_rect(sack, Color(0.72, 0.56, 0.30, 0.32), false, 1.0)
	var back := Vector2(rect.size.x * 0.46, rect.size.y * 0.54)
	draw_circle(back + Vector2(0.0, -50.0), 23.0, Color(0.09, 0.065, 0.045, 1.0))
	draw_rect(Rect2(back + Vector2(-18.0, -28.0), Vector2(36.0, 82.0)), Color(0.11, 0.075, 0.045, 1.0))
	draw_line(back + Vector2(-20.0, 3.0), back + Vector2(-68.0, 56.0), Color(0.11, 0.075, 0.045, 1.0), 12.0)
	draw_line(back + Vector2(20.0, 4.0), back + Vector2(64.0, 50.0), Color(0.11, 0.075, 0.045, 1.0), 12.0)
	draw_line(back + Vector2(-10.0, 54.0), back + Vector2(-34.0, 128.0), Color(0.10, 0.07, 0.045, 1.0), 14.0)
	draw_line(back + Vector2(10.0, 54.0), back + Vector2(28.0, 128.0), Color(0.10, 0.07, 0.045, 1.0), 14.0)
	for idx in range(5):
		var x := rect.size.x * (0.70 + float(idx) * 0.045)
		var h := 88.0 - float(idx % 2) * 18.0
		var alpha := 0.18 + float(idx) * 0.055
		draw_rect(Rect2(Vector2(x, floor_y - h), Vector2(18.0, h)), Color(0.02, 0.018, 0.016, alpha))
		draw_circle(Vector2(x + 9.0, floor_y - h - 11.0), 13.0, Color(0.02, 0.018, 0.016, alpha))
	var door := Rect2(rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.18), Vector2(rect.size.x * 0.34, rect.size.y * 0.50))
	draw_rect(door, Color(0.76, 0.48, 0.19, 0.08))
	draw_rect(door, Color(0.92, 0.66, 0.28, 0.20), false, 2.0)

func _draw_generic_fallback(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(-80.0, 30.0), 96.0, Color(0.16, 0.10, 0.055, 0.82))
	draw_circle(center + Vector2(-80.0, -74.0), 30.0, Color(0.08, 0.055, 0.035, 0.96))
	for idx in range(6):
		var x := rect.size.x * (0.62 + float(idx) * 0.045)
		draw_line(Vector2(x, rect.size.y * 0.42), Vector2(x + 14.0, rect.size.y * 0.74), Color(0.02, 0.018, 0.015, 0.18 + idx * 0.04), 14.0)
	var slash_color := Color(0.88, 0.58, 0.22, 0.12)
	for idx in range(9):
		var y := rect.size.y * (0.20 + float(idx) * 0.065)
		draw_line(Vector2(rect.size.x * 0.08, y), Vector2(rect.size.x * 0.92, y + 34.0), slash_color, 1.0)

func _draw_cinematic_text() -> void:
	var font := get_theme_default_font()
	var title := str(cinematic.get("title", "人心反转"))
	var subtitle := str(cinematic.get("subtitle", ""))
	var title_pos := Vector2(52.0, maxf(74.0, size.y * 0.13))
	_draw_outlined_string(font, title_pos, title, 34, Color(0.98, 0.82, 0.46, 1.0), 7, size.x - 104.0)
	if not subtitle.is_empty():
		_draw_outlined_string(font, title_pos + Vector2(0.0, 36.0), subtitle, 15, Color(0.84, 0.74, 0.56, 0.96), 4, size.x - 104.0)
	var lines: Array = cinematic.get("dialogue", [])
	if lines.is_empty():
		return
	var line: Dictionary = lines[clampi(_line_index(), 0, lines.size() - 1)]
	var box_width := minf(size.x - 88.0, 920.0)
	var box := Rect2(Vector2((size.x - box_width) * 0.5, size.y - 172.0), Vector2(box_width, 92.0))
	draw_rect(box, Color(0.018, 0.014, 0.010, 0.82))
	draw_rect(box, Color(0.86, 0.60, 0.28, 0.50), false, 1.0)
	var speaker := str(line.get("speaker", ""))
	var text := str(line.get("text", ""))
	_draw_outlined_string(font, box.position + Vector2(18.0, 28.0), speaker, 16, Color(0.98, 0.78, 0.42, 1.0), 4, box.size.x - 36.0)
	_draw_outlined_string(font, box.position + Vector2(18.0, 62.0), text, 23, Color(0.96, 0.90, 0.74, 1.0), 5, box.size.x - 36.0)
	_skip_rect = Rect2(Vector2(size.x - 124.0, size.y - 54.0), Vector2(86.0, 30.0))
	draw_rect(_skip_rect, Color(0.08, 0.058, 0.036, 0.78))
	draw_rect(_skip_rect, Color(0.82, 0.60, 0.32, 0.44), false, 1.0)
	_draw_outlined_string(font, _skip_rect.position + Vector2(18.0, 20.0), "继续", 13, Color(0.88, 0.78, 0.58, 1.0), 3, 58.0)

func _draw_progress() -> void:
	var progress := clampf(elapsed / maxf(_duration(), 0.1), 0.0, 1.0)
	var rect := Rect2(Vector2(52.0, size.y - 38.0), Vector2(size.x - 210.0, 3.0))
	draw_rect(rect, Color(0.20, 0.15, 0.09, 0.68))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), Color(0.90, 0.64, 0.30, 0.82))

func _line_index() -> int:
	var lines: Array = cinematic.get("dialogue", [])
	if lines.is_empty():
		return 0
	return clampi(int(elapsed / LINE_SECONDS), 0, lines.size() - 1)

func _duration() -> float:
	var lines: Array = cinematic.get("dialogue", [])
	return maxf(6.8, float(maxi(lines.size(), 1)) * LINE_SECONDS + 1.4)

func _play_music() -> void:
	var music_path := str(cinematic.get("music_path", ""))
	var stream := _load_audio(music_path)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = -36.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -8.0, MUSIC_FADE_SECONDS)

func _play_voice_line(index: int) -> void:
	var lines: Array = cinematic.get("dialogue", [])
	if index < 0 or index >= lines.size():
		return
	var line: Dictionary = lines[index]
	var stream := _load_audio(str(line.get("voice_path", "")))
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.volume_db = -3.0
	_voice_player.play()

func _finish() -> void:
	if _dismissed:
		return
	_dismissed = true
	set_process(false)
	if _music_player != null:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -42.0, 0.42)
		tween.finished.connect(func() -> void:
			if _music_player != null:
				_music_player.stop()
		)
	if _voice_player != null:
		_voice_player.stop()
	visible = false
	finished.emit()

func _load_audio(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as AudioStream

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var imported_texture := ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image_path := path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(image_path):
		return null
	var image := Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

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

func _draw_letterbox() -> void:
	var bar_height := clampf(size.y * 0.095, 44.0, 92.0)
	draw_rect(Rect2(0.0, 0.0, size.x, bar_height), Color(0.0, 0.0, 0.0, 0.92))
	draw_rect(Rect2(0.0, size.y - bar_height, size.x, bar_height), Color(0.0, 0.0, 0.0, 0.92))

func _draw_dark_edges() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x * 0.18, size.y), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(size.x * 0.82, 0.0, size.x * 0.18, size.y), Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(Rect2(0.0, size.y * 0.62, size.x, size.y * 0.38), Color(0.0, 0.0, 0.0, 0.20))

func _draw_film_grain(alpha: float) -> void:
	for idx in range(180):
		var x := fmod(float(idx * 73), maxf(size.x, 1.0))
		var y := fmod(float(idx * 41), maxf(size.y, 1.0))
		draw_rect(Rect2(x, y, 1.0, 1.0), Color(1.0, 0.86, 0.55, alpha * (0.35 + float(idx % 5) * 0.12)))

func _draw_outlined_string(font: Font, position: Vector2, text: String, font_size: int, color: Color, outline_size: int = 3, width: float = -1.0) -> void:
	var outline_color := Color(0.010, 0.008, 0.006, 0.95)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, outline_size, outline_color)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
