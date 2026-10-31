class_name WorldHUD
extends CanvasLayer
## Shared in-world HUD: location badge, partner status, interaction prompt and pause/travel menu.

signal pause_changed(paused: bool)
signal travel_requested(location: String)

var world: Node
var player: PlayerController
var location_title := "STADIUM PLAYGROUND"
var location_subtitle := "Explore, train and challenge the locals"
var paused := false
var _prompt_panel: PanelContainer
var _prompt_key: Label
var _prompt_title: Label
var _prompt_text: Label
var _pause_layer: Control
var _pause_panel: PanelContainer
var _pause_buttons: VBoxContainer
var _location_label: Label
var _location_sub: Label
var _partner_label: Label
var _progress_label: Label
var _rocket_chip: PanelContainer
var _rocket_label: Label
var _banner_layer: Control
var _banner_kicker: Label
var _banner_title: Label
var _banner_sub: Label
var _toast_anchor: VBoxContainer
var _travel_buttons: Array[Button] = []
var _current_location := ""

func setup(world_node: Node, player_node: PlayerController, title: String, subtitle: String, location_id: String) -> void:
	world = world_node
	player = player_node
	location_title = title
	location_subtitle = subtitle
	_current_location = location_id
	if player != null and player.has_signal("interact_target_changed"):
		if not player.interact_target_changed.is_connected(_on_target_changed):
			player.interact_target_changed.connect(_on_target_changed)
	if is_inside_tree():
		_refresh_all()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_bar()
	_build_prompt()
	_build_banner()
	_build_pause()
	_build_toast_anchor()
	GameState.state_changed.connect(_refresh_all)
	GameState.progression_changed.connect(_refresh_all)
	if player != null:
		player.interact_target_changed.connect(_on_target_changed)
	_refresh_all()
	set_process_unhandled_input(true)

func _build_top_bar() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 30
	top.offset_right = -30
	top.offset_top = 24
	top.offset_bottom = 118
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := UIKit.hbox(14)
	top.add_child(row)

	var location_card := UIKit.panel(Color(0.03, 0.055, 0.12, 0.82), Color(0.55, 0.88, 1.0, 0.22), 14)
	location_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(location_card)
	var loc_inner := UIKit.hbox(12)
	location_card.add_child(loc_inner)
	var ball := UIKit.pokeball(38, 0.45, Color("#ffd05a"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loc_inner.add_child(ball)
	var loc_text := UIKit.vbox(0)
	loc_inner.add_child(loc_text)
	var kicker := UIKit.small("CURRENT LOCATION", Color(0.62, 0.8, 1.0, 0.62))
	kicker.add_theme_constant_override("letter_spacing", 2)
	loc_text.add_child(kicker)
	_location_label = UIKit.label(location_title, 20, UIKit.PAPER)
	loc_text.add_child(_location_label)
	_location_sub = UIKit.small(location_subtitle, Color(0.72, 0.84, 1.0, 0.7))
	loc_text.add_child(_location_sub)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_rocket_chip = UIKit.panel(Color(0.16, 0.02, 0.05, 0.94), Color(1, 0.3, 0.4, 0.65), 12)
	_rocket_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_rocket_chip)
	var rocket_row := UIKit.hbox(8)
	_rocket_chip.add_child(rocket_row)
	var rocket_ball := UIKit.pokeball(24, 1.6, Color("#ff334d"))
	rocket_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rocket_row.add_child(rocket_ball)
	_rocket_label = UIKit.label("TEAM ROCKET ALERT", 13, Color("#ff9aa5"))
	_rocket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rocket_label.add_theme_constant_override("letter_spacing", 1)
	rocket_row.add_child(_rocket_label)

	var partner_card := UIKit.panel(Color(0.03, 0.055, 0.12, 0.82), Color(1, 1, 1, 0.1), 14)
	partner_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(partner_card)
	var partner_inner := UIKit.hbox(12)
	partner_card.add_child(partner_inner)
	var partner_ball := UIKit.pokeball(34, 0.35, Color("#78e2ff"))
	partner_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	partner_inner.add_child(partner_ball)
	var partner_text := UIKit.vbox(0)
	partner_inner.add_child(partner_text)
	var pk := UIKit.small("ACTIVE PARTNER", Color(0.62, 0.8, 1.0, 0.62))
	pk.add_theme_constant_override("letter_spacing", 2)
	partner_text.add_child(pk)
	_partner_label = UIKit.label("—", 18, UIKit.PAPER)
	partner_text.add_child(_partner_label)
	_progress_label = UIKit.small("", Color(0.7, 0.84, 1.0, 0.66))
	_progress_label.add_theme_font_size_override("font_size", 13)
	partner_text.add_child(_progress_label)

func _build_prompt() -> void:
	var anchor := CenterContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.offset_left = -240
	anchor.offset_right = 240
	anchor.offset_top = -142
	anchor.offset_bottom = -92
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_prompt_panel = UIKit.panel(Color(0.03, 0.055, 0.12, 0.94), Color(0.55, 0.9, 1.0, 0.5), 14)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	anchor.add_child(_prompt_panel)
	var row := UIKit.hbox(12)
	_prompt_panel.add_child(row)
	var key_panel := UIKit.panel(Color(0.12, 0.2, 0.36, 0.98), Color(0.7, 0.95, 1.0, 0.6), 8)
	key_panel.custom_minimum_size = Vector2(38, 34)
	key_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key_panel)
	_prompt_key = UIKit.label("E", 18, UIKit.PAPER)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(_prompt_key)
	var text_box := UIKit.vbox(0)
	row.add_child(text_box)
	_prompt_title = UIKit.label("", 16, UIKit.PAPER)
	text_box.add_child(_prompt_title)
	_prompt_text = UIKit.small("", Color(0.74, 0.86, 1.0, 0.8))
	_prompt_text.add_theme_font_size_override("font_size", 13)
	text_box.add_child(_prompt_text)

