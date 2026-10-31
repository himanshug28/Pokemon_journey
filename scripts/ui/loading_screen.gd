extends Control
## Cinematic loading screen: preloads scenes, composes the soundtrack and fades into the menu.

const CORE_SCENES: Array[String] = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/trainer_select.tscn",
	"res://scenes/ui/starter_select.tscn",
	"res://scenes/arenas/stadium_playground.tscn",
	"res://scenes/arenas/battle_arena.tscn",
	"res://scenes/battle/battle_scene.tscn",
	"res://scenes/battle/rocket_intro.tscn",
	"res://scenes/ui/collection.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/arenas_screen.tscn",
]
const MUSIC_ORDER: Array[String] = ["menu", "playground", "arena", "battle", "rocket", "victory", "defeat"]
const TIPS: Array[String] = [
	"Type matchups matter. Fire melts Grass, Water douses Fire, Electric shocks Water.",
	"Win regular matches to unlock new partners for your collection.",
	"Team Rocket strikes after every two completed matches. Be ready.",
	"Press E to interact with people and gates in the world.",
	"Hold Shift to sprint around the Stadium Playground.",
	"Every Pokémon has four moves. Watch your PP and pick the right moment.",
	"Bonds grow through battle. Your partner earns XP every fight.",
]

var _progress_bar: ProgressBar
var _progress_label: Label
var _status_label: Label
var _tip_label: Label
var _hint_label: Label
var _title_box: VBoxContainer
var _silhouette_row: HBoxContainer
var _ball: PokeballIcon
var _ready_to_enter := false
var _navigated := false
var _tip_index := 0

func _ready() -> void:
	_build()
	set_process(true)
	AudioManager.play_music("menu", 0.6)
	call_deferred("_run_loading")

