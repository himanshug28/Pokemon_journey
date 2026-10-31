extends Node3D
## Stadium Playground: a bright outdoor training park in front of the stadium.
## Free third-person exploration, NPC challengers, a following partner and travel to the arena.

const SCENE_PATH := "res://scenes/arenas/stadium_playground.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var player: PlayerController
var hud: WorldHUD
var companion: PokemonModel
var companion_root: Node3D
var _rng := RandomNumberGenerator.new()
var _npcs: Array[Node3D] = []
var _time := 0.0
var _companion_facing := 0.0
var _pet_cooldown := 0.0

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.3, "MAIN MENU")
		return
	GameState.set_location(GameState.LOCATION_PLAYGROUND)
	_rng.seed = 9917
	_build_environment()
	_build_ground()
	_build_stadium()
	_build_props()
	_build_boundary()
	_spawn_player()
	_spawn_companion()
	_spawn_npcs()
	_spawn_interactables()
	_build_hud()
	AudioManager.play_music("playground", 0.8)
	AudioManager.play_ambience("stop", 0.3)
	_show_intro()
	_consume_last_result()
	set_process(true)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#2f7fd6")
	sky_material.sky_horizon_color = Color("#bfe9ff")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color("#2c6d49")
	sky_material.ground_horizon_color = Color("#b7e6cb")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("#cfeaff")
	env.fog_light_energy = 0.5
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("#fff2d8")
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.04
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 142, 0)
	fill.light_color = Color("#9dd7ff")
	fill.light_energy = 0.42
	add_child(fill)

