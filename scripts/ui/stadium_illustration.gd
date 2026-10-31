class_name StadiumIllustration
extends Control
## Self-contained stylized location art for menu cards and travel screens.

@export_enum("playground", "arena") var mode: String = "playground"
@export var animated: bool = true
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(animated)
	clip_contents = true

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	if mode == "arena":
		_draw_arena(w, h)
	else:
		_draw_playground(w, h)

func _gradient_rect(rect: Rect2, top: Color, bottom: Color, steps: int = 24) -> void:
	for i in steps:
		var t := float(i) / float(steps - 1)
		var y := rect.position.y + rect.size.y * float(i) / float(steps)
		var hh := rect.size.y / float(steps) + 1.0
		draw_rect(Rect2(rect.position.x, y, rect.size.x, hh), top.lerp(bottom, t))

func _draw_playground(w: float, h: float) -> void:
	_gradient_rect(Rect2(0, 0, w, h * 0.66), Color("#74c9ff"), Color("#d8f4ff"), 20)
	# Sun and clouds.
	draw_circle(Vector2(w * 0.82, h * 0.19), h * 0.085, Color(1, 0.86, 0.36, 0.95))
	draw_circle(Vector2(w * 0.82, h * 0.19), h * 0.14, Color(1, 0.9, 0.45, 0.13))
	for i in 3:
		var cx := fmod(w * (0.15 + i * 0.26) + _time * (2.0 + i) * 0.7, w + 120.0) - 60.0
		var cy := h * (0.12 + i * 0.045)
		_draw_cloud(Vector2(cx, cy), h * (0.045 + i * 0.008))
	# Distant hills.
	draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.66), Vector2(w * 0.22, h * 0.39), Vector2(w * 0.48, h * 0.66)]), Color("#4eaa68"))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.34, h * 0.66), Vector2(w * 0.66, h * 0.35), Vector2(w, h * 0.66)]), Color("#5fbd78"))
	# Ground.
	_gradient_rect(Rect2(0, h * 0.60, w, h * 0.40), Color("#68cf73"), Color("#2e8b50"), 20)
	# Winding path.
	var path := PackedVector2Array([
		Vector2(w * 0.37, h), Vector2(w * 0.63, h), Vector2(w * 0.57, h * 0.75),
		Vector2(w * 0.66, h * 0.6), Vector2(w * 0.58, h * 0.6), Vector2(w * 0.49, h * 0.75),
	])
	draw_colored_polygon(path, Color("#e8c98b"))
	# Trees.
	for i in 6:
		var tx := w * (0.06 + i * 0.17)
		var ty := h * (0.58 + (i % 2) * 0.05)
		_draw_tree(Vector2(tx, ty), h * (0.075 + (i % 3) * 0.012), Color("#2c7a47"), Color("#49a45f"))
	# Spectator stand at left.
	var stand := Rect2(w * 0.02, h * 0.47, w * 0.25, h * 0.16)
	draw_rect(stand, Color("#30496e"))
	draw_rect(Rect2(stand.position.x, stand.position.y, stand.size.x, h * 0.035), Color("#ff6a5e"))
	for row in 3:
		draw_rect(Rect2(stand.position.x + w * 0.01, stand.position.y + h * (0.05 + row * 0.035), stand.size.x - w * 0.02, h * 0.018), Color("#5576a3"))
		for col in 5:
			draw_circle(Vector2(stand.position.x + w * (0.035 + col * 0.044), stand.position.y + h * (0.045 + row * 0.035)), h * 0.011, Color("#ffd56b") if (row + col) % 2 == 0 else Color("#ff8e8e"))
	# Training targets.
	for i in 3:
		var px := w * (0.72 + i * 0.08)
		var py := h * (0.64 + (i % 2) * 0.05)
		draw_line(Vector2(px, py + h * 0.10), Vector2(px, py), Color("#7b5631"), maxf(2.0, h * 0.012))
		draw_circle(Vector2(px, py), h * 0.045, Color("#f7f9ff"))
		draw_circle(Vector2(px, py), h * 0.033, Color("#ff5c62"))
		draw_circle(Vector2(px, py), h * 0.016, Color("#f7f9ff"))
	# Flowers.
	for i in 22:
		var fx := fmod(i * 97.0 + 33.0, w)
		var fy := h * (0.68 + fmod(i * 37.0, 28.0) / 100.0)
		draw_circle(Vector2(fx, fy), maxf(1.0, h * 0.005), Color("#ffe27a") if i % 3 == 0 else Color("#ff9fc8"))

