extends Control
## Main menu with a live 3D partner showcase, journey summary and navigation.

var _preview: ModelPreview
var _profile_box: VBoxContainer
var _continue_button: Button
var _rocket_panel: PanelContainer
var _credits_dialog: AcceptDialog
var _confirm_dialog: ConfirmationDialog
var _left_column: VBoxContainer
var _partner_name: Label
var _partner_level: Label
var _partner_types: HBoxContainer

func _ready() -> void:
	_build()
	AudioManager.play_music("menu", 0.7)
	AudioManager.play_ambience("stop", 0.4)
	_refresh_profile()
	_animate_in()

func _build() -> void:
	var bg := UIKit.background("menu")
	add_child(bg)
	var particles := UIKit.particle_field(52, 0.45)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 68)
	margin.add_theme_constant_override("margin_right", 68)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var columns := UIKit.hbox(36)
	margin.add_child(columns)

	_left_column = UIKit.vbox(0)
	_left_column.custom_minimum_size = Vector2(700, 0)
	_left_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columns.add_child(_left_column)

	var brand_row := UIKit.hbox(12)
	var ball := UIKit.pokeball(34, 0.7)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(ball)
	var brand := UIKit.label("POKÉMON JOURNEY", 14, Color(0.72, 0.88, 1.0, 0.86))
	brand.add_theme_constant_override("letter_spacing", 5)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand_row.add_child(brand)
	brand_row.add_child(UIKit.spacer(0, 10))
	var version := UIKit.small("BUILD 1.0", Color(0.6, 0.72, 0.92, 0.5))
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand_row.add_child(version)
	_left_column.add_child(brand_row)

	_left_column.add_child(UIKit.spacer(16))
	var title := UIKit.title("POKÉMON", 94, UIKit.GOLD)
	_left_column.add_child(title)
	var title2 := UIKit.title("JOURNEY", 56, Color("#f2f9ff"))
	title2.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.2, 0.95))
	_left_column.add_child(title2)
	var tagline := UIKit.label("Build a bond. Win the crowd. Rise through the arena.", 18, Color(0.8, 0.89, 1.0, 0.9))
	_left_column.add_child(tagline)

	_left_column.add_child(UIKit.spacer(18))
	_rocket_panel = _build_rocket_alert()
	_rocket_panel.visible = false
	_left_column.add_child(_rocket_panel)

	_profile_box = UIKit.vbox(0)
	_left_column.add_child(_profile_box)

	_left_column.add_child(UIKit.spacer(18))
	var buttons := UIKit.vbox(10)
	buttons.custom_minimum_size = Vector2(470, 0)
	_left_column.add_child(buttons)

	_continue_button = UIKit.button("Continue Journey", "primary", "", 56)
	_continue_button.pressed.connect(_on_continue)
	buttons.add_child(_continue_button)

	var new_btn := UIKit.button("New Journey", "glass", "", 50)
	new_btn.pressed.connect(_on_new_journey)
	buttons.add_child(new_btn)

	var row := UIKit.hbox(10)
	buttons.add_child(row)
	var arenas_btn := UIKit.button("Battle Arenas", "glass", "", 48)
	arenas_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arenas_btn.pressed.connect(_go_submenu.bind("res://scenes/ui/arenas_screen.tscn", "BATTLE ARENAS"))
	row.add_child(arenas_btn)
	var collection_btn := UIKit.button("Collection", "glass", "", 48)
	collection_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_btn.pressed.connect(_go_submenu.bind("res://scenes/ui/collection.tscn", "COLLECTION"))
	row.add_child(collection_btn)

	var row2 := UIKit.hbox(10)
	buttons.add_child(row2)
	var exhibition_btn := UIKit.button("Exhibition Match", "glass", "", 44)
	exhibition_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exhibition_btn.pressed.connect(_open_exhibition)
	row2.add_child(exhibition_btn)
	var settings_btn := UIKit.button("Settings", "ghost", "", 44)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.pressed.connect(_go_submenu.bind("res://scenes/ui/settings.tscn", "SETTINGS"))
	row2.add_child(settings_btn)
	var credits_btn := UIKit.button("Credits", "ghost", "", 44)
	credits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_btn.pressed.connect(_show_credits)
	row2.add_child(credits_btn)
	var quit_btn := UIKit.button("Quit", "ghost", "", 44)
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(func(): get_tree().quit())
	row2.add_child(quit_btn)

	_left_column.add_child(UIKit.spacer(16))
	var hints := UIKit.hbox(22)
	hints.add_child(UIHelpers.key_hint("WASD", "Move"))
	hints.add_child(UIHelpers.key_hint("E", "Interact"))
	hints.add_child(UIHelpers.key_hint("ESC", "Pause"))
	_left_column.add_child(hints)

	# Right showcase column
	var right := UIKit.vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	var showcase_head := UIKit.hbox(10)
	var live_dot := ColorRect.new()
	live_dot.color = UIKit.MINT
	live_dot.custom_minimum_size = Vector2(8, 8)
	live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	showcase_head.add_child(live_dot)
	var live_label := UIKit.label("LIVE PARTNER SHOWCASE", 13, Color(0.78, 0.9, 1.0, 0.75))
	live_label.add_theme_constant_override("letter_spacing", 3)
	live_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	showcase_head.add_child(live_label)
	right.add_child(showcase_head)

	_preview = ModelPreview.new()
	_preview.custom_minimum_size = Vector2(0, 520)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_preview)

	var partner_card := UIKit.panel(Color(0.035, 0.06, 0.13, 0.86), Color(0.55, 0.86, 1.0, 0.2), 18)
	right.add_child(partner_card)
	var partner_inner := UIKit.hbox(14)
	partner_card.add_child(partner_inner)
	var mini_ball := UIKit.pokeball(46, 0.4, Color("#ffd05a"))
	mini_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	partner_inner.add_child(mini_ball)
	var partner_info := UIKit.vbox(2)
	partner_inner.add_child(partner_info)
	_partner_name = UIKit.label("No partner yet", 26, UIKit.PAPER)
	partner_info.add_child(_partner_name)
	_partner_level = UIKit.small("Choose a starter to begin", UIKit.MUTED)
	partner_info.add_child(_partner_level)
	_partner_types = UIKit.hbox(6)
	partner_info.add_child(_partner_types)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	partner_inner.add_child(spacer)
	var status := UIKit.vbox(2)
	var status_kicker := UIKit.small("STATUS", Color(0.65, 0.78, 1.0, 0.6))
	status_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(status_kicker)
	var status_value := UIKit.label("READY", 18, UIKit.MINT)
	status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(status_value)
	partner_inner.add_child(status)

	_build_dialogs()

