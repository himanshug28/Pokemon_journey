class_name PokemonSilhouette
extends Control
## Stylized 2D silhouettes for the loading screen and locked collection cards.

@export var pokemon_id: String = "pikachu":
	set(value):
		pokemon_id = value
		queue_redraw()
@export var glow_color: Color = Color(0.4, 0.8, 1.0, 0.2)
@export var float_speed: float = 1.0

var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	custom_minimum_size = Vector2(120, 120)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y) / 200.0
	if s <= 0.0:
		return
	var bob := sin(_time * float_speed + float(pokemon_id.length())) * 3.0
	var origin := Vector2(size.x * 0.5, size.y * 0.52 + bob)
	draw_circle(origin + Vector2(0, 10 * s), 80.0 * s, glow_color)
	draw_set_transform(origin, 0, Vector2(s, s))
	var fill := Color(0.025, 0.035, 0.09, 0.96)
	var rim := Color(glow_color.r, glow_color.g, glow_color.b, 0.55)
	match pokemon_id:
		"charizard": _charizard(fill, rim)
		"bulbasaur": _bulbasaur(fill, rim)
		"gengar": _gengar(fill, rim)
		"pikachu": _pikachu(fill, rim)
		"squirtle": _squirtle(fill, rim)
		_: _pikachu(fill, rim)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _charizard(fill: Color, rim: Color) -> void:
	# Wings
	_poly([Vector2(-10, -22), Vector2(-92, -92), Vector2(-78, -22), Vector2(-100, 8), Vector2(-18, 16)], fill)
	_poly([Vector2(10, -22), Vector2(92, -92), Vector2(78, -22), Vector2(100, 8), Vector2(18, 16)], fill)
	draw_polyline(PackedVector2Array([Vector2(-10, -22), Vector2(-92, -92), Vector2(-78, -22), Vector2(-100, 8), Vector2(-18, 16)]), rim, 2.0)
	draw_polyline(PackedVector2Array([Vector2(10, -22), Vector2(92, -92), Vector2(78, -22), Vector2(100, 8), Vector2(18, 16)]), rim, 2.0)
	# Tail and flame
	_poly([Vector2(10, 34), Vector2(68, 58), Vector2(55, 76), Vector2(26, 54)], fill)
	_poly([Vector2(65, 64), Vector2(78, 88), Vector2(64, 82), Vector2(74, 105), Vector2(48, 90), Vector2(54, 72)], Color(1, 0.55, 0.18, 0.9))
	# Body / neck / head
	draw_circle(Vector2(0, 12), 35, fill)
	_poly([Vector2(-14, -4), Vector2(-8, -52), Vector2(14, -56), Vector2(20, -4)], fill)
	draw_circle(Vector2(5, -60), 25, fill)
	_poly([Vector2(20, -66), Vector2(45, -58), Vector2(30, -44)], fill)
	_poly([Vector2(-6, -80), Vector2(4, -100), Vector2(14, -76)], fill)
	# Legs / arms
	draw_circle(Vector2(-18, 45), 14, fill)
	draw_circle(Vector2(18, 45), 14, fill)
	_poly([Vector2(-24, 2), Vector2(-46, 24), Vector2(-36, 30), Vector2(-16, 16)], fill)
	_poly([Vector2(26, 2), Vector2(48, 24), Vector2(38, 30), Vector2(18, 16)], fill)
	draw_arc(Vector2(5, -60), 25, 3.6, 5.4, 12, rim, 2.0)

func _bulbasaur(fill: Color, rim: Color) -> void:
	draw_circle(Vector2(0, 32), 46, fill)
	draw_circle(Vector2(0, -18), 34, fill)
	_poly([Vector2(-30, -38), Vector2(-58, -58), Vector2(-36, -18)], fill)
	_poly([Vector2(30, -38), Vector2(58, -58), Vector2(36, -18)], fill)
	# Legs
	for p in [Vector2(-30, 62), Vector2(-10, 68), Vector2(16, 68), Vector2(34, 60)]:
		draw_circle(p, 13, fill)
	# Bulb
	draw_circle(Vector2(0, 2), 35, fill)
	_poly([Vector2(-34, -4), Vector2(-16, -42), Vector2(-2, -8)], fill)
	_poly([Vector2(34, -4), Vector2(16, -42), Vector2(2, -8)], fill)
	_poly([Vector2(-8, -22), Vector2(0, -58), Vector2(10, -20)], fill)
	draw_arc(Vector2(0, -18), 34, 3.3, 6.1, 14, rim, 2.0)
	draw_arc(Vector2(0, 2), 35, 0.0, 3.14, 12, rim, 2.0)

