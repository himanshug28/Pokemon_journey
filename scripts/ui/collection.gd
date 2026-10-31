extends Control
## Partner collection: locked silhouettes, live previews, stats, moves and active-partner selection.

const SCENE_PATH := "res://scenes/ui/collection.tscn"

var _species: Array[PokemonData] = []
var _selected := 0
var _cards: Array[Button] = []
var _card_row: HBoxContainer
var _preview: ModelPreview
var _preview_holder: Control
var _locked_holder: Control
var _locked_sil: PokemonSilhouette
var _locked_hint: Label
var _preview_caption: Label
var _name_label: Label
var _dex_label: Label
var _types: HBoxContainer
var _description: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _xp_box: VBoxContainer
var _stats_box: VBoxContainer
var _moves_grid: GridContainer
var _moves_note: Label
var _set_button: Button
var _active_chip: Label
var _content: HBoxContainer
var _summary_label: Label

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.3, "MAIN MENU")
		return
	for id in GameState.POKEMON_ORDER:
		var species := AssetLibrary.get_pokemon(id)
		if species != null:
			_species.append(species)
	_build()
	AudioManager.play_music("menu", 0.7)
	var start_index := 0
	var active := GameState.active_pokemon()
	for i in _species.size():
		if _species[i].id == active:
			start_index = i
			break
	_refresh_cards()
	_select(start_index, false)
	_animate_in()

# ------------------------------------------------------------------ layout

