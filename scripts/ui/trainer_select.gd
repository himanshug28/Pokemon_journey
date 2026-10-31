extends Control
## Step 1: choose a trainer identity and nickname.

var _selected := 0
var _trainers: Array = []
var _preview: ModelPreview
var _name_edit: LineEdit
var _title_label: Label
var _subtitle_label: Label
var _meta_label: Label
var _motto_label: Label
var _style_label: Label
var _hometown_label: Label
var _buttons: Array[Button] = []
var _content: HBoxContainer
var _accent_bar: ColorRect
var _on_start_button: Button

func _ready() -> void:
	_trainers = AssetLibrary.trainers
	if GameState.trainer_id() != "":
		var ids := AssetLibrary.trainer_ids()
		var idx := ids.find(GameState.trainer_id())
		if idx >= 0:
			_selected = idx
	_build()
	AudioManager.play_music("menu", 0.7)
	_select(_selected, false)
	_animate_in()

func _build() -> void:
	var bg := UIKit.background("starter")
	add_child(bg)
	var particles := UIKit.particle_field(44, 0.4)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var column := UIKit.vbox(16)
	margin.add_child(column)

	var header := UIKit.hbox(18)
	column.add_child(header)
	var back := UIKit.button("< Back", "ghost", "", 42)
	back.custom_minimum_size = Vector2(106, 42)
	back.pressed.connect(_on_back)
	header.add_child(back)
	var titles := UIKit.vbox(0)
	header.add_child(titles)
	var kicker := UIKit.small("STEP 1 OF 2  •  TRAINER PROFILE", Color(0.75, 0.9, 1.0, 0.8))
	kicker.add_theme_constant_override("letter_spacing", 2)
	titles.add_child(kicker)
	titles.add_child(UIKit.title("WHO WILL YOU BE?", 46))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)
	var step_panel := UIKit.panel(Color(0.05, 0.09, 0.18, 0.75), Color(0.55, 0.9, 1.0, 0.2), 10)
	var step_row := UIKit.hbox(8)
	step_panel.add_child(step_row)
	step_row.add_child(_step_dot(true))
	step_row.add_child(_step_dot(false))
	header.add_child(step_panel)

	_content = UIKit.hbox(20)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	# Preview card
	var preview_card := UIKit.card(Color(0.035, 0.06, 0.13, 0.82), Color(0.55, 0.88, 1.0, 0.18))
	preview_card.custom_minimum_size = Vector2(500, 0)
	preview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(preview_card)
	var preview_box := UIKit.vbox(0)
	preview_card.add_child(preview_box)
	_preview = ModelPreview.new()
	_preview.custom_minimum_size = Vector2(0, 390)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_child(_preview)
	var preview_footer := UIKit.hbox(10)
	preview_box.add_child(preview_footer)
	var ball := UIKit.pokeball(30, 0.4)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_footer.add_child(ball)
	var preview_note := UIKit.small("Rotating live model  •  procedural PBR sculpt", Color(0.68, 0.8, 1.0, 0.65))
	preview_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_footer.add_child(preview_note)

	# Details card
	var details := UIKit.card(Color(0.04, 0.07, 0.15, 0.88), Color(1, 1, 1, 0.1))
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(details)
	var detail_box := UIKit.vbox(10)
	details.add_child(detail_box)

	var name_row := UIKit.hbox(12)
	detail_box.add_child(name_row)
	var name_box := UIKit.vbox(0)
	name_row.add_child(name_box)
	_title_label = UIKit.label("Kai", 40, UIKit.PAPER)
	name_box.add_child(_title_label)
	_subtitle_label = UIKit.label("Blazing Rookie", 18, UIKit.GOLD)
	name_box.add_child(_subtitle_label)
	var name_flex := Control.new()
	name_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_flex)
	var badge := UIKit.panel(Color(0.09, 0.16, 0.3, 0.9), Color(0.55, 0.9, 1.0, 0.3), 10)
	var badge_row := UIKit.hbox(8)
	badge.add_child(badge_row)
	badge_row.add_child(UIKit.pokeball(24, 0.6, Color("#ffd05a")))
	_style_label = UIKit.label("BALANCED", 13, Color(0.8, 0.9, 1.0, 0.9))
	_style_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_row.add_child(_style_label)
	name_row.add_child(badge)

	detail_box.add_child(UIKit.separator(Color(1, 1, 1, 0.08), 1))

	var meta_row := UIKit.hbox(24)
	detail_box.add_child(meta_row)
	var home_box := UIKit.vbox(1)
	meta_row.add_child(home_box)
	home_box.add_child(UIKit.small("HOMETOWN", Color(0.62, 0.75, 1.0, 0.55)))
	_hometown_label = UIKit.label("Ember Town", 17, UIKit.PAPER)
	home_box.add_child(_hometown_label)
	var meta_box := UIKit.vbox(1)
	meta_row.add_child(meta_box)
	meta_box.add_child(UIKit.small("PARTNER STYLE", Color(0.62, 0.75, 1.0, 0.55)))
	_meta_label = UIKit.label("Balanced", 17, UIKit.PAPER)
	meta_box.add_child(_meta_label)

	var quote_panel := UIKit.panel(Color(0.08, 0.12, 0.24, 0.72), Color(1, 1, 1, 0.08), 12)
	detail_box.add_child(quote_panel)
	_motto_label = UIKit.label("“Go big, or go home!”", 18, Color(0.86, 0.93, 1.0, 0.92))
	_motto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_panel.add_child(_motto_label)

	detail_box.add_child(UIKit.spacer(4))
	detail_box.add_child(UIKit.small("TRAINER NAME", Color(0.62, 0.75, 1.0, 0.6)))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Enter your trainer name"
	_name_edit.max_length = 18
	_name_edit.text = GameState.trainer_name() if GameState.trainer_name() != "" else "Riley"
	_name_edit.custom_minimum_size = Vector2(0, 48)
	_name_edit.text_submitted.connect(func(_t): _on_start())
	detail_box.add_child(_name_edit)
	var hint := UIKit.small("This name appears on your save file and battle intro.", Color(0.6, 0.7, 0.9, 0.55))
	detail_box.add_child(hint)

	detail_box.add_child(UIKit.spacer(6))
	_on_start_button = UIKit.button("Continue to Partner", "primary", "", 56)
	_on_start_button.pressed.connect(_on_start)
	detail_box.add_child(_on_start_button)

	# Carousel
	var carousel_head := UIKit.hbox(10)
	column.add_child(carousel_head)
	carousel_head.add_child(UIKit.small("SELECT A TRAINER", Color(0.7, 0.84, 1.0, 0.65)))
	var line := UIKit.separator(Color(1, 1, 1, 0.08), 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carousel_head.add_child(line)

	var carousel := UIKit.hbox(10)
	column.add_child(carousel)
	for i in _trainers.size():
		var data: Dictionary = _trainers[i]
		var button := UIKit.button("", "glass", "", 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [str(data.get("name", "Trainer")), str(data.get("title", ""))]
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select.bind(i))
		carousel.add_child(button)
		_buttons.append(button)

	var footer := UIKit.hbox(16)
	column.add_child(footer)
	footer.add_child(UIHelpers.key_hint("ENTER", "Confirm"))
	footer.add_child(UIHelpers.key_hint("ESC", "Back"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	footer.add_child(UIKit.small("Trainer portraits are original procedural models.", Color(0.6, 0.7, 0.9, 0.45)))

func _step_dot(active: bool) -> Control:
	var dot := PanelContainer.new()
	var style := UIKit.style_box(UIKit.GOLD if active else Color(0.2, 0.28, 0.44, 0.9), Color(1, 1, 1, 0.2), 5, 1, 0, 0)
	dot.add_theme_stylebox_override("panel", style)
	dot.custom_minimum_size = Vector2(26 if active else 12, 8)
	return dot

func _select(index: int, play_sound: bool = true) -> void:
	if _trainers.is_empty():
		return
	_selected = clampi(index, 0, _trainers.size() - 1)
	var data: Dictionary = _trainers[_selected]
	_preview.set_trainer(data)
	_preview.set_accent(Color(str(data.get("accent", "#78e2ff"))))
	_title_label.text = str(data.get("name", "Trainer"))
	_subtitle_label.text = str(data.get("title", "Pokémon Trainer"))
	_style_label.text = str(data.get("style", "Balanced")).to_upper()
	_meta_label.text = str(data.get("style", "Balanced"))
	_hometown_label.text = str(data.get("hometown", "Unknown"))
	_motto_label.text = "“%s”" % str(data.get("motto", "..."))
	for i in _buttons.size():
		var button := _buttons[i]
		var variant := "primary" if i == _selected else "glass"
		UIKit._apply_button_variant(button, variant)
	if play_sound:
		AudioManager.play_sfx("hover")

func _on_start() -> void:
	var trainer_name := _name_edit.text.strip_edges()
	if trainer_name.length() < 1:
		UIKit.toast("Please enter a trainer name.", UIKit.RED)
		_name_edit.grab_focus()
		return
	if trainer_name.length() > 18:
		trainer_name = trainer_name.substr(0, 18)
	var data: Dictionary = _trainers[_selected]
	GameState.set_trainer(str(data.get("id", "kai")), trainer_name)
	AudioManager.play_sfx("confirm")
	SceneRouter.goto("res://scenes/ui/starter_select.tscn", 0.4, "CHOOSING PARTNER")

func _on_back() -> void:
	AudioManager.play_sfx("back")
	SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.35, "MAIN MENU")

func _animate_in() -> void:
	_content.modulate = Color(1, 1, 1, 0)
	_content.position.y = 18
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_content, "modulate:a", 1.0, 0.45)
	tw.tween_property(_content, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	elif event.is_action_pressed("ui_accept") and not _name_edit.has_focus():
		_on_start()
