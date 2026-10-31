extends Control
## Exhibition match picker - watch two Pokemon fight each other.

const SPECIES := ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]

var _player_index := 0
var _enemy_index := 1
var _player_level := 10
var _enemy_level := 10

var _player_preview: ModelPreview
var _enemy_preview: ModelPreview
var _player_name: Label
var _enemy_name: Label
var _player_level_label: Label
var _enemy_level_label: Label

func _ready() -> void:
	_build()
	AudioManager.play_music("menu", 0.7)
	_update_previews()

func _build() -> void:
	var bg := UIKit.background("starter")
	add_child(bg)
	var particles := UIKit.particle_field(40, 0.4)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var root := UIKit.vbox(18)
	margin.add_child(root)

	var header := UIKit.hbox(12)
	root.add_child(header)
	var ball := UIKit.pokeball(36, 0.7)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(ball)
	var title := UIKit.title("EXHIBITION MATCH", 56, UIKit.GOLD)
	header.add_child(title)
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(flex)
	var back := UIKit.button("Back", "ghost", "", 44)
	back.pressed.connect(_back)
	header.add_child(back)

	root.add_child(UIKit.label("Watch two Pokemon battle each other - no XP or progression changes", 16, UIKit.MUTED))

	var main := UIKit.hbox(28)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	# Player side
	var player_panel := UIKit.panel(Color(0.03, 0.06, 0.12, 0.88), Color(0.47, 0.89, 1.0, 0.24), 22)
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(player_panel)
	var pbox := UIKit.vbox(10)
	player_panel.add_child(pbox)
	pbox.add_child(UIKit.label("LEFT FIGHTER", 13, Color(0.72, 0.88, 1.0, 0.7)))
	_player_name = UIKit.label("Pikachu", 28, UIKit.PAPER)
	pbox.add_child(_player_name)
	_player_preview = ModelPreview.new()
	_player_preview.custom_minimum_size = Vector2(0, 380)
	_player_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pbox.add_child(_player_preview)
	var prow := UIKit.hbox(8)
	pbox.add_child(prow)
	var pl := UIKit.button("<", "glass", "", 42)
	pl.pressed.connect(func(): _change_player(-1))
	prow.add_child(pl)
	var pr := UIKit.button(">", "glass", "", 42)
	pr.pressed.connect(func(): _change_player(1))
	prow.add_child(pr)
	_player_level_label = UIKit.label("Lv. 10", 18, UIKit.CYAN)
	prow.add_child(_player_level_label)
	var plm := UIKit.button("-", "glass", "", 42)
	plm.pressed.connect(func(): _change_level(true, -1))
	prow.add_child(plm)
	var plp := UIKit.button("+", "glass", "", 42)
	plp.pressed.connect(func(): _change_level(true, 1))
	prow.add_child(plp)
	var flexp := Control.new()
	flexp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(flexp)
	var prad := UIKit.button("Random", "ghost", "", 42)
	prad.pressed.connect(func(): _randomize(true))
	prow.add_child(prad)

	# VS
	var vs_box := UIKit.vbox(10)
	vs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(vs_box)
	vs_box.add_child(UIKit.title("VS", 64, UIKit.GOLD))

	# Enemy side
	var enemy_panel := UIKit.panel(Color(0.03, 0.06, 0.12, 0.88), Color(1.0, 0.45, 0.5, 0.24), 22)
	enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(enemy_panel)
	var ebox := UIKit.vbox(10)
	enemy_panel.add_child(ebox)
	ebox.add_child(UIKit.label("RIGHT FIGHTER", 13, Color(1.0, 0.72, 0.75, 0.7)))
	_enemy_name = UIKit.label("Bulbasaur", 28, UIKit.PAPER)
	ebox.add_child(_enemy_name)
	_enemy_preview = ModelPreview.new()
	_enemy_preview.custom_minimum_size = Vector2(0, 380)
	_enemy_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ebox.add_child(_enemy_preview)
	var erow := UIKit.hbox(8)
	ebox.add_child(erow)
	var el := UIKit.button("<", "glass", "", 42)
	el.pressed.connect(func(): _change_enemy(-1))
	erow.add_child(el)
	var er := UIKit.button(">", "glass", "", 42)
	er.pressed.connect(func(): _change_enemy(1))
	erow.add_child(er)
	_enemy_level_label = UIKit.label("Lv. 10", 18, Color("#ff9aa5"))
	erow.add_child(_enemy_level_label)
	var elm := UIKit.button("-", "glass", "", 42)
	elm.pressed.connect(func(): _change_level(false, -1))
	erow.add_child(elm)
	var elp := UIKit.button("+", "glass", "", 42)
	elp.pressed.connect(func(): _change_level(false, 1))
	erow.add_child(elp)
	var flexe := Control.new()
	flexe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(flexe)
	var erad := UIKit.button("Random", "ghost", "", 42)
	erad.pressed.connect(func(): _randomize(false))
	erow.add_child(erad)

	var bottom := UIKit.hbox(10)
	root.add_child(bottom)
	var flexb := Control.new()
	flexb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(flexb)
	var start := UIKit.button("START AUTO BATTLE", "primary", "", 58)
	start.pressed.connect(_start_battle)
	bottom.add_child(start)
	var flexb2 := Control.new()
	flexb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(flexb2)

