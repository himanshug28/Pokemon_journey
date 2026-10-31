extends Node
## Shared visual language: fonts, theme, reusable widgets, backgrounds and toasts.

const HEADING_FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/Nunito-Variable.ttf"
const BG_SHADER_PATH := "res://shaders/ui_background.gdshader"

const INK := Color("#151b30")
const PAPER := Color("#f8fbff")
const MUTED := Color("#a9b7d6")
const GOLD := Color("#ffd05a")
const ORANGE := Color("#ff9a3d")
const CYAN := Color("#78e2ff")
const MINT := Color("#66e3a4")
const RED := Color("#ff5c67")
const PURPLE := Color("#b28bff")

var font_heading: Font
var font_body: Font
var font_bold: Font
var theme: Theme
var _toast_layer: CanvasLayer
var _toast_box: VBoxContainer

func _ready() -> void:
	font_heading = _load_font(HEADING_FONT_PATH)
	font_body = _load_font(BODY_FONT_PATH)
	font_bold = _make_bold_font(font_body)
	_build_theme()
	_build_toast_layer()

func _load_font(path: String) -> Font:
	var res = load(path)
	if res is Font:
		return res
	return ThemeDB.fallback_font

func _make_bold_font(base: Font) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {0x77676874: 700.0}
	variation.variation_embolden = 0.18
	return variation

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 18

	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.28))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_constant("shadow_outline_size", "Label", 1)

	theme.set_color("default_color", "RichTextLabel", PAPER)
	theme.set_font("normal_font", "RichTextLabel", font_body)
	theme.set_font("bold_font", "RichTextLabel", font_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 18)
	theme.set_font_size("bold_font_size", "RichTextLabel", 18)

	# Panels
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_stylebox("panel", "PopupPanel", panel_style(Color(0.04, 0.06, 0.13, 0.98), Color(0.45, 0.8, 1.0, 0.28)))

	# Buttons
	theme.set_font("font", "Button", font_bold)
	theme.set_font_size("font_size", "Button", 19)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color("#fff5c9"))
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", Color(0.65, 0.7, 0.82, 0.45))
	theme.set_color("icon_normal_color", "Button", Color(1, 1, 1, 0.9))
	theme.set_color("icon_hover_color", "Button", GOLD)
	theme.set_color("icon_pressed_color", "Button", INK)
	theme.set_color("icon_focus_color", "Button", PAPER)
	theme.set_constant("icon_max_width", "Button", 24)
	theme.set_constant("h_separation", "Button", 12)
	var normal := style_box(Color(0.07, 0.11, 0.22, 0.86), Color(1, 1, 1, 0.10), 14, 1, 18, 12)
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	var hover := style_box(Color(0.13, 0.21, 0.38, 0.96), Color(0.55, 0.87, 1.0, 0.7), 14, 2, 18, 12)
	hover.shadow_color = Color(0.2, 0.65, 1.0, 0.18)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 3)
	var pressed := style_box(Color(0.85, 0.62, 0.2, 0.96), Color(1, 0.9, 0.55, 0.9), 14, 2, 18, 12)
	var focus := style_box(Color(0, 0, 0, 0), Color(0.55, 0.9, 1.0, 0.95), 14, 2, 18, 12)
	var disabled := style_box(Color(0.07, 0.09, 0.15, 0.6), Color(1, 1, 1, 0.05), 14, 1, 18, 12)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("disabled", "Button", disabled)

	# Sliders
	theme.set_stylebox("slider", "HSlider", style_box(Color(0.04, 0.07, 0.14, 0.9), Color(1, 1, 1, 0.08), 6, 1, 0, 0))
	var grabber := style_box(Color(0.45, 0.9, 1.0, 0.95), Color(1, 1, 1, 0.55), 8, 2, 0, 0)
	theme.set_stylebox("grabber_area", "HSlider", grabber)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	theme.set_icon("grabber", "HSlider", _circle_icon(18, Color("#f8fbff")))
	theme.set_icon("grabber_highlight", "HSlider", _circle_icon(20, Color("#ffd05a")))

	# Check button
	theme.set_font("font", "CheckButton", font_bold)
	theme.set_color("font_color", "CheckButton", PAPER)
	theme.set_color("font_pressed_color", "CheckButton", GOLD)
	theme.set_stylebox("normal", "CheckButton", style_box(Color(0.07, 0.11, 0.22, 0.7), Color(1, 1, 1, 0.1), 12, 1, 14, 8))
	theme.set_stylebox("hover", "CheckButton", style_box(Color(0.12, 0.2, 0.36, 0.9), Color(0.55, 0.9, 1.0, 0.55), 12, 1, 14, 8))
	theme.set_stylebox("pressed", "CheckButton", style_box(Color(0.12, 0.2, 0.36, 0.9), Color(0.55, 0.9, 1.0, 0.55), 12, 1, 14, 8))
	theme.set_stylebox("focus", "CheckButton", focus)

	# Line edit
	theme.set_stylebox("normal", "LineEdit", style_box(Color(0.04, 0.07, 0.14, 0.95), Color(1, 1, 1, 0.15), 12, 1, 14, 10))
	theme.set_stylebox("focus", "LineEdit", style_box(Color(0.06, 0.1, 0.2, 1), Color(0.55, 0.9, 1.0, 0.85), 12, 2, 14, 10))
	theme.set_color("font_color", "LineEdit", PAPER)
	theme.set_color("caret_color", "LineEdit", CYAN)
	theme.set_font("font", "LineEdit", font_body)
	theme.set_font_size("font_size", "LineEdit", 18)

	# Progress bar
	theme.set_stylebox("background", "ProgressBar", style_box(Color(0.03, 0.05, 0.1, 0.9), Color(1, 1, 1, 0.08), 8, 1, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", style_box(CYAN, Color(1, 1, 1, 0.2), 8, 0, 0, 0))
	theme.set_color("font_color", "ProgressBar", PAPER)
	theme.set_font("font", "ProgressBar", font_bold)

	# Tooltips and scroll
	theme.set_stylebox("panel", "TooltipPanel", style_box(Color(0.03, 0.05, 0.1, 0.98), Color(0.55, 0.9, 1.0, 0.4), 10, 1, 10, 8))
	theme.set_color("font_color", "TooltipLabel", PAPER)
	theme.set_font("font", "TooltipLabel", font_body)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

func style_box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 16, border_width: int = 1, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	box.anti_aliasing = true
	return box

func panel_style(bg: Color = Color(0.045, 0.07, 0.15, 0.88), border: Color = Color(1, 1, 1, 0.10), radius: int = 20) -> StyleBoxFlat:
	var box := style_box(bg, border, radius, 1, 22, 18)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	return box

# ------------------------------------------------------------------ widgets

func title(text: String, size: int = 64, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font_heading)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.09, 0.9))
	label.add_theme_constant_override("outline_size", maxi(2, int(size * 0.09)))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", maxi(2, int(size * 0.045)))
	return label