func _build_ground() -> void:
	var grass := WorldBuilder.material(Color("#5bbd6d"), 0.94)
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 36.0
	ground_mesh.bottom_radius = 37.0
	ground_mesh.height = 0.9
	ground_mesh.radial_segments = 72
	ground_mesh.rings = 4
	var ground := WorldBuilder.add_mesh(self, ground_mesh, grass, Vector3(0, -0.45, 0))
	ground.name = "Ground"

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	var ground_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 36.0
	cylinder.height = 1.0
	ground_shape.shape = cylinder
	ground_shape.position = Vector3(0, -0.5, 0)
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	# Central plaza.
	var plaza := WorldBuilder.cylinder(self, Vector3(0, 0.01, 0), 8.2, 8.4, 0.08, Color("#d9cfa9"), Vector3.ZERO, 0.82)
	plaza.name = "Plaza"
	WorldBuilder.torus(self, Vector3(0, 0.07, 0), 7.6, 7.95, Color("#f3ead0"), Vector3.ONE, Vector3.ZERO)
	WorldBuilder.torus(self, Vector3(0, 0.075, 0), 3.9, 4.15, Color("#ffffff"), Vector3.ONE, Vector3.ZERO)
	WorldBuilder.torus(self, Vector3(0, 0.08, 0), 1.0, 1.25, Color("#ff5c62"), Vector3.ONE, Vector3.ZERO)
	WorldBuilder.cylinder(self, Vector3(0, 0.03, 0), 3.8, 3.8, 0.05, Color("#fff7e2"), Vector3.ZERO, 0.7)
	WorldBuilder.box(self, Vector3(0, 0.06, 0), Vector3(7.4, 0.02, 0.32), Color("#ff5c62"))
	WorldBuilder.cylinder(self, Vector3(0, 0.07, 0), 0.62, 0.62, 0.04, Color("#1b2540"), Vector3.ZERO, 0.4)
	WorldBuilder.cylinder(self, Vector3(0, 0.09, 0), 0.22, 0.22, 0.03, Color("#eaf6ff"), Vector3.ZERO, 0.3)

	# Paths.
	var path_mat := Color("#e5cf9f")
	WorldBuilder.box(self, Vector3(0, 0.04, 8.8), Vector3(4.4, 0.06, 15.4), path_mat, Vector3.ZERO, 0.85)
	WorldBuilder.box(self, Vector3(0, 0.04, -16.2), Vector3(4.4, 0.06, 17.6), path_mat, Vector3.ZERO, 0.85)
	WorldBuilder.box(self, Vector3(9.6, 0.04, 4.4), Vector3(15.0, 0.06, 3.4), path_mat, Vector3.ZERO, 0.85)
	WorldBuilder.box(self, Vector3(-9.4, 0.04, 3.4), Vector3(13.0, 0.06, 3.0), path_mat, Vector3.ZERO, 0.85)
	WorldBuilder.box(self, Vector3(-8.8, 0.04, -7.0), Vector3(3.0, 0.06, 12.0), path_mat, Vector3.ZERO, 0.85)

	# Training field.
	WorldBuilder.box(self, Vector3(11.0, 0.02, -7.2), Vector3(10.0, 0.06, 9.0), Color("#d6b77f"), Vector3.ZERO, 0.92)
	for i in 3:
		var x := 8.2 + i * 2.7
		WorldBuilder.cylinder(self, Vector3(x, 0.05, -7.2), 0.9, 0.9, 0.04, Color("#f2e6c8"), Vector3.ZERO, 0.85)
		WorldBuilder.torus(self, Vector3(x, 0.08, -7.2), 0.78, 0.92, Color("#ffffff"), Vector3.ONE, Vector3.ZERO)

	# Pond.
	var pond_pos := Vector3(-11.5, -0.02, -4.0)
	WorldBuilder.cylinder(self, pond_pos + Vector3(0, -0.02, 0), 4.6, 4.9, 0.2, Color("#a98a5d"), Vector3.ZERO, 0.9)
	var water := WorldBuilder.material(Color("#4fb8dd"), 0.12, 0.25, Color("#2d9ed0"), 0.25)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(0.28, 0.72, 0.86, 0.82)
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 4.2
	water_mesh.bottom_radius = 4.2
	water_mesh.height = 0.05
	water_mesh.radial_segments = 48
	WorldBuilder.add_mesh(self, water_mesh, water, pond_pos + Vector3(0, 0.06, 0))
	for i in 11:
		var angle := TAU * float(i) / 11.0
		WorldBuilder.sphere(self, pond_pos + Vector3(cos(angle) * 4.45, 0.08, sin(angle) * 4.45), 0.34, Color("#b9a37c"), Vector3(1.2, 0.55, 1.0), 0.9)
	# Lily pads.
	for i in 6:
		var angle := float(i) * 1.7
		var radius := 1.4 + float(i % 3) * 0.7
		WorldBuilder.cylinder(self, pond_pos + Vector3(cos(angle) * radius, 0.1, sin(angle) * radius), 0.34, 0.34, 0.02, Color("#4e9d58"), Vector3.ZERO, 0.7)
	WorldBuilder.cylinder(self, pond_pos + Vector3(1.1, 0.16, 0.4), 0.13, 0.13, 0.28, Color("#ff9fc8"), Vector3.ZERO, 0.5)

	# Flower beds.
	for bed in [Vector3(-6.8, 0, 13.2), Vector3(7.4, 0, 13.6), Vector3(-16.5, 0, 6.2), Vector3(17.0, 0, 2.0)]:
		WorldBuilder.cylinder(self, bed + Vector3(0, 0.02, 0), 2.1, 2.2, 0.12, Color("#8b5f39"), Vector3.ZERO, 0.95)
		WorldBuilder.cylinder(self, bed + Vector3(0, 0.08, 0), 1.9, 1.9, 0.05, Color("#4f9c4d"), Vector3.ZERO, 0.9)
		for i in 12:
			var angle := TAU * float(i) / 12.0
			var radius := 0.4 + float(i % 4) * 0.36
			var color: Color = [Color("#ffe27a"), Color("#ff9fc8"), Color("#ffffff"), Color("#ff8a6a")][i % 4]
			WorldBuilder.sphere(self, bed + Vector3(cos(angle) * radius, 0.2, sin(angle) * radius), 0.075, color, Vector3(1.0, 0.7, 1.0), 0.5)
			WorldBuilder.cylinder(self, bed + Vector3(cos(angle) * radius, 0.13, sin(angle) * radius), 0.012, 0.018, 0.18, Color("#3b7a3e"))