func _draw_arena(w: float, h: float) -> void:
	_gradient_rect(Rect2(0, 0, w, h), Color("#10162e"), Color("#070a16"), 20)
	# Sky beams.
	for i in 4:
		var angle := -0.7 + i * 0.45
		var origin := Vector2(w * 0.5, h * 0.22)
		var end := origin + Vector2(sin(angle), -cos(angle)) * h * 0.75
		draw_line(origin, end, Color(0.3, 0.7, 1.0, 0.055), h * 0.16)
	# Stadium bowl.
	var center := Vector2(w * 0.5, h * 0.55)
	draw_set_transform(center, 0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, w * 0.43, Color("#273456"))
	draw_circle(Vector2.ZERO, w * 0.37, Color("#1d2846"))
	draw_circle(Vector2.ZERO, w * 0.29, Color("#36527c"))
	draw_circle(Vector2.ZERO, w * 0.22, Color("#1f3552"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Roof truss.
	var truss_y := h * 0.22
	draw_rect(Rect2(w * 0.08, truss_y, w * 0.84, h * 0.035), Color("#1b2340"))
	for i in 11:
		var x := w * (0.09 + i * 0.082)
		draw_line(Vector2(x, truss_y), Vector2(x, h * 0.34), Color("#2c3b63"), maxf(1.0, h * 0.006))
		draw_circle(Vector2(x, h * 0.34), h * 0.011, Color("#ffd56b") if i % 2 == 0 else Color("#7fe3ff"))
	# Crowd tiers.
	for row in 4:
		var ry := h * (0.40 + row * 0.055)
		var rw := w * (0.68 + row * 0.075)
		draw_rect(Rect2(w * 0.5 - rw * 0.5, ry, rw, h * 0.045), Color("#18213b").lerp(Color("#2b3c66"), row / 5.0))
		for col in 15:
			var cx := w * 0.5 - rw * 0.5 + rw * (0.03 + col * 0.064)
			var bob := sin(_time * 2.0 + col * 0.9 + row) * h * 0.003
			var c := Color("#ffd56b") if (col + row) % 4 == 0 else (Color("#7fe3ff") if (col + row) % 3 == 0 else Color("#ff8c8c"))
			draw_circle(Vector2(cx, ry + h * 0.018 + bob), h * 0.0085, c)
	# Battle field.
	draw_set_transform(Vector2(w * 0.5, h * 0.76), 0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, w * 0.25, Color("#2a7a55"))
	draw_circle(Vector2.ZERO, w * 0.205, Color("#53b97c"))
	draw_arc(Vector2.ZERO, w * 0.205, 0, TAU, 48, Color(1, 1, 1, 0.3), maxf(1.0, h * 0.006))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Center Poké Ball motif.
	var c := Vector2(w * 0.5, h * 0.76)
	draw_circle(c, h * 0.07, Color(1, 1, 1, 0.75))
	draw_circle(c, h * 0.055, Color("#ff5c62"))
	draw_rect(Rect2(c.x - h * 0.055, c.y - h * 0.008, h * 0.11, h * 0.016), Color("#18203c"))
	draw_circle(c, h * 0.018, Color("#18203c"))
	draw_circle(c, h * 0.009, Color("#7fe3ff"))
	# Spotlights.
	for i in 4:
		var x := w * (0.18 + i * 0.21)
		draw_line(Vector2(x, h * 0.28), Vector2(w * 0.5 + (i - 1.5) * w * 0.06, h * 0.74), Color(0.7, 0.9, 1.0, 0.07), h * 0.08)
		draw_circle(Vector2(x, h * 0.28), h * 0.012, Color(1, 0.95, 0.75))
	# Banner.
	draw_rect(Rect2(w * 0.38, h * 0.30, w * 0.24, h * 0.055), Color("#ef3f52"))
	draw_rect(Rect2(w * 0.395, h * 0.312, w * 0.21, h * 0.031), Color("#ffd56b"))
	draw_circle(Vector2(w * 0.5, h * 0.327), h * 0.018, Color("#18203c"))

func _draw_cloud(c: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.72)
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.9, r * 0.15), r * 0.72, col)
	draw_circle(c + Vector2(-r * 0.9, r * 0.18), r * 0.65, col)
	draw_rect(Rect2(c.x - r * 1.3, c.y, r * 2.7, r * 0.72), col)

func _draw_tree(base: Vector2, r: float, dark: Color, light: Color) -> void:
	draw_rect(Rect2(base.x - r * 0.16, base.y - r * 0.5, r * 0.32, r * 1.1), Color("#7b5631"))
	draw_circle(base + Vector2(0, -r * 0.75), r * 0.95, dark)
	draw_circle(base + Vector2(-r * 0.55, -r * 0.45), r * 0.62, dark)
	draw_circle(base + Vector2(r * 0.55, -r * 0.4), r * 0.6, light)
	draw_circle(base + Vector2(r * 0.05, -r * 0.95), r * 0.55, light)
