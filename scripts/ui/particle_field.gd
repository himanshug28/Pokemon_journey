class_name ParticleField
extends Control
## Lightweight drifting motes for menus and loading screens.

@export var particle_count: int = 46
@export var colors: Array[Color] = [Color(1.0, 0.9, 0.45, 0.7), Color(0.55, 0.9, 1.0, 0.55), Color(1.0, 0.6, 0.4, 0.45)]
@export var speed_scale: float = 1.0
@export var glow: bool = true

var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_rng.seed = 90210
	_spawn_particles()
	resized.connect(_spawn_particles)

func _spawn_particles() -> void:
	_particles.clear()
	var area := size
	if area.x < 2.0 or area.y < 2.0:
		area = Vector2(1600, 900)
	for i in particle_count:
		var p := {
			"pos": Vector2(_rng.randf_range(0, area.x), _rng.randf_range(0, area.y)),
			"radius": _rng.randf_range(0.8, 3.4),
			"speed": _rng.randf_range(4.0, 20.0) * speed_scale,
			"drift": _rng.randf_range(-9.0, 9.0) * speed_scale,
			"phase": _rng.randf_range(0, TAU),
			"pulse": _rng.randf_range(0.6, 2.0),
			"color": colors[_rng.randi_range(0, colors.size() - 1)],
			"alpha": _rng.randf_range(0.25, 0.9),
		}
		_particles.append(p)

func _process(delta: float) -> void:
	_time += delta
	if size.x < 2.0 or size.y < 2.0:
		return
	for p in _particles:
		p.pos.y -= p.speed * delta
		p.pos.x += (p.drift + sin(_time * 0.5 + p.phase) * 6.0) * delta
		if p.pos.y < -12.0:
			p.pos.y = size.y + 12.0
			p.pos.x = _rng.randf_range(0, size.x)
		if p.pos.x < -12.0:
			p.pos.x = size.x + 12.0
		elif p.pos.x > size.x + 12.0:
			p.pos.x = -12.0
	queue_redraw()

func _draw() -> void:
	for p in _particles:
		var pulse := 0.65 + 0.35 * sin(_time * p.pulse + p.phase)
		var col: Color = p.color
		col.a *= p.alpha * pulse
		var pos: Vector2 = p.pos
		var radius: float = p.radius
		if glow:
			var halo := col
			halo.a *= 0.16
			draw_circle(pos, radius * 4.0, halo)
			halo.a *= 0.5
			draw_circle(pos, radius * 2.1, halo)
		draw_circle(pos, radius, col)
		draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.36, Color(1, 1, 1, col.a * 0.75))