func _build_stadium() -> void:
	var stadium := Node3D.new()
	stadium.name = "StadiumFacade"
	add_child(stadium)
	var wall := Color("#d9dce8")
	var dark := Color("#2a3350")
	var accent := Color("#ef3f52")
	var gold := Color("#ffd05a")
	# Main curved-ish facade made of stacked boxes.
	WorldBuilder.box(stadium, Vector3(0, 4.2, -35.5), Vector3(34.0, 8.4, 2.4), wall, Vector3.ZERO, 0.7)
	WorldBuilder.box(stadium, Vector3(0, 9.2, -35.2), Vector3(37.0, 2.4, 3.2), dark, Vector3.ZERO, 0.55)
	WorldBuilder.box(stadium, Vector3(0, 2.2, -34.2), Vector3(30.0, 1.1, 0.5), Color("#eef2fb"), Vector3.ZERO, 0.6)
	WorldBuilder.box(stadium, Vector3(0, 10.7, -35.0), Vector3(39.0, 0.5, 4.0), accent, Vector3.ZERO, 0.5)
	# Entrance.
	WorldBuilder.box(stadium, Vector3(-4.1, 3.2, -33.9), Vector3(2.2, 6.4, 2.8), Color("#b9c1d8"), Vector3.ZERO, 0.6)
	WorldBuilder.box(stadium, Vector3(4.1, 3.2, -33.9), Vector3(2.2, 6.4, 2.8), Color("#b9c1d8"), Vector3.ZERO, 0.6)
	WorldBuilder.box(stadium, Vector3(0, 6.9, -33.9), Vector3(10.4, 1.8, 2.8), Color("#c9d0e4"), Vector3.ZERO, 0.6)
	WorldBuilder.box(stadium, Vector3(0, 3.3, -32.4), Vector3(6.4, 6.6, 0.35), Color("#0b1226"), Vector3.ZERO, 0.3)
	WorldBuilder.box(stadium, Vector3(0, 6.3, -32.2), Vector3(7.6, 0.4, 0.5), gold, Vector3.ZERO, 0.4)
	# Banner and sign.
	WorldBuilder.box(stadium, Vector3(0, 12.2, -33.0), Vector3(22.0, 2.4, 0.4), accent, Vector3.ZERO, 0.55)
	WorldBuilder.label3d(stadium, "STADIUM PLAYGROUND", Vector3(0, 12.2, -32.7), Color("#fff7dd"), 72, 0.012, false)
	WorldBuilder.label3d(stadium, "BATTLE ARENA  •  ENTRANCE", Vector3(0, 8.3, -32.0), Color("#ffe9a8"), 30, 0.0065, false)
	# Side towers.
	for side in [-1, 1]:
		var x: float = 14.5 * side
		WorldBuilder.cylinder(stadium, Vector3(x, 7.0, -34.0), 2.1, 2.5, 14.0, Color("#e6eaf5"), Vector3.ZERO, 0.6)
		WorldBuilder.cylinder(stadium, Vector3(x, 14.2, -34.0), 2.8, 2.8, 1.0, accent, Vector3.ZERO, 0.5)
		WorldBuilder.cylinder(stadium, Vector3(x, 15.2, -34.0), 0.3, 0.45, 3.0, dark, Vector3.ZERO, 0.4)
		WorldBuilder.sphere(stadium, Vector3(x, 16.8, -34.0), 0.42, gold, Vector3.ONE, 0.3, gold, 2.2)
		for row in 3:
			for col in 3:
				WorldBuilder.box(stadium, Vector3(x - 1.1 + col * 1.1, 8.6 + row * 1.7, -32.5), Vector3(0.7, 0.9, 0.15), Color("#8fb7e6"), Vector3.ZERO, 0.25, Color("#8fc7ff"), 0.35)
	# Roof trusses.
	for i in 7:
		var x := -15.0 + i * 5.0
		WorldBuilder.box(stadium, Vector3(x, 15.5, -36.0), Vector3(0.4, 8.0, 0.4), dark, Vector3.ZERO, 0.5)
	WorldBuilder.box(stadium, Vector3(0, 18.9, -36.0), Vector3(34.0, 0.5, 0.6), dark, Vector3.ZERO, 0.5)
	# Forecourt planters.
	for side in [-1, 1]:
		WorldBuilder.cylinder(stadium, Vector3(10.0 * side, 0.2, -29.0), 1.5, 1.7, 0.4, Color("#a98a5d"), Vector3.ZERO, 0.9)
		WorldBuilder.tree(stadium, Vector3(10.0 * side, 0.3, -29.0), 0.55, Color("#3f9a57"), Color("#5fc470"))
	# Lights.
	WorldBuilder.spotlight(stadium, Vector3(-11.0, 13.0, -27.0), Vector3(0, 0, -2), Color("#d8f2ff"), 5.0, 34.0, 38.0)
	WorldBuilder.spotlight(stadium, Vector3(11.0, 13.0, -27.0), Vector3(0, 0, -2), Color("#ffe6b0"), 5.0, 34.0, 38.0)

