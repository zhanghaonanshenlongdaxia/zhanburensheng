class_name SceneIllustration
extends Control

var weather_id: String = "clear"
var phase: String = "morning"
var focus_location: String = "field"
var _generated_scene_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(0, 180)
	_generated_scene_texture = _load_texture_from_file("res://assets/generated/scenes/village_gate_dawn_v2.jpg")

func set_context(new_weather_id: String, new_phase: String, new_focus_location: String) -> void:
	weather_id = new_weather_id
	phase = new_phase
	focus_location = new_focus_location
	queue_redraw()

func _draw() -> void:
	if _generated_scene_texture != null and _should_use_generated_scene():
		_draw_generated_scene()
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, _get_backdrop_color())
	_draw_paper_grain()
	_draw_sky_bands()
	_draw_orb()
	_draw_far_ridge()
	_draw_near_ground()
	_draw_location_feature()
	_draw_weather_overlay()
	_draw_vignette()

func _load_texture_from_file(path: String) -> Texture2D:
	var imported_texture: Texture2D = load(path) as Texture2D
	if imported_texture != null:
		return imported_texture
	if not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _should_use_generated_scene() -> bool:
	return true

func _draw_generated_scene() -> void:
	var texture_size: Vector2 = _generated_scene_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color(0.035, 0.032, 0.028, 1.0))
	var scale: float = maxf(size.x / texture_size.x, size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale
	var draw_position: Vector2 = (size - draw_size) * 0.5
	draw_texture_rect(_generated_scene_texture, Rect2(draw_position, draw_size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.018, 0.015, 0.22))
	if weather_id == "rain":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.12, 0.16))
		_draw_weather_overlay()
	_draw_vignette()

func _get_backdrop_color() -> Color:
	match phase:
		"night":
			return Color(0.055, 0.058, 0.065, 1.0)
		"afternoon":
			return Color(0.17, 0.14, 0.105, 1.0)
		_:
			return Color(0.115, 0.105, 0.09, 1.0)

func _draw_paper_grain() -> void:
	for idx in range(34):
		var x_pos: float = fposmod(float(idx * 97), maxf(size.x, 1.0))
		var y_pos: float = fposmod(float(idx * 53), maxf(size.y, 1.0))
		var alpha: float = 0.035 + float(idx % 4) * 0.01
		draw_rect(Rect2(x_pos, y_pos, 1.0 + float(idx % 3), 1.0), Color(0.9, 0.74, 0.45, alpha))

func _draw_sky_bands() -> void:
	var upper: Rect2 = Rect2(0.0, 0.0, size.x, size.y * 0.45)
	var lower: Rect2 = Rect2(0.0, size.y * 0.45, size.x, size.y * 0.3)
	draw_rect(upper, Color(0.18, 0.18, 0.19, 0.75))
	draw_rect(lower, Color(0.22, 0.18, 0.13, 0.36))

func _draw_orb() -> void:
	var orb_center: Vector2 = Vector2(size.x - maxf(58.0, size.x * 0.11), size.y * 0.34)
	var orb_color: Color = Color(0.94, 0.75, 0.36, 0.92)
	if phase == "night":
		orb_color = Color(0.72, 0.78, 0.86, 0.88)
	draw_circle(orb_center, 24.0, Color(orb_color.r, orb_color.g, orb_color.b, 0.16))
	draw_circle(orb_center, 18.0, orb_color)

func _draw_far_ridge() -> void:
	var ridge: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, size.y * 0.62),
		Vector2(size.x * 0.18, size.y * 0.52),
		Vector2(size.x * 0.36, size.y * 0.63),
		Vector2(size.x * 0.56, size.y * 0.54),
		Vector2(size.x * 0.72, size.y * 0.64),
		Vector2(size.x, size.y * 0.55),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(ridge, Color(0.10, 0.12, 0.14, 0.96))

func _draw_near_ground() -> void:
	var ground: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, size.y * 0.78),
		Vector2(size.x * 0.16, size.y * 0.72),
		Vector2(size.x * 0.38, size.y * 0.82),
		Vector2(size.x * 0.58, size.y * 0.75),
		Vector2(size.x * 0.82, size.y * 0.82),
		Vector2(size.x, size.y * 0.76),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(ground, Color(0.045, 0.052, 0.06, 1.0))
	draw_line(Vector2(0, size.y * 0.78), Vector2(size.x, size.y * 0.76), Color(0.55, 0.38, 0.18, 0.25), 2.0)