func _build() -> void:
	var bg := UIKit.background("collection")
	add_child(bg)
	var particles := UIKit.particle_field(48, 0.4)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var column := UIKit.vbox(12)
	margin.add_child(column)

	var header := UIKit.hbox(16)
	column.add_child(header)
	var back := UIKit.button("< Back", "ghost", "", 44)
	back.custom_minimum_size = Vector2(108, 44)
	back.pressed.connect(_go_back)
	header.add_child(back)

	var titles := UIKit.vbox(0)
	header.add_child(titles)
	var kicker := UIKit.small("PARTNER COLLECTION  •  BOND ARCHIVE", Color(0.7, 0.9, 1.0, 0.78))
	kicker.add_theme_constant_override("letter_spacing", 3)
	titles.add_child(kicker)
	titles.add_child(UIKit.title("YOUR PARTNERS", 46, UIKit.GOLD))

	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)

	var stats := UIKit.hbox(10)
	header.add_child(stats)
	stats.add_child(_header_stat("UNLOCKED", "%d / %d" % [GameState.unlocked_pokemon().size(), _species.size()], UIKit.MINT))
	stats.add_child(_header_stat("WINS", str(GameState.regular_wins()), UIKit.CYAN))
	stats.add_child(_header_stat("ROCKET BADGES", str(GameState.rocket_badges()), Color("#ff8a95")))

	_card_row = UIKit.hbox(10)
	column.add_child(_card_row)

	_content = UIKit.hbox(18)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var preview_card := UIKit.card(Color(0.03, 0.055, 0.12, 0.86), Color(0.55, 0.9, 1.0, 0.2))
	preview_card.custom_minimum_size = Vector2(470, 0)
	preview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(preview_card)
	var preview_box := UIKit.vbox(0)
	preview_card.add_child(preview_box)

	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 320)
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.clip_contents = true
	preview_box.add_child(_preview_holder)

	_preview = ModelPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_holder.add_child(_preview)

	_locked_holder = Control.new()
	_locked_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_locked_holder.visible = false
	_preview_holder.add_child(_locked_holder)
	var locked_center := CenterContainer.new()
	locked_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_locked_holder.add_child(locked_center)
	var locked_box := UIKit.vbox(4)
	locked_box.alignment = BoxContainer.ALIGNMENT_CENTER
	locked_center.add_child(locked_box)
	_locked_sil = UIKit.silhouette("pikachu", Color(0.75, 0.45, 1.0, 0.26))
	_locked_sil.custom_minimum_size = Vector2(220, 220)
	_locked_sil.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	locked_box.add_child(_locked_sil)
	_locked_hint = UIKit.label("SIGNAL LOCKED", 18, Color("#c9b8ff"))
	_locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_box.add_child(_locked_hint)

	var preview_footer := UIKit.hbox(10)
	preview_box.add_child(preview_footer)
	var ball := UIKit.pokeball(26, 0.5, Color("#78e2ff"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_footer.add_child(ball)
	_preview_caption = UIKit.small("LIVE 3D PREVIEW", Color(0.68, 0.84, 1.0, 0.62))
	_preview_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_footer.add_child(_preview_caption)
	var preview_flex := Control.new()
	preview_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_footer.add_child(preview_flex)
	preview_footer.add_child(UIKit.small("Original procedural sculpt", Color(0.6, 0.72, 0.92, 0.42)))

	var details := UIKit.card(Color(0.035, 0.065, 0.14, 0.94), Color(1, 1, 1, 0.11))
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(details)
	var detail_box := UIKit.vbox(7)
	details.add_child(detail_box)

	var head := UIKit.hbox(12)
	detail_box.add_child(head)
	var name_box := UIKit.vbox(0)
	head.add_child(name_box)
	_name_label = UIKit.label("Partner", 38, UIKit.PAPER)
	name_box.add_child(_name_label)
	_dex_label = UIKit.label("DEX #000", 12, Color(0.68, 0.82, 1.0, 0.7))
	_dex_label.add_theme_constant_override("letter_spacing", 2)
	name_box.add_child(_dex_label)
	var head_flex := Control.new()
	head_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_flex)
	_types = UIKit.hbox(6)
	_types.alignment = BoxContainer.ALIGNMENT_END
	_types.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_types)

	_description = UIKit.label("", 15, Color(0.83, 0.91, 1.0, 0.9), true)
	_description.custom_minimum_size = Vector2(0, 44)
	detail_box.add_child(_description)

	_xp_box = UIKit.vbox(3)
	detail_box.add_child(_xp_box)
	var xp_head := UIKit.hbox(8)
	_xp_box.add_child(xp_head)
	xp_head.add_child(UIKit.small("BOND PROGRESS", Color(0.64, 0.78, 1.0, 0.6)))
	var xp_flex := Control.new()
	xp_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_head.add_child(xp_flex)
	_xp_label = UIKit.small("", Color(0.78, 0.9, 1.0, 0.8))
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_head.add_child(_xp_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.max_value = 100.0
	_xp_bar.value = 0.0
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 12)
	_xp_bar.add_theme_stylebox_override("background", UIKit.style_box(Color(0.03, 0.05, 0.1, 0.9), Color(1, 1, 1, 0.07), 6, 1, 0, 0))
	_xp_bar.add_theme_stylebox_override("fill", UIKit.style_box(UIKit.CYAN, Color(1, 1, 1, 0.22), 6, 0, 0, 0))
	_xp_box.add_child(_xp_bar)

	var stats_head := UIKit.hbox(8)
	detail_box.add_child(stats_head)
	stats_head.add_child(UIKit.small("BASE STATS", Color(0.64, 0.78, 1.0, 0.55)))
	var stats_line := UIKit.separator(Color(1, 1, 1, 0.07), 1)
	stats_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_head.add_child(stats_line)
	_stats_box = UIKit.vbox(3)
	detail_box.add_child(_stats_box)

	var moves_head := UIKit.hbox(8)
	detail_box.add_child(moves_head)
	moves_head.add_child(UIKit.small("SIGNATURE MOVES", Color(0.64, 0.78, 1.0, 0.55)))
	var moves_line := UIKit.separator(Color(1, 1, 1, 0.07), 1)
	moves_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moves_head.add_child(moves_line)
	_moves_note = UIKit.small("", Color(0.62, 0.72, 0.92, 0.55))
	_moves_note.visible = false
	detail_box.add_child(_moves_note)
	_moves_grid = GridContainer.new()
	_moves_grid.columns = 2
	_moves_grid.add_theme_constant_override("h_separation", 8)
	_moves_grid.add_theme_constant_override("v_separation", 6)
	detail_box.add_child(_moves_grid)

	var action_flex := Control.new()
	action_flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(action_flex)
	var actions := UIKit.hbox(10)
	detail_box.add_child(actions)
	_active_chip = UIKit.small("", Color(0.72, 0.9, 1.0, 0.7))
	_active_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_child(_active_chip)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	_set_button = UIKit.button("Set as Active Partner", "primary", "", 48)
	_set_button.custom_minimum_size = Vector2(290, 48)
	_set_button.pressed.connect(_set_active)
	actions.add_child(_set_button)

	var footer := UIKit.hbox(18)
	column.add_child(footer)
	footer.add_child(UIHelpers.key_hint("ESC", "Back"))
	footer.add_child(UIHelpers.key_hint("1-5", "Select partner"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	_summary_label = UIKit.small(GameState.summary_line(), Color(0.62, 0.76, 0.95, 0.55))
	footer.add_child(_summary_label)

func _header_stat(kicker: String, value: String, color: Color) -> PanelContainer:
	var card := UIKit.panel(Color(0.035, 0.06, 0.13, 0.75), Color(1, 1, 1, 0.08), 12)
	var box := UIKit.vbox(0)
	card.add_child(box)
	var k := UIKit.small(kicker, Color(0.64, 0.78, 1.0, 0.6))
	k.add_theme_constant_override("letter_spacing", 1)
	box.add_child(k)
	box.add_child(UIKit.label(value, 20, color))
	return card

# ------------------------------------------------------------------ cards

func _refresh_cards() -> void:
	if _card_row == null:
		return
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	for i in _species.size():
		var species := _species[i]
		var unlocked := GameState.is_unlocked(species.id)
		var active := GameState.active_pokemon() == species.id
		var button := UIKit.button("", "primary" if i == _selected else "glass", "", 190)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 190)
		button.pressed.connect(_select.bind(i))
		_card_row.add_child(button)
		_cards.append(button)

		var margin := UIKit.margin(UIKit.vbox(1), 7)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var box := margin.get_child(0) as VBoxContainer
		box.alignment = BoxContainer.ALIGNMENT_CENTER

		var sil := UIKit.silhouette(species.id, TypeChart.type_color(species.primary_type) * Color(1, 1, 1, 0.32 if unlocked else 0.12))
		sil.custom_minimum_size = Vector2(88, 88)
		sil.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sil.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.55)
		box.add_child(sil)
		sil.custom_minimum_size = Vector2(88, 88)

		var name_label := UIKit.label(species.display_name if unlocked else "???", 18, UIKit.PAPER if unlocked else Color(0.72, 0.7, 0.9, 0.7))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)

		var sub := UIKit.small(
			"Lv. %d  •  %s" % [int(GameState.xp_progress(species.id).get("level", 5)), species.type_label()] if unlocked else species.requirement_text(),
			Color(0.72, 0.86, 1.0, 0.7) if unlocked else Color(0.82, 0.7, 0.95, 0.7)
		)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(0, 26)
		box.add_child(sub)

		var tag_text := "ACTIVE PARTNER" if active else ("UNLOCKED" if unlocked else "LOCKED")
		var tag_color := UIKit.GOLD if active else (UIKit.MINT if unlocked else Color("#c9a8ff"))
		var tag := UIKit.small(tag_text, tag_color)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_constant_override("letter_spacing", 1)
		box.add_child(tag)