func _build_props() -> void:
	# Trees around the perimeter.
	var tree_positions: Array[Vector3] = []
	for i in 22:
		var angle := TAU * float(i) / 22.0 + 0.08
		var radius := 26.5 + float(i % 3) * 1.4
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if pos.z < -23.0:
			continue
		tree_positions.append(pos)
	for i in 8:
		var angle := float(i) * 2.1 + 0.4
		var radius := 19.5 + float(i % 3) * 1.1
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if pos.distance_to(Vector3(0, 0, 0)) > 14.0 and pos.z > -20.0:
			tree_positions.append(pos)
	for i in tree_positions.size():
		var size := 0.9 + float(i % 4) * 0.16
		WorldBuilder.tree(self, tree_positions[i], size, Color("#3f9a57").lerp(Color("#2e7d49"), float(i % 3) / 4.0), Color("#6ed07a"))
	# Bushes.
	for i in 26:
		var angle := TAU * float(i) / 26.0 + 0.2
		var radius := 23.0 + float(i % 4) * 1.2
		var pos := Vector3(cos(angle) * radius, 0.2, sin(angle) * radius)
		if pos.z < -22.0:
			continue
		WorldBuilder.sphere(self, pos, 0.62 + float(i % 3) * 0.16, Color("#3f9a57"), Vector3(1.3, 0.8, 1.2), 0.9)
	# Benches around the plaza.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var pos := Vector3(cos(angle) * 10.2, 0, sin(angle) * 10.2)
		WorldBuilder.bench(self, pos, rad_to_deg(angle) + 90.0)
	# Lamps.
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.15
		var pos := Vector3(cos(angle) * 12.5, 0, sin(angle) * 12.5)
		WorldBuilder.cylinder(self, pos + Vector3(0, 1.7, 0), 0.07, 0.1, 3.4, Color("#26314a"), Vector3.ZERO, 0.5)
		WorldBuilder.sphere(self, pos + Vector3(0, 3.5, 0), 0.3, Color("#fff3c9"), Vector3(1, 1.1, 1), 0.3, Color("#ffd05a"), 1.6)
		WorldBuilder.cylinder(self, pos + Vector3(0, 0.12, 0), 0.26, 0.3, 0.24, Color("#26314a"), Vector3.ZERO, 0.5)
	# Training dummies.
	for i in 3:
		var pos := Vector3(7.8 + i * 2.6, 0, -7.2)
		WorldBuilder.cylinder(self, pos + Vector3(0, 0.6, 0), 0.1, 0.14, 1.2, Color("#7b5631"), Vector3.ZERO, 0.8)
		WorldBuilder.torus(self, pos + Vector3(0, 1.5, 0), 0.32, 0.48, Color("#ff5c62"), Vector3.ONE, Vector3(90, 0, 0))
		WorldBuilder.sphere(self, pos + Vector3(0, 1.5, 0), 0.18, Color("#f7f9ff"), Vector3(1, 1, 0.3), 0.4)
	# Rocks and logs near the pond.
	for i in 5:
		var angle := float(i) * 1.5
		WorldBuilder.sphere(self, Vector3(-15.5 + cos(angle) * 2.4, 0.15, -9.0 + sin(angle) * 2.0), 0.36, Color("#8d99b0"), Vector3(1.3, 0.7, 1.0), 0.9)
	# Signboards.
	_sign(Vector3(3.2, 0, 5.6), "TRAINING TIPS", "Win matches to unlock new partners.\nType matchups decide battles — pick your challenger wisely.\nTeam Rocket strikes after every 2 matches.")
	_sign(Vector3(-3.4, 0, -18.0), "BATTLE ARENA", "Step through the gate to challenge the arena.")
	# Clouds.
	for i in 7:
		WorldBuilder.cloud(self, Vector3(-34.0 + i * 12.0, 24.0 + float(i % 3) * 4.0, -48.0 + float(i % 2) * 8.0), 2.2)
	# Fireflies.
	var fireflies := CPUParticles3D.new()
	fireflies.position = Vector3(0, 1.2, 0)
	fireflies.amount = 42
	fireflies.lifetime = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(24.0, 2.5, 24.0)
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.gravity = Vector3(0, 0.05, 0)
	fireflies.initial_velocity_min = 0.05
	fireflies.initial_velocity_max = 0.35
	fireflies.scale_amount_min = 0.025
	fireflies.scale_amount_max = 0.06
	var spark := SphereMesh.new()
	spark.radius = 1.0
	spark.height = 2.0
	spark.radial_segments = 6
	spark.rings = 3
	fireflies.mesh = spark
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.92, 0.55, 0.7)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.85, 0.4)
	spark_mat.emission_energy_multiplier = 2.0
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireflies.material_override = spark_mat
	add_child(fireflies)

