class_name TrainerModel
extends Node3D
## Stylized 3D trainer assembled from PBR primitives, with six distinct looks.

var trainer_data: Dictionary = {}
var trainer_id := ""
var idle_root: Node3D
var body_root: Node3D
var _parts: Dictionary = {}
var _base_rot: Dictionary = {}
var _materials: Array[StandardMaterial3D] = []
var _time := 0.0
var _phase := 0.0
var _move_blend := 0.0
var _target_move := 0.0
var _using_external := false
var _external_root: Node3D

func setup(data: Dictionary) -> void:
	trainer_data = data
	trainer_id = str(data.get("id", "kai"))
	_phase = float(abs(hash(trainer_id)) % 100) / 13.0
	idle_root = Node3D.new()
	idle_root.name = "IdleRoot"
	add_child(idle_root)
	body_root = Node3D.new()
	body_root.name = "BodyRoot"
	idle_root.add_child(body_root)
	var external := AssetLibrary.optional_trainer_model_path(trainer_id)
	if external != "":
		_build_external(external)
	else:
		_build_trainer()
	set_process(true)

func _build_external(path: String) -> void:
	_using_external = true
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		_build_trainer()
		_using_external = false
		return
	_external_root = packed.instantiate()
	idle_root.add_child(_external_root)
	for child in _external_root.find_children("*", "AnimationPlayer", true, false):
		if child is AnimationPlayer:
			var names: PackedStringArray = (child as AnimationPlayer).get_animation_list()
			if names.size() > 0:
				(child as AnimationPlayer).play(str(names[0]))
			break
	for child in _external_root.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _mat(color: Color, rough: float = 0.62, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	if emission.a > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_materials.append(m)
	return m

func _sphere(parent: Node3D, pos: Vector3, radii: Vector3, color: Color, rough: float = 0.62, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, rough, emission, energy)
	mi.position = pos
	mi.scale = radii
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.6) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, rough)
	mi.position = pos
	mi.scale = size
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 2.0
	mesh.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.65)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3(radius * 2.0, height * 0.5, radius * 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.6)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3(radius, height * 0.5, radius)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 18
	mesh.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.55)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _pivot(key: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = key
	n.position = pos
	parent.add_child(n)
	_parts[key] = n
	_base_rot[key] = n.rotation_degrees
	return n

func _build_trainer() -> void:
	var skin := Color(str(trainer_data.get("skin", "#f2c49b")))
	var hair := Color(str(trainer_data.get("hair", "#241b1c")))
	var shirt := Color(str(trainer_data.get("shirt", "#2d6cdf")))
	var jacket := Color(str(trainer_data.get("jacket", "#d93d52")))
	var pants := Color(str(trainer_data.get("pants", "#26314a")))
	var shoes := Color(str(trainer_data.get("shoes", "#f6f8ff")))
	var accent := Color(str(trainer_data.get("accent", "#ffd05a")))
	var cap_color := Color(str(trainer_data.get("cap_color", "#ef3f52")))
	var hairstyle := str(trainer_data.get("hairstyle", "spiky"))
	var outfit := str(trainer_data.get("outfit", "jacket"))
	var has_cap := bool(trainer_data.get("cap", false))
	var has_glasses := bool(trainer_data.get("glasses", false))
	var has_backpack := str(trainer_data.get("backpack", "")) != ""
	var backpack_color := Color(str(trainer_data.get("backpack", "#ffb23b")))

	# Legs and shoes
	for side in [-1, 1]:
		var leg := _pivot("leg_%s" % ("l" if side < 0 else "r"), body_root, Vector3(0.16 * side, 0.72, 0))
		_capsule(leg, Vector3(0, -0.28, 0), 0.105, 0.56, pants)
		_sphere(leg, Vector3(0, -0.58, 0.05), Vector3(0.12, 0.075, 0.19), shoes, 0.4)
		_sphere(leg, Vector3(0, -0.57, 0.15), Vector3(0.12, 0.05, 0.1), shoes.lightened(0.15), 0.35)

	# Torso
	_sphere(body_root, Vector3(0, 1.16, 0), Vector3(0.34, 0.42, 0.23), shirt)
	if outfit == "jacket" or outfit == "coat":
		_sphere(body_root, Vector3(0, 1.18, 0.03), Vector3(0.37, 0.43, 0.25), jacket)
		_box(body_root, Vector3(0, 1.16, 0.26), Vector3(0.12, 0.56, 0.03), shirt)
		_box(body_root, Vector3(-0.18, 1.33, 0.22), Vector3(0.22, 0.08, 0.06), jacket.lightened(0.12), Vector3(0, 0, 18))
		_box(body_root, Vector3(0.18, 1.33, 0.22), Vector3(0.22, 0.08, 0.06), jacket.lightened(0.12), Vector3(0, 0, -18))
		if outfit == "coat":
			_box(body_root, Vector3(-0.26, 0.91, 0), Vector3(0.12, 0.5, 0.22), jacket.darkened(0.08), Vector3(0, 0, 3))
			_box(body_root, Vector3(0.26, 0.91, 0), Vector3(0.12, 0.5, 0.22), jacket.darkened(0.08), Vector3(0, 0, -3))
	elif outfit == "vest":
		_sphere(body_root, Vector3(0, 1.18, 0.03), Vector3(0.35, 0.42, 0.24), jacket)
		_box(body_root, Vector3(0, 1.16, 0.25), Vector3(0.2, 0.58, 0.03), shirt)
		_box(body_root, Vector3(-0.28, 1.18, 0.08), Vector3(0.06, 0.6, 0.22), jacket.darkened(0.08))
		_box(body_root, Vector3(0.28, 1.18, 0.08), Vector3(0.06, 0.6, 0.22), jacket.darkened(0.08))
	else:
		_sphere(body_root, Vector3(0, 1.18, 0.03), Vector3(0.35, 0.42, 0.24), jacket)
	# Belt / accents
	_box(body_root, Vector3(0, 0.91, 0.18), Vector3(0.52, 0.055, 0.04), accent)
	_sphere(body_root, Vector3(0, 1.25, 0.25), Vector3(0.035, 0.035, 0.02), accent, 0.3, accent, 0.6)

	# Arms
	for side in [-1, 1]:
		var arm := _pivot("arm_%s" % ("l" if side < 0 else "r"), body_root, Vector3(0.37 * side, 1.36, 0.02))
		_capsule(arm, Vector3(0.04 * side, -0.22, 0), 0.08, 0.46, jacket, Vector3(0, 0, -5 * side))
		_sphere(arm, Vector3(0.04 * side, -0.44, 0.02), Vector3(0.085, 0.085, 0.085), skin, 0.6)
		_sphere(arm, Vector3(0.04 * side, -0.49, 0.02), Vector3(0.075, 0.04, 0.075), skin.darkened(0.08), 0.6)

	# Neck / head
	_capsule(body_root, Vector3(0, 1.47, 0), 0.09, 0.14, skin)
	var head := _pivot("head", body_root, Vector3(0, 1.63, 0))
	_sphere(head, Vector3.ZERO, Vector3(0.25, 0.28, 0.24), skin, 0.55)
	# Ears
	_sphere(head, Vector3(-0.24, -0.02, 0), Vector3(0.055, 0.09, 0.05), skin.darkened(0.04), 0.6)
	_sphere(head, Vector3(0.24, -0.02, 0), Vector3(0.055, 0.09, 0.05), skin.darkened(0.04), 0.6)
	# Eyes and face
	for side in [-1, 1]:
		_sphere(head, Vector3(0.085 * side, 0.02, 0.225), Vector3(0.045, 0.052, 0.02), Color.WHITE, 0.2)
		_sphere(head, Vector3(0.085 * side, 0.02, 0.242), Vector3(0.024, 0.03, 0.012), Color("#241f2d"), 0.1)
		_sphere(head, Vector3(0.078 * side, 0.035, 0.252), Vector3(0.009, 0.01, 0.005), Color.WHITE, 0.1)
	_sphere(head, Vector3(0, -0.045, 0.247), Vector3(0.018, 0.015, 0.014), skin.darkened(0.18), 0.6)
	_sphere(head, Vector3(0, -0.11, 0.235), Vector3(0.045, 0.012, 0.01), Color("#8a3e48"), 0.5)
	# Hair
	_build_hair(head, hairstyle, hair)
	# Cap
	if has_cap:
		var cap := _pivot("cap", head, Vector3(0, 0.2, 0))
		_sphere(cap, Vector3(0, 0.02, -0.02), Vector3(0.255, 0.12, 0.25), cap_color, 0.5)
		_box(cap, Vector3(0, -0.005, 0.25), Vector3(0.32, 0.025, 0.24), cap_color.darkened(0.05), Vector3(0, 0, 0))
		_sphere(cap, Vector3(0, 0.02, 0.2), Vector3(0.07, 0.035, 0.02), Color.WHITE, 0.4)
		_sphere(cap, Vector3(0, 0.02, 0.217), Vector3(0.035, 0.035, 0.01), accent, 0.3, accent, 0.4)
	# Glasses
	if has_glasses:
		for side in [-1, 1]:
			_torus(head, Vector3(0.085 * side, 0.02, 0.258), 0.032, 0.048, Color("#1c2233"), Vector3(90, 0, 0))
		_box(head, Vector3(0, 0.02, 0.258), Vector3(0.07, 0.012, 0.012), Color("#1c2233"))
	# Backpack
	if has_backpack:
		_box(body_root, Vector3(0, 1.12, -0.27), Vector3(0.36, 0.46, 0.18), backpack_color, Vector3.ZERO, 0.55)
		_box(body_root, Vector3(0, 1.17, -0.37), Vector3(0.26, 0.18, 0.08), backpack_color.darkened(0.15), Vector3.ZERO, 0.55)
		_box(body_root, Vector3(0, 1.12, -0.365), Vector3(0.3, 0.05, 0.02), accent, Vector3.ZERO, 0.5)

func _build_hair(head: Node3D, hairstyle: String, hair: Color) -> void:
	match hairstyle:
		"spiky":
			_sphere(head, Vector3(0, 0.16, -0.02), Vector3(0.255, 0.18, 0.23), hair, 0.65)
			for i in 5:
				var x := -0.18 + i * 0.09
				_cone(head, Vector3(x, 0.32 + (i % 2) * 0.05, -0.05), 0.09, 0.2, hair, Vector3(-18, 0, (x) * 70))
			_sphere(head, Vector3(-0.21, 0.12, 0.05), Vector3(0.06, 0.15, 0.12), hair, 0.65)
			_sphere(head, Vector3(0.21, 0.12, 0.05), Vector3(0.06, 0.15, 0.12), hair, 0.65)
		"bob":
			_sphere(head, Vector3(0, 0.1, -0.02), Vector3(0.28, 0.25, 0.26), hair, 0.6)
			_sphere(head, Vector3(-0.24, -0.02, 0.02), Vector3(0.09, 0.2, 0.17), hair, 0.6)
			_sphere(head, Vector3(0.24, -0.02, 0.02), Vector3(0.09, 0.2, 0.17), hair, 0.6)
			_box(head, Vector3(0, 0.17, 0.18), Vector3(0.34, 0.12, 0.08), hair, Vector3(-12, 0, 0))
		"ponytail":
			_sphere(head, Vector3(0, 0.15, -0.02), Vector3(0.26, 0.18, 0.24), hair, 0.6)
			_sphere(head, Vector3(0, 0.08, -0.27), Vector3(0.12, 0.14, 0.12), hair, 0.6)
			_capsule(head, Vector3(0.02, -0.08, -0.34), 0.09, 0.4, hair, Vector3(-20, 0, 0))
			_sphere(head, Vector3(0.03, -0.29, -0.4), Vector3(0.08, 0.08, 0.08), hair, 0.6)
			_box(head, Vector3(-0.2, 0.15, 0.1), Vector3(0.1, 0.18, 0.08), hair, Vector3(0, 0, 20))
		"curly":
			_sphere(head, Vector3(0, 0.13, -0.01), Vector3(0.27, 0.2, 0.25), hair, 0.6)
			for i in 7:
				var ang := TAU * float(i) / 7.0
				_sphere(head, Vector3(cos(ang) * 0.2, 0.2 + sin(ang) * 0.1, -0.03 + sin(ang) * 0.18), Vector3(0.1, 0.1, 0.1), hair, 0.6)
			_sphere(head, Vector3(-0.22, 0.02, 0.02), Vector3(0.08, 0.16, 0.14), hair, 0.6)
			_sphere(head, Vector3(0.22, 0.02, 0.02), Vector3(0.08, 0.16, 0.14), hair, 0.6)
		_:
			_sphere(head, Vector3(0, 0.15, -0.02), Vector3(0.265, 0.17, 0.24), hair, 0.6)
			_sphere(head, Vector3(-0.21, 0.08, 0.05), Vector3(0.06, 0.13, 0.12), hair, 0.6)
			_sphere(head, Vector3(0.21, 0.08, 0.05), Vector3(0.06, 0.13, 0.12), hair, 0.6)

# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	if idle_root == null:
		return
	_time += delta
	_move_blend = lerpf(_move_blend, _target_move, clampf(delta * 8.0, 0.0, 1.0))
	var bob := sin(_time * 2.2 + _phase) * 0.012
	idle_root.position = Vector3(0, bob, 0)
	idle_root.rotation_degrees = Vector3(0, 0, sin(_time * 1.1 + _phase) * 0.5)
	var swing := sin(_time * 8.0 + _phase) * 28.0 * _move_blend
	for key in ["leg_l", "leg_r"]:
		if _parts.has(key):
			var leg: Node3D = _parts[key]
			var base: Vector3 = _base_rot.get(key, Vector3.ZERO)
			var side := -1.0 if key.ends_with("l") else 1.0
			leg.rotation_degrees = base + Vector3(swing * side, 0, 0)
	for key in ["arm_l", "arm_r"]:
		if _parts.has(key):
			var arm: Node3D = _parts[key]
			var base: Vector3 = _base_rot.get(key, Vector3.ZERO)
			var side := -1.0 if key.ends_with("l") else 1.0
			arm.rotation_degrees = base + Vector3(-swing * side * 0.8, 0, side * sin(_time * 1.4 + _phase) * 1.5)
	if _parts.has("head"):
		var head: Node3D = _parts["head"]
		var base: Vector3 = _base_rot.get("head", Vector3.ZERO)
		head.rotation_degrees = base + Vector3(sin(_time * 1.2 + _phase) * 1.2, sin(_time * 0.8 + _phase) * 2.0, 0)

func set_move_speed(speed: float) -> void:
	_target_move = clampf(speed / 5.5, 0.0, 1.4)

func play_wave() -> void:
	if not _parts.has("arm_r"):
		return
	var arm: Node3D = _parts["arm_r"]
	var tw := create_tween()
	tw.tween_property(arm, "rotation_degrees:z", -150.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arm, "rotation_degrees:z", -125.0, 0.15)
	tw.tween_property(arm, "rotation_degrees:z", -150.0, 0.15)
	tw.tween_property(arm, "rotation_degrees:z", -125.0, 0.15)
	tw.tween_property(arm, "rotation_degrees:z", _base_rot.get("arm_r", Vector3.ZERO).z, 0.25)
	await tw.finished

func play_throw() -> void:
	if not _parts.has("arm_r"):
		return
	var arm: Node3D = _parts["arm_r"]
	var tw := create_tween()
	tw.tween_property(arm, "rotation_degrees:x", -120.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arm, "rotation_degrees:x", 35.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(arm, "rotation_degrees:x", 0.0, 0.22)
	await tw.finished

func play_victory() -> void:
	if idle_root == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	if _parts.has("arm_l"):
		tw.tween_property(_parts["arm_l"], "rotation_degrees:z", 155.0, 0.3).set_trans(Tween.TRANS_BACK)
	if _parts.has("arm_r"):
		tw.tween_property(_parts["arm_r"], "rotation_degrees:z", -155.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_property(idle_root, "position:y", 0.25, 0.18).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(idle_root, "position:y", 0.0, 0.18)
	await tw.finished

func play_defeat() -> void:
	if idle_root == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(idle_root, "rotation_degrees:x", 12.0, 0.4)
	tw.tween_property(idle_root, "position:y", -0.05, 0.4)
	if _parts.has("head"):
		tw.tween_property(_parts["head"], "rotation_degrees:x", 25.0, 0.4)
	await tw.finished

func reset_pose() -> void:
	if idle_root != null:
		idle_root.rotation_degrees = Vector3.ZERO
		idle_root.position = Vector3.ZERO
	for key in _parts:
		var node: Node3D = _parts[key]
		node.rotation_degrees = _base_rot.get(key, Vector3.ZERO)
