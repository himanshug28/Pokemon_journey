class_name PlayerController
extends CharacterBody3D
## Third-person explorer controller with mouse orbit camera, sprint, jump and interaction scanning.

signal interact_target_changed(target: Node3D)
signal interacted(target: Node3D)

const WALK_SPEED := 5.4
const SPRINT_SPEED := 8.2
const ACCELERATION := 26.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 6.4
const GRAVITY := 20.0
const MOUSE_SENSITIVITY_FALLBACK := 0.0024
const INTERACT_RADIUS := 3.6
const CAMERA_MIN_DISTANCE := 2.3
const CAMERA_MAX_DISTANCE := 7.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var trainer_model: TrainerModel
var visual_root: Node3D
var control_enabled := true
var mouse_captured := true
var current_target: Node3D
var camera_distance := 4.8

var _pitch := -0.16
var _scan_timer := 0.0
var _step_timer := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _camera_base_position := Vector3.ZERO
var _visual_facing := 0.0
var _jump_buffer := 0.0

func _ready() -> void:
	add_to_group("player")
	_build_visual()
	camera_pivot.position = Vector3(0, 1.58, 0)
	spring_arm.spring_length = camera_distance
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.25
	spring_arm.rotation.x = _pitch
	camera.fov = 68.0
	camera.current = true
	_camera_base_position = camera.position
	capture_mouse(true)
	set_physics_process(true)

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	var trainer_data := AssetLibrary.get_trainer(GameState.trainer_id())
	if trainer_data.is_empty() and not AssetLibrary.trainers.is_empty():
		trainer_data = AssetLibrary.trainers[0]
	trainer_model = TrainerModel.new()
	visual_root.add_child(trainer_model)
	trainer_model.setup(trainer_data)
	trainer_model.scale = Vector3.ONE * 1.12

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		if trainer_model != null:
			trainer_model.set_move_speed(0.0)
		_set_target(null)

func capture_mouse(should_capture: bool) -> void:
	mouse_captured = should_capture
	if should_capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventMouseMotion and mouse_captured:
		var sensitivity := float(GameState.get_setting("camera_sensitivity", MOUSE_SENSITIVITY_FALLBACK))
		sensitivity = clampf(sensitivity, 0.0008, 0.006)
		camera_pivot.rotation.y -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -0.95, 0.55)
		spring_arm.rotation.x = lerpf(spring_arm.rotation.x, _pitch, 0.65)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clampf(camera_distance - 0.35, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clampf(camera_distance + 0.35, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	elif event.is_action_pressed("interact"):
		if current_target != null:
			interact_with(current_target)

func _physics_process(delta: float) -> void:
	if not control_enabled:
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.6

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3.ZERO
	if input_vector.length_squared() > 0.001:
		var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
		direction = (yaw_basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	var sprinting := Input.is_action_pressed("sprint") and direction.length_squared() > 0.01
	var target_speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var target_velocity := direction * target_speed
	var accel := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		AudioManager.play_sfx("whoosh", -14.0, 1.35)

	move_and_slide()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if direction.length_squared() > 0.01:
		var target_facing := atan2(direction.x, direction.z)
		_visual_facing = lerp_angle(_visual_facing, target_facing, clampf(delta * 11.0, 0.0, 1.0))
		visual_root.rotation.y = _visual_facing
	if trainer_model != null:
		trainer_model.set_move_speed(horizontal_speed)
	_footsteps(delta, horizontal_speed, sprinting)

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_scan_for_interactables()
	_update_camera(delta)

func _footsteps(delta: float, speed: float, sprinting: bool) -> void:
	if speed < 0.4 or not is_on_floor():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.31 if sprinting else 0.44
		AudioManager.play_sfx("click", -26.0, 0.62 if sprinting else 0.52)

func _scan_for_interactables() -> void:
	var best: Node3D = null
	var best_score := -999.0
	var forward := -camera_pivot.global_transform.basis.z
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		var target := node as Node3D
		if target.has_method("is_available") and not bool(target.call("is_available")):
			continue
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > INTERACT_RADIUS:
			continue
		var flat_forward := Vector3(forward.x, 0, forward.z).normalized()
		var facing := flat_forward.dot(to_target.normalized())
		var score := facing * 2.0 - distance * 0.15
		if facing < 0.15:
			score -= 1.5
		if score > best_score:
			best_score = score
			best = target
	_set_target(best)

func _set_target(target: Node3D) -> void:
	if target == current_target:
		return
	current_target = target
	interact_target_changed.emit(target)

func interact_with(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("is_available") and not bool(target.call("is_available")):
		return
	AudioManager.play_sfx("confirm", -4.0, 1.12)
	if target.has_method("interact"):
		target.call("interact", self)
	interacted.emit(target)

func _update_camera(delta: float) -> void:
	spring_arm.spring_length = lerpf(spring_arm.spring_length, camera_distance, clampf(delta * 6.0, 0.0, 1.0))
	spring_arm.rotation.x = lerpf(spring_arm.rotation.x, _pitch, clampf(delta * 14.0, 0.0, 1.0))
	if _shake_time > 0.0:
		_shake_time -= delta
		var falloff := clampf(_shake_time / 0.35, 0.0, 1.0)
		camera.position = _camera_base_position + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * _shake_strength * falloff
	else:
		camera.position = camera.position.lerp(_camera_base_position, clampf(delta * 10.0, 0.0, 1.0))

func shake(strength: float = 0.16, duration: float = 0.3) -> void:
	_shake_strength = strength
	_shake_time = maxf(_shake_time, duration)

func teleport(position_value: Vector3, yaw: float = 0.0) -> void:
	global_position = position_value
	camera_pivot.rotation.y = yaw
	velocity = Vector3.ZERO

func facing_yaw() -> float:
	return camera_pivot.rotation.y

func get_camera() -> Camera3D:
	return camera