func _sign(pos: Vector3, heading: String, body: String) -> void:
	WorldBuilder.cylinder(self, pos + Vector3(0, 0.8, 0), 0.08, 0.1, 1.6, Color("#7b5631"), Vector3.ZERO, 0.85)
	var board := WorldBuilder.box(self, pos + Vector3(0, 1.6, 0), Vector3(3.2, 1.5, 0.12), Color("#b9824c"), Vector3.ZERO, 0.8)
	board.rotation_degrees.y = 0.0
	WorldBuilder.box(self, pos + Vector3(0, 1.6, 0.08), Vector3(2.9, 1.2, 0.04), Color("#f3e6c8"), Vector3.ZERO, 0.85)
	WorldBuilder.label3d(self, heading, pos + Vector3(0, 2.02, 0.12), Color("#3a2b1c"), 32, 0.0055, false)
	WorldBuilder.label3d(self, body, pos + Vector3(0, 1.52, 0.12), Color("#4a3828"), 17, 0.0042, false)

func _build_boundary() -> void:
	var hedge_mat := Color("#3d8d50")
	var segments := 40
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var pos := Vector3(cos(angle) * 30.0, 0.55, sin(angle) * 30.0)
		if pos.z < -25.0:
			continue
		var rot := -rad_to_deg(angle) + 90.0
		WorldBuilder.box(self, pos, Vector3(4.8, 1.1, 0.9), hedge_mat, Vector3(0, rot, 0), 0.95)
		WorldBuilder.box(self, pos + Vector3(0, 0.62, 0), Vector3(4.9, 0.25, 1.0), hedge_mat.lightened(0.08), Vector3(0, rot, 0), 0.95)
	# Invisible tall boundary with a wider radius so jumping cannot escape.
	var boundary := StaticBody3D.new()
	boundary.name = "WorldBoundary"
	add_child(boundary)
	for i in 36:
		var angle := TAU * float(i) / 36.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 8.0, 0.8)
		shape.shape = box
		shape.position = Vector3(cos(angle) * 31.5, 4.0, sin(angle) * 31.5)
		shape.rotation.y = -angle
		boundary.add_child(shape)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.05, 13.5)
	player.camera_pivot.rotation.y = 0.0
	player.capture_mouse(true)

