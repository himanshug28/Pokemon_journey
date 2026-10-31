class_name Interactable
extends Node3D
## Floating world interaction point. The player scans this group and calls interact().

var title := "Interact"
var prompt_text := "Press E"
var marker_color := Color("#78e2ff")
var available := true
var action: Callable
var marker: Node3D
var label: Label3D
var _pulse_time := 0.0
var _base_marker_y := 0.0

func setup(display_title: String, display_prompt: String, color: Color, callback: Callable, show_label: bool = true) -> void:
	title = display_title
	prompt_text = display_prompt
	marker_color = color
	action = callback
	add_to_group("interactable")
	marker = WorldBuilder.ring_marker(self, Vector3.ZERO, color, 0.9)
	_base_marker_y = 0.0
	if show_label:
		label = WorldBuilder.label3d(self, title, Vector3(0, 2.35, 0), Color(0.92, 0.97, 1.0, 0.95), 34, 0.0052, true)
		label.outline_size = 8
	set_process(true)

func set_available(value: bool) -> void:
	available = value
	if marker != null:
		marker.visible = value
	if label != null:
		label.modulate = Color(1, 1, 1, 1) if value else Color(0.6, 0.6, 0.7, 0.55)

func set_title(value: String) -> void:
	title = value
	if label != null:
		label.text = value

func is_available() -> bool:
	return available

func get_prompt() -> String:
	return prompt_text

func interact(player: Node) -> void:
	## Callbacks may either declare the player argument or ignore it entirely.
	## Calling a zero-argument callback with an extra argument is a runtime error in
	## Godot 4, so the call shape has to match what the callable expects.
	if not available or not action.is_valid():
		return
	if action.get_argument_count() == 0:
		action.call()
	else:
		action.call(player)

func _process(delta: float) -> void:
	_pulse_time += delta
	if marker != null and marker.visible:
		marker.scale = Vector3.ONE * (1.0 + sin(_pulse_time * 2.4) * 0.035)
