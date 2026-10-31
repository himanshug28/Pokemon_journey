extends Control
## Step 2: pick the first partner from the five starters.

var _selected := 0
var _species: Array[PokemonData] = []
var _preview: ModelPreview
var _name_label: Label
var _dex_label: Label
var _types: HBoxContainer
var _description: Label
var _stats_box: VBoxContainer
var _moves_grid: GridContainer
var _choose_button: Button
var _cards: Array[Button] = []
var _content: HBoxContainer
var _subtitle: Label

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto("res://scenes/ui/trainer_select.tscn", 0.3, "TRAINER SELECT")
		return
	for id in GameState.POKEMON_ORDER:
		var species := AssetLibrary.get_pokemon(id)
		if species != null:
			_species.append(species)
	_build()
	AudioManager.play_music("menu", 0.7)
	_select(0, false)
	_animate_in()

func _build() -> void:
	var bg := UIKit.background("starter")
	add_child(bg)
	var particles := UIKit.particle_field(46, 0.42)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var column := UIKit.vbox(14)
	margin.add_child(column)

	var header := UIKit.hbox(18)
	column.add_child(header)
	var back := UIKit.button("< Back", "ghost", "", 42)
	back.custom_minimum_size = Vector2(106, 42)
	back.pressed.connect(_on_back)
	header.add_child(back)
	var titles := UIKit.vbox(0)
	header.add_child(titles)
	var kicker := UIKit.small("STEP 2 OF 2  •  FIRST PARTNER", Color(0.75, 0.9, 1.0, 0.8))
	kicker.add_theme_constant_override("letter_spacing", 2)
	titles.add_child(kicker)
	titles.add_child(UIKit.title("CHOOSE YOUR FIRST PARTNER", 44))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)
	_subtitle = UIKit.small("Trainer: %s" % GameState.trainer_name(), Color(0.82, 0.92, 1.0, 0.8))
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_subtitle)

	_content = UIKit.hbox(20)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var preview_card := UIKit.card(Color(0.035, 0.06, 0.13, 0.82), Color(0.55, 0.88, 1.0, 0.18))
	preview_card.custom_minimum_size = Vector2(540, 0)
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
	var ball := UIKit.pokeball(28, 0.5)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_footer.add_child(ball)
	var note := UIKit.small("All five partners are available for your first pick.", Color(0.68, 0.8, 1.0, 0.65))
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_footer.add_child(note)

	var details := UIKit.card(Color(0.04, 0.07, 0.15, 0.9), Color(1, 1, 1, 0.1))
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(details)
	var detail_box := UIKit.vbox(8)
	details.add_child(detail_box)

	var head := UIKit.hbox(12)
	detail_box.add_child(head)
	var name_box := UIKit.vbox(0)
	head.add_child(name_box)
	_name_label = UIKit.label("Charizard", 40, UIKit.PAPER)
	name_box.add_child(_name_label)
	_dex_label = UIKit.label("DEX #006", 13, Color(0.7, 0.82, 1.0, 0.7))
	_dex_label.add_theme_constant_override("letter_spacing", 2)
	name_box.add_child(_dex_label)
	var head_flex := Control.new()
	head_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_flex)
	_types = UIKit.hbox(6)
	_types.alignment = BoxContainer.ALIGNMENT_END
	_types.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_types)

	_description = UIKit.small("", Color(0.82, 0.9, 1.0, 0.88))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(0, 46)
	detail_box.add_child(_description)

	var stats_head := UIKit.hbox(8)
	detail_box.add_child(stats_head)
	stats_head.add_child(UIKit.small("BASE STATS", Color(0.62, 0.75, 1.0, 0.55)))
	var stats_line := UIKit.separator(Color(1, 1, 1, 0.07), 1)
	stats_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_head.add_child(stats_line)

	_stats_box = UIKit.vbox(4)
	detail_box.add_child(_stats_box)

	var moves_head := UIKit.hbox(8)
	detail_box.add_child(moves_head)
	moves_head.add_child(UIKit.small("SIGNATURE MOVES", Color(0.62, 0.75, 1.0, 0.55)))
	var moves_line := UIKit.separator(Color(1, 1, 1, 0.07), 1)
	moves_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moves_head.add_child(moves_line)

	_moves_grid = GridContainer.new()
	_moves_grid.columns = 2
	_moves_grid.add_theme_constant_override("h_separation", 8)
	_moves_grid.add_theme_constant_override("v_separation", 6)
	detail_box.add_child(_moves_grid)

	var choose_flex := Control.new()
	choose_flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(choose_flex)
	_choose_button = UIKit.button("Choose Partner", "primary", "", 54)
	_choose_button.pressed.connect(_on_choose)
	detail_box.add_child(_choose_button)

	var carousel_head := UIKit.hbox(10)
	column.add_child(carousel_head)
	carousel_head.add_child(UIKit.small("STARTER PARTNERS", Color(0.7, 0.84, 1.0, 0.65)))
	var line := UIKit.separator(Color(1, 1, 1, 0.08), 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carousel_head.add_child(line)

	var carousel := UIKit.hbox(10)
	column.add_child(carousel)
	for i in _species.size():
		var species := _species[i]
		var button := UIKit.button("", "glass", "", 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [species.display_name, species.type_label()]
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select.bind(i))
		carousel.add_child(button)
		_cards.append(button)

	var footer := UIKit.hbox(16)
	column.add_child(footer)
	footer.add_child(UIHelpers.key_hint("ENTER", "Choose"))
	footer.add_child(UIHelpers.key_hint("ESC", "Back"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	footer.add_child(UIKit.small("Your starter is always unlocked. Win matches to unlock the rest.", Color(0.6, 0.7, 0.9, 0.45)))

func _select(index: int, play_sound: bool = true) -> void:
	if _species.is_empty():
		return
	_selected = clampi(index, 0, _species.size() - 1)
	var species := _species[_selected]
	_preview.set_pokemon(species.id)
	var accent := TypeChart.type_color(species.primary_type)
	_preview.set_accent(accent)
	_name_label.text = species.display_name
	_dex_label.text = "DEX #%03d  •  %s" % [species.dex_number, species.type_label().to_upper()]
	_description.text = species.description
	for child in _types.get_children():
		child.queue_free()
	for type_name in species.types():
		_types.add_child(UIKit.type_badge(type_name, true))
	for child in _stats_box.get_children():
		child.queue_free()
	_stats_box.add_child(UIHelpers.stat_row("HP", species.base_hp, 160, Color("#61dd78")))
	_stats_box.add_child(UIHelpers.stat_row("Attack", species.attack, 160, Color("#ff9a3d")))
	_stats_box.add_child(UIHelpers.stat_row("Defense", species.defense, 160, Color("#78e2ff")))
	_stats_box.add_child(UIHelpers.stat_row("Speed", species.speed, 160, Color("#ffd05a")))
	for child in _moves_grid.get_children():
		child.queue_free()
	for move in species.moves:
		_moves_grid.add_child(UIHelpers.move_chip(move, true))
	_choose_button.text = "Choose %s" % species.display_name
	for i in _cards.size():
		var variant := "primary" if i == _selected else "glass"
		UIKit._apply_button_variant(_cards[i], variant)
	if play_sound:
		AudioManager.play_sfx("hover")

func _on_choose() -> void:
	if _species.is_empty():
		return
	var species := _species[_selected]
	GameState.choose_starter(species.id)
	AudioManager.play_sfx("unlock")
	AudioManager.play_cry(species.id, species.battle_cry_pitch)
	SceneRouter.goto("res://scenes/arenas/stadium_playground.tscn", 0.6, "WELCOME, %s" % GameState.trainer_name().to_upper())

func _on_back() -> void:
	AudioManager.play_sfx("back")
	SceneRouter.goto("res://scenes/ui/trainer_select.tscn", 0.35, "TRAINER SELECT")

func _animate_in() -> void:
	_content.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, 0.45)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	elif event.is_action_pressed("ui_accept"):
		_on_choose()