func _build_banner() -> void:
	_banner_layer = Control.new()
	_banner_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.modulate = Color(1, 1, 1, 0)
	add_child(_banner_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(center)
	var box := UIKit.vbox(4)
	box.custom_minimum_size = Vector2(800, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	_banner_kicker = UIKit.label("", 14, Color(0.75, 0.9, 1.0, 0.85))
	_banner_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_kicker.add_theme_constant_override("letter_spacing", 5)
	box.add_child(_banner_kicker)
	_banner_title = UIKit.title("", 70, UIKit.GOLD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_title)
	_banner_sub = UIKit.label("", 18, Color(0.86, 0.93, 1.0, 0.92))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_sub)

func _build_pause() -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.055, 0.82)
	_pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	_pause_panel = UIKit.panel(Color(0.035, 0.06, 0.13, 0.97), Color(0.55, 0.88, 1.0, 0.3), 24)
	_pause_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_pause_panel)
	_pause_buttons = UIKit.vbox(10)
	_pause_panel.add_child(_pause_buttons)

	var head := UIKit.hbox(12)
	_pause_buttons.add_child(head)
	var pause_ball := UIKit.pokeball(48, 0.0, Color("#ffd05a"))
	pause_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pause_ball)
	var head_text := UIKit.vbox(0)
	head.add_child(head_text)
	var kicker := UIKit.small("JOURNEY PAUSED", Color(0.66, 0.82, 1.0, 0.7))
	kicker.add_theme_constant_override("letter_spacing", 3)
	head_text.add_child(kicker)
	head_text.add_child(UIKit.title("TAKE A BREATH", 40))
	_pause_buttons.add_child(UIKit.separator(Color(1, 1, 1, 0.08), 1))

	var resume := UIKit.button("Resume Exploring", "primary", "", 52)
	resume.pressed.connect(func(): set_paused(false))
	_pause_buttons.add_child(resume)

	var row := UIKit.hbox(10)
	_pause_buttons.add_child(row)
	var collection := UIKit.button("Collection", "glass", "", 46)
	collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection.pressed.connect(_open_collection)
	row.add_child(collection)
	var settings := UIKit.button("Settings", "glass", "", 46)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(_open_settings)
	row.add_child(settings)

	var travel_head := UIKit.small("TRAVEL", Color(0.66, 0.82, 1.0, 0.62))
	travel_head.add_theme_constant_override("letter_spacing", 2)
	_pause_buttons.add_child(travel_head)
	var travel_row := UIKit.hbox(10)
	_pause_buttons.add_child(travel_row)
	var playground := UIKit.button("Stadium Playground", "nav", "", 50)
	playground.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playground.pressed.connect(_travel.bind(GameState.LOCATION_PLAYGROUND))
	travel_row.add_child(playground)
	_travel_buttons.append(playground)
	var arena := UIKit.button("Battle Arena", "nav", "", 50)
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.pressed.connect(_travel.bind(GameState.LOCATION_ARENA))
	travel_row.add_child(arena)
	_travel_buttons.append(arena)

	var menu := UIKit.button("Save & Return to Main Menu", "ghost", "", 44)
	menu.pressed.connect(_go_main_menu)
	_pause_buttons.add_child(menu)

	_pause_buttons.add_child(UIKit.separator(Color(1, 1, 1, 0.07), 1))
	var controls := UIKit.hbox(16)
	_pause_buttons.add_child(controls)
	controls.add_child(UIHelpers.key_hint("WASD", "Move"))
	controls.add_child(UIHelpers.key_hint("SHIFT", "Sprint"))
	controls.add_child(UIHelpers.key_hint("SPACE", "Jump"))
	controls.add_child(UIHelpers.key_hint("E", "Interact"))
	controls.add_child(UIHelpers.key_hint("ESC", "Pause"))

func _build_toast_anchor() -> void:
	_toast_anchor = VBoxContainer.new()
	_toast_anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toast_anchor.offset_left = 30
	_toast_anchor.offset_bottom = -28
	_toast_anchor.offset_top = -260
	_toast_anchor.offset_right = 430
	_toast_anchor.alignment = BoxContainer.ALIGNMENT_END
	_toast_anchor.add_theme_constant_override("separation", 8)
	_toast_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_anchor)

