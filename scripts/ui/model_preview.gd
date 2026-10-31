class_name ModelPreview
extends SubViewportContainer
## Reusable 3D turntable for trainers and Pokémon. Renders into a transparent SubViewport.

var mode := "pokemon"
var pokemon_id := "pikachu"
var trainer_data: Dictionary = {}
var rotation_speed := 0.32
var accent := Color("#78e2ff")

var _viewport: SubViewport
var _world: Node3D
var _stage: Node3D
var _model_root: Node3D
var _model: Node3D
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _fill_light: OmniLight3D
var _rim_light: OmniLight3D
var _time := 0.0
var _ready_built := false
var _last_pokemon := ""
var _last_trainer := ""
var _wave_timer := 0.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build_world()
	_ready_built = true
	_refresh()

func set_pokemon(id: String) -> void:
	pokemon_id = id
	mode = "pokemon"
	_last_pokemon = ""
	if _ready_built:
		_refresh()

func set_trainer(data: Dictionary) -> void:
	trainer_data = data
	mode = "trainer"
	_last_trainer = ""
	if _ready_built:
		_refresh()

func set_accent(color: Color) -> void:
	accent = color
	if _ready_built:
		_apply_accent()

func _build_world() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(640, 640)
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_world = Node3D.new()
	_world.name = "PreviewWorld"
	_viewport.add_child(_world)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.62, 0.88)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.18
	world_env.environment = env
	_world.add_child(world_env)

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.position = Vector3(0, 1.75, 5.1)
	_camera.look_at_from_position(Vector3(0, 1.75, 5.1), Vector3(0, 1.0, 0))
	_camera.current = true
	_world.add_child(_camera)

	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-48, -34, 0)
	_key_light.light_energy = 1.5
	_key_light.light_color = Color(1.0, 0.95, 0.88)
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_max_distance = 16.0
	_world.add_child(_key_light)

	_fill_light = OmniLight3D.new()
	_fill_light.position = Vector3(-2.6, 2.0, 2.2)
	_fill_light.light_energy = 2.0
	_fill_light.omni_range = 9.0
	_fill_light.light_color = Color("#78e2ff")
	_world.add_child(_fill_light)

	_rim_light = OmniLight3D.new()
	_rim_light.position = Vector3(2.4, 2.4, -2.0)
	_rim_light.light_energy = 3.2
	_rim_light.omni_range = 8.0
	_rim_light.light_color = Color("#ffb23b")
	_world.add_child(_rim_light)

	_stage = Node3D.new()
	_stage.name = "Stage"
	_world.add_child(_stage)
	_build_stage()
	_apply_accent()

func _build_stage() -> void:
	var platform := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.42
	cyl.bottom_radius = 1.55
	cyl.height = 0.22
	cyl.radial_segments = 48
	platform.mesh = cyl
	platform.position = Vector3(0, -0.11, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.055, 0.08, 0.16)
	mat.metallic = 0.45
	mat.roughness = 0.32
	platform.material_override = mat
	platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_stage.add_child(platform)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.33
	torus.outer_radius = 1.46
	torus.rings = 48
	torus.ring_segments = 10
	ring.mesh = torus
	ring.position = Vector3(0, 0.005, 0)
	ring.material_override = _glow_material(accent, 1.8)
	_stage.add_child(ring)

	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.3
	disc_mesh.bottom_radius = 1.3
	disc_mesh.height = 0.012
	disc_mesh.radial_segments = 48
	disc.mesh = disc_mesh
	disc.position = Vector3(0, 0.008, 0)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.08)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.emission_enabled = true
	disc_mat.emission = accent
	disc_mat.emission_energy_multiplier = 0.35
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = disc_mat
	_stage.add_child(disc)

	var particles := CPUParticles3D.new()
	particles.amount = 26
	particles.lifetime = 2.8
	particles.position = Vector3(0, 0.05, 0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = 1.4
	particles.emission_ring_inner_radius = 1.2
	particles.emission_ring_height = 0.05
	particles.direction = Vector3.UP
	particles.spread = 14.0
	particles.gravity = Vector3(0, 0.32, 0)
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.45
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.045
	var spark := SphereMesh.new()
	spark.radius = 1.0
	spark.height = 2.0
	spark.radial_segments = 6
	spark.rings = 3
	particles.mesh = spark
	particles.material_override = _glow_material(accent, 2.2)
	_stage.add_child(particles)

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_stage.add_child(_model_root)

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _apply_accent() -> void:
	if _stage == null:
		return
	for child in _stage.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat := child.material_override as StandardMaterial3D
			if mat.emission_enabled:
				mat.albedo_color = Color(accent.r, accent.g, accent.b, mat.albedo_color.a)
				mat.emission = accent
		elif child is CPUParticles3D and child.material_override is StandardMaterial3D:
			var pmat := child.material_override as StandardMaterial3D
			pmat.albedo_color = accent
			pmat.emission = accent
	if _fill_light != null:
		_fill_light.light_color = accent.lightened(0.25)
	if _rim_light != null:
		_rim_light.light_color = accent.lerp(Color("#ffb23b"), 0.35)

func _refresh() -> void:
	if _model_root == null:
		return
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	if mode == "trainer":
		var key := str(trainer_data.get("id", ""))
		if key == "":
			return
		_last_trainer = key
		_last_pokemon = ""
		var trainer := TrainerModel.new()
		_model_root.add_child(trainer)
		trainer.setup(trainer_data)
		trainer.scale = Vector3.ONE * 1.42
		_model = trainer
		_camera.position = Vector3(0, 2.05, 5.6)
		_camera.look_at_from_position(Vector3(0, 2.05, 5.6), Vector3(0, 1.1, 0))
		_wave_timer = 1.2
	else:
		var id := pokemon_id
		if id == "":
			id = "pikachu"
		_last_pokemon = id
		_last_trainer = ""
		var species := AssetLibrary.get_pokemon(id)
		if species == null:
			return
		var pokemon := PokemonModel.new()
		_model_root.add_child(pokemon)
		pokemon.setup(species, true)
		pokemon.set_idle_speed(0.85)
		var species_scale := species.model_scale if species.model_scale > 0.0 else 1.0
		pokemon.scale = Vector3.ONE * (1.28 * species_scale)
		_model = pokemon
		var tall := id in ["charizard", "gengar"]
		_camera.position = Vector3(0, 1.85 if tall else 1.55, 5.4 if tall else 4.7)
		_camera.look_at_from_position(_camera.position, Vector3(0, 1.08 if tall else 0.85, 0))
		_wave_timer = 0.0
	_apply_accent()
	_model_root.scale = Vector3(0.82, 0.82, 0.82)
	_model_root.rotation.y = -0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_model_root, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model_root, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_time += delta
	if _model_root != null:
		_model_root.rotation.y = sin(_time * rotation_speed) * 0.34
	if _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0 and _model is TrainerModel:
			(_model as TrainerModel).play_wave()
			_wave_timer = 5.5
	if _fill_light != null:
		_fill_light.position = Vector3(cos(_time * 0.4) * 2.7, 2.0, sin(_time * 0.4) * 2.2)