func label(text: String, size: int = 18, color: Color = PAPER, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func small(text: String, color: Color = MUTED) -> Label:
	var l := label(text, 14, color)
	l.add_theme_font_override("font", font_body)
	return l

func button(text: String, variant: String = "glass", icon_path: String = "", height: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icon_path != "":
		var icon = load(icon_path)
		if icon is Texture2D:
			b.icon = icon
	_apply_button_variant(b, variant)
	b.pressed.connect(func(): AudioManager.play_sfx("click"))
	b.mouse_entered.connect(func(): AudioManager.play_sfx("hover"))
	return b

func _apply_button_variant(b: Button, variant: String) -> void:
	var normal_bg := Color(0.07, 0.11, 0.22, 0.86)
	var hover_bg := Color(0.13, 0.21, 0.38, 0.96)
	var pressed_bg := Color(0.85, 0.62, 0.2, 0.96)
	var border := Color(1, 1, 1, 0.10)
	var hover_border := Color(0.55, 0.87, 1.0, 0.7)
	var text_color := PAPER
	var hover_text := Color("#fff5c9")
	var pressed_text := INK
	var radius := 14
	var border_w := 1
	match variant:
		"primary":
			normal_bg = Color("#ffb23b")
			hover_bg = Color("#ffc95f")
			pressed_bg = Color("#e8901e")
			border = Color(1, 0.94, 0.7, 0.8)
			hover_border = Color(1, 1, 1, 0.95)
			text_color = INK
			hover_text = INK
			pressed_text = INK
			radius = 16
			border_w = 2
		"success":
			normal_bg = Color("#2da96b")
			hover_bg = Color("#43c985")
			pressed_bg = Color("#1d7e50")
			border = Color(0.55, 1.0, 0.75, 0.5)
			hover_border = Color(0.75, 1.0, 0.85, 0.9)
			text_color = Color("#f4fff9")
			pressed_text = Color("#082417")
		"danger":
			normal_bg = Color("#c8384c")
			hover_bg = Color("#ef4c62")
			pressed_bg = Color("#8f1f33")
			border = Color(1, 0.65, 0.7, 0.5)
			hover_border = Color(1, 0.8, 0.82, 0.9)
		"rocket":
			normal_bg = Color(0.09, 0.04, 0.07, 0.95)
			hover_bg = Color(0.25, 0.05, 0.1, 0.98)
			pressed_bg = Color(0.55, 0.08, 0.16, 1)
			border = Color(0.9, 0.2, 0.3, 0.55)
			hover_border = Color(1, 0.45, 0.5, 0.95)
		"ghost":
			normal_bg = Color(1, 1, 1, 0.02)
			hover_bg = Color(1, 1, 1, 0.09)
			pressed_bg = Color(1, 1, 1, 0.16)
			border = Color(1, 1, 1, 0.0)
			hover_border = Color(1, 1, 1, 0.18)
			text_color = Color(0.82, 0.88, 1.0, 0.92)
			pressed_text = PAPER
		"nav":
			normal_bg = Color(0.06, 0.10, 0.2, 0.72)
			hover_bg = Color(0.14, 0.23, 0.41, 0.94)
			pressed_bg = Color(0.23, 0.35, 0.56, 0.98)
			border = Color(1, 1, 1, 0.07)
			hover_border = Color(0.55, 0.9, 1.0, 0.6)
			radius = 13
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_constant_override("h_separation", 16)
		"small":
			radius = 10
			b.add_theme_font_size_override("font_size", 15)
			b.custom_minimum_size = Vector2(0, 38)
	var normal := style_box(normal_bg, border, radius, border_w, 18, 10)
	normal.shadow_color = Color(0, 0, 0, 0.28)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	var hover := style_box(hover_bg, hover_border, radius, maxi(border_w, 2), 18, 10)
	hover.shadow_color = Color(0.25, 0.7, 1.0, 0.18)
	hover.shadow_size = 12
	hover.shadow_offset = Vector2(0, 4)
	var pressed := style_box(pressed_bg, hover_border, radius, 2, 18, 10)
	var focus := style_box(Color(0, 0, 0, 0), Color(0.55, 0.92, 1.0, 0.95), radius, 2, 18, 10)
	var disabled := style_box(Color(0.06, 0.08, 0.14, 0.6), Color(1, 1, 1, 0.05), radius, 1, 18, 10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", hover_text)
	b.add_theme_color_override("font_pressed_color", pressed_text)
	b.add_theme_color_override("font_focus_color", text_color)
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.7, 0.82, 0.4))
	b.add_theme_color_override("icon_normal_color", text_color)
	b.add_theme_color_override("icon_hover_color", hover_text)
	b.add_theme_color_override("icon_pressed_color", pressed_text)

func panel(bg: Color = Color(0.045, 0.07, 0.15, 0.88), border: Color = Color(1, 1, 1, 0.10), radius: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border, radius))
	return p