func _spawn_companion() -> void:
	companion_root = Node3D.new()
	companion_root.name = "Companion"
	add_child(companion_root)
	var active := GameState.active_pokemon()
	var species := AssetLibrary.get_pokemon(active)
	if species == null:
		return
	companion = PokemonModel.new()
	companion_root.add_child(companion)
	companion.setup(species)
	companion.scale = Vector3.ONE * (species.model_scale if species.model_scale > 0.0 else 1.0) * 0.82
	companion_root.global_position = player.global_position + Vector3(1.3, 0, 1.4)
	companion_root.rotation.y = PI
	companion.set_idle_speed(1.05)
	# Pet interaction.
	var pet := Interactable.new()
	companion_root.add_child(pet)
	pet.position = Vector3(0, 0.05, 0)
	pet.setup("Pet %s" % species.display_name, "Show your partner some love", Color("#ffd05a"), _pet_companion, false)

func _spawn_npcs() -> void:
	_spawn_npc("rowan", "ben", Vector3(5.6, 0, -3.2), 210.0, Color("#66e3a4"))
	_spawn_npc("mira", "maya", Vector3(-6.4, 0, 7.0), 140.0, Color("#78e2ff"))
	_spawn_npc("nova", "rin", Vector3(8.2, 0, -15.0), 200.0, Color("#ffd05a"))
	_spawn_npc("rex", "leo", Vector3(-3.8, 0, -13.5), 175.0, Color("#ff9a3d"))

func _spawn_npc(trainer_id: String, opponent_id: String, pos: Vector3, yaw: float, accent: Color) -> void:
	var opponent := AssetLibrary.get_opponent_by_id(opponent_id, GameState.regular_matches_completed(), GameState.regular_wins())
	if opponent.is_empty():
		return
	var root := Node3D.new()
	root.name = "NPC_%s" % opponent_id
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var trainer_data := AssetLibrary.get_trainer(trainer_id)
	if trainer_data.is_empty():
		trainer_data = {"id": trainer_id, "accent": accent.to_html(false)}
	var model := TrainerModel.new()
	root.add_child(model)
	model.setup(trainer_data)
	model.scale = Vector3.ONE * 1.16
	WorldBuilder.ring_marker(root, Vector3.ZERO, accent, 0.78)
	WorldBuilder.label3d(root, str(opponent.get("name", "Trainer")), Vector3(0, 2.15, 0), Color(0.92, 0.97, 1.0, 0.96), 30, 0.005, true)
	var interact := Interactable.new()
	root.add_child(interact)
	interact.position = Vector3.ZERO
	interact.setup(str(opponent.get("name", "Trainer")), "Challenge to a battle", accent, func(_player: Node) -> void: _start_regular_battle(opponent_id), false)
	_npcs.append(root)