func _change_player(delta: int) -> void:
	_player_index = (_player_index + delta + SPECIES.size()) % SPECIES.size()
	_update_previews()

func _change_enemy(delta: int) -> void:
	_enemy_index = (_enemy_index + delta + SPECIES.size()) % SPECIES.size()
	_update_previews()

func _change_level(is_player: bool, delta: int) -> void:
	if is_player:
		_player_level = clampi(_player_level + delta * 2, 1, 100)
	else:
		_enemy_level = clampi(_enemy_level + delta * 2, 1, 100)
	_update_previews()

func _randomize(is_player: bool) -> void:
	if is_player:
		_player_index = randi() % SPECIES.size()
	else:
		_enemy_index = randi() % SPECIES.size()
	_update_previews()

func _update_previews() -> void:
	var p_id := SPECIES[_player_index]
	var e_id := SPECIES[_enemy_index]
	if _player_preview != null:
		_player_preview.set_pokemon(p_id)
		_player_preview.set_accent(TypeChart.type_color(AssetLibrary.get_pokemon(p_id).primary_type if AssetLibrary.get_pokemon(p_id) != null else "normal"))
	if _enemy_preview != null:
		_enemy_preview.set_pokemon(e_id)
		_enemy_preview.set_accent(TypeChart.type_color(AssetLibrary.get_pokemon(e_id).primary_type if AssetLibrary.get_pokemon(e_id) != null else "normal"))
	if _player_name != null:
		var ps := AssetLibrary.get_pokemon(p_id)
		_player_name.text = ps.display_name if ps != null else p_id.capitalize()
	if _enemy_name != null:
		var es := AssetLibrary.get_pokemon(e_id)
		_enemy_name.text = es.display_name if es != null else e_id.capitalize()
	if _player_level_label != null:
		_player_level_label.text = "Lv. %d" % _player_level
	if _enemy_level_label != null:
		_enemy_level_label.text = "Lv. %d" % _enemy_level

func _start_battle() -> void:
	AudioManager.play_sfx("confirm")
	var p_id := SPECIES[_player_index]
	var e_id := SPECIES[_enemy_index]
	GameState.pending_battle = {
		"rocket": false,
		"exhibition": true,
		"auto": true,
		"player_species": p_id,
		"enemy_species": e_id,
		"player_level": _player_level,
		"enemy_level": _enemy_level,
		"opponent": {
			"id": "exhibition_opponent",
			"name": (AssetLibrary.get_pokemon(e_id).display_name if AssetLibrary.get_pokemon(e_id) != null else "Opponent"),
			"title": "Exhibition",
			"pokemon": e_id,
			"level": _enemy_level,
			"intro": "Let the exhibition match begin!",
			"defeat": "A great showing!",
			"accent": "#ffd05a",
			"xp": 0,
		},
		"return_scene": "res://scenes/ui/exhibition.tscn",
	}
	SceneRouter.goto("res://scenes/battle/battle_scene.tscn", 0.6, "EXHIBITION BATTLE")

func _back() -> void:
	AudioManager.play_sfx("confirm")
	SceneRouter.goto(GameState.SCENE_MAIN_MENU, 0.4, "MAIN MENU")