func card(bg: Color = Color(0.05, 0.08, 0.17, 0.9), border: Color = Color(1, 1, 1, 0.1)) -> PanelContainer:
	var p := panel(bg, border, 18)
	return p

func margin(inner: Control, amount: int = 20) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", amount)
	m.add_theme_constant_override("margin_right", amount)
	m.add_theme_constant_override("margin_top", amount)
	m.add_theme_constant_override("margin_bottom", amount)
	m.add_child(inner)
	return m

func vbox(separation: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box

func hbox(separation: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box

func spacer(height: float, width: float = 0.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(width, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

func separator(color: Color = Color(1, 1, 1, 0.1), height: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func type_badge(type_name: String, compact: bool = false) -> TypeBadge:
	var badge := TypeBadge.new()
	badge.setup(type_name, compact)
	return badge

func health_bar(current: float, maximum: float, compact: bool = false, numbers: bool = true) -> HealthBar:
	var bar := HealthBar.new()
	bar.compact = compact
	bar.show_numbers = numbers
	bar.set_values(current, maximum, true)
	return bar

func pokeball(size_px: float = 64, spin: float = 0.0, accent: Color = Color("#ff5b62")) -> PokeballIcon:
	var ball := PokeballIcon.new()
	ball.custom_minimum_size = Vector2(size_px, size_px)
	ball.spin_speed = spin
	ball.accent = accent
	return ball

func particle_field(count: int = 46, speed: float = 1.0) -> ParticleField:
	var field := ParticleField.new()
	field.particle_count = count
	field.speed_scale = speed
	return field

func silhouette(id: String, glow: Color = Color(0.4, 0.8, 1.0, 0.22)) -> PokemonSilhouette:
	var s := PokemonSilhouette.new()
	s.pokemon_id = id
	s.glow_color = glow
	return s

func stadium_art(mode: String) -> StadiumIllustration:
	var art := StadiumIllustration.new()
	art.mode = mode
	return art

func background(kind: String = "menu") -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader = load(BG_SHADER_PATH)
	if shader is Shader:
		mat.shader = shader
	rect.material = mat
	var palette := {
		"top_color": Color("#0b1c45"),
		"bottom_color": Color("#03050d"),
		"accent_a": Color("#1ec8ff"),
		"accent_b": Color("#ff8a3d"),
		"accent_c": Color("#8c5cff"),
		"glow_strength": 0.8,
		"star_strength": 0.65,
	}
	match kind:
		"loading":
			palette["top_color"] = Color("#081d42")
			palette["bottom_color"] = Color("#02040a")
			palette["accent_a"] = Color("#42d7ff")
			palette["accent_b"] = Color("#ffb13b")
			palette["accent_c"] = Color("#7d5cff")
			palette["glow_strength"] = 1.0
		"arena":
			palette["top_color"] = Color("#081426")
			palette["bottom_color"] = Color("#03040a")
			palette["accent_a"] = Color("#21b8ff")
			palette["accent_b"] = Color("#ff4b55")
			palette["accent_c"] = Color("#ffd05a")
			palette["star_strength"] = 0.45
		"rocket":
			palette["top_color"] = Color("#25050b")
			palette["bottom_color"] = Color("#060103")
			palette["accent_a"] = Color("#ff334d")
			palette["accent_b"] = Color("#ff7a2e")
			palette["accent_c"] = Color("#7a1cff")
			palette["glow_strength"] = 0.95
		"collection":
			palette["top_color"] = Color("#0a2337")
			palette["bottom_color"] = Color("#03060d")
			palette["accent_a"] = Color("#45f0c0")
			palette["accent_b"] = Color("#ff9a3d")
			palette["accent_c"] = Color("#7a8cff")
		"starter":
			palette["top_color"] = Color("#10284f")
			palette["bottom_color"] = Color("#040611")
			palette["accent_a"] = Color("#63e6ff")
			palette["accent_b"] = Color("#ffca55")
			palette["accent_c"] = Color("#ff6f91")
			palette["glow_strength"] = 0.95
	if mat.shader != null:
		for key in palette:
			mat.set_shader_parameter(key, palette[key])
	return rect

func section_header(kicker: String, heading: String, color: Color = GOLD) -> VBoxContainer:
	var box := vbox(2)
	var k := label(kicker.to_upper(), 13, color)
	k.add_theme_constant_override("letter_spacing", 2)
	box.add_child(k)
	box.add_child(title(heading, 42))
	return box

func icon(path: String) -> Texture2D:
	var res = load(path)
	if res is Texture2D:
		return res
	return null

func circle_texture(size_px: int, color: Color) -> ImageTexture:
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size_px * 0.5, size_px * 0.5)
	var radius := size_px * 0.45
	for y in size_px:
		for x in size_px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _circle_icon(size_px: int, color: Color) -> Texture2D:
	return circle_texture(size_px, color)

func fit_label(label_node: Label, max_width: float) -> void:
	label_node.custom_minimum_size.x = 0
	label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_node.custom_minimum_size = Vector2(max_width, 0)

func toast(text: String, accent: Color = CYAN, duration: float = 2.6) -> void:
	if _toast_box == null:
		return
	var panel_node := panel(Color(0.035, 0.055, 0.12, 0.96), Color(accent.r, accent.g, accent.b, 0.55), 14)
	var row := hbox(10)
	row.add_child(pokeball(20, 0.0, accent))
	var l := label(text, 15, PAPER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	panel_node.add_child(row)
	panel_node.modulate = Color(1, 1, 1, 0)
	panel_node.scale = Vector2(0.96, 0.96)
	_toast_box.add_child(panel_node)
	panel_node.pivot_offset = Vector2(240, 20)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel_node, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel_node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(duration)
	tw.tween_property(panel_node, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel_node.queue_free)

func _build_toast_layer() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 250
	add_child(_toast_layer)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position = Vector2(-240, 22)
	_toast_box.custom_minimum_size = Vector2(480, 0)
	_toast_box.add_theme_constant_override("separation", 8)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_box)
