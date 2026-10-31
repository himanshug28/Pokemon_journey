extends Control
## Team Rocket cinematic. Reads GameState.pending_battle, plays the villain dialogue
## and hands the still-pending battle to the 3D battle scene.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const SCENE_PATH := "res://scenes/battle/rocket_intro.tscn"

var _opponent: Dictionary = {}
var _lines: Array[Dictionary] = []
var _line_index := 0
var _typing := false
var _intro_done := false
var _leaving := false

var _content: Control
var _speaker_label: Label
var _dialogue_label: Label
var _counter_label: Label
var _continue_button: Button
var _skip_button: Button
var _battle_button: Button
var _dots: HBoxContainer
var _preview: ModelPreview
var _aura: PanelContainer
var _pulse_time := 0.0
var _title_label: Label
var _subtitle_label: Label

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.3, "MAIN MENU")
		return
	_resolve_opponent()
	_build()
	AudioManager.play_music("rocket", 0.7, true)
	AudioManager.play_ambience("stop", 0.4)
	AudioManager.play_sfx("rocket_alarm", -4.0)
	_show_line(0, false)
	set_process(true)

# ------------------------------------------------------------------ data

func _resolve_opponent() -> void:
	var pending: Dictionary = GameState.pending_battle
	if pending is Dictionary and not pending.is_empty():
		_opponent = pending.get("opponent", {})
		if not _opponent is Dictionary:
			_opponent = {}
	if _opponent.is_empty():
		_opponent = AssetLibrary.get_rocket_opponent(GameState.rocket_events_completed(), GameState.regular_matches_completed())
	if _opponent.is_empty():
		_opponent = {
			"id": "rocket_grunt",
			"name": "Rocket Grunt",
			"title": "Team Rocket",
			"pokemon": "gengar",
			"display_override": "Shadow Gengar",
			"level_offset": 2,
			"intro": "Team Rocket runs this arena now. Hand over your Pokémon!",
			"defeat": "This isn't over!",
			"accent": "#ff334d",
			"xp": 170,
			"lines": [
				"Listen up, arena! Team Rocket is running the show now!",
				"Shadow Gengar, show this rookie what real fear feels like!",
			],
		}
	# Keep the battle pending so the battle scene consumes it exactly once.
	GameState.pending_battle = {
		"rocket": true,
		"opponent": _opponent.duplicate(true),
		"return_scene": str(GameState.pending_battle.get("return_scene", GameState.SCENE_ARENA)) if GameState.pending_battle is Dictionary else GameState.SCENE_ARENA,
	}
	GameState.return_scene = str(GameState.pending_battle.get("return_scene", GameState.SCENE_ARENA))

	var raw_lines: Array = _opponent.get("lines", [])
	var speaker := str(_opponent.get("name", "Team Rocket"))
	_lines.append({"speaker": "BATTLE ARENA", "text": "The floodlights cut out. The crowd goes silent. A shadow steps onto the centre stage."})
	for entry in raw_lines:
		var text := str(entry)
		if text != "":
			_lines.append({"speaker": speaker, "text": text})
	var intro := str(_opponent.get("intro", ""))
	if intro != "":
		_lines.append({"speaker": speaker, "text": intro})
	_lines.append({"speaker": "BATTLE ARENA", "text": "The takeover battle is about to begin. Your partner is counting on you."})

func _pokemon_id() -> String:
	return str(_opponent.get("pokemon", "gengar"))

func _accent() -> Color:
	return Color(str(_opponent.get("accent", "#ff334d")))

# ------------------------------------------------------------------ layout

