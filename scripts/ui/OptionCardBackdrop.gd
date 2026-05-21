class_name OptionCardBackdrop
extends Control

var location_id: String = "field"
var risk_level: String = "low"
var min_left_inset: float = 220.0
var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_textures()

func set_context(new_location_id: String, risk_desc: String) -> void:
	location_id = new_location_id
	risk_level = _resolve_risk_level(risk_desc)
	queue_redraw()

func set_layout_inset(value: float) -> void:
	min_left_inset = value
	queue_redraw()

func _draw() -> void:
	var texture: Texture2D = _textures.get(location_id, null) as Texture2D
	if texture == null:
		texture = _textures.get("field", null) as Texture2D
	if texture == null or size.x <= 1.0 or size.y <= 1.0:
		return

	var start_x: float = maxf(min_left_inset, size.x * 0.36)
	var rect := Rect2(
		Vector2(start_x, 7.0),
		Vector2(maxf(size.x - start_x - 10.0, 0.0), maxf(size.y - 14.0, 0.0))
	)
	if rect.size.x <= 8.0 or rect.size.y <= 8.0:
		return

	_draw_cover_texture(texture, rect)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.26))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.24)), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.70), Vector2(rect.size.x, rect.size.y * 0.30)), Color(0.0, 0.0, 0.0, 0.28))
	for idx in range(9):
		var alpha := lerpf(0.62, 0.0, float(idx) / 8.0)
		draw_rect(Rect2(rect.position + Vector2(float(idx) * 10.0, 0.0), Vector2(10.0, rect.size.y)), Color(0.0, 0.0, 0.0, alpha))
	var edge_color := _risk_color()
	draw_rect(rect, Color(edge_color.r, edge_color.g, edge_color.b, 0.42), false, 1.0)

func _load_textures() -> void:
	for id in ["field", "mountain", "river", "graveyard", "forest"]:
		_textures[id] = _load_texture_from_file("res://assets/generated/ui/options/%s_banner.jpg" % id)

func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported_texture: Texture2D = ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image_path: String = path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
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

func _resolve_risk_level(risk_desc: String) -> String:
	if risk_desc.contains("高风险"):
		return "high"
	if risk_desc.contains("中风险"):
		return "mid"
	return "low"

func _risk_color() -> Color:
	match risk_level:
		"high":
			return Color(0.72, 0.30, 0.22, 1.0)
		"mid":
			return Color(0.78, 0.55, 0.25, 1.0)
		_:
			return Color(0.44, 0.65, 0.42, 1.0)
