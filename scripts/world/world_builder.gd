class_name WorldBuilder
extends RefCounted
## Procedural environment kit: PBR primitives, trees, crowds, signs and props.

static func material(color: Color, roughness: float = 0.62, metallic: float = 0.0, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat

static func add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.62, emission: Color = Color.TRANSPARENT, energy: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, material(color, rough, 0.0, emission, energy), pos, rot_deg, Vector3.ONE, shadows)

static func cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.6, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 2
	return add_mesh(parent, mesh, material(color, rough, 0.0, emission, energy), pos, rot_deg)

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, scl: Vector3 = Vector3.ONE, rough: float = 0.6, emission: Color = Color.TRANSPARENT, energy: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return add_mesh(parent, mesh, material(color, rough, 0.0, emission, energy), pos, Vector3.ZERO, scl, shadows)

static func torus(parent: Node3D, pos: Vector3, inner: float, outer: float, color: Color, scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO, emission: Color = Color.TRANSPARENT, energy: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 10
	return add_mesh(parent, mesh, material(color, 0.5, 0.15, emission, energy), pos, rot_deg, scl)

static func label3d(parent: Node3D, text: String, pos: Vector3, color: Color = Color.WHITE, size: int = 48, pixel: float = 0.006, billboard: bool = true) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = maxi(4, int(size * 0.12))
	label.outline_modulate = Color(0.01, 0.02, 0.06, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.render_priority = 2
	label.double_sided = true
	parent.add_child(label)
	return label

static func tree(parent: Node3D, base: Vector3, size: float = 1.0, leaf: Color = Color("#3f9a57"), leaf_light: Color = Color("#5fc470")) -> void:
	cylinder(parent, base + Vector3(0, 1.3 * size, 0), 0.16 * size, 0.24 * size, 2.6 * size, Color("#75502f"), Vector3.ZERO, 0.85)
	var trunk_top := base + Vector3(0, 2.5 * size, 0)
	sphere(parent, trunk_top + Vector3(0, 0.7 * size, 0), 1.35 * size, leaf, Vector3(1.0, 0.9, 1.0), 0.85)
	sphere(parent, trunk_top + Vector3(-0.85 * size, 0.25 * size, 0.2 * size), 0.95 * size, leaf, Vector3(1.0, 0.85, 1.0), 0.85)
	sphere(parent, trunk_top + Vector3(0.8 * size, 0.35 * size, -0.15 * size), 0.9 * size, leaf_light, Vector3(1.0, 0.8, 1.0), 0.85)
	sphere(parent, trunk_top + Vector3(0.1 * size, 1.25 * size, 0.1 * size), 0.82 * size, leaf_light, Vector3(1.0, 0.9, 1.0), 0.8)

static func cloud(parent: Node3D, pos: Vector3, scale_value: float = 1.0) -> void:
	var mat := material(Color(1, 1, 1, 0.92), 1.0, 0.0, Color(1, 1, 1, 0.18), 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var offset := Vector3(float(i - 1.5) * 2.2, sin(float(i) * 1.8) * 0.7, cos(float(i) * 2.1) * 0.9)
		var mesh := SphereMesh.new()
		mesh.radius = 1.8 + float(i % 2) * 0.8
		mesh.height = mesh.radius * 1.25
		mesh.radial_segments = 16
		mesh.rings = 8
		add_mesh(parent, mesh, mat, pos + offset * scale_value, Vector3.ZERO, Vector3(1.3, 0.58, 1.0) * scale_value, false)

static func fence(parent: Node3D, from: Vector3, to: Vector3, height: float = 1.1) -> void:
	var distance := from.distance_to(to)
	var mid := (from + to) * 0.5
	var direction := (to - from).normalized()
	var yaw := rad_to_deg(atan2(direction.x, direction.z))
	var wood := Color("#b07a45")
	box(parent, mid + Vector3(0, height, 0), Vector3(0.1, 0.1, distance), wood, Vector3(0, yaw, 0), 0.8)
	box(parent, mid + Vector3(0, height * 0.55, 0), Vector3(0.09, 0.09, distance), wood.darkened(0.08), Vector3(0, yaw, 0), 0.8)
	var posts := maxi(2, int(distance / 2.2))
	for i in posts + 1:
		var t := float(i) / float(posts)
		var p := from.lerp(to, t)
		box(parent, p + Vector3(0, height * 0.5, 0), Vector3(0.16, height, 0.16), wood.darkened(0.12), Vector3(0, yaw, 0), 0.8)

static func bench(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> void:
	var wood := Color("#b9824c")
	var metal := Color("#3a4560")
	box(parent, pos + Vector3(0, 0.48, 0), Vector3(1.9, 0.12, 0.55), wood, Vector3(0, yaw, 0), 0.75)
	box(parent, pos + Vector3(0, 0.75, -0.24), Vector3(1.9, 0.45, 0.09), wood.lightened(0.06), Vector3(-8, yaw, 0), 0.75)
	for side in [-1, 1]:
		box(parent, pos + Vector3(0.72 * side, 0.24, 0), Vector3(0.1, 0.48, 0.45), metal, Vector3(0, yaw, 0), 0.5)

static func crowd(parent: Node3D, center: Vector3, rx: float, rz: float, rows: int, per_row: int, base_y: float, row_height: float) -> void:
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.62
	body_mesh.radial_segments = 8
	body_mesh.rings = 3
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	bodies.instance_count = rows * per_row
	bodies.mesh = body_mesh
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	heads.instance_count = rows * per_row
	heads.mesh = head_mesh
	var shirt_palette: Array[Color] = [Color("#ffd05a"), Color("#78e2ff"), Color("#ff7a8a"), Color("#8be28b"), Color("#b28bff"), Color("#ffb23b"), Color("#f2f7ff"), Color("#ff5c67")]
	var skin_palette: Array[Color] = [Color("#f2c49b"), Color("#d99b73"), Color("#b9754f"), Color("#8a5a42"), Color("#e6b48e"), Color("#c88f68")]
	var index := 0
	for row in rows:
		for seat in per_row:
			var angle := TAU * float(seat) / float(per_row) + float(row) * 0.045
			var radius_scale := 1.0 + float(row) * 0.035
			var pos := center + Vector3(cos(angle) * rx * radius_scale, base_y + float(row) * row_height, sin(angle) * rz * radius_scale)
			var bob := sin(float(seat) * 2.1 + float(row)) * 0.05
			var look := center - pos
			var yaw := atan2(look.x, look.z)
			var basis := Basis(Vector3.UP, yaw)
			bodies.set_instance_transform(index, Transform3D(basis, pos + Vector3(0, 0.31 + bob, 0)))
			bodies.set_instance_color(index, shirt_palette[(index * 3 + row) % shirt_palette.size()])
			heads.set_instance_transform(index, Transform3D(basis, pos + Vector3(0, 0.72 + bob, 0)))
			heads.set_instance_color(index, skin_palette[(index + row) % skin_palette.size()])
			index += 1
	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.roughness = 0.8
	body_mat.rim_enabled = true
	body_mat.rim = 0.18
	var body_instance := MultiMeshInstance3D.new()
	body_instance.multimesh = bodies
	body_instance.material_override = body_mat
	body_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body_instance.extra_cull_margin = 30.0
	parent.add_child(body_instance)
	var head_mat := StandardMaterial3D.new()
	head_mat.vertex_color_use_as_albedo = true
	head_mat.roughness = 0.7
	var head_instance := MultiMeshInstance3D.new()
	head_instance.multimesh = heads
	head_instance.material_override = head_mat
	head_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	head_instance.extra_cull_margin = 30.0
	parent.add_child(head_instance)

static func spotlight(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float = 6.0, range_value: float = 30.0, angle: float = 32.0) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_value
	light.spot_angle = angle
	light.spot_attenuation = 1.2
	light.shadow_enabled = true
	parent.add_child(light)
	light.look_at(target, Vector3.UP)
	return light

static func ring_marker(parent: Node3D, pos: Vector3, color: Color, radius: float = 0.85) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	torus(root, Vector3(0, 0.02, 0), radius * 0.82, radius, color, Vector3.ONE, Vector3.ZERO, color, 1.8)
	var diamond := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.26
	mesh.radial_segments = 4
	mesh.rings = 2
	diamond.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	diamond.material_override = mat
	diamond.position = Vector3(0, 1.65, 0)
	root.add_child(diamond)
	var tw := root.create_tween().set_loops()
	tw.tween_property(diamond, "position:y", 1.9, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(diamond, "position:y", 1.65, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return root
