class_name PokemonModel
extends Node3D
## Procedurally sculpted, animated Pokémon models with optional .glb overrides.
## Every model is built from PBR meshes and custom extruded shapes; no placeholder cubes.

var data: PokemonData
var species_id := ""
var idle_root: Node3D
var attack_root: Node3D
var effect_anchor: Node3D
var materials: Array[StandardMaterial3D] = []
var _parts: Dictionary = {}
var _base_rot: Dictionary = {}
var _time := 0.0
var _phase := 0.0
var _idle_speed := 1.0
var _idle_enabled := true
var _fainted := false
var _using_external := false
var _external_root: Node3D
var _animation_player: AnimationPlayer
var _preview := false
var _effect_timer: SceneTreeTimer

func setup(pokemon_data: PokemonData, preview: bool = false) -> void:
	data = pokemon_data
	_preview = preview
	if data == null:
		return
	species_id = data.id
	_phase = float(abs(hash(species_id)) % 100) / 17.0
	idle_root = Node3D.new()
	idle_root.name = "IdleRoot"
	add_child(idle_root)
	attack_root = Node3D.new()
	attack_root.name = "AttackRoot"
	idle_root.add_child(attack_root)
	var external := AssetLibrary.optional_model_path(species_id)
	if external != "":
		_build_external(external)
	else:
		match species_id:
			"charizard": _build_charizard()
			"bulbasaur": _build_bulbasaur()
			"gengar": _build_gengar()
			"pikachu": _build_pikachu()
			"squirtle": _build_squirtle()
			_: _build_pikachu()
	effect_anchor = Node3D.new()
	effect_anchor.name = "EffectAnchor"
	effect_anchor.position = _default_effect_position()
	attack_root.add_child(effect_anchor)
	scale = Vector3.ONE * (data.model_scale if data.model_scale > 0.0 else 1.0)
	if scale.length() < 0.001:
		scale = Vector3.ONE
	_apply_idle_extras()
	visible = true
	show()
	set_process(true)

func _default_effect_position() -> Vector3:
	match species_id:
		"charizard": return Vector3(0, 1.55, 0.55)
		"bulbasaur": return Vector3(0, 0.85, 0.65)
		"gengar": return Vector3(0, 1.25, 0.55)
		"pikachu": return Vector3(0, 0.95, 0.45)
		"squirtle": return Vector3(0, 0.9, 0.5)
	return Vector3(0, 1.0, 0.4)

func _build_external(path: String) -> void:
	_using_external = true
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		push_warning("Could not load external model: %s" % path)
		_build_pikachu()
		_using_external = false
		return
	_external_root = packed.instantiate()
	idle_root.add_child(_external_root)
	_collect_external_meshes(_external_root)
	for child in _external_root.find_children("*", "AnimationPlayer", true, false):
		if child is AnimationPlayer:
			_animation_player = child
			break
	if _animation_player != null:
		var names := _animation_player.get_animation_list()
		var chosen := ""
		for anim_name in names:
			var lower := str(anim_name).to_lower()
			if "idle" in lower:
				chosen = str(anim_name)
				break
		if chosen == "" and names.size() > 0:
			chosen = str(names[0])
		if chosen != "":
			_animation_player.play(chosen)
	_add_external_shadow(_external_root)

func _collect_external_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh != null else 0:
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				materials.append(mat)
	elif node is GeometryInstance3D:
		var mat2 := (node as GeometryInstance3D).material_override
		if mat2 is StandardMaterial3D:
			materials.append(mat2)
	for child in node.get_children():
		_collect_external_meshes(child)

func _add_external_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_add_external_shadow(child)

# ------------------------------------------------------------------ material / mesh helpers

