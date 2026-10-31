class_name TypeBadge
extends Control
## Colorful, self-drawn type pill with a custom icon.

@export var poke_type: String = "normal":
	set(value):
		poke_type = value
		queue_redraw()
@export var compact: bool = false:
	set(value):
		compact = value
		queue_redraw()

var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIKit.font_body
	custom_minimum_size = Vector2(78 if compact else 92, 24 if compact else 28)
	queue_redraw()

func setup(type_name: String, is_compact: bool = false) -> TypeBadge:
	poke_type = type_name
	compact = is_compact
	return self

func _draw() -> void:
	if _font == null:
		_font = UIKit.font_body
	var rect := Rect2(Vector2.ZERO, size)
	var bg := TypeChart.type_color(poke_type)
	var dark := TypeChart.type_dark(poke_type)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(int(size.y * 0.5))
	style.border_color = Color(1, 1, 1, 0.24)
	style.set_border_width_all(1)
	style.shadow_color = Color(dark.r, dark.g, dark.b, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	draw_style_box(style, rect)
	var icon_center := Vector2(size.y * 0.52, size.y * 0.5)
	_draw_type_icon(icon_center, size.y * 0.28, dark)
	var text := poke_type.to_upper()
	var font_size := 11 if compact else 13
	var text_x := size.y * 0.88
	draw_string(_font, Vector2(text_x, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dark)

func _draw_type_icon(c: Vector2, r: float, color: Color) -> void:
	match poke_type:
		"fire":
			var flame := PackedVector2Array([
				c + Vector2(0, -r * 1.15), c + Vector2(r * 0.7, -r * 0.1),
				c + Vector2(r * 0.45, r * 0.65), c + Vector2(0, r * 0.95),
				c + Vector2(-r * 0.55, r * 0.55), c + Vector2(-r * 0.65, -r * 0.1),
				c + Vector2(-r * 0.15, -r * 0.4), c + Vector2(0, -r * 0.15),
			])
			draw_colored_polygon(flame, color)
			draw_circle(c + Vector2(0, r * 0.38), r * 0.34, Color(1, 0.8, 0.35, 0.75))
		"water":
			var drop := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.1),
				c + Vector2(r * 0.48, r * 0.72), c + Vector2(0, r * 0.9),
				c + Vector2(-r * 0.48, r * 0.72), c + Vector2(-r * 0.7, r * 0.1),
			])
			draw_colored_polygon(drop, color)
			draw_circle(c + Vector2(-r * 0.25, r * 0.2), r * 0.14, Color(1, 1, 1, 0.6))
		"grass":
			var leaf := PackedVector2Array([
				c + Vector2(-r * 0.8, r * 0.6), c + Vector2(-r * 0.25, -r * 0.8),
				c + Vector2(r * 0.8, -r * 0.65), c + Vector2(r * 0.45, r * 0.55),
			])
			draw_colored_polygon(leaf, color)
			draw_line(c + Vector2(-r * 0.55, r * 0.42), c + Vector2(r * 0.5, -r * 0.45), Color(1, 1, 1, 0.35), maxf(1, r * 0.12))
		"electric":
			var bolt := PackedVector2Array([
				c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.6, r * 0.15),
				c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.25, r),
				c + Vector2(r * 0.65, -r * 0.2), c + Vector2(r * 0.08, -r * 0.14),
			])
			draw_colored_polygon(bolt, color)
		"ghost":
			draw_circle(c + Vector2(0, -r * 0.15), r * 0.72, color)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.7, r * 0.05), c + Vector2(-r * 0.35, r * 0.9),
				c + Vector2(-r * 0.05, r * 0.2), c + Vector2(r * 0.25, r * 0.9),
				c + Vector2(r * 0.7, r * 0.05),
			]), color)
			draw_circle(c + Vector2(-r * 0.26, -r * 0.25), r * 0.12, Color(1, 1, 1, 0.85))
			draw_circle(c + Vector2(r * 0.26, -r * 0.25), r * 0.12, Color(1, 1, 1, 0.85))
		"poison":
			draw_circle(c + Vector2(-r * 0.35, r * 0.2), r * 0.46, color)
			draw_circle(c + Vector2(r * 0.35, r * 0.35), r * 0.33, color)
			draw_circle(c + Vector2(r * 0.28, -r * 0.42), r * 0.24, color)
			draw_circle(c + Vector2(-r * 0.05, r * 0.05), r * 0.1, Color(1, 1, 1, 0.55))
		"flying":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r, -r * 0.1), c + Vector2(-r * 0.15, -r * 0.55),
				c + Vector2(r, -r * 0.85), c + Vector2(r * 0.35, r * 0.15),
				c + Vector2(-r * 0.2, r * 0.45),
			]), color)
			draw_line(c + Vector2(-r * 0.7, r * 0.1), c + Vector2(r * 0.65, -r * 0.6), Color(1, 1, 1, 0.35), maxf(1, r * 0.1))
		"dark":
			draw_circle(c, r * 0.85, color)
			draw_circle(c + Vector2(r * 0.42, -r * 0.18), r * 0.72, TypeChart.type_color("dark"))
			draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.13, Color(1, 1, 1, 0.8))
		_:
			draw_circle(c, r * 0.9, color)
			draw_circle(c, r * 0.42, Color(1, 1, 1, 0.55))
