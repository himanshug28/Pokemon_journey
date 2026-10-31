class_name PokeballIcon
extends Control
## Hand-drawn Poké Ball mark used throughout the interface.

@export var spin_speed: float = 0.0
@export var accent: Color = Color("#ff5b62")
@export var line_color: Color = Color("#17203d")
@export var shine: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	set_process(spin_speed != 0.0)

func _process(delta: float) -> void:
	if spin_speed != 0.0:
		rotation += spin_speed * delta

func _draw() -> void:
	var s := minf(size.x, size.y)
	var center := size * 0.5
	var radius := s * 0.43
	var outline := maxf(2.0, s * 0.055)
	# Shadow
	draw_circle(center + Vector2(0, s * 0.035), radius + outline, Color(0, 0, 0, 0.24))
	# Bottom shell
	draw_circle(center, radius, Color("#f7f9ff"))
	# Top shell (half circle)
	var points := PackedVector2Array()
	for i in range(0, 33):
		var angle := PI + PI * float(i) / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, accent)
	# Rim and center band
	draw_arc(center, radius, 0, TAU, 64, line_color, outline, true)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), line_color, outline, true)
	# Center button
	draw_circle(center, radius * 0.34, line_color)
	draw_circle(center, radius * 0.25, Color("#f9fbff"))
	draw_circle(center, radius * 0.115, Color("#7fe3ff"))
	if shine:
		draw_circle(center + Vector2(-radius * 0.42, -radius * 0.47), radius * 0.16, Color(1, 1, 1, 0.55))
		draw_circle(center + Vector2(-radius * 0.32, -radius * 0.57), radius * 0.07, Color(1, 1, 1, 0.4))