func _draw_location_feature() -> void:
	match focus_location:
		"river":
			_draw_river()
		"graveyard":
			_draw_graveyard()
		"forest":
			_draw_forest()
		"mountain":
			_draw_mountain()
		_:
			_draw_field()

func _draw_field() -> void:
	var base_y: float = size.y * 0.78
	for idx in range(9):
		var x_pos: float = size.x * 0.09 + float(idx) * size.x * 0.065
		draw_line(Vector2(x_pos, base_y - 4.0), Vector2(x_pos - 10.0, base_y + 20.0), Color(0.58, 0.68, 0.34, 0.72), 2.0)
	draw_rect(Rect2(size.x * 0.06, base_y + 14.0, size.x * 0.38, 4.0), Color(0.45, 0.35, 0.18, 0.56))

func _draw_river() -> void:
	var river_points: PackedVector2Array = PackedVector2Array([
		Vector2(size.x * 0.57, size.y * 0.42),
		Vector2(size.x * 0.50, size.y * 0.58),
		Vector2(size.x * 0.60, size.y * 0.74),
		Vector2(size.x * 0.52, size.y)
	])
	draw_polyline(river_points, Color(0.34, 0.58, 0.68, 0.78), 18.0)
	draw_polyline(river_points, Color(0.74, 0.85, 0.82, 0.45), 4.0)

func _draw_graveyard() -> void:
	for idx in range(5):
		var base_x: float = size.x * 0.14 + float(idx) * 42.0
		var base_y: float = size.y * 0.79 - float(idx % 2) * 8.0
		draw_rect(Rect2(base_x, base_y - 20.0, 12.0, 22.0), Color(0.40, 0.38, 0.36, 0.92))
		draw_rect(Rect2(base_x - 6.0, base_y - 12.0, 24.0, 5.0), Color(0.40, 0.38, 0.36, 0.92))
	draw_rect(Rect2(size.x * 0.08, size.y * 0.66, size.x * 0.38, 22.0), Color(0.7, 0.63, 0.54, 0.08))

func _draw_forest() -> void:
	for idx in range(7):
		var center_x: float = size.x * 0.08 + float(idx) * 42.0
		var center_y: float = size.y * 0.82 + float(idx % 2) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(center_x, center_y - 58.0),
			Vector2(center_x - 24.0, center_y),
			Vector2(center_x + 24.0, center_y)
		]), Color(0.08, 0.19, 0.13, 0.98))
		draw_line(Vector2(center_x, center_y - 8.0), Vector2(center_x, center_y + 18.0), Color(0.22, 0.16, 0.10, 0.95), 4.0)

func _draw_mountain() -> void:
	var center_x: float = size.x * 0.22
	var base_y: float = size.y * 0.78
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 80.0, base_y),
		Vector2(center_x, size.y * 0.18),
		Vector2(center_x + 92.0, base_y)
	]), Color(0.30, 0.33, 0.35, 0.94))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 24.0, size.y * 0.42),
		Vector2(center_x, size.y * 0.18),
		Vector2(center_x + 26.0, size.y * 0.42)
	]), Color(0.86, 0.84, 0.78, 0.9))

func _draw_weather_overlay() -> void:
	match weather_id:
		"rain":
			for idx in range(18):
				var start: Vector2 = Vector2(12.0 + float(idx) * (size.x - 24.0) / 17.0, 10.0 + float(idx % 5) * 14.0)
				draw_line(start, start + Vector2(-10.0, 22.0), Color(0.54, 0.68, 0.72, 0.45), 2.0)
		"snow":
			for idx in range(20):
				var center: Vector2 = Vector2(18.0 + float(idx) * (size.x - 36.0) / 19.0, 20.0 + float(idx % 6) * 14.0)
				draw_circle(center, 2.0, Color(0.86, 0.84, 0.78, 0.7))
		_:
			for idx in range(5):
				var center: Vector2 = Vector2(size.x * 0.12 + float(idx) * size.x * 0.12, size.y * 0.35 + float(idx % 2) * 10.0)
				draw_circle(center, 16.0, Color(0.75, 0.69, 0.58, 0.09))
				draw_circle(center + Vector2(16.0, 3.0), 12.0, Color(0.75, 0.69, 0.58, 0.09))

func _draw_vignette() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, 2.0), Color(0.80, 0.56, 0.25, 0.22))
	draw_rect(Rect2(0.0, size.y - 2.0, size.x, 2.0), Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(Rect2(0.0, 0.0, 2.0, size.y), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(size.x - 2.0, 0.0, 2.0, size.y), Color(0.0, 0.0, 0.0, 0.28))
