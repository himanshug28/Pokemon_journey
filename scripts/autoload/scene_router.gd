extends CanvasLayer
## Fade transitions between scenes, plus safe scene loading.

signal transition_started(path: String)
signal transition_finished(path: String)

var transitioning := false
var _fade_rect: ColorRect
var _label: Label
var _spinner: PokeballIcon
var _center: VBoxContainer

func _ready() -> void:
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.015, 0.025, 0.06, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
	_center = VBoxContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.custom_minimum_size = Vector2(220, 140)
	_center.position = Vector2(-110, -70)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.modulate = Color(1, 1, 1, 0)
	add_child(_center)
	_spinner = PokeballIcon.new()
	_spinner.custom_minimum_size = Vector2(54, 54)
	_spinner.spin_speed = 3.2
	_spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_center.add_child(_spinner)
	_label = Label.new()
	_label.text = "LOADING"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UIKit.font_heading)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.8))
	_center.add_child(_label)

func goto(path: String, fade_time: float = 0.35, label_text: String = "LOADING") -> void:
	if transitioning:
		return
	transitioning = true
	transition_started.emit(path)
	_label.text = label_text
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, fade_time)
	_center.modulate = Color(1, 1, 1, 1)
	var err := get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if err != OK:
		push_error("Failed to load scene: %s (error %s)" % [path, err])
		_label.text = "LOAD FAILED"
		await get_tree().create_timer(1.2).timeout
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.modulate = Color(1, 1, 1, 0)
	await _fade_to(0.0, fade_time)
	transitioning = false
	transition_finished.emit(path)

func goto_location(location: String) -> void:
	GameState.set_location(location)
	await goto(GameState.location_scene(location), 0.45, "TRAVELLING")

func goto_main_menu() -> void:
	GameState.save_game()
	await goto(GameState.SCENE_MAIN_MENU, 0.4, "MAIN MENU")

func reload_current_scene() -> void:
	await goto(get_tree().current_scene.scene_file_path, 0.3)

func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", alpha, maxf(0.01, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
