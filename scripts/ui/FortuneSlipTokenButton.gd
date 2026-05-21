class_name FortuneSlipTokenButton
extends Button

const TOKEN_TEXTURE_PATH := "res://assets/generated/ui/fortune_slip_token_ui.jpg"

var _glow_phase: float = 0.0
var _token_texture: Texture2D

func _ready() -> void:
	flat = true
	if ResourceLoader.exists(TOKEN_TEXTURE_PATH):
		_token_texture = ResourceLoader.load(TOKEN_TEXTURE_PATH) as Texture2D
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_glow_phase = fmod(_glow_phase + delta * 2.4, TAU)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var glow := 0.5 + 0.5 * sin(_glow_phase)
	if _token_texture != null:
		draw_texture_rect(_token_texture, Rect2(Vector2.ZERO, size), false, Color(1.0 + glow * 0.08, 0.98 + glow * 0.04, 0.88 + glow * 0.05, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.52, 0.36, 0.16, 0.98), true)
	var edge := Color(1.0, 0.76 + glow * 0.18, 0.30, 0.22 + glow * 0.18)
	draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), edge, false, 1.0)