func _build() -> void:
	var bg := UIKit.background("rocket")
	add_child(bg)

	var stadium := UIKit.stadium_art("arena")
	stadium.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stadium.modulate = Color(0.65, 0.55, 0.85, 0.28)
	add_child(stadium)

	var particles := UIKit.particle_field(62, 0.55)
	particles.colors = [
		Color(1.0, 0.28, 0.36, 0.72),
		Color(0.72, 0.45, 1.0, 0.62),
		Color(1.0, 0.58, 0.25, 0.5),
	]
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.03, 0.0, 0.02, 0.36)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	_build_rocket_mark()
	_build_header()
	_build_preview()
	_build_dialogue()
	_build_footer()
	_animate_in()

func _build_rocket_mark() -> void:
	var mark := UIKit.panel(Color(0.22, 0.015, 0.035, 0.72), Color(1, 0.25, 0.35, 0.35), 34)
	mark.custom_minimum_size = Vector2(430, 430)
	mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mark.offset_left = -90
	mark.offset_top = -110
	mark.offset_right = 340
	mark.offset_bottom = 320
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.modulate = Color(1, 1, 1, 0.55)
	add_child(mark)
	var letter := UIKit.title("R", 330, Color(1, 0.22, 0.32, 0.16))
	letter.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.position = Vector2(-160, -190)
	letter.size = Vector2(320, 380)
	mark.add_child(letter)

	var stripe_a := ColorRect.new()
	stripe_a.color = Color(1, 0.18, 0.28, 0.14)
	stripe_a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stripe_a.rotation = -0.38
	stripe_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(stripe_a)

func _build_header() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 76
	margin.offset_right = -76
	margin.offset_top = 42
	margin.offset_bottom = 300
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := UIKit.vbox(2)
	column.custom_minimum_size = Vector2(820, 0)
	margin.add_child(column)

	var alert_row := UIKit.hbox(12)
	column.add_child(alert_row)
	var ball := UIKit.pokeball(30, 1.6, Color("#ff334d"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_row.add_child(ball)
	var kicker := UIKit.label("TEAM ROCKET EVENT", 15, Color("#ff8a95"))
	kicker.add_theme_constant_override("letter_spacing", 5)
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_row.add_child(kicker)
	var live := UIKit.small("LIVE  •  THE ARENA IS COMPROMISED", Color(0.9, 0.72, 0.78, 0.7))
	live.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_row.add_child(live)

	_title_label = UIKit.title("THE ARENA IS\nUNDER SIEGE", 68, Color("#ffd05a"))
	column.add_child(_title_label)
	_subtitle_label = UIKit.label("An unscheduled challenger has taken the centre stage.", 20, Color(0.94, 0.84, 0.88, 0.9), true)
	_subtitle_label.custom_minimum_size = Vector2(720, 0)
	column.add_child(_subtitle_label)

func _build_preview() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_left = -700
	holder.offset_right = -88
	holder.offset_top = 118
	holder.offset_bottom = 700
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_aura = UIKit.panel(Color(0.18, 0.04, 0.34, 0.5), Color(0.7, 0.4, 1.0, 0.5), 28)
	_aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_aura)

	var preview_box := UIKit.vbox(0)
	_aura.add_child(preview_box)
	_preview = ModelPreview.new()
	_preview.custom_minimum_size = Vector2(0, 430)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.set_pokemon(_pokemon_id())
	_preview.set_accent(Color("#b28bff"))
	preview_box.add_child(_preview)

	var preview_footer := UIKit.hbox(10)
	preview_box.add_child(preview_footer)
	var tag := UIKit.small("SHADOW POKÉMON", Color(0.86, 0.72, 1.0, 0.9))
	tag.add_theme_constant_override("letter_spacing", 2)
	preview_footer.add_child(tag)
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_footer.add_child(flex)
	preview_footer.add_child(UIKit.small(str(_opponent.get("display_override", "Unknown"))))

	var name_card := UIKit.panel(Color(0.12, 0.02, 0.06, 0.9), Color(1, 0.28, 0.38, 0.45), 16)
	name_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_card.offset_left = 18
	name_card.offset_right = -18
	name_card.offset_top = -104
	name_card.offset_bottom = -18
	name_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_card)
	var name_row := UIKit.hbox(12)
	name_card.add_child(name_row)
	var badge := UIKit.pokeball(42, 1.3, Color("#ff334d"))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(badge)
	var who := UIKit.vbox(0)
	name_row.add_child(who)
	who.add_child(UIKit.small(str(_opponent.get("title", "Team Rocket")), Color(0.92, 0.72, 0.78, 0.8)))
	who.add_child(UIKit.label(str(_opponent.get("name", "Team Rocket")), 26, Color("#ffe8ec")))

