class_name OptionIllustration
extends Control

var location_id: String = "field"
var risk_level: String = "low"
var reward_hint: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(88.0, 88.0)

func set_context(new_location_id: String, risk_desc: String, new_reward_hint: String = "") -> void:
	location_id = new_location_id
	reward_hint = new_reward_hint
	risk_level = _resolve_risk_level(risk_desc)
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.07, 0.055, 0.25))
	_draw_seal()
	_draw_location_symbol()
	_draw_reward_mark()

func _resolve_risk_level(risk_desc: String) -> String:
	if risk_desc.contains("高风险"):
		return "high"
	if risk_desc.contains("中风险"):
		return "mid"
	return "low"

func _seal_color() -> Color:
	match risk_level:
		"high":
			return Color(0.72, 0.30, 0.22, 0.95)
		"mid":
			return Color(0.78, 0.55, 0.25, 0.95)
		_:
			return Color(0.44, 0.65, 0.42, 0.95)

func _draw_seal() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	var seal_color: Color = _seal_color()
	draw_circle(center, radius, Color(0.09, 0.08, 0.07, 0.96))
	draw_arc(center, radius, 0.0, TAU, 32, seal_color, 3.0)
	draw_arc(center, radius - 7.0, 0.0, TAU, 32, Color(seal_color.r, seal_color.g, seal_color.b, 0.28), 1.0)

func _draw_location_symbol() -> void:
	match location_id:
		"river":
			_draw_river_symbol()
		"graveyard":
			_draw_grave_symbol()
		"forest":
			_draw_tree_symbol()
		"mountain":
			_draw_mountain_symbol()
		_:
			_draw_field_symbol()

func _draw_field_symbol() -> void:
	var center: Vector2 = size * 0.5
	draw_rect(Rect2(center.x - 20.0, center.y + 12.0, 40.0, 7.0), Color(0.48, 0.58, 0.30, 1.0))
	for idx in range(3):
		var x_pos: float = center.x - 14.0 + float(idx) * 14.0
		draw_line(Vector2(x_pos, center.y - 17.0), Vector2(x_pos - 4.0, center.y + 11.0), Color(0.68, 0.80, 0.38, 0.9), 2.0)

func _draw_river_symbol() -> void:
	var center: Vector2 = size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(4.0, -30.0),
		center + Vector2(-8.0, -10.0),
		center + Vector2(8.0, 8.0),
		center + Vector2(-4.0, 30.0)
	])
	draw_polyline(points, Color(0.45, 0.72, 0.78, 0.95), 8.0)
	draw_polyline(points, Color(0.78, 0.86, 0.82, 0.65), 2.0)

func _draw_grave_symbol() -> void:
	var center: Vector2 = size * 0.5
	draw_rect(Rect2(center.x - 8.0, center.y - 18.0, 16.0, 30.0), Color(0.67, 0.64, 0.57, 1.0))
	draw_rect(Rect2(center.x - 15.0, center.y - 7.0, 30.0, 6.0), Color(0.67, 0.64, 0.57, 1.0))

func _draw_tree_symbol() -> void:
	var center: Vector2 = size * 0.5
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -28.0),
		center + Vector2(-24.0, 16.0),
		center + Vector2(24.0, 16.0)
	]), Color(0.26, 0.50, 0.30, 1.0))
	draw_rect(Rect2(center.x - 4.0, center.y + 14.0, 8.0, 18.0), Color(0.37, 0.25, 0.15, 1.0))

func _draw_mountain_symbol() -> void:
	var center: Vector2 = size * 0.5
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-26.0, 26.0),
		center + Vector2(0.0, -30.0),
		center + Vector2(28.0, 26.0)
	]), Color(0.52, 0.53, 0.49, 1.0))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-9.0, -10.0),
		center + Vector2(0.0, -30.0),
		center + Vector2(10.0, -10.0)
	]), Color(0.86, 0.82, 0.72, 0.95))

func _draw_reward_mark() -> void:
	var mark_pos: Vector2 = size * 0.5 + Vector2(22.0, 22.0)
	if reward_hint.contains("铜钱"):
		draw_circle(mark_pos, 7.0, Color(0.84, 0.62, 0.28, 0.95))
		draw_circle(mark_pos, 3.0, Color(0.28, 0.18, 0.08, 0.95))
	elif reward_hint.contains("药草"):
		draw_line(mark_pos + Vector2(-4.0, 4.0), mark_pos + Vector2(3.0, -8.0), Color(0.60, 0.72, 0.38, 1.0), 2.0)
		draw_circle(mark_pos + Vector2(-5.0, 1.0), 4.0, Color(0.44, 0.64, 0.32, 0.9))
		draw_circle(mark_pos + Vector2(4.0, -6.0), 4.0, Color(0.44, 0.64, 0.32, 0.9))
	elif reward_hint.contains("肉"):
		draw_circle(mark_pos, 7.0, Color(0.72, 0.36, 0.30, 0.95))
		draw_circle(mark_pos + Vector2(6.0, -5.0), 3.8, Color(0.86, 0.78, 0.64, 0.95))