func _material(color: Color, roughness: float = 0.55, metallic: float = 0.0, emission: Color = Color.TRANSPARENT, emission_energy: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.rim_enabled = true
	mat.rim = 0.32
	mat.rim_tint = 0.55
	if emission.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
		mat.set_meta("orig_emission_enabled", true)
		mat.set_meta("orig_emission", emission)
		mat.set_meta("orig_emission_energy", emission_energy)
	else:
		mat.set_meta("orig_emission_enabled", false)
		mat.set_meta("orig_emission", Color.TRANSPARENT)
		mat.set_meta("orig_emission_energy", 0.0)
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials.append(mat)
	return mat

func _sphere_mesh(segments: int = 20) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(6, int(segments * 0.6))
	return mesh

func _capsule_mesh() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 6
	return mesh

func _cylinder_mesh(top_r: float = 1.0, bottom_r: float = 1.0, height: float = 2.0, segments: int = 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	return mesh

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _torus_mesh(inner: float = 0.7, outer: float = 1.0) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 10
	return mesh

func _add_mesh(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, scl: Vector3 = Vector3.ONE, rough: float = 0.55, emission: Color = Color.TRANSPARENT, energy: float = 0.0, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mat := _material(color, rough, 0.0, emission, energy)
	return _add_mesh(_sphere_mesh(), mat, parent, pos, rot_deg, Vector3(radius, radius, radius) * scl)

func _ellipsoid(parent: Node3D, pos: Vector3, radii: Vector3, color: Color, rough: float = 0.55, emission: Color = Color.TRANSPARENT, energy: float = 0.0, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mat := _material(color, rough, 0.0, emission, energy)
	return _add_mesh(_sphere_mesh(), mat, parent, pos, rot_deg, radii)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.55) -> MeshInstance3D:
	var mat := _material(color, rough)
	return _add_mesh(_capsule_mesh(), mat, parent, pos, rot_deg, Vector3(radius * 2.0, height * 0.5, radius * 2.0))

func _cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.55, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mat := _material(color, rough, 0.0, emission, energy)
	return _add_mesh(_cylinder_mesh(top_r, bottom_r, height), mat, parent, pos, rot_deg)

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mat := _material(color, 0.5, 0.0, emission, energy)
	return _add_mesh(_cylinder_mesh(0.0, radius, height), mat, parent, pos, rot_deg)

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mat := _material(color, 0.5, 0.0, emission, energy)
	return _add_mesh(_box_mesh(size), mat, parent, pos, rot_deg)

func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mat := _material(color, 0.6)
	return _add_mesh(_torus_mesh(inner, outer), mat, parent, pos, rot_deg)

func _prism(points: Array, depth: float, color: Color, parent: Node3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var n := points.size()
	for i in range(1, n - 1):
		var a: Vector2 = points[0]
		var b: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		# front (+Z)
		st.add_vertex(Vector3(a.x, a.y, hz))
		st.add_vertex(Vector3(b.x, b.y, hz))
		st.add_vertex(Vector3(c.x, c.y, hz))
		# back (-Z)
		st.add_vertex(Vector3(a.x, a.y, -hz))
		st.add_vertex(Vector3(c.x, c.y, -hz))
		st.add_vertex(Vector3(b.x, b.y, -hz))
	for i in n:
		var a2: Vector2 = points[i]
		var b2: Vector2 = points[(i + 1) % n]
		st.add_vertex(Vector3(a2.x, a2.y, hz))
		st.add_vertex(Vector3(b2.x, b2.y, hz))
		st.add_vertex(Vector3(b2.x, b2.y, -hz))
		st.add_vertex(Vector3(a2.x, a2.y, hz))
		st.add_vertex(Vector3(b2.x, b2.y, -hz))
		st.add_vertex(Vector3(a2.x, a2.y, -hz))
	st.generate_normals()
	var mesh := st.commit()
	var mat := _material(color, 0.5, 0.0, emission, energy)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _add_mesh(mesh, mat, parent, pos, rot_deg)

func _pivot(key: String, parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = key
	node.position = pos
	parent.add_child(node)
	_parts[key] = node
	_base_rot[key] = node.rotation_degrees
	return node

func _eyes(parent: Node3D, left_pos: Vector3, right_pos: Vector3, eye_size: float, iris: Color = Color("#1a1424"), pupil: Color = Color.BLACK) -> void:
	for pos in [left_pos, right_pos]:
		_sphere(parent, pos, eye_size, Color.WHITE, Vector3(1, 1, 0.55), 0.18)
		_sphere(parent, pos + Vector3(0, 0, eye_size * 0.55), eye_size * 0.62, iris, Vector3(1, 1, 0.5), 0.15)
		_sphere(parent, pos + Vector3(0, 0, eye_size * 0.84), eye_size * 0.28, pupil, Vector3(1, 1, 0.4), 0.1)
		_sphere(parent, pos + Vector3(-eye_size * 0.2, eye_size * 0.22, eye_size * 0.94), eye_size * 0.22, Color.WHITE, Vector3(1, 1, 0.4), 0.1)

func _add_particles(parent: Node3D, pos: Vector3, color: Color, count: int, size: float, lifetime: float, velocity: float, gravity: Vector3, spread: float = 35.0, radius: float = 0.25) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = count
	p.lifetime = lifetime
	p.emitting = true
	p.local_coords = true
	p.direction = Vector3.UP
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = velocity * 0.4
	p.initial_velocity_max = velocity
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat
	parent.add_child(p)
	return p

func _apply_idle_extras() -> void:
	match species_id:
		"charizard":
			_add_particles(attack_root, Vector3(0, 0.38, -0.72), Color(1.0, 0.55, 0.1, 0.9), 14, 0.06, 0.55, 0.5, Vector3(0, 2.2, 0), 30.0, 0.08)
			_add_particles(attack_root, Vector3(0, 0.38, -0.72), Color(1.0, 0.92, 0.3, 0.8), 8, 0.035, 0.4, 0.3, Vector3(0, 2.0, 0), 20.0, 0.05)
		"gengar":
			_add_particles(attack_root, Vector3(0, 0.7, 0), Color(0.55, 0.3, 0.95, 0.35), 12, 0.05, 1.4, 0.25, Vector3(0, 0.4, 0), 180.0, 0.5)
		"pikachu":
			_add_particles(attack_root, Vector3(-0.28, 1.0, 0.28), Color(1.0, 0.9, 0.2, 0.8), 6, 0.025, 0.3, 0.4, Vector3(0, 1.2, 0), 90.0, 0.05)
			_add_particles(attack_root, Vector3(0.28, 1.0, 0.28), Color(1.0, 0.9, 0.2, 0.8), 6, 0.025, 0.3, 0.4, Vector3(0, 1.2, 0), 90.0, 0.05)
		"bulbasaur":
			_add_particles(attack_root, Vector3(0, 1.0, -0.2), Color(0.5, 0.9, 0.4, 0.6), 8, 0.04, 1.6, 0.3, Vector3(0, 0.5, 0), 180.0, 0.35)
		"squirtle":
			_add_particles(attack_root, Vector3(0.35, 1.0, 0.3), Color(0.55, 0.85, 1.0, 0.45), 6, 0.035, 1.2, 0.3, Vector3(0, 1.0, 0), 60.0, 0.15)

# ------------------------------------------------------------------ species sculpts

func _build_charizard() -> void:
	var body_col := data.body_color
	var belly := data.belly_color
	var wing_col := data.accent_color
	var dark := body_col.darkened(0.35)
	var cream := Color("#fff0c2")
	# Tail
	var tail := _pivot("tail", attack_root, Vector3(0, 0.72, -0.32))
	_cylinder(tail, Vector3(0, -0.05, -0.25), 0.11, 0.16, 0.55, body_col, Vector3(58, 0, 0))
	_cylinder(tail, Vector3(0, -0.18, -0.55), 0.06, 0.11, 0.45, body_col, Vector3(72, 0, 0))
	_cone(tail, Vector3(0, 0.05, -0.82), 0.18, 0.5, Color("#ff8a2a"), Vector3(-20, 0, 0), Color("#ff5a1f"), 1.6)
	_cone(tail, Vector3(0, 0.11, -0.9), 0.09, 0.34, Color("#ffe36b"), Vector3(-20, 0, 0), Color("#ffd23f"), 2.2)
	# Legs
	for side in [-1, 1]:
		var leg := _pivot("leg_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.27 * side, 0.55, 0.0))
		_capsule(leg, Vector3(0, -0.22, 0.0), 0.16, 0.55, body_col)
		_sphere(leg, Vector3(0, -0.5, 0.08), 0.17, body_col, Vector3(1.1, 0.7, 1.25))
		for claw in [-1, 0, 1]:
			_cone(leg, Vector3(claw * 0.09, -0.55, 0.25), 0.035, 0.15, cream, Vector3(90, 0, 0))
	# Body
	_ellipsoid(attack_root, Vector3(0, 0.9, 0), Vector3(0.38, 0.55, 0.34), body_col)
	_ellipsoid(attack_root, Vector3(0, 0.87, 0.22), Vector3(0.27, 0.43, 0.15), belly)
	# Arms
	for side in [-1, 1]:
		var arm := _pivot("arm_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.36 * side, 1.12, 0.05))
		_capsule(arm, Vector3(0.08 * side, -0.16, 0.08), 0.09, 0.42, body_col, Vector3(0, 0, -28 * side))
		_sphere(arm, Vector3(0.15 * side, -0.34, 0.14), 0.1, body_col, Vector3(1, 0.8, 1.1))
		for claw in [-1, 0, 1]:
			_cone(arm, Vector3(0.15 * side + claw * 0.035, -0.38, 0.24), 0.02, 0.1, cream, Vector3(90, 0, 0))
	# Neck
	_cylinder(attack_root, Vector3(0, 1.27, 0.05), 0.22, 0.28, 0.36, body_col)
	_ellipsoid(attack_root, Vector3(0, 1.18, 0.16), Vector3(0.18, 0.22, 0.1), belly)
	# Head
	var head := _pivot("head", attack_root, Vector3(0, 1.5, 0.07))
	_ellipsoid(head, Vector3.ZERO, Vector3(0.3, 0.27, 0.28), body_col)
	_ellipsoid(head, Vector3(0, -0.06, 0.22), Vector3(0.23, 0.14, 0.22), body_col)
	_ellipsoid(head, Vector3(0, -0.11, 0.34), Vector3(0.15, 0.07, 0.08), belly.darkened(0.05))
	_ellipsoid(head, Vector3(0, -0.14, 0.39), Vector3(0.06, 0.02, 0.03), dark)
	# Horns
	_cone(head, Vector3(-0.12, 0.24, -0.08), 0.05, 0.3, cream, Vector3(-25, 0, -12))
	_cone(head, Vector3(0.12, 0.24, -0.08), 0.05, 0.3, cream, Vector3(-25, 0, 12))
	# Eyes
	_eyes(head, Vector3(-0.13, 0.07, 0.24), Vector3(0.13, 0.07, 0.24), 0.06, Color("#2a5da8"), Color("#101728"))
	# Wing bones and membranes
	for side in [-1, 1]:
		var wing := _pivot("wing_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.24 * side, 1.22, -0.2))
		var pts: Array = []
		if side > 0:
			pts = [Vector2(0, 0), Vector2(0.5, 0.3), Vector2(0.98, 0.78), Vector2(0.72, 0.82), Vector2(0.86, 1.16), Vector2(0.5, 0.9), Vector2(0.38, 1.08), Vector2(0.2, 0.62), Vector2(0.06, 0.7)]
		else:
			for p in [Vector2(0, 0), Vector2(-0.5, 0.3), Vector2(-0.98, 0.78), Vector2(-0.72, 0.82), Vector2(-0.86, 1.16), Vector2(-0.5, 0.9), Vector2(-0.38, 1.08), Vector2(-0.2, 0.62), Vector2(-0.06, 0.7)]:
				pts.append(p)
		_prism(pts, 0.055, wing_col, wing, Vector3.ZERO, Vector3.ZERO)
		_cylinder(wing, Vector3(0.24 * side, 0.4, 0.02), 0.045, 0.06, 0.9, dark, Vector3(0, 0, -30 * side))
		_cylinder(wing, Vector3(0.55 * side, 0.68, 0.02), 0.025, 0.04, 0.55, dark, Vector3(0, 0, -65 * side))
	# Feet claws / flame base
	_sphere(attack_root, Vector3(0, 0.02, 0), 0.01, Color.TRANSPARENT, Vector3.ONE, 1.0)
	_ellipsoid(attack_root, Vector3(0, 0.03, 0), Vector3(0.38, 0.02, 0.3), Color(0, 0, 0, 0.18))

func _build_bulbasaur() -> void:
	var body_col := data.body_color
	var belly := data.belly_color
	var accent := data.accent_color
	var dark := body_col.darkened(0.28)
	# Legs
	for side in [-1, 1]:
		for front in [-1, 1]:
			var leg := _pivot("leg_%s%s" % ["l" if side < 0 else "r", "f" if front > 0 else "b"], attack_root, Vector3(0.32 * side, 0.28, 0.28 * front))
			_capsule(leg, Vector3(0, -0.12, 0), 0.12, 0.26, body_col)
			_sphere(leg, Vector3(0, -0.23, 0.04), 0.13, body_col, Vector3(1.05, 0.75, 1.15))
	# Body
	_ellipsoid(attack_root, Vector3(0, 0.55, -0.02), Vector3(0.45, 0.4, 0.55), body_col)
	_ellipsoid(attack_root, Vector3(0, 0.5, 0.38), Vector3(0.32, 0.3, 0.18), belly)
	# Spots
	_sphere(attack_root, Vector3(-0.32, 0.65, 0.15), 0.07, dark, Vector3(1, 1, 0.35))
	_sphere(attack_root, Vector3(0.34, 0.6, -0.1), 0.06, dark, Vector3(1, 1, 0.35))
	_sphere(attack_root, Vector3(0.15, 0.72, -0.35), 0.05, dark, Vector3(1, 1, 0.35))
	# Head
	var head := _pivot("head", attack_root, Vector3(0, 0.9, 0.32))
	_ellipsoid(head, Vector3.ZERO, Vector3(0.37, 0.32, 0.36), body_col)
	_ellipsoid(head, Vector3(0, -0.06, 0.28), Vector3(0.27, 0.18, 0.18), body_col)
	_ellipsoid(head, Vector3(0, -0.1, 0.43), Vector3(0.17, 0.06, 0.06), dark)
	# Ears
	for side in [-1, 1]:
		var ear := _pivot("ear_%s" % ("l" if side < 0 else "r"), head, Vector3(0.28 * side, 0.18, -0.02))
		_cone(ear, Vector3(0.05 * side, 0.12, 0), 0.1, 0.32, body_col, Vector3(0, 0, -24 * side))
		_cone(ear, Vector3(0.07 * side, 0.17, 0.02), 0.045, 0.16, dark, Vector3(0, 0, -24 * side))
	# Eyes
	_eyes(head, Vector3(-0.13, 0.04, 0.31), Vector3(0.13, 0.04, 0.31), 0.06, Color("#d94b57"), Color("#22121a"))
	# Bulb
	var bulb := _pivot("bulb", attack_root, Vector3(0, 1.0, -0.34))
	_sphere(bulb, Vector3.ZERO, 0.32, accent, Vector3(1.0, 1.05, 1.0), 0.6)
	_sphere(bulb, Vector3(0, 0.12, -0.05), 0.18, accent.lightened(0.12), Vector3(1.0, 0.8, 1.0), 0.5)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var petal := _pivot("petal_%d" % i, bulb, Vector3(cos(ang) * 0.2, 0.1, sin(ang) * 0.2))
		_ellipsoid(petal, Vector3(cos(ang) * 0.08, 0.15, sin(ang) * 0.08), Vector3(0.12, 0.24, 0.05), accent.lightened(0.08), 0.55, Color.TRANSPARENT, 0.0, Vector3(-sin(ang) * 35, 0, cos(ang) * 35))
	# Vine hints
	_cylinder(attack_root, Vector3(-0.42, 0.55, 0.15), 0.02, 0.03, 0.35, accent.darkened(0.1), Vector3(0, 0, 40))
	_cylinder(attack_root, Vector3(0.42, 0.55, 0.15), 0.02, 0.03, 0.35, accent.darkened(0.1), Vector3(0, 0, -40))

func _build_gengar() -> void:
	var body_col := data.body_color
	var dark := body_col.darkened(0.3)
	var accent := data.accent_color
	# Aura / shadow pool
	_ellipsoid(attack_root, Vector3(0, 0.02, 0), Vector3(0.62, 0.02, 0.48), Color(0.08, 0.03, 0.14, 0.5))
	# Spikes around the back
	for i in 9:
		var ang := -PI * 0.9 + float(i) * (PI * 1.8 / 8.0)
		var spike := _pivot("spike_%d" % i, attack_root, Vector3(cos(ang) * 0.46, 0.9 + sin(ang) * 0.35, -0.22))
		_cone(spike, Vector3(cos(ang) * 0.12, sin(ang) * 0.12, 0), 0.08, 0.3, dark, Vector3(0, 0, -ang * 180.0 / PI + 90))
	# Body / head (one rounded mass)
	_ellipsoid(attack_root, Vector3(0, 0.88, 0), Vector3(0.5, 0.55, 0.45), body_col)
	_ellipsoid(attack_root, Vector3(0, 1.23, 0.02), Vector3(0.48, 0.45, 0.43), body_col)
	_ellipsoid(attack_root, Vector3(0, 0.72, 0.31), Vector3(0.28, 0.26, 0.12), dark)
	# Ears / horns
	for side in [-1, 1]:
		var ear := _pivot("ear_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.35 * side, 1.5, 0))
		_cone(ear, Vector3(0.1 * side, 0.14, 0), 0.14, 0.42, body_col, Vector3(0, 0, -18 * side))
		_cone(ear, Vector3(0.12 * side, 0.18, 0.02), 0.06, 0.22, dark, Vector3(0, 0, -18 * side))
	# Eyes
	_eyes(attack_root, Vector3(-0.17, 1.3, 0.38), Vector3(0.17, 1.3, 0.38), 0.07, accent, Color("#2a0612"))
	# Grin
	_ellipsoid(attack_root, Vector3(0, 1.1, 0.43), Vector3(0.22, 0.1, 0.04), Color("#1a0719"))
	for i in 5:
		var x := -0.16 + i * 0.08
		_box(attack_root, Vector3(x, 1.13 + absf(x) * 0.12, 0.46), Vector3(0.055, 0.055, 0.02), Color("#f3eaff"))
	# Arms
	for side in [-1, 1]:
		var arm := _pivot("arm_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.46 * side, 1.0, 0.05))
		_capsule(arm, Vector3(0.1 * side, -0.15, 0.05), 0.08, 0.38, body_col, Vector3(0, 0, -50 * side))
		_sphere(arm, Vector3(0.24 * side, -0.32, 0.1), 0.1, body_col, Vector3(1, 0.8, 1))
		for finger in [-1, 0, 1]:
			_cone(arm, Vector3(0.24 * side + finger * 0.045, -0.38, 0.18), 0.022, 0.12, dark, Vector3(90, 0, 0))
	# Legs
	for side in [-1, 1]:
		var leg := _pivot("leg_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.23 * side, 0.42, 0))
		_sphere(leg, Vector3(0, -0.16, 0.03), 0.15, body_col, Vector3(1, 0.85, 1.1))
		_sphere(leg, Vector3(0, -0.26, 0.12), 0.09, dark, Vector3(1.2, 0.5, 1.4))

func _build_pikachu() -> void:
	var body_col := data.body_color
	var belly := data.belly_color
	var accent := data.accent_color
	var brown := Color("#8a5a2d")
	var black := Color("#1a1722")
	# Tail
	var tail := _pivot("tail", attack_root, Vector3(0, 0.55, -0.26))
	_box(tail, Vector3(0, 0.06, -0.12), Vector3(0.08, 0.22, 0.08), brown, Vector3(-20, 0, 0))
	var tail_pts: Array = [
		Vector2(0, 0), Vector2(0.12, -0.03), Vector2(0.05, 0.2), Vector2(0.27, 0.13),
		Vector2(0.12, 0.4), Vector2(0.4, 0.34), Vector2(0.2, 0.63), Vector2(0.46, 0.58),
		Vector2(0.18, 0.92), Vector2(0.26, 0.55), Vector2(0.02, 0.62), Vector2(0.11, 0.3),
	]
	_prism(tail_pts, 0.055, body_col, tail, Vector3(0.02, 0.15, -0.05), Vector3(0, -8, 0))
	_prism(tail_pts, 0.06, brown, tail, Vector3(0.02, 0.13, -0.06), Vector3(0, -8, 0))
	# Legs
	for side in [-1, 1]:
		var leg := _pivot("leg_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.18 * side, 0.36, 0))
		_capsule(leg, Vector3(0, -0.11, 0), 0.1, 0.25, body_col)
		_sphere(leg, Vector3(0, -0.22, 0.05), 0.13, body_col, Vector3(1.0, 0.62, 1.35))
	# Body
	_ellipsoid(attack_root, Vector3(0, 0.6, 0), Vector3(0.32, 0.38, 0.3), body_col)
	_ellipsoid(attack_root, Vector3(0, 0.57, 0.2), Vector3(0.22, 0.28, 0.13), belly)
	# Arms
	for side in [-1, 1]:
		var arm := _pivot("arm_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.29 * side, 0.72, 0.05))
		_capsule(arm, Vector3(0.05 * side, -0.12, 0.08), 0.07, 0.3, body_col, Vector3(0, 0, -25 * side))
		_sphere(arm, Vector3(0.1 * side, -0.27, 0.15), 0.08, body_col, Vector3(1, 0.8, 1))
	# Head
	var head := _pivot("head", attack_root, Vector3(0, 1.02, 0.03))
	_ellipsoid(head, Vector3.ZERO, Vector3(0.36, 0.32, 0.33), body_col)
	# Ears
	for side in [-1, 1]:
		var ear := _pivot("ear_%s" % ("l" if side < 0 else "r"), head, Vector3(0.22 * side, 0.24, -0.02))
		_capsule(ear, Vector3(0.08 * side, 0.22, 0), 0.075, 0.52, body_col, Vector3(0, 0, -13 * side))
		_cone(ear, Vector3(0.14 * side, 0.52, 0), 0.075, 0.18, black, Vector3(0, 0, -13 * side))
	# Cheeks
	_sphere(head, Vector3(-0.25, -0.04, 0.26), 0.09, accent, Vector3(1, 0.8, 0.45))
	_sphere(head, Vector3(0.25, -0.04, 0.26), 0.09, accent, Vector3(1, 0.8, 0.45))
	# Eyes / nose / mouth
	_eyes(head, Vector3(-0.14, 0.06, 0.29), Vector3(0.14, 0.06, 0.29), 0.065, black, Color("#08060c"))
	_sphere(head, Vector3(0, -0.02, 0.35), 0.03, black, Vector3(1, 0.7, 0.8))
	_ellipsoid(head, Vector3(0, -0.11, 0.33), Vector3(0.045, 0.018, 0.02), Color("#5b2e2e"))
	# Back stripes
	_box(attack_root, Vector3(-0.2, 0.55, -0.2), Vector3(0.13, 0.035, 0.02), brown, Vector3(0, 20, 8))
	_box(attack_root, Vector3(0.16, 0.5, -0.23), Vector3(0.13, 0.035, 0.02), brown, Vector3(0, -20, -8))

func _build_squirtle() -> void:
	var body_col := data.body_color
	var belly := data.belly_color
	var accent := data.accent_color
	var shell_dark := accent.darkened(0.35)
	var cream := Color("#f2d9a0")
	# Tail
	var tail := _pivot("tail", attack_root, Vector3(0, 0.42, -0.32))
	_capsule(tail, Vector3(0, 0.05, -0.18), 0.07, 0.3, body_col, Vector3(60, 0, 0))
	_sphere(tail, Vector3(0, 0.18, -0.33), 0.09, body_col, Vector3(1, 0.8, 1))
	# Legs
	for side in [-1, 1]:
		var leg := _pivot("leg_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.22 * side, 0.36, 0))
		_capsule(leg, Vector3(0, -0.12, 0), 0.1, 0.25, body_col)
		_sphere(leg, Vector3(0, -0.23, 0.06), 0.12, body_col, Vector3(1.05, 0.62, 1.35))
	# Shell back
	_ellipsoid(attack_root, Vector3(0, 0.62, -0.22), Vector3(0.42, 0.45, 0.25), shell_dark)
	_torus(attack_root, Vector3(0, 0.62, -0.28), 0.25, 0.38, cream, Vector3(90, 0, 0))
	_sphere(attack_root, Vector3(0, 0.75, -0.38), 0.09, shell_dark.lightened(0.12), Vector3(1, 1, 0.25))
	_sphere(attack_root, Vector3(-0.2, 0.55, -0.4), 0.06, shell_dark.lightened(0.12), Vector3(1, 1, 0.25))
	_sphere(attack_root, Vector3(0.19, 0.6, -0.4), 0.05, shell_dark.lightened(0.12), Vector3(1, 1, 0.25))
	# Body / belly
	_ellipsoid(attack_root, Vector3(0, 0.58, 0.02), Vector3(0.36, 0.4, 0.3), body_col)
	_ellipsoid(attack_root, Vector3(0, 0.56, 0.22), Vector3(0.26, 0.3, 0.13), belly)
	for i in 3:
		_box(attack_root, Vector3(0, 0.47 + i * 0.1, 0.33), Vector3(0.25, 0.014, 0.015), belly.darkened(0.22))
	# Arms
	for side in [-1, 1]:
		var arm := _pivot("arm_%s" % ("l" if side < 0 else "r"), attack_root, Vector3(0.33 * side, 0.68, 0.06))
		_capsule(arm, Vector3(0.06 * side, -0.13, 0.08), 0.075, 0.32, body_col, Vector3(0, 0, -30 * side))
		_sphere(arm, Vector3(0.13 * side, -0.3, 0.16), 0.09, body_col, Vector3(1, 0.8, 1.1))
		for finger in [-1, 0, 1]:
			_cone(arm, Vector3(0.13 * side + finger * 0.035, -0.33, 0.24), 0.018, 0.08, body_col.darkened(0.1), Vector3(90, 0, 0))
	# Head
	var head := _pivot("head", attack_root, Vector3(0, 0.98, 0.04))
	_ellipsoid(head, Vector3.ZERO, Vector3(0.34, 0.31, 0.33), body_col)
	_ellipsoid(head, Vector3(0, -0.06, 0.27), Vector3(0.22, 0.16, 0.15), body_col)
	_ellipsoid(head, Vector3(0, -0.1, 0.39), Vector3(0.12, 0.05, 0.04), belly.darkened(0.12))
	# Small side fins
	_sphere(head, Vector3(-0.31, 0.08, -0.02), 0.08, body_col, Vector3(0.5, 0.8, 1.0))
	_sphere(head, Vector3(0.31, 0.08, -0.02), 0.08, body_col, Vector3(0.5, 0.8, 1.0))
	# Eyes
	_eyes(head, Vector3(-0.14, 0.05, 0.29), Vector3(0.14, 0.05, 0.29), 0.07, Color("#6d3b2b"), Color("#100b0b"))
	# Sunglasses-like shell rim? keep authentic simple.
	_ellipsoid(head, Vector3(0, 0.2, 0.04), Vector3(0.22, 0.08, 0.2), body_col.darkened(0.12))

# ------------------------------------------------------------------ animation API

func _process(delta: float) -> void:
	if idle_root == null:
		return
	_time += delta * _idle_speed
	if not _idle_enabled:
		return
	var bob := sin(_time * 2.1 + _phase) * 0.025
	var float_offset := 0.0
	if species_id == "gengar":
		float_offset = 0.07 + sin(_time * 1.4 + _phase) * 0.06
	idle_root.position = Vector3(0, bob + float_offset, 0)
	idle_root.rotation = Vector3(sin(_time * 0.8 + _phase) * 0.008, 0, sin(_time * 1.1 + _phase) * 0.008)
	if _parts.has("head"):
		var head: Node3D = _parts["head"]
		var base: Vector3 = _base_rot.get("head", Vector3.ZERO)
		head.rotation_degrees = base + Vector3(sin(_time * 1.3 + _phase) * 2.2, sin(_time * 0.7 + _phase) * 3.5, sin(_time * 1.0 + _phase) * 1.0)
	for key in ["ear_l", "ear_r"]:
		if _parts.has(key):
			var ear: Node3D = _parts[key]
			var base: Vector3 = _base_rot.get(key, Vector3.ZERO)
			var side := -1.0 if key.ends_with("l") else 1.0
			ear.rotation_degrees = base + Vector3(sin(_time * 2.3 + _phase + side) * 3.0, 0, side * sin(_time * 1.8 + _phase) * 2.0)
	for key in ["wing_l", "wing_r"]:
		if _parts.has(key):
			var wing: Node3D = _parts[key]
			var base: Vector3 = _base_rot.get(key, Vector3.ZERO)
			var side := -1.0 if key.ends_with("l") else 1.0
			wing.rotation_degrees = base + Vector3(0, 0, side * sin(_time * 2.6 + _phase) * 8.0)
	if _parts.has("tail"):
		var tail: Node3D = _parts["tail"]
		var base: Vector3 = _base_rot.get("tail", Vector3.ZERO)
		tail.rotation_degrees = base + Vector3(0, sin(_time * 2.0 + _phase) * 7.0, sin(_time * 1.5 + _phase) * 2.0)
	if _parts.has("bulb"):
		var bulb: Node3D = _parts["bulb"]
		bulb.rotation_degrees = Vector3(0, sin(_time * 0.8 + _phase) * 3.0, 0)
	for key in ["arm_l", "arm_r"]:
		if _parts.has(key):
			var arm: Node3D = _parts[key]
			var base: Vector3 = _base_rot.get(key, Vector3.ZERO)
			var side := -1.0 if key.ends_with("l") else 1.0
			arm.rotation_degrees = base + Vector3(sin(_time * 1.7 + _phase + side) * 2.0, 0, side * sin(_time * 1.2 + _phase) * 2.0)

func set_idle_speed(speed: float) -> void:
	_idle_speed = maxf(0.0, speed)

func face_angle(y_radians: float) -> void:
	rotation.y = y_radians

func get_effect_global_position() -> Vector3:
	if effect_anchor != null:
		return effect_anchor.global_position
	return global_position + Vector3(0, 1, 0.3)

func play_entrance() -> void:
	if idle_root == null:
		return
	idle_root.scale = Vector3(0.01, 0.01, 0.01)
	idle_root.rotation_degrees.y = -180.0
	_spawn_burst("normal", effect_anchor.position if effect_anchor != null else Vector3(0, 1, 0), 16)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(idle_root, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(idle_root, "rotation_degrees:y", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

func play_attack(move_type: String) -> void:
	if attack_root == null:
		return
	var physical := move_type in ["normal", "flying", "dark"]
	if physical:
		var tw := create_tween()
		tw.tween_property(attack_root, "position:z", 0.85, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _spawn_burst(move_type, effect_anchor.position if effect_anchor != null else Vector3(0, 1, 0.4), 20))
		tw.tween_property(attack_root, "position:z", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		var tw := create_tween()
		tw.tween_property(attack_root, "scale", Vector3(1.08, 1.08, 1.08), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): _spawn_burst(move_type, effect_anchor.position if effect_anchor != null else Vector3(0, 1, 0.4), 26))
		tw.tween_property(attack_root, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK)
		await tw.finished
	attack_root.position = Vector3.ZERO
	attack_root.scale = Vector3.ONE

func play_hit(effectiveness: float = 1.0) -> void:
	if attack_root == null:
		return
	var strength := 0.22 if effectiveness > 1.0 else 0.12
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(attack_root, "position:x", strength, 0.05)
	tw.tween_property(attack_root, "position:x", -strength, 0.08)
	tw.tween_property(attack_root, "position:x", 0.0, 0.08)
	tw.tween_property(attack_root, "rotation_degrees:z", -7.0 * (1.0 if randf() > 0.5 else -1.0), 0.07)
	tw.tween_property(attack_root, "rotation_degrees:z", 0.0, 0.14)
	_flash_materials()
	_spawn_burst("impact", Vector3(0, 1.0, 0.5), 12)
	await tw.finished

func play_faint() -> void:
	if attack_root == null:
		return
	_idle_enabled = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(attack_root, "rotation_degrees:z", 78.0 if randf() > 0.5 else -78.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(attack_root, "position:y", -0.25, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(attack_root, "scale", Vector3(0.92, 0.92, 0.92), 0.7)
	await tw.finished
	_fainted = true

func play_victory() -> void:
	if attack_root == null:
		return
	var tw := create_tween()
	for i in 3:
		tw.tween_property(attack_root, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(attack_root, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.08)
	tw.tween_property(attack_root, "rotation_degrees:y", 360.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): attack_root.rotation_degrees.y = 0.0)
	await tw.finished

func _flash_materials() -> void:
	for mat in materials:
		if mat == null:
			continue
		mat.emission_enabled = true
		mat.emission = Color(1, 0.92, 0.92)
		mat.emission_energy_multiplier = 1.5
	var timer := get_tree().create_timer(0.12)
	await timer.timeout
	for mat in materials:
		if mat == null:
			continue
		var orig_enabled := bool(mat.get_meta("orig_emission_enabled", false))
		mat.emission_enabled = orig_enabled
		if orig_enabled:
			mat.emission = mat.get_meta("orig_emission", Color.TRANSPARENT)
			mat.emission_energy_multiplier = float(mat.get_meta("orig_emission_energy", 0.0))
		else:
			mat.emission_energy_multiplier = 0.0

func _spawn_burst(effect_type: String, local_pos: Vector3, count: int = 20) -> void:
	if not is_inside_tree():
		return
	var color := _effect_color(effect_type)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.55
	p.emitting = true
	p.local_coords = false
	p.position = local_pos
	p.direction = Vector3(0, 0.35, 0.9)
	p.spread = 60.0
	p.gravity = Vector3(0, -3.0, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.2
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.11
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat
	attack_root.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 2.4
	light.position = local_pos
	attack_root.add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)
	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(p.queue_free)

func _effect_color(effect_type: String) -> Color:
	match effect_type:
		"fire": return Color("#ff7a2a")
		"water": return Color("#5fc9ff")
		"grass": return Color("#6fe37f")
		"electric": return Color("#ffe14d")
		"ghost": return Color("#a97bff")
		"poison": return Color("#d06ae8")
		"flying": return Color("#d8f2ff")
		"dark": return Color("#8d5bff")
		"impact": return Color("#fff2c4")
		_: return Color("#ffffff")