func _build_rocket_alert() -> PanelContainer:
	var panel := UIKit.panel(Color(0.12, 0.02, 0.045, 0.94), Color(0.95, 0.2, 0.3, 0.65), 14)
	var row := UIKit.hbox(12)
	panel.add_child(row)
	var ball := UIKit.pokeball(28, 1.4, Color("#ff334d"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ball)
	var text_box := UIKit.vbox(1)
	row.add_child(text_box)
	var heading := UIKit.label("TEAM ROCKET ALERT", 15, Color("#ff8a95"))
	heading.add_theme_constant_override("letter_spacing", 2)
	text_box.add_child(heading)
	text_box.add_child(UIKit.small("They've taken over the Battle Arena. Confront them there.", Color(0.95, 0.8, 0.84, 0.9)))
	var go := UIKit.button("Go", "rocket", "", 36)
	go.custom_minimum_size = Vector2(74, 36)
	go.pressed.connect(func(): SceneRouter.goto_location(GameState.LOCATION_ARENA))
	row.add_child(go)
	return panel

func _build_dialogs() -> void:
	_credits_dialog = AcceptDialog.new()
	_credits_dialog.title = "Credits"
	_credits_dialog.ok_button_text = "Close"
	_credits_dialog.min_size = Vector2i(640, 420)
	_credits_dialog.dialog_text = """POKÉMON JOURNEY

A fan-made, non-commercial 3D battle adventure built with Godot 4.

DESIGN & CODE
Original procedural Pokémon-inspired sculpts, trainers, stadiums and effects.

AUDIO
Original chiptune soundtrack, cries and sound effects generated at runtime.

FONTS
Lilita One — SIL Open Font License
Nunito — SIL Open Font License

POKÉMON
Pokémon and Pokémon character names are trademarks of Nintendo,
Creatures Inc. and GAME FREAK inc. This project is an unofficial fan work
and is not affiliated with or endorsed by them. Official assets are not
included; optional .glb model overrides are the user's responsibility.

Thank you for playing!"""
	_credits_dialog.theme = UIKit.theme
	add_child(_credits_dialog)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Start a New Journey?"
	_confirm_dialog.dialog_text = "This will permanently erase your current journey, including unlocks, levels and Team Rocket progress."
	_confirm_dialog.ok_button_text = "Erase & Start New"
	_confirm_dialog.cancel_button_text = "Keep Journey"
	_confirm_dialog.min_size = Vector2i(560, 240)
	_confirm_dialog.theme = UIKit.theme
	_confirm_dialog.confirmed.connect(_start_new_journey)
	add_child(_confirm_dialog)

func _refresh_profile() -> void:
	for child in _profile_box.get_children():
		child.queue_free()
	_partner_types.add_child(UIKit.small("—", Color(0.55, 0.65, 0.85, 0.5)))
	if not GameState.has_save or GameState.trainer_id() == "":
		_continue_button.disabled = true
		_continue_button.tooltip_text = "Start a New Journey first"
		_rocket_panel.visible = false
		var empty := UIKit.panel(Color(0.04, 0.07, 0.15, 0.78), Color(1, 1, 1, 0.09), 18)
		var inner := UIKit.vbox(8)
		empty.add_child(inner)
		inner.add_child(UIKit.small("NO JOURNEY STARTED", Color(0.7, 0.84, 1.0, 0.7)))
		inner.add_child(UIKit.label("A new adventure awaits", 30, UIKit.PAPER))
		var empty_hint := UIKit.small("Pick a trainer, choose your first partner and step into the Stadium Playground.", UIKit.MUTED)
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(empty_hint)
		var silhouettes := UIKit.hbox(8)
		for id in GameState.POKEMON_ORDER:
			var sil := UIKit.silhouette(id, Color(0.4, 0.75, 1.0, 0.18))
			sil.custom_minimum_size = Vector2(54, 54)
			sil.modulate = Color(1, 1, 1, 0.5)
			silhouettes.add_child(sil)
		inner.add_child(silhouettes)
		_profile_box.add_child(empty)
		_preview.set_pokemon("pikachu")
		_preview.set_accent(Color("#ffd05a"))
		_partner_name.text = "Pikachu"
		_partner_level.text = "Waiting for a trainer"
		for child in _partner_types.get_children():
			child.queue_free()
		_partner_types.add_child(UIKit.type_badge("electric", true))
		return

	_continue_button.disabled = false
	_continue_button.tooltip_text = ""
	_rocket_panel.visible = GameState.rocket_pending()

	var trainer := AssetLibrary.get_trainer(GameState.trainer_id())
	var trainer_name := GameState.trainer_name()
	var trainer_title := UIHelpers.trainer_title(trainer)

	var card := UIKit.panel(Color(0.04, 0.07, 0.15, 0.82), Color(1, 1, 1, 0.1), 18)
	var inner := UIKit.vbox(8)
	card.add_child(inner)
	var head := UIKit.hbox(12)
	inner.add_child(head)
	var avatar := UIKit.pokeball(44, 0.3, Color("#ffd05a"))
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(avatar)
	var who := UIKit.vbox(0)
	head.add_child(who)
	who.add_child(UIKit.small("CURRENT JOURNEY", Color(0.7, 0.84, 1.0, 0.65)))
	who.add_child(UIKit.label(trainer_name, 28, UIKit.PAPER))
	who.add_child(UIKit.small(trainer_title, Color(0.76, 0.86, 1.0, 0.8)))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(flex)
	var stats_box := UIKit.vbox(1)
	head.add_child(stats_box)
	var win_label := UIKit.label("%d WINS" % int(GameState.data.get("battles_won", 0)), 18, UIKit.GOLD)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_box.add_child(win_label)
	var badge_label := UIKit.small("%d Rocket badges" % GameState.rocket_badges(), UIKit.MUTED)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_box.add_child(badge_label)

	inner.add_child(UIKit.separator(Color(1, 1, 1, 0.08), 1))

	var progress := UIKit.hbox(16)
	inner.add_child(progress)
	progress.add_child(_mini_stat("MATCHES", str(GameState.regular_matches_completed()), UIKit.CYAN))
	progress.add_child(_mini_stat("UNLOCKED", "%d / 5" % GameState.unlocked_pokemon().size(), UIKit.MINT))
	progress.add_child(_mini_stat("ROCKET", str(GameState.rocket_wins()), Color("#ff7a8a")))
	var next_box := UIKit.vbox(1)
	next_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_child(next_box)
	var until := GameState.matches_until_rocket()
	next_box.add_child(UIKit.small("NEXT ROCKET EVENT", Color(0.7, 0.8, 1.0, 0.55)))
	next_box.add_child(UIKit.label("In %d match%s" % [until, "" if until == 1 else "es"] if until > 0 else "RIGHT NOW", 16, Color("#ff9aa5")))
	_profile_box.add_child(card)

	var active := GameState.active_pokemon()
	var species := AssetLibrary.get_pokemon(active)
	if species != null:
		_preview.set_pokemon(active)
		_preview.set_accent(TypeChart.type_color(species.primary_type))
		_partner_name.text = species.display_name
		var xp := GameState.xp_progress(active)
		_partner_level.text = "Lv. %d  •  %d / %d XP" % [int(xp.get("level", 5)), int(xp.get("current", 0)), int(xp.get("needed", 1))]
		for child in _partner_types.get_children():
			child.queue_free()
		for type_name in species.types():
			_partner_types.add_child(UIKit.type_badge(type_name, true))

func _mini_stat(label_text: String, value: String, color: Color) -> VBoxContainer:
	var box := UIKit.vbox(1)
	var k := UIKit.small(label_text, Color(0.66, 0.78, 1.0, 0.55))
	k.add_theme_constant_override("letter_spacing", 1)
	box.add_child(k)
	box.add_child(UIKit.label(value, 20, color))
	return box

func _animate_in() -> void:
	_left_column.modulate = Color(1, 1, 1, 0)
	_left_column.position.x = -24
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_left_column, "modulate:a", 1.0, 0.55)
	tw.tween_property(_left_column, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_continue() -> void:
	if not GameState.has_save or GameState.trainer_id() == "":
		_go("res://scenes/ui/trainer_select.tscn", "TRAINER SELECT")
		return
	if GameState.starter_id() == "":
		_go("res://scenes/ui/starter_select.tscn", "CHOOSING PARTNER")
		return
	AudioManager.play_sfx("confirm")
	SceneRouter.goto(GameState.current_location_scene(), 0.5, "TRAVELLING")

func _on_new_journey() -> void:
	if GameState.has_save:
		_confirm_dialog.popup_centered()
	else:
		_start_new_journey()

func _start_new_journey() -> void:
	GameState.reset_journey()
	AudioManager.play_sfx("confirm")
	_go("res://scenes/ui/trainer_select.tscn", "TRAINER SELECT")

func _go(path: String, label_text: String) -> void:
	AudioManager.play_sfx("confirm")
	SceneRouter.goto(path, 0.4, label_text)

func _go_submenu(path: String, label_text: String) -> void:
	GameState.ui_context["return_scene"] = GameState.SCENE_MAIN_MENU
	_go(path, label_text)


func _open_exhibition() -> void:
	AudioManager.play_sfx("confirm")
	SceneRouter.goto("res://scenes/ui/exhibition.tscn", 0.4, "EXHIBITION")


func _show_credits() -> void:
	_credits_dialog.popup_centered()