func _spawn_interactables() -> void:
	# Arena gate.
	var gate_root := Node3D.new()
	gate_root.position = Vector3(0, 0, -27.0)
	add_child(gate_root)
	WorldBuilder.torus(gate_root, Vector3(0, 0.05, 0), 2.6, 3.0, Color("#78e2ff"), Vector3.ONE, Vector3.ZERO, Color("#78e2ff"), 0.8)
	WorldBuilder.cylinder(gate_root, Vector3(-3.0, 2.4, 0), 0.32, 0.42, 4.8, Color("#e6eaf5"), Vector3.ZERO, 0.5)
	WorldBuilder.cylinder(gate_root, Vector3(3.0, 2.4, 0), 0.32, 0.42, 4.8, Color("#e6eaf5"), Vector3.ZERO, 0.5)
	WorldBuilder.box(gate_root, Vector3(0, 4.8, 0), Vector3(6.6, 0.8, 0.6), Color("#ef3f52"), Vector3.ZERO, 0.5)
	WorldBuilder.label3d(gate_root, "BATTLE ARENA", Vector3(0, 5.0, 0.35), Color("#fff7dd"), 38, 0.006, true)
	var gate := Interactable.new()
	gate_root.add_child(gate)
	gate.setup("Battle Arena Gate", "Travel to the Battle Arena", Color("#78e2ff"), _travel_to_arena, false)
	var gate_label := WorldBuilder.label3d(gate_root, "Enter the Arena", Vector3(0, 1.2, 0), Color(0.86, 0.95, 1.0, 0.95), 28, 0.005, true)
	gate_label.outline_size = 7
	# Poké PC.
	var pc_root := Node3D.new()
	pc_root.position = Vector3(4.6, 0, 9.8)
	pc_root.rotation_degrees.y = -35.0
	add_child(pc_root)
	WorldBuilder.box(pc_root, Vector3(0, 1.0, 0), Vector3(1.3, 2.0, 0.9), Color("#26314a"), Vector3.ZERO, 0.4)
	WorldBuilder.box(pc_root, Vector3(0, 1.15, 0.5), Vector3(1.0, 0.7, 0.08), Color("#78e2ff"), Vector3.ZERO, 0.2, Color("#78e2ff"), 1.1)
	WorldBuilder.box(pc_root, Vector3(0, 0.35, 0.5), Vector3(1.1, 0.18, 0.12), Color("#ffd05a"), Vector3.ZERO, 0.4)
	WorldBuilder.label3d(pc_root, "POKÉ PC", Vector3(0, 2.3, 0), Color("#c9f2ff"), 32, 0.0055, true)
	var pc := Interactable.new()
	pc_root.add_child(pc)
	pc.setup("Poké PC", "Manage your collection and partner", Color("#78e2ff"), _open_collection, false)
	# Rest tent.
	var tent_root := Node3D.new()
	tent_root.position = Vector3(-15.8, 0, 10.2)
	add_child(tent_root)
	WorldBuilder.cylinder(tent_root, Vector3(0, 1.4, 0), 0.05, 2.0, 2.8, Color("#ef3f52"), Vector3.ZERO, 0.7)
	WorldBuilder.sphere(tent_root, Vector3(0, 2.6, 0), 0.25, Color("#ffd05a"), Vector3(1, 1, 1), 0.4, Color("#ffd05a"), 1.2)
	WorldBuilder.box(tent_root, Vector3(0, 0.3, 0), Vector3(3.4, 0.2, 3.0), Color("#8b5f39"), Vector3.ZERO, 0.9)
	WorldBuilder.label3d(tent_root, "REST TENT", Vector3(0, 3.2, 0), Color("#fff0c2"), 34, 0.0055, true)
	var tent := Interactable.new()
	tent_root.add_child(tent)
	tent.setup("Rest Tent", "Take a breather with your partner", Color("#66e3a4"), _rest, false)
	# Tips sign interaction.
	var tip_root := Node3D.new()
	tip_root.position = Vector3(3.2, 0, 5.6)
	add_child(tip_root)
	var tips := Interactable.new()
	tip_root.add_child(tips)
	tips.setup("Training Tips", "Read the playground guide", Color("#ffd05a"), _show_tips, false)

func _build_hud() -> void:
	hud = WorldHUD.new()
	add_child(hud)
	hud.setup(self, player, "STADIUM PLAYGROUND", "Training park outside the Battle Arena", GameState.LOCATION_PLAYGROUND)
	hud.travel_requested.connect(_on_travel_requested)

func _show_intro() -> void:
	if not GameState.playground_tip_seen():
		GameState.set_playground_tip_seen()
		hud.show_banner("WELCOME, %s" % GameState.trainer_name().to_upper(), "STADIUM PLAYGROUND", "WASD to move  •  Mouse to look  •  E to interact  •  ESC to pause", 5.0, UIKit.CYAN)
		await get_tree().create_timer(0.8).timeout
		UIKit.toast("Talk to the trainers around the park to begin your first match.", UIKit.GOLD, 4.0)
	else:
		hud.show_banner("STADIUM PLAYGROUND", "TRAINING PARK", "Win matches to unlock new partners. Team Rocket strikes every 2 matches.", 3.4, UIKit.CYAN)

func _consume_last_result() -> void:
	var summary = GameState.ui_context.get("last_result", null)
	if summary is Dictionary and not summary.is_empty():
		GameState.ui_context.erase("last_result")
		hud.announce_result(summary)

func _process(delta: float) -> void:
	_time += delta
	_pet_cooldown = maxf(0.0, _pet_cooldown - delta)
	_update_companion(delta)

