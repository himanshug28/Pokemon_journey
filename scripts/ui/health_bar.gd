class_name HealthBar
extends Control
## Smoothly animated HP bar with an authentic layered look.

@export var max_value: float = 100.0
@export var value: float = 100.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		queue_redraw()
@export var show_numbers: bool = true
@export var compact: bool = false
@export var accent_override: Color = Color.TRANSPARENT
@export var low_hp_pulse: bool = true

var _display: float = 100.0
var _target: float = 100.0
var _flash: float = 0.0
var _time: float = 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(220, 18 if compact else 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UIKit.font_body
	_display = value
	_target = value
	set_process(true)

func set_values(current: float, maximum: float, instant: bool = false) -> void:
	max_value = maxf(1.0, maximum)
	value = current
	_target = value
	if instant:
		_display = value
	queue_redraw()

func set_ratio(ratio: float, instant: bool = false) -> void:
	max_value = 100.0
	set_values(clampf(ratio, 0.0, 1.0) * 100.0, 100.0, instant)

func flash() -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	_time += delta
	var speed := 8.0 if not compact else 12.0
	_display = lerpf(_display, _target, clampf(delta * speed, 0.0, 1.0))
	if absf(_display - _target) < 0.02:
		_display = _target
	_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()

func _draw() -> void:
	if _font == null:
		_font = UIKit.font_body
	var rect := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.05, 0.10, 0.92)
	bg.set_corner_radius_all(int(size.y * 0.5))
	bg.border_color = Color(1, 1, 1, 0.14)
	bg.set_border_width_all(1)
	draw_style_box(bg, rect)

	var inset := maxf(2.0, size.y * 0.14)
	var inner := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var ratio := clampf(_display / maxf(1.0, max_value), 0.0, 1.0)
	var color := accent_override
	if color.a <= 0.0:
		if ratio > 0.5:
			color = Color("#61dd78")
		elif ratio > 0.2:
			color = Color("#ffd44f")
		else:
			color = Color("#ff5c62")
	if low_hp_pulse and ratio <= 0.2 and ratio > 0.0:
		color = color.lerp(Color.WHITE, (sin(_time * 8.0) * 0.5 + 0.5) * 0.28)
	var fill_rect := Rect2(inner.position, Vector2(maxf(0.0, inner.size.x * ratio), inner.size.y))
	if fill_rect.size.x > 0.5:
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(int(inner.size.y * 0.5))
		draw_style_box(fill, fill_rect)
		var shine := Color(1, 1, 1, 0.28)
		draw_line(inner.position + Vector2(inner.size.y * 0.3, inner.size.y * 0.22), inner.position + Vector2(maxf(inner.size.y * 0.4, fill_rect.size.x - inner.size.y * 0.3), inner.size.y * 0.22), shine, maxf(1.0, inner.size.y * 0.12))
	# Segment ticks for an arcade feel.
	for i in range(1, 8):
		var x := inner.position.x + inner.size.x * float(i) / 8.0
		draw_line(Vector2(x, inner.position.y + 1), Vector2(x, inner.end.y - 1), Color(0, 0, 0, 0.14), 1.0)
	if _flash > 0.0:
		draw_rect(rect, Color(1, 1, 1, _flash * 0.35))
	if show_numbers:
		var label := "%d / %d" % [int(round(_display)), int(round(max_value))]
		var font_size := 10 if compact else 12
		var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(_font, Vector2(size.x - text_size.x - 8, size.y * 0.5 + font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.92))