func _build_dialogue() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_left = 76
	margin.offset_right = -76
	margin.offset_top = -300
	margin.offset_bottom = -40
	add_child(margin)

	var row := UIKit.hbox(18)
	margin.add_child(row)

	_content = UIKit.panel(Color(0.035, 0.02, 0.06, 0.96), Color(1, 0.28, 0.38, 0.35), 22)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_content)
	var box := UIKit.vbox(8)
	_content.add_child(box)

	var head := UIKit.hbox(12)
	box.add_child(head)
	var dot := ColorRect.new()
	dot.color = _accent()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(dot)
	_speaker_label = UIKit.label("BATTLE ARENA", 16, Color("#ff9aa5"))
	_speaker_label.add_theme_constant_override("letter_spacing", 3)
	head.add_child(_speaker_label)
	var head_flex := Control.new()
	head_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_flex)
	_counter_label = UIKit.small("", Color(0.72, 0.6, 0.72, 0.7))
	head.add_child(_counter_label)

	_dialogue_label = UIKit.label("", 24, Color("#fff4f6"), true)
	_dialogue_label.custom_minimum_size = Vector2(0, 118)
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_dialogue_label)

	var foot := UIKit.hbox(10)
	box.add_child(foot)
	_dots = UIKit.hbox(6)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_dots)
	var foot_flex := Control.new()
	foot_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(foot_flex)
	_skip_button = UIKit.button("Skip Intro", "ghost", "", 40)
	_skip_button.custom_minimum_size = Vector2(130, 40)
	_skip_button.pressed.connect(_skip_to_end)
	foot.add_child(_skip_button)
	_continue_button = UIKit.button("Continue", "primary", "", 46)
	_continue_button.custom_minimum_size = Vector2(190, 46)
	_continue_button.pressed.connect(_advance)
	foot.add_child(_continue_button)

	var side := UIKit.vbox(10)
	side.custom_minimum_size = Vector2(330, 0)
	row.add_child(side)

	var stakes := UIKit.panel(Color(0.1, 0.02, 0.05, 0.9), Color(1, 0.3, 0.4, 0.32), 18)
	stakes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(stakes)
	var stakes_box := UIKit.vbox(8)
	stakes.add_child(stakes_box)
	stakes_box.add_child(UIKit.small("WHAT'S AT STAKE", Color(0.9, 0.7, 0.76, 0.65)))
	stakes_box.add_child(UIKit.label("A Rocket badge", 24, UIKit.GOLD))
	var stake_text := UIKit.small("Win this event to earn a badge, a big XP payout and a shot at unlocking a rare partner. A loss still counts as the event being completed.", Color(0.88, 0.8, 0.85, 0.82))
	stake_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stakes_box.add_child(stake_text)

	_battle_button = UIKit.button("Begin the Battle", "rocket", "", 56)
	_battle_button.visible = false
	_battle_button.pressed.connect(_begin_battle)
	side.add_child(_battle_button)

func _build_footer() -> void:
	var footer := UIKit.hbox(18)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 80
	footer.offset_right = -80
	footer.offset_top = -34
	footer.offset_bottom = -10
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.add_child(UIHelpers.key_hint("ENTER", "Advance"))
	footer.add_child(UIHelpers.key_hint("ESC", "Skip intro"))
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(flex)
	var hint := UIKit.small("Original procedural models and chiptune audio", Color(0.65, 0.5, 0.6, 0.5))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(hint)