func _gengar(fill: Color, rim: Color) -> void:
	# Spiky round body
	_poly([Vector2(-55, 20), Vector2(-72, 0), Vector2(-54, -6), Vector2(-62, -26), Vector2(-42, -22), Vector2(-38, -48), Vector2(-18, -38), Vector2(0, -56), Vector2(18, -38), Vector2(38, -48), Vector2(42, -22), Vector2(62, -26), Vector2(54, -6), Vector2(72, 0), Vector2(55, 20), Vector2(58, 52), Vector2(30, 42), Vector2(0, 56), Vector2(-30, 42), Vector2(-58, 52)], fill)
	draw_circle(Vector2(0, -5), 50, fill)
	# Ears
	_poly([Vector2(-40, -36), Vector2(-62, -66), Vector2(-22, -46)], fill)
	_poly([Vector2(40, -36), Vector2(62, -66), Vector2(22, -46)], fill)
	# Arms and legs
	_poly([Vector2(-50, 0), Vector2(-82, 22), Vector2(-74, 34), Vector2(-46, 18)], fill)
	_poly([Vector2(50, 0), Vector2(82, 22), Vector2(74, 34), Vector2(46, 18)], fill)
	draw_circle(Vector2(-30, 52), 16, fill)
	draw_circle(Vector2(30, 52), 16, fill)
	draw_arc(Vector2(0, -5), 50, 3.5, 6.0, 12, rim, 2.0)

func _pikachu(fill: Color, rim: Color) -> void:
	# Tail
	_poly([Vector2(34, 12), Vector2(70, -10), Vector2(58, -24), Vector2(82, -46), Vector2(66, -52), Vector2(88, -78), Vector2(48, -54), Vector2(56, -42), Vector2(38, -30)], fill)
	# Body / head
	draw_circle(Vector2(0, 28), 34, fill)
	draw_circle(Vector2(0, -20), 38, fill)
	# Ears
	_poly([Vector2(-30, -44), Vector2(-48, -104), Vector2(-10, -50)], fill)
	_poly([Vector2(30, -44), Vector2(48, -104), Vector2(10, -50)], fill)
	# Feet / arms
	draw_circle(Vector2(-22, 58), 12, fill)
	draw_circle(Vector2(22, 58), 12, fill)
	_poly([Vector2(-30, 20), Vector2(-48, 40), Vector2(-38, 46), Vector2(-22, 30)], fill)
	_poly([Vector2(30, 20), Vector2(48, 40), Vector2(38, 46), Vector2(22, 30)], fill)
	draw_arc(Vector2(0, -20), 38, 3.5, 5.9, 12, rim, 2.0)
	# Cheek circles hinted in rim
	draw_circle(Vector2(-24, -10), 8, Color(rim.r, rim.g, rim.b, 0.22))
	draw_circle(Vector2(24, -10), 8, Color(rim.r, rim.g, rim.b, 0.22))

func _squirtle(fill: Color, rim: Color) -> void:
	# Shell
	draw_circle(Vector2(0, 22), 45, fill)
	draw_circle(Vector2(0, 22), 32, Color(fill.r, fill.g, fill.b, 1.0))
	draw_arc(Vector2(0, 22), 38, 0, TAU, 32, rim, 2.0)
	# Head
	draw_circle(Vector2(0, -30), 32, fill)
	# Arms / legs
	draw_circle(Vector2(-38, 20), 13, fill)
	draw_circle(Vector2(38, 20), 13, fill)
	draw_circle(Vector2(-24, 60), 14, fill)
	draw_circle(Vector2(24, 60), 14, fill)
	# Tail curl
	_poly([Vector2(30, 34), Vector2(62, 22), Vector2(68, 38), Vector2(46, 44)], fill)
	draw_arc(Vector2(0, -30), 32, 3.4, 6.0, 12, rim, 2.0)