func _refresh_all() -> void:
	if _location_label == null:
		return
	_location_label.text = location_title
	_location_sub.text = location_subtitle
	var active_id := GameState.active_pokemon()
	var species := AssetLibrary.get_pokemon(active_id)
	if species != null:
		var progress := GameState.xp_progress(active_id)
		_partner_label.text = "%s  •  Lv. %d" % [species.display_name, int(progress.get("level", 5))]
		_progress_label.text = "%d / %d XP  •  %d wins" % [int(progress.get("current", 0)), int(progress.get("needed", 1)), GameState.regular_wins()]
	else:
		_partner_label.text = "No partner"
		_progress_label.text = "Visit the collection to choose one"
	_rocket_chip.visible = GameState.rocket_pending()
	if GameState.rocket_pending():
		_rocket_label.text = "TEAM ROCKET ALERT"
	else:
		var until := GameState.matches_until_rocket()
		_rocket_label.text = "ROCKET IN %d MATCH%s" % [until, "" if until == 1 else "ES"]
	_rocket_chip.visible = true
	for button in _travel_buttons:
		button.disabled = false
	if _current_location == GameState.LOCATION_PLAYGROUND:
		_travel_buttons[0].disabled = true
	elif _current_location == GameState.LOCATION_ARENA:
		_travel_buttons[1].disabled = true

func _on_target_changed(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		_prompt_panel.visible = false
		return
	var title_value = target.get("title")
	var title := str(title_value) if title_value != null and str(title_value) != "" else "Interact"
	var prompt := "Press E"
	if target.has_method("get_prompt"):
		prompt = str(target.call("get_prompt"))
	_prompt_title.text = title
	_prompt_text.text = prompt
	_prompt_panel.visible = true
	_prompt_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_prompt_panel, "modulate:a", 1.0, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if _pause_layer.visible:
			set_paused(false)
		else:
			set_paused(true)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	if _pause_layer == null:
		return
	paused = value
	_pause_layer.visible = value
	if player != null:
		player.set_control_enabled(not value)
		player.capture_mouse(not value)
	if value:
		_prompt_panel.visible = false
		AudioManager.play_sfx("back", -3.0, 1.0)
	pause_changed.emit(value)

func show_banner(kicker: String, heading: String, subtitle: String, duration: float = 3.0, color: Color = UIKit.GOLD) -> void:
	if _banner_layer == null:
		return
	_banner_kicker.text = kicker.to_upper()
	_banner_title.text = heading
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner_layer.modulate = Color(1, 1, 1, 0)
	_banner_layer.position.y = 20
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner_layer, "modulate:a", 1.0, 0.4)
	tw.tween_property(_banner_layer, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(maxf(0.4, duration))
	tw.set_parallel(true)
	tw.tween_property(_banner_layer, "modulate:a", 0.0, 0.55)
	tw.tween_property(_banner_layer, "position:y", -16.0, 0.55)

func show_alert(text: String, duration: float = 4.0) -> void:
	var panel := UIKit.panel(Color(0.16, 0.02, 0.05, 0.95), Color(1, 0.3, 0.4, 0.7), 12)
	var row := UIKit.hbox(10)
	panel.add_child(row)
	var ball := UIKit.pokeball(22, 1.4, Color("#ff334d"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ball)
	var label := UIKit.label(text, 14, Color("#ffd4d8"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_toast_anchor.add_child(panel)
	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

func announce_result(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	var won := bool(summary.get("won", false))
	var text := "Victory! +%d XP" % int(summary.get("xp", 0)) if won else "Defeat. Your partner still grew stronger."
	show_alert(text, 4.5)
	var level_up: Dictionary = summary.get("level_up", {})
	if int(level_up.get("levels", 0)) > 0:
		show_alert("LEVEL UP! Your partner reached Lv. %d" % int(level_up.get("new_level", 5)), 4.0)
	var unlocked: Array = summary.get("unlocked", [])
	for id in unlocked:
		var species := AssetLibrary.get_pokemon(str(id))
		if species != null:
			show_alert("NEW PARTNER UNLOCKED: %s" % species.display_name, 5.0)

func _travel(location: String) -> void:
	if location == GameState.current_location():
		return
	set_paused(false)
	AudioManager.play_sfx("confirm")
	travel_requested.emit(location)

func _open_collection() -> void:
	GameState.ui_context["return_scene"] = get_tree().current_scene.scene_file_path
	set_paused(false)
	SceneRouter.goto("res://scenes/ui/collection.tscn", 0.4, "COLLECTION")

func _open_settings() -> void:
	GameState.ui_context["return_scene"] = get_tree().current_scene.scene_file_path
	set_paused(false)
	SceneRouter.goto("res://scenes/ui/settings.tscn", 0.4, "SETTINGS")

func _go_main_menu() -> void:
	set_paused(false)
	GameState.save_game()
	SceneRouter.goto_main_menu()