func _animate_in() -> void:
	_content.modulate = Color(1, 1, 1, 0)
	_content.position.y = 28
	_aura.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_content, "modulate:a", 1.0, 0.4)
	tw.tween_property(_content, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_aura, "modulate:a", 1.0, 0.6)

# ------------------------------------------------------------------ dialogue flow

func _show_line(index: int, animate: bool = true) -> void:
	if _lines.is_empty():
		_finish_intro()
		return
	_line_index = clampi(index, 0, _lines.size() - 1)
	var line: Dictionary = _lines[_line_index]
	_speaker_label.text = str(line.get("speaker", "TEAM ROCKET")).to_upper()
	_counter_label.text = "%02d / %02d" % [_line_index + 1, _lines.size()]
	_dialogue_label.text = str(line.get("text", ""))
	_dialogue_label.visible_ratio = 0.0 if animate else 1.0
	_typing = animate
	_refresh_dots()
	if animate:
		var duration := clampf(float(_dialogue_label.text.length()) * 0.013, 0.25, 1.1)
		var tw := create_tween()
		tw.tween_property(_dialogue_label, "visible_ratio", 1.0, duration)
		await tw.finished
		_typing = false
		AudioManager.play_sfx("click", -12.0)
	else:
		_typing = false
	_continue_button.text = "Continue" if _line_index < _lines.size() - 1 else "Face Team Rocket"
	_continue_button.visible = true
	_battle_button.visible = false
	_skip_button.visible = true

func _refresh_dots() -> void:
	if _dots == null:
		return
	for child in _dots.get_children():
		child.queue_free()
	for i in _lines.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16 if i == _line_index else 8, 4)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = _accent() if i == _line_index else Color(1, 1, 1, 0.18)
		_dots.add_child(dot)

func _advance() -> void:
	if _leaving or _intro_done:
		return
	if _typing:
		_dialogue_label.visible_ratio = 1.0
		_typing = false
		return
	if _line_index < _lines.size() - 1:
		AudioManager.play_sfx("click", -8.0)
		_show_line(_line_index + 1, true)
	else:
		_finish_intro()

func _skip_to_end() -> void:
	if _leaving:
		return
	_intro_done = true
	_typing = false
	_line_index = maxi(0, _lines.size() - 1)
	if not _lines.is_empty():
		var line: Dictionary = _lines[_line_index]
		_speaker_label.text = str(line.get("speaker", "TEAM ROCKET")).to_upper()
		_dialogue_label.text = str(line.get("text", ""))
		_dialogue_label.visible_ratio = 1.0
		_counter_label.text = "%02d / %02d" % [_line_index + 1, _lines.size()]
		_refresh_dots()
	_continue_button.visible = false
	_skip_button.visible = false
	_battle_button.visible = true
	_battle_button.grab_focus()
	AudioManager.play_sfx("confirm", -6.0)

func _finish_intro() -> void:
	if _intro_done or _leaving:
		return
	_intro_done = true
	_continue_button.visible = false
	_skip_button.visible = false
	_battle_button.visible = true
	_battle_button.grab_focus()
	AudioManager.play_sfx("rocket_alarm", -8.0)
	var tw := create_tween()
	tw.tween_property(_battle_button, "scale", Vector2(1.04, 1.04), 0.14)
	tw.tween_property(_battle_button, "scale", Vector2.ONE, 0.18)

func _begin_battle() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play_sfx("confirm")
	SceneRouter.goto(BATTLE_SCENE, 0.55, "BATTLE START")

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		if _intro_done:
			_begin_battle()
		else:
			_skip_to_end()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if _intro_done:
			_begin_battle()
		else:
			_advance()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_pulse_time += delta
	if _aura != null:
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 2.1)
		_aura.modulate = Color(1.0, 0.92 + pulse * 0.08, 1.0, 1.0)
		_aura.scale = Vector2.ONE * (1.0 + pulse * 0.006)