func _build() -> void:
	var bg := UIKit.background("loading")
	add_child(bg)

	var particles := UIKit.particle_field(64, 0.55)
	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.01, 0.02, 0.05, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -30
	add_child(center)

	_title_box = UIKit.vbox(4)
	_title_box.custom_minimum_size = Vector2(860, 0)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_title_box)

	_ball = UIKit.pokeball(84, 1.8, Color("#ff5b62"))
	_ball.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_box.add_child(_ball)

	var kicker := UIKit.label("A  3D  BATTLE  ADVENTURE", 14, Color(0.72, 0.86, 1.0, 0.82))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_constant_override("letter_spacing", 6)
	_title_box.add_child(kicker)

	var title := UIKit.title("POKÉMON", 96, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(title)

	var journey := UIKit.title("JOURNEY", 54, Color("#eaf6ff"))
	journey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journey.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.24, 0.95))
	_title_box.add_child(journey)

	_title_box.add_child(UIKit.spacer(10))

	_silhouette_row = UIKit.hbox(10)
	_silhouette_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_silhouette_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ids: Array[String] = ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]
	for i in ids.size():
		var sil := UIKit.silhouette(ids[i], Color(0.35, 0.8, 1.0, 0.24))
		sil.custom_minimum_size = Vector2(86, 86)
		sil.modulate = Color(1, 1, 1, 0)
		sil.position.y = 14
		_silhouette_row.add_child(sil)
		var tw := create_tween()
		tw.tween_interval(0.32 + i * 0.11)
		tw.set_parallel(true)
		tw.tween_property(sil, "modulate:a", 0.82, 0.5)
		tw.tween_property(sil, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_box.add_child(_silhouette_row)

	_title_box.add_child(UIKit.spacer(24))

	var bar_holder := VBoxContainer.new()
	bar_holder.custom_minimum_size = Vector2(620, 0)
	bar_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar_holder.add_theme_constant_override("separation", 8)
	_title_box.add_child(bar_holder)

	var progress_row := UIKit.hbox(12)
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_holder.add_child(progress_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(540, 16)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg_style := UIKit.style_box(Color(0.02, 0.04, 0.09, 0.92), Color(1, 1, 1, 0.12), 8, 1, 0, 0)
	var fill_style := UIKit.style_box(Color("#ffcf57"), Color(1, 1, 1, 0.35), 8, 0, 0, 0)
	fill_style.shadow_color = Color(1.0, 0.75, 0.25, 0.35)
	fill_style.shadow_size = 10
	_progress_bar.add_theme_stylebox_override("background", bg_style)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_row.add_child(_progress_bar)

	_progress_label = UIKit.label("0%", 16, UIKit.PAPER)
	_progress_label.custom_minimum_size = Vector2(52, 0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(_progress_label)

	_status_label = UIKit.small("Preparing your journey…", Color(0.78, 0.88, 1.0, 0.9))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_holder.add_child(_status_label)

	_title_box.add_child(UIKit.spacer(18))

	var tip_panel := UIKit.panel(Color(0.03, 0.055, 0.12, 0.72), Color(0.55, 0.85, 1.0, 0.18), 12)
	tip_panel.custom_minimum_size = Vector2(660, 0)
	tip_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip_label = UIKit.small(TIPS[0], Color(0.82, 0.9, 1.0, 0.9))
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_panel.add_child(_tip_label)
	_title_box.add_child(tip_panel)

	var hint_row := CenterContainer.new()
	hint_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_row.offset_top = -64
	hint_row.offset_bottom = -20
	add_child(hint_row)
	_hint_label = UIKit.small("Original procedural artwork  •  Original chiptune soundtrack", Color(0.65, 0.75, 0.95, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_row.add_child(_hint_label)

	var version := UIKit.small("v1.0", Color(0.6, 0.7, 0.9, 0.5))
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.position = Vector2(-70, 22)
	version.size = Vector2(50, 20)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)

	_title_box.modulate = Color(1, 1, 1, 0)
	_title_box.scale = Vector2(0.96, 0.96)
	_title_box.pivot_offset = Vector2(430, 280)
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(_title_box, "modulate:a", 1.0, 0.6)
	intro.tween_property(_title_box, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tip_timer := Timer.new()
	tip_timer.wait_time = 4.5
	tip_timer.autostart = true
	tip_timer.timeout.connect(_cycle_tip)
	add_child(tip_timer)

func _cycle_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	var tw := create_tween()
	tw.tween_property(_tip_label, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): _tip_label.text = TIPS[_tip_index])
	tw.tween_property(_tip_label, "modulate:a", 1.0, 0.28)

func _set_progress(value: float, status: String) -> void:
	var pct := clampf(value, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_progress_bar, "value", pct * 100.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_progress_label.text = "%d%%" % int(round(pct * 100.0))
	_status_label.text = status

func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _run_loading() -> void:
	_set_progress(0.02, "Checking save data…")
	await _wait(0.18)

	var scene_count := CORE_SCENES.size()
	for i in scene_count:
		var path := CORE_SCENES[i]
		if not ResourceLoader.exists(path):
			continue
		var err := ResourceLoader.load_threaded_request(path, "PackedScene")
		if err != OK:
			continue
		var progress: Array = []
		while true:
			var state := ResourceLoader.load_threaded_get_status(path, progress)
			var local := float(progress[0]) if progress.size() > 0 else 0.0
			var overall := (float(i) + local) / float(maxi(1, scene_count))
			_set_progress(0.04 + overall * 0.56, "Loading %s…" % _friendly_scene_name(path))
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				break
			if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			await get_tree().process_frame
		await get_tree().process_frame

	var music_count := MUSIC_ORDER.size()
	for i in music_count:
		var track := MUSIC_ORDER[i]
		_set_progress(0.62 + (float(i) / float(maxi(1, music_count))) * 0.34, "Composing %s theme…" % track.capitalize())
		await get_tree().process_frame
		AudioManager.prepare_track(track)
		await get_tree().process_frame

	_set_progress(0.98, "Polishing the Poké Balls…")
	if GameState.has_save:
		GameState.check_unlocks()
	await _wait(0.35)
	_set_progress(1.0, "Ready!")
	_status_label.text = "Click or press any key to begin"
	_status_label.add_theme_color_override("font_color", UIKit.GOLD)
	_ready_to_enter = true
	var pulse := create_tween().set_loops()
	pulse.tween_property(_status_label, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_status_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	await _wait(1.15)
	if not _navigated and not Input.is_anything_pressed():
		_enter_menu()

func _friendly_scene_name(path: String) -> String:
	var base := path.get_file().get_basename().replace("_", " ")
	return base.capitalize()

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_enter or _navigated:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		_enter_menu()

func _enter_menu() -> void:
	if _navigated:
		return
	_navigated = true
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.65, "MAIN MENU")
