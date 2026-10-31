extends Control
## Settings: audio, camera, display, save diagnostics and journey reset.

const SCENE_PATH := "res://scenes/ui/settings.tscn"

var _music_value: Label
var _sfx_value: Label
var _sensitivity_value: Label
var _fullscreen_toggle: CheckButton
var _diagnostics: Label
var _reset_dialog: ConfirmationDialog
var _content: HBoxContainer

func _ready() -> void:
	_build()
	AudioManager.play_music("menu", 0.7)
	_refresh_diagnostics()
	_animate_in()

# ------------------------------------------------------------------ layout

func _build() -> void:
	var bg := UIKit.background("menu")
	add_child(bg)
	var particles := UIKit.particle_field(36, 0.32)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var column := UIKit.vbox(14)
	margin.add_child(column)

	var header := UIKit.hbox(16)
	column.add_child(header)
	var back := UIKit.button("< Back", "ghost", "", 44)
	back.custom_minimum_size = Vector2(108, 44)
	back.pressed.connect(_go_back)
	header.add_child(back)
	var titles := UIKit.vbox(0)
	header.add_child(titles)
	var kicker := UIKit.small("SYSTEM  •  PREFERENCES", Color(0.7, 0.9, 1.0, 0.78))
	kicker.add_theme_constant_override("letter_spacing", 3)
	titles.add_child(kicker)
	titles.add_child(UIKit.title("SETTINGS", 46, UIKit.GOLD))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)
	var save_note := UIKit.small("Changes save automatically", Color(0.62, 0.8, 1.0, 0.6))
	save_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(save_note)

	_content = UIKit.hbox(18)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var left := UIKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(left)
	var right := UIKit.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(right)

	# ---------------- audio + display
	var audio_card := UIKit.card(Color(0.035, 0.065, 0.14, 0.94), Color(0.55, 0.9, 1.0, 0.18))
	left.add_child(audio_card)
	var audio_box := UIKit.vbox(12)
	audio_card.add_child(audio_box)
	audio_box.add_child(UIKit.section_header("AUDIO", "Sound & Music", UIKit.CYAN))
	audio_box.add_child(UIKit.separator(Color(1, 1, 1, 0.07), 1))

	var music_row := _slider_row("Music", "Original chiptune soundtrack", 0.0, 100.0, 1.0, float(GameState.get_setting("music", 0.62)) * 100.0)
	_music_value = music_row["value_label"]
	var music_slider: HSlider = music_row["slider"]
	music_slider.value_changed.connect(_on_music_changed)
	audio_box.add_child(music_row["root"])

	var sfx_row := _slider_row("Sound Effects", "Cries, hits and UI feedback", 0.0, 100.0, 1.0, float(GameState.get_setting("sfx", 0.8)) * 100.0)
	_sfx_value = sfx_row["value_label"]
	var sfx_slider: HSlider = sfx_row["slider"]
	sfx_slider.value_changed.connect(_on_sfx_changed)
	audio_box.add_child(sfx_row["root"])

	var display_card := UIKit.card(Color(0.035, 0.065, 0.14, 0.94), Color(1, 1, 1, 0.1))
	left.add_child(display_card)
	var display_box := UIKit.vbox(10)
	display_card.add_child(display_box)
	display_box.add_child(UIKit.section_header("DISPLAY", "Window & Camera", Color("#ffb23b")))
	display_box.add_child(UIKit.separator(Color(1, 1, 1, 0.07), 1))

	var sens_row := _slider_row("Camera Sensitivity", "Mouse look speed in the world", 8.0, 60.0, 1.0, float(GameState.get_setting("camera_sensitivity", 0.0024)) * 10000.0)
	_sensitivity_value = sens_row["value_label"]
	var sens_slider: HSlider = sens_row["slider"]
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	display_box.add_child(sens_row["root"])

	var fullscreen_row := UIKit.hbox(12)
	display_box.add_child(fullscreen_row)
	var fs_text := UIKit.vbox(0)
	fullscreen_row.add_child(fs_text)
	fs_text.add_child(UIKit.label("Fullscreen", 18, UIKit.PAPER))
	fs_text.add_child(UIKit.small("Use the whole display for battles", Color(0.68, 0.8, 1.0, 0.65)))
	var fs_flex := Control.new()
	fs_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_row.add_child(fs_flex)
	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.text = "On" if bool(GameState.get_setting("fullscreen", false)) else "Off"
	_fullscreen_toggle.button_pressed = bool(GameState.get_setting("fullscreen", false))
	_fullscreen_toggle.custom_minimum_size = Vector2(110, 42)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	fullscreen_row.add_child(_fullscreen_toggle)

	# ---------------- journey + diagnostics
	var journey_card := UIKit.card(Color(0.035, 0.065, 0.14, 0.94), Color(1, 0.82, 0.4, 0.2))
	right.add_child(journey_card)
	var journey_box := UIKit.vbox(10)
	journey_card.add_child(journey_box)
	journey_box.add_child(UIKit.section_header("JOURNEY", "Save & Progress", UIKit.GOLD))
	journey_box.add_child(UIKit.separator(Color(1, 1, 1, 0.07), 1))

	var trainer := AssetLibrary.get_trainer(GameState.trainer_id())
	var trainer_name := GameState.trainer_name() if GameState.trainer_id() != "" else "No trainer"
	var trainer_title := UIHelpers.trainer_title(trainer) if not trainer.is_empty() else "Start a journey from the main menu"
	var who := UIKit.hbox(12)
	journey_box.add_child(who)
	var avatar := UIKit.pokeball(42, 0.4, Color("#ffd05a"))
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(avatar)
	var who_text := UIKit.vbox(0)
	who.add_child(who_text)
	who_text.add_child(UIKit.label(trainer_name, 24, UIKit.PAPER))
	who_text.add_child(UIKit.small(trainer_title, Color(0.72, 0.84, 1.0, 0.72)))

	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 12)
	stat_grid.add_theme_constant_override("v_separation", 8)
	journey_box.add_child(stat_grid)
	stat_grid.add_child(_stat_block("MATCHES", str(GameState.regular_matches_completed()), UIKit.CYAN))
	stat_grid.add_child(_stat_block("UNLOCKED", "%d / 5" % GameState.unlocked_pokemon().size(), UIKit.MINT))
	stat_grid.add_child(_stat_block("ROCKET WINS", str(GameState.rocket_wins()), Color("#ff8a95")))

	var rocket_line := UIKit.panel(Color(0.1, 0.02, 0.05, 0.85), Color(1, 0.3, 0.4, 0.3), 12)
	journey_box.add_child(rocket_line)
	var rocket_text := UIKit.small(_rocket_status_text(), Color(0.9, 0.78, 0.82, 0.9))
	rocket_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rocket_line.add_child(rocket_text)

	var reset := UIKit.button("Reset Journey…", "danger", "", 46)
	reset.pressed.connect(_confirm_reset)
	journey_box.add_child(reset)

	var diag_card := UIKit.card(Color(0.03, 0.055, 0.12, 0.94), Color(0.7, 0.55, 1.0, 0.2))
	diag_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(diag_card)
	var diag_box := UIKit.vbox(8)
	diag_card.add_child(diag_box)
	diag_box.add_child(UIKit.section_header("DIAGNOSTICS", "Assets & Save Data", Color("#c9a8ff")))
	diag_box.add_child(UIKit.separator(Color(1, 1, 1, 0.07), 1))
	_diagnostics = UIKit.small("Reading asset registry…", Color(0.76, 0.84, 1.0, 0.8))
	_diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diag_box.add_child(_diagnostics)
	var diag_actions := UIKit.hbox(8)
	diag_box.add_child(diag_actions)
	var open_folder := UIKit.button("Open Save Folder", "glass", "", 40)
	open_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_folder.pressed.connect(_open_save_folder)
	diag_actions.add_child(open_folder)
	var copy := UIKit.button("Copy Report", "ghost", "", 40)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_copy_report)
	diag_actions.add_child(copy)

	var footer := UIKit.hbox(18)
	column.add_child(footer)
	footer.add_child(UIHelpers.key_hint("ESC", "Back"))
	footer.add_child(UIHelpers.key_hint("WASD", "Move"))
	footer.add_child(UIHelpers.key_hint("E", "Interact"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	footer.add_child(UIKit.small("Original assets  •  No external Pokémon files required", Color(0.6, 0.72, 0.92, 0.45)))

	_build_reset_dialog()

func _slider_row(title: String, subtitle: String, minimum: float, maximum: float, step: float, initial: float) -> Dictionary:
	var root := UIKit.vbox(4)
	var head := UIKit.hbox(10)
	root.add_child(head)
	var text := UIKit.vbox(0)
	head.add_child(text)
	text.add_child(UIKit.label(title, 17, UIKit.PAPER))
	text.add_child(UIKit.small(subtitle, Color(0.68, 0.8, 1.0, 0.62)))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(flex)
	var value_label := UIKit.label("", 16, UIKit.CYAN)
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = clampf(initial, minimum, maximum)
	slider.custom_minimum_size = Vector2(0, 26)
	root.add_child(slider)
	return {"root": root, "slider": slider, "value_label": value_label}

func _stat_block(kicker: String, value: String, color: Color) -> VBoxContainer:
	var box := UIKit.vbox(0)
	var k := UIKit.small(kicker, Color(0.64, 0.78, 1.0, 0.6))
	k.add_theme_constant_override("letter_spacing", 1)
	box.add_child(k)
	box.add_child(UIKit.label(value, 22, color))
	return box

func _build_reset_dialog() -> void:
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Reset Journey?"
	_reset_dialog.dialog_text = "This permanently erases your trainer, unlocks, levels, Rocket badges and save file. This cannot be undone."
	_reset_dialog.ok_button_text = "Erase Everything"
	_reset_dialog.cancel_button_text = "Keep My Journey"
	_reset_dialog.min_size = Vector2i(600, 260)
	_reset_dialog.theme = UIKit.theme
	_reset_dialog.confirmed.connect(_do_reset)
	add_child(_reset_dialog)

func _rocket_status_text() -> String:
	if GameState.rocket_pending():
		return "TEAM ROCKET ALERT  •  They have taken over the Battle Arena. Confront them there to complete the event."
	var until := GameState.matches_until_rocket()
	return "Team Rocket is quiet for now. %d more completed match%s will draw them out." % [until, "" if until == 1 else "es"]

# ------------------------------------------------------------------ actions

func _on_music_changed(value: float) -> void:
	_music_value.text = "%d%%" % int(round(value))
	GameState.set_setting("music", clampf(value / 100.0, 0.0, 1.0))

func _on_sfx_changed(value: float) -> void:
	_sfx_value.text = "%d%%" % int(round(value))
	GameState.set_setting("sfx", clampf(value / 100.0, 0.0, 1.0))

func _on_sensitivity_changed(value: float) -> void:
	_sensitivity_value.text = "%d" % int(round(value))
	GameState.set_setting("camera_sensitivity", clampf(value / 10000.0, 0.0005, 0.008))

func _on_fullscreen_toggled(pressed: bool) -> void:
	_fullscreen_toggle.text = "On" if pressed else "Off"
	GameState.set_setting("fullscreen", pressed)
	GameState.apply_settings()
	AudioManager.play_sfx("click")

func _confirm_reset() -> void:
	AudioManager.play_sfx("back")
	_reset_dialog.popup_centered()

func _do_reset() -> void:
	GameState.reset_journey()
	AudioManager.play_sfx("confirm")
	SceneRouter.goto_main_menu()

func _refresh_diagnostics() -> void:
	if _diagnostics == null:
		return
	var lines: Array[String] = []
	lines.append("SAVE FILE")
	lines.append(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	lines.append("Save present: %s  •  Trainer: %s" % ["yes" if GameState.has_save else "no", GameState.trainer_id() if GameState.trainer_id() != "" else "—"])
	lines.append("")
	lines.append("ASSETS")
	lines.append(AssetLibrary.asset_status_report())
	lines.append("")
	lines.append("ENGINE")
	lines.append("Godot %s  •  %s  •  %s" % [Engine.get_version_info().get("string", "4.x"), OS.get_name(), RenderingServer.get_video_adapter_name()])
	_diagnostics.text = "\n".join(lines)
	_music_value.text = "%d%%" % int(round(float(GameState.get_setting("music", 0.62)) * 100.0))
	_sfx_value.text = "%d%%" % int(round(float(GameState.get_setting("sfx", 0.8)) * 100.0))
	_sensitivity_value.text = "%d" % int(round(float(GameState.get_setting("camera_sensitivity", 0.0024)) * 10000.0))

func _open_save_folder() -> void:
	AudioManager.play_sfx("confirm")
	var path := ProjectSettings.globalize_path("user://")
	var err := OS.shell_open(path)
	if err != OK:
		UIKit.toast("Could not open the save folder. Path copied to clipboard.", UIKit.RED, 3.0)
		DisplayServer.clipboard_set(path)

func _copy_report() -> void:
	AudioManager.play_sfx("confirm")
	var report := _diagnostics.text
	DisplayServer.clipboard_set(report)
	UIKit.toast("Diagnostics copied to clipboard.", UIKit.MINT, 2.6)

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
	_content.position.y = 14
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_content, "modulate:a", 1.0, 0.4)
	tw.tween_property(_content, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _reset_dialog.visible:
		_go_back()
		get_viewport().set_input_as_handled()