func _update_companion(delta: float) -> void:
	if companion_root == null or player == null:
		return
	var yaw := player.camera_pivot.rotation.y
	var behind := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var desired := player.global_position + behind * 1.55 + right * 0.85
	desired.y = 0.02
	var previous := companion_root.global_position
	companion_root.global_position = companion_root.global_position.lerp(desired, clampf(delta * 4.5, 0.0, 1.0))
	var movement := companion_root.global_position - previous
	if movement.length() > 0.004:
		_companion_facing = lerp_angle(_companion_facing, atan2(movement.x, movement.z), clampf(delta * 7.0, 0.0, 1.0))
	companion_root.rotation.y = _companion_facing
	if companion != null:
		var distance := companion_root.global_position.distance_to(player.global_position)
		companion.set_idle_speed(1.0 + clampf(movement.length() / maxf(0.001, delta) * 0.06, 0.0, 0.55))
		companion.visible = distance < 18.0

func _pet_companion(_player: Node) -> void:
	if _pet_cooldown > 0.0:
		return
	_pet_cooldown = 2.2
	var active := GameState.active_pokemon()
	var species := AssetLibrary.get_pokemon(active)
	if species == null:
		return
	AudioManager.play_cry(active, species.battle_cry_pitch)
	UIKit.toast("%s nuzzles against you happily!" % species.display_name, UIKit.GOLD, 2.6)
	var hearts := CPUParticles3D.new()
	hearts.one_shot = true
	hearts.explosiveness = 0.9
	hearts.amount = 14
	hearts.lifetime = 0.9
	hearts.emitting = true
	hearts.local_coords = false
	hearts.position = companion_root.global_position + Vector3(0, 0.9, 0)
	hearts.direction = Vector3.UP
	hearts.spread = 55.0
	hearts.gravity = Vector3(0, 1.2, 0)
	hearts.initial_velocity_min = 0.4
	hearts.initial_velocity_max = 1.3
	hearts.scale_amount_min = 0.04
	hearts.scale_amount_max = 0.09
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	hearts.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#ff8fb4")
	mat.emission_enabled = true
	mat.emission = Color("#ff6f9c")
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hearts.material_override = mat
	add_child(hearts)
	get_tree().create_timer(1.4).timeout.connect(hearts.queue_free)

func _show_tips() -> void:
	hud.show_banner("PLAYGROUND GUIDE", "HOW TO PLAY", "WASD move  •  Shift sprint  •  Space jump  •  E interact  •  Esc pause", 4.0, UIKit.GOLD)
	await get_tree().create_timer(0.7).timeout
	UIKit.toast("Unlock partners by winning matches. Rocket events trigger after every 2 completed matches.", UIKit.CYAN, 5.0)

func _rest() -> void:
	AudioManager.play_sfx("heal", -3.0)
	UIKit.toast("Your partner is fully energized. Ready for the next challenge!", UIKit.MINT, 3.2)
	hud.show_banner("REST TENT", "READY TO GO", "Your partner rests up and shakes off the fatigue.", 2.4, UIKit.MINT)

func _open_collection() -> void:
	GameState.ui_context["return_scene"] = SCENE_PATH
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto("res://scenes/ui/collection.tscn", 0.4, "COLLECTION")

func _travel_to_arena() -> void:
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto_location(GameState.LOCATION_ARENA)

func _start_regular_battle(opponent_id: String, _player: Node = null) -> void:
	if SceneRouter.transitioning:
		return
	var opponent := AssetLibrary.get_opponent_by_id(opponent_id, GameState.regular_matches_completed(), GameState.regular_wins())
	if opponent.is_empty():
		UIKit.toast("That trainer is not ready to battle yet.", UIKit.RED)
		return
	GameState.pending_battle = {
		"rocket": false,
		"opponent": opponent,
		"return_scene": SCENE_PATH,
	}
	GameState.return_scene = SCENE_PATH
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto("res://scenes/battle/battle_scene.tscn", 0.55, "BATTLE START")

func _on_travel_requested(location: String) -> void:
	if location == GameState.LOCATION_ARENA:
		await SceneRouter.goto_location(GameState.LOCATION_ARENA)
