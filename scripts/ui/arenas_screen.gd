extends Control
## Battle Arenas: travel hub for the two playable locations, with live status and Rocket alerts.

const SCENE_PATH := "res://scenes/ui/arenas_screen.tscn"

var _content: VBoxContainer
var _cards: Dictionary = {}
var _rocket_line: Label
var _rocket_panel: PanelContainer
var _header_stats: HBoxContainer

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto(GameState.SCENE_MAIN_MENU, 0.3, "MAIN MENU")
		return
	_build()
	AudioManager.play_music("menu", 0.7)
	AudioManager.play_ambience("stop", 0.4)
	_refresh()
	_animate_in()

# ------------------------------------------------------------------ layout

func _build() -> void:
	var bg := UIKit.background("arena")
	add_child(bg)
	var particles := UIKit.particle_field(44, 0.36)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	_content = UIKit.vbox(16)
	margin.add_child(_content)

	var header := UIKit.hbox(16)
	_content.add_child(header)
	var back := UIKit.button("< Back", "ghost", "", 44)
	back.custom_minimum_size = Vector2(108, 44)
	back.pressed.connect(_go_back)
	header.add_child(back)

	var titles := UIKit.vbox(0)
	header.add_child(titles)
	var kicker := UIKit.small("WORLD MAP  •  DESTINATIONS", Color(0.7, 0.9, 1.0, 0.78))
	kicker.add_theme_constant_override("letter_spacing", 3)
	titles.add_child(kicker)
	titles.add_child(UIKit.title("BATTLE ARENAS", 46, UIKit.GOLD))

	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)

	_header_stats = UIKit.hbox(10)
	header.add_child(_header_stats)

	var intro := UIKit.hbox(14)
	_content.add_child(intro)
	var intro_text := UIKit.small("Choose where to continue your journey. The Stadium Playground is your training ground; the Battle Arena hosts championship matches and Team Rocket confrontations.", Color(0.82, 0.9, 1.0, 0.85))
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro.add_child(intro_text)

	_rocket_panel = UIKit.panel(Color(0.14, 0.02, 0.05, 0.92), Color(1, 0.3, 0.4, 0.45), 14)
	_content.add_child(_rocket_panel)
	var rocket_row := UIKit.hbox(12)
	_rocket_panel.add_child(rocket_row)
	var rocket_ball := UIKit.pokeball(30, 1.5, Color("#ff334d"))
	rocket_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rocket_row.add_child(rocket_ball)
	var rocket_text_box := UIKit.vbox(0)
	rocket_row.add_child(rocket_text_box)
	var rocket_kicker := UIKit.small("TEAM ROCKET", Color(1, 0.62, 0.68, 0.9))
	rocket_kicker.add_theme_constant_override("letter_spacing", 2)
	rocket_text_box.add_child(rocket_kicker)
	_rocket_line = UIKit.label("", 16, Color("#ffd4d8"))
	_rocket_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rocket_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rocket_text_box.add_child(_rocket_line)
	var rocket_flex := Control.new()
	rocket_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rocket_row.add_child(rocket_flex)
	var rocket_go := UIKit.button("Confront", "rocket", "", 40)
	rocket_go.custom_minimum_size = Vector2(150, 40)
	rocket_go.pressed.connect(_travel.bind(GameState.LOCATION_ARENA))
	rocket_row.add_child(rocket_go)
	rocket_go.visible = false
	_cards["rocket_button"] = rocket_go

	var row := UIKit.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	row.add_child(_build_location_card(
		GameState.LOCATION_PLAYGROUND,
		"STADIUM PLAYGROUND",
		"Bright outdoor training park",
		"Free movement  •  NPC challengers  •  Partner companion",
		"playground",
		UIKit.CYAN,
		["Third-person exploration", "Challenge four local trainers", "Pet and bond with your partner", "Arena gate to the night stadium"]
	))
	row.add_child(_build_location_card(
		GameState.LOCATION_ARENA,
		"BATTLE ARENA",
		"Night championship stadium",
		"Cinematic battles  •  Crowd  •  Team Rocket",
		"arena",
		Color("#ff8a95"),
		["Championship battle stage", "Full crowd and jumbotron", "Team Rocket showdowns", "Travel gate back to the park"]
	))

	var footer := UIKit.hbox(18)
	_content.add_child(footer)
	footer.add_child(UIHelpers.key_hint("ESC", "Back"))
	footer.add_child(UIHelpers.key_hint("E", "Interact in world"))
	footer.add_child(UIHelpers.key_hint("WASD", "Move"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	footer.add_child(UIKit.small(GameState.summary_line(), Color(0.62, 0.76, 0.95, 0.55)))

func _build_location_card(location_id: String, heading: String, subtitle: String, tagline: String, art_mode: String, accent: Color, features: Array) -> PanelContainer:
	var card := UIKit.card(Color(0.03, 0.055, 0.12, 0.94), Color(accent.r, accent.g, accent.b, 0.28))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := UIKit.vbox(10)
	card.add_child(box)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(0, 250)
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_holder.clip_contents = true
	box.add_child(art_holder)

	var art := UIKit.stadium_art(art_mode)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_holder.add_child(art)

	var badge := UIKit.panel(Color(0.02, 0.04, 0.09, 0.82), Color(accent.r, accent.g, accent.b, 0.5), 10)
	badge.position = Vector2(14, 14)
	badge.custom_minimum_size = Vector2(140, 32)
	var badge_label := UIKit.small("YOU ARE HERE", accent)
	badge_label.add_theme_constant_override("letter_spacing", 2)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	art_holder.add_child(badge)
	_cards["badge_%s" % location_id] = badge

	var head := UIKit.hbox(10)
	box.add_child(head)
	var title_box := UIKit.vbox(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_box)
	var kicker := UIKit.small(subtitle.to_upper(), Color(accent.r, accent.g, accent.b, 0.82))
	kicker.add_theme_constant_override("letter_spacing", 2)
	title_box.add_child(kicker)
	title_box.add_child(UIKit.title(heading, 34))
	var tag := UIKit.small(tagline, Color(0.76, 0.86, 1.0, 0.75))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tag)

	var feature_box := UIKit.vbox(4)
	box.add_child(feature_box)
	for feature in features:
		var line := UIKit.hbox(8)
		var dot := ColorRect.new()
		dot.color = accent
		dot.custom_minimum_size = Vector2(5, 5)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var text := UIKit.small(str(feature), Color(0.8, 0.88, 1.0, 0.82))
		line.add_child(text)
		feature_box.add_child(line)

	var action_flex := Control.new()
	action_flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(action_flex)

	var button := UIKit.button("Travel Here", "primary" if location_id == GameState.LOCATION_ARENA else "glass", "", 50)
	button.pressed.connect(_travel.bind(location_id))
	box.add_child(button)
	_cards["button_%s" % location_id] = button
	return card

func _header_stat(kicker: String, value: String, color: Color) -> PanelContainer:
	var card := UIKit.panel(Color(0.035, 0.06, 0.13, 0.75), Color(1, 1, 1, 0.08), 12)
	var box := UIKit.vbox(0)
	card.add_child(box)
	var k := UIKit.small(kicker, Color(0.64, 0.78, 1.0, 0.6))
	k.add_theme_constant_override("letter_spacing", 1)
	box.add_child(k)
	box.add_child(UIKit.label(value, 20, color))
	return card

# ------------------------------------------------------------------ state

func _refresh() -> void:
	for child in _header_stats.get_children():
		_header_stats.remove_child(child)
		child.queue_free()
	_header_stats.add_child(_header_stat("MATCHES", str(GameState.regular_matches_completed()), UIKit.CYAN))
	_header_stats.add_child(_header_stat("UNLOCKED", "%d / 5" % GameState.unlocked_pokemon().size(), UIKit.MINT))
	_header_stats.add_child(_header_stat("ROCKET BADGES", str(GameState.rocket_badges()), Color("#ff8a95")))

	var current := GameState.current_location()
	for location_id in [GameState.LOCATION_PLAYGROUND, GameState.LOCATION_ARENA]:
		var badge: PanelContainer = _cards.get("badge_%s" % location_id)
		if badge != null:
			badge.visible = location_id == current
		var button: Button = _cards.get("button_%s" % location_id)
		if button == null:
			continue
		if location_id == current:
			button.text = "Current Location"
			button.disabled = true
		else:
			button.text = "Travel to %s" % ("Battle Arena" if location_id == GameState.LOCATION_ARENA else "Stadium Playground")
			button.disabled = false

	var rocket_button: Button = _cards.get("rocket_button")
	if GameState.rocket_pending():
		_rocket_panel.visible = true
		_rocket_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.16, 0.02, 0.05, 0.95), Color(1, 0.3, 0.4, 0.7), 14))
		_rocket_line.text = "ALERT: Team Rocket has seized the Battle Arena. Confront them there to complete the event and earn a badge."
		_rocket_line.add_theme_color_override("font_color", Color("#ffd4d8"))
		if rocket_button != null:
			rocket_button.visible = current != GameState.LOCATION_ARENA
	else:
		_rocket_panel.visible = true
		_rocket_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.035, 0.06, 0.13, 0.9), Color(1, 1, 1, 0.1), 14))
		var until := GameState.matches_until_rocket()
		_rocket_line.text = "Team Rocket is quiet. %d more completed match%s will draw them out of hiding." % [until, "" if until == 1 else "es"]
		_rocket_line.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0, 0.82))
		if rocket_button != null:
			rocket_button.visible = false

# ------------------------------------------------------------------ navigation

func _travel(location: String) -> void:
	if SceneRouter.transitioning:
		return
	if location == GameState.current_location():
		UIKit.toast("You are already at %s." % ("the Battle Arena" if location == GameState.LOCATION_ARENA else "the Stadium Playground"), UIKit.CYAN, 2.4)
		return
	if GameState.active_pokemon() == "":
		UIKit.toast("Choose an active partner in your collection first.", UIKit.RED, 3.0)
		return
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto_location(location)

func _go_back() -> void:
	if SceneRouter.transitioning:
		return
	var target := str(GameState.ui_context.get("return_scene", GameState.SCENE_MAIN_MENU))
	if target == "" or not ResourceLoader.exists(target):
		target = GameState.SCENE_MAIN_MENU
	AudioManager.play_sfx("back")
	SceneRouter.goto(target, 0.4, "RETURNING")

func _animate_in() -> void:
	_content.modulate = Color(1, 1, 1, 0)
	_content.position.y = 16
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_content, "modulate:a", 1.0, 0.4)
	tw.tween_property(_content, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
