class_name FortuneChoiceEffectLayer
extends Control

var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_rng.randomize()

func emit_dissolve(global_rect: Rect2, tint: Color = Color(0.78, 0.64, 0.42, 1.0)) -> void:
	var local_pos := get_global_transform().affine_inverse() * global_rect.position
	var rect := Rect2(local_pos, global_rect.size)
	for i in 36:
		var side_bias := _rng.randf_range(0.55, 1.0)
		var pos := rect.position + Vector2(
			_rng.randf_range(rect.size.x * 0.10, rect.size.x * 0.94),
			_rng.randf_range(rect.size.y * 0.16, rect.size.y * 0.88)
		)
		var velocity := Vector2(_rng.randf_range(20.0, 86.0) * side_bias, _rng.randf_range(-42.0, 34.0))
		_particles.append({
			"pos": pos,
			"vel": velocity,
			"life": _rng.randf_range(0.55, 0.95),
			"max_life": _rng.randf_range(0.55, 0.95),
			"size": _rng.randf_range(1.5, 4.2),
			"color": Color(tint.r, tint.g, tint.b, _rng.randf_range(0.46, 0.82))
		})
	set_process(true)
	queue_redraw()

func emit_confirm_sparks(global_rect: Rect2) -> void:
	var local_pos := get_global_transform().affine_inverse() * global_rect.position
	var rect := Rect2(local_pos, global_rect.size)
	var center := rect.get_center()
	for i in 28:
		var angle := _rng.randf_range(-PI, PI)
		var speed := _rng.randf_range(26.0, 118.0)
		_particles.append({
			"pos": center + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-18.0, 18.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": _rng.randf_range(0.35, 0.70),
			"max_life": _rng.randf_range(0.35, 0.70),
			"size": _rng.randf_range(1.8, 5.0),
			"color": Color(0.96, 0.76, 0.36, _rng.randf_range(0.55, 0.95))
		})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle["life"] = float(particle.get("life", 0.0)) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(index)
			continue
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		vel.y += 42.0 * delta
		particle["vel"] = vel * 0.985
		particle["pos"] = (particle.get("pos", Vector2.ZERO) as Vector2) + vel * delta
		_particles[index] = particle
	if _particles.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for particle in _particles:
		var life := float(particle.get("life", 0.0))
		var max_life := maxf(float(particle.get("max_life", 1.0)), 0.001)
		var ratio := clampf(life / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color.WHITE)
		color.a *= ratio
		draw_circle(particle.get("pos", Vector2.ZERO), float(particle.get("size", 2.0)) * (0.7 + ratio * 0.6), color)