func _select(index: int, play_sound: bool = true) -> void:
	if _species.is_empty():
		return
	_selected = clampi(index, 0, _species.size() - 1)
	_refresh_cards()
	_refresh_details()
	if play_sound:
		AudioManager.play_sfx("hover")

func _refresh_details() -> void:
	if _species.is_empty():
		return
	var species := _species[_selected]
	var unlocked := GameState.is_unlocked(species.id)
	var active := GameState.active_pokemon() == species.id
	var accent := TypeChart.type_color(species.primary_type)

	_preview.visible = unlocked
	_locked_holder.visible = not unlocked
	_preview_caption.text = "LIVE 3D PREVIEW" if unlocked else "LOCKED SIGNAL"
	if unlocked:
		_preview.set_pokemon(species.id)
		_preview.set_accent(accent)
	else:
		_locked_sil.pokemon_id = species.id
		_locked_sil.glow_color = Color(0.72, 0.46, 1.0, 0.24)
		_locked_hint.text = "SIGNAL LOCKED"

	_name_label.text = species.display_name if unlocked else "Unknown Partner"
	_name_label.add_theme_color_override("font_color", UIKit.PAPER if unlocked else Color(0.78, 0.72, 0.92))
	_dex_label.text = "DEX #%03d  •  %s" % [species.dex_number, species.type_label().to_upper()]
	for child in _types.get_children():
		child.queue_free()
	for type_name in species.types():
		_types.add_child(UIKit.type_badge(type_name, true))

	if unlocked:
		_description.text = species.description
	else:
		_description.text = "This partner has not joined your journey yet. %s to add them to your collection." % species.requirement_text()

	_xp_box.visible = unlocked
	if unlocked:
		var progress := GameState.xp_progress(species.id)
		var level := int(progress.get("level", 5))
		var current := int(progress.get("current", 0))
		var needed := maxi(1, int(progress.get("needed", 1)))
		_xp_label.text = "Lv. %d  •  %d / %d XP" % [level, current, needed]
		_xp_bar.value = clampf(float(current) / float(needed) * 100.0, 0.0, 100.0)
		_xp_bar.add_theme_stylebox_override("fill", UIKit.style_box(accent, Color(1, 1, 1, 0.22), 6, 0, 0, 0))

	for child in _stats_box.get_children():
		child.queue_free()
	_stats_box.add_child(UIHelpers.stat_row("HP", species.base_hp, 160, Color("#61dd78")))
	_stats_box.add_child(UIHelpers.stat_row("Attack", species.attack, 160, Color("#ff9a3d")))
	_stats_box.add_child(UIHelpers.stat_row("Defense", species.defense, 160, Color("#78e2ff")))
	_stats_box.add_child(UIHelpers.stat_row("Speed", species.speed, 160, Color("#ffd05a")))
	_stats_box.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.55)

	for child in _moves_grid.get_children():
		child.queue_free()
	if unlocked:
		_moves_note.visible = false
		for move in species.moves:
			_moves_grid.add_child(UIHelpers.move_chip(move, true))
	else:
		_moves_note.visible = true
		_moves_note.text = "Moves, stats and bond progress are revealed when this partner joins you."
		_moves_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not unlocked:
		_set_button.text = "Locked"
		_set_button.disabled = true
		_active_chip.text = "LOCKED PARTNER"
		_active_chip.add_theme_color_override("font_color", Color(0.82, 0.7, 0.95, 0.7))
	elif active:
		_set_button.text = "Current Partner"
		_set_button.disabled = true
		_active_chip.text = "ACTIVE PARTNER  •  READY FOR BATTLE"
		_active_chip.add_theme_color_override("font_color", UIKit.GOLD)
	else:
		_set_button.text = "Set as Active Partner"
		_set_button.disabled = false
		_active_chip.text = "AVAILABLE PARTNER"
		_active_chip.add_theme_color_override("font_color", UIKit.MINT)
	_summary_label.text = GameState.summary_line()

func _set_active() -> void:
	if _species.is_empty():
		return
	var species := _species[_selected]
	if not GameState.is_unlocked(species.id):
		AudioManager.play_sfx("cancel")
		UIKit.toast("Win more matches to unlock %s." % species.display_name, Color("#c9a8ff"), 3.0)
		return
	if GameState.set_active_pokemon(species.id):
		AudioManager.play_sfx("unlock", -3.0)
		AudioManager.play_cry(species.id, species.battle_cry_pitch)
		UIKit.toast("%s is now your active partner." % species.display_name, UIKit.GOLD, 2.8)
		_refresh_cards()
		_refresh_details()

# ------------------------------------------------------------------ navigation

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
	if SceneRouter.transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
		return
	for i in 5:
		if event.is_action_pressed("battle_move_%d" % (i + 1)):
			_select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept"):
		_set_active()
		get_viewport().set_input_as_handled()
