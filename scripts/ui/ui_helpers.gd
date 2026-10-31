class_name UIHelpers
extends RefCounted
## Small reusable UI builders shared by menus, collection and battle screens.

static func stat_row(stat_name: String, value: int, maximum: int = 150, color: Color = Color("#78e2ff")) -> HBoxContainer:
	var row := UIKit.hbox(12)
	var name_label := UIKit.label(stat_name.to_upper(), 12, UIKit.MUTED)
	name_label.custom_minimum_size = Vector2(92, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = clampi(value, 0, maximum)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := UIKit.style_box(Color(0.03, 0.05, 0.1, 0.9), Color(1, 1, 1, 0.07), 5, 1, 0, 0)
	var fill := UIKit.style_box(color, Color(1, 1, 1, 0.18), 5, 0, 0, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var value_label := UIKit.label(str(value), 14, UIKit.PAPER)
	value_label.custom_minimum_size = Vector2(38, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row

static func stat_block(species: PokemonData) -> VBoxContainer:
	var box := UIKit.vbox(7)
	box.add_child(stat_row("HP", species.base_hp, 160, Color("#61dd78")))
	box.add_child(stat_row("Attack", species.attack, 160, Color("#ff9a3d")))
	box.add_child(stat_row("Defense", species.defense, 160, Color("#78e2ff")))
	box.add_child(stat_row("Speed", species.speed, 160, Color("#ffd05a")))
	return box

static func type_row(types: Array, compact: bool = false) -> HBoxContainer:
	var row := UIKit.hbox(6)
	for type_name in types:
		row.add_child(UIKit.type_badge(str(type_name), compact))
	return row

static func move_chip(move: MoveData, compact: bool = false) -> PanelContainer:
	var card := UIKit.panel(Color(0.045, 0.075, 0.15, 0.9), Color(1, 1, 1, 0.08), 12)
	var row := UIKit.hbox(10)
	var info := UIKit.vbox(1)
	var name_label := UIKit.label(move.display_name, 15 if not compact else 13, UIKit.PAPER)
	info.add_child(name_label)
	var sub := UIKit.small("Power %d  •  %d PP" % [move.power, move.max_pp], UIKit.MUTED)
	info.add_child(sub)
	row.add_child(info)
	row.add_child(UIKit.type_badge(move.poke_type, true))
	card.add_child(row)
	return card

static func moves_block(species: PokemonData) -> VBoxContainer:
	var box := UIKit.vbox(6)
	for move in species.moves:
		box.add_child(move_chip(move, true))
	return box

static func key_hint(key_text: String, action: String) -> HBoxContainer:
	var row := UIKit.hbox(8)
	var key_panel := UIKit.panel(Color(0.06, 0.1, 0.2, 0.95), Color(1, 1, 1, 0.18), 7)
	key_panel.custom_minimum_size = Vector2(30, 26)
	var key_label := UIKit.label(key_text, 12, UIKit.PAPER)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(key_label)
	row.add_child(key_panel)
	var action_label := UIKit.small(action, UIKit.MUTED)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(action_label)
	return row

static func trainer_title(trainer: Dictionary) -> String:
	var title := str(trainer.get("title", ""))
	return title if title != "" else "Pokémon Trainer"

static func level_text(pokemon_id: String) -> String:
	var progress := GameState.xp_progress(pokemon_id)
	return "Lv. %d" % int(progress.get("level", 5))

static func accent_for_pokemon(pokemon_id: String) -> Color:
	var species := AssetLibrary.get_pokemon(pokemon_id)
	if species == null:
		return UIKit.CYAN
	return TypeChart.type_color(species.primary_type)

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
