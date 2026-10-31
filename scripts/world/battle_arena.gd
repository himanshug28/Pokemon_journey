extends Node3D
## Battle Arena: a floodlit stadium interior where challengers gather and Team Rocket strikes.
## The Rocket cinematic is queued automatically whenever a Rocket event is pending.

const SCENE_PATH := "res://scenes/arenas/battle_arena.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ROCKET_INTRO_SCENE := "res://scenes/battle/rocket_intro.tscn"

var player: PlayerController
var hud: WorldHUD
var companion: PokemonModel
var companion_root: Node3D
var _rng := RandomNumberGenerator.new()
var _npcs: Array[Node3D] = []
var _time := 0.0
var _companion_facing := 0.0
var _pet_cooldown := 0.0
var _cheer_timer := 9.0
var _rocket_started := false
var _jumbotron_player_name: Label3D
var _jumbotron_player_pokemon: Label3D
var _jumbotron_opponent_name: Label3D
var _jumbotron_opponent_pokemon: Label3D

func _ready() -> void:
	if GameState.trainer_id() == "":
		SceneRouter.goto("res://scenes/ui/main_menu.tscn", 0.3, "MAIN MENU")
		return
	GameState.set_location(GameState.LOCATION_ARENA)
	_rng.seed = 48271
	_build_environment()
	_build_field()
	_build_stands()
	_build_screens()
	_build_props()
	_spawn_player()
	_spawn_companion()
	_spawn_challengers()
	_spawn_interactables()
	_build_hud()
	AudioManager.play_music("arena", 0.9)
	AudioManager.play_ambience("crowd", 1.2)
	_show_intro()
	_consume_last_result()
	set_process(true)
	if GameState.rocket_pending():
		_queue_rocket_event()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#03060f")
	sky_material.sky_horizon_color = Color("#15234a")
	sky_material.sky_curve = 0.1
	sky_material.ground_bottom_color = Color("#05070d")
	sky_material.ground_horizon_color = Color("#111b34")
	sky_material.sun_angle_max = 6.0
	sky_material.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.25
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#0d1830")
	env.fog_light_energy = 0.35
	env.fog_density = 0.006
	env.fog_sky_affect = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.16
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, 26, 0)
	moon.light_color = Color("#bcd6ff")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	moon.shadow_bias = 0.04
	add_child(moon)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color("#5f8cff")
	fill.light_energy = 0.6
	add_child(fill)

	# Concourse lamps keep the walkable ring readable without flattening the bowl.
	for lamp in [Vector3(-13.0, 6.4, 12.0), Vector3(13.0, 6.4, 12.0), Vector3(-13.0, 6.4, -12.0), Vector3(13.0, 6.4, -12.0)]:
		WorldBuilder.cylinder(self, Vector3(lamp.x, lamp.y * 0.5, lamp.z), 0.16, 0.22, lamp.y, Color("#1b2742"), Vector3.ZERO, 0.5)
		var bulb := OmniLight3D.new()
		bulb.position = lamp
		bulb.light_color = Color("#ffe9c4")
		bulb.light_energy = 3.4
		bulb.omni_range = 19.0
		bulb.omni_attenuation = 1.1
		add_child(bulb)
		WorldBuilder.sphere(self, lamp, 0.34, Color("#fff4c9"), Vector3.ONE, 0.2, Color("#fff0b0"), 2.4)

	# Warm wash over the entrance gate so the player always reads the exit.
	var gate_light := OmniLight3D.new()
	gate_light.position = Vector3(0, 5.5, 13.5)
	gate_light.light_color = Color("#9fd8ff")
	gate_light.light_energy = 4.0
	gate_light.omni_range = 16.0
	add_child(gate_light)

func _build_field() -> void:
	# Outer concourse and inner pitch.
	WorldBuilder.cylinder(self, Vector3(0, -0.35, 0), 18.0, 18.6, 0.7, Color("#1c2740"), Vector3.ZERO, 0.72)
	WorldBuilder.cylinder(self, Vector3(0, 0.02, 0), 16.2, 16.5, 0.22, Color("#2e7c52"), Vector3.ZERO, 0.86)
	WorldBuilder.torus(self, Vector3(0, 0.15, 0), 14.4, 15.0, Color("#e9f5ff"), Vector3.ONE, Vector3.ZERO, Color("#bde8ff"), 0.35)
	WorldBuilder.torus(self, Vector3(0, 0.15, 0), 8.4, 8.7, Color("#d7f1ff"), Vector3.ONE, Vector3.ZERO, Color("#bde8ff"), 0.25)

	# Flat midfield branding leaves the fighting space clear and unobstructed.
	WorldBuilder.torus(self, Vector3(0, 0.16, 0), 4.25, 4.38, Color("#d7ecff"), Vector3.ONE, Vector3.ZERO, Color("#8acfff"), 0.38)
	var field_logo := WorldBuilder.label3d(self, "Pokémon", Vector3(0, 0.165, 0), Color("#2867d6"), 144, 0.0105, false)
	field_logo.rotation_degrees.x = -90.0
	field_logo.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	field_logo.outline_size = 25
	field_logo.outline_modulate = Color("#ffd34d")
	field_logo.modulate = Color("#2867d6")

	# Trainer boxes.
	for side in [-1, 1]:
		WorldBuilder.box(self, Vector3(11.0 * side, 0.14, 3.6), Vector3(4.6, 0.28, 3.2), Color("#23405f"), Vector3.ZERO, 0.7)
		WorldBuilder.box(self, Vector3(11.0 * side, 0.3, 3.6), Vector3(4.2, 0.08, 2.8), Color("#3c628c"), Vector3.ZERO, 0.6)
		WorldBuilder.box(self, Vector3(11.0 * side, 0.55, 5.2), Vector3(3.6, 0.08, 0.6), Color("#ffd05a"), Vector3.ZERO, 0.4, Color("#ffd05a"), 0.3)

	# Goal / battle markers.
	for x in [-5.8, 5.8]:
		WorldBuilder.torus(self, Vector3(x, 0.17, 0), 1.0, 1.22, Color("#9fe8ff"), Vector3.ONE, Vector3.ZERO, Color("#9fe8ff"), 0.7)

	# Collision: the pitch is walkable, the stands are not.
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	var ground_shape := CollisionShape3D.new()
	var ground_cylinder := CylinderShape3D.new()
	ground_cylinder.radius = 18.0
	ground_cylinder.height = 1.0
	ground_shape.shape = ground_cylinder
	ground_shape.position = Vector3(0, -0.37, 0)
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	var boundary := StaticBody3D.new()
	boundary.name = "ArenaBoundary"
	add_child(boundary)
	for i in 36:
		var angle := TAU * float(i) / 36.0
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(3.2, 8.0, 0.6)
		wall_shape.shape = wall_box
		wall_shape.position = Vector3(cos(angle) * 16.9, 4.0, sin(angle) * 16.9)
		wall_shape.rotation.y = -angle
		boundary.add_child(wall_shape)

func _build_stands() -> void:
	var wall_color := Color("#111b31")
	# Arena wall ring.
	for i in 36:
		var angle := TAU * float(i) / 36.0
		var pos := Vector3(cos(angle) * 23.0 * 1.18, 4.4, sin(angle) * 23.0)
		var rot := -rad_to_deg(angle) + 90.0
		WorldBuilder.box(self, pos, Vector3(4.4, 8.8, 0.7), wall_color, Vector3(0, rot, 0), 0.7)
		WorldBuilder.box(self, pos + Vector3(0, 3.3, 0), Vector3(4.5, 0.35, 0.8), Color("#223656"), Vector3(0, rot, 0), 0.6)

	# Tiered seating rings.
	for tier in 4:
		var radius := 17.8 + float(tier) * 1.35
		var y := 1.55 + float(tier) * 1.55
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius - 0.92
		mesh.outer_radius = radius + 0.92
		mesh.rings = 64
		mesh.ring_segments = 8
		var tier_mesh := MeshInstance3D.new()
		tier_mesh.mesh = mesh
		tier_mesh.position = Vector3(0, y, 0)
		tier_mesh.scale = Vector3(1.18, 1.0, 1.0)
		var mat := WorldBuilder.material(Color("#16213b").lerp(Color("#2a3f66"), float(tier) / 4.0), 0.8)
		tier_mesh.material_override = mat
		tier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(tier_mesh)

	# Crowd around the bowl.
	WorldBuilder.crowd(self, Vector3(0, 0, 0), 17.8 * 1.18, 17.8, 4, 54, 1.72, 1.55)
	WorldBuilder.crowd(self, Vector3(0, 0, 0), 21.4 * 1.18, 21.4, 2, 44, 6.3, 1.4)

	# Roof trusses and banner ring.
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var pos := Vector3(cos(angle) * 25.0 * 1.12, 11.6, sin(angle) * 25.0)
		WorldBuilder.box(self, pos, Vector3(0.42, 7.2, 0.42), Color("#0b1222"), Vector3(0, -rad_to_deg(angle), 0), 0.5)
	WorldBuilder.torus(self, Vector3(0, 15.0, 0), 26.0, 26.6, Color("#0b1222"), Vector3(1.12, 1.0, 1.0), Vector3.ZERO)

	# Floodlight towers.
	var light_positions := [
		Vector3(-24.0, 13.5, -18.0), Vector3(24.0, 13.5, -18.0),
		Vector3(-24.0, 13.5, 18.0), Vector3(24.0, 13.5, 18.0),
	]
	for i in light_positions.size():
		var pos: Vector3 = light_positions[i]
		WorldBuilder.cylinder(self, Vector3(pos.x, pos.y * 0.5, pos.z), 0.3, 0.48, pos.y, Color("#1b2742"), Vector3.ZERO, 0.5)
		WorldBuilder.box(self, pos, Vector3(2.0, 0.8, 0.5), Color("#0c1424"), Vector3.ZERO, 0.4)
		for j in 3:
			WorldBuilder.sphere(self, pos + Vector3(-0.6 + j * 0.6, 0.0, 0.28), 0.16, Color("#fff4c9"), Vector3(1, 1, 0.5), 0.2, Color("#fff0b0"), 2.2)
		var target := Vector3(0, 0, 0)
		WorldBuilder.spotlight(self, pos, target, Color("#d9efff") if i % 2 == 0 else Color("#ffe6b8"), 8.0, 48.0, 30.0)

func _build_screens() -> void:
	# Main jumbotron: live matchup board, sized to read clearly across the stadium.
	var screen_root := Node3D.new()
	screen_root.name = "Jumbotron"
	screen_root.position = Vector3(0, 9.6, -21.0)
	add_child(screen_root)
	WorldBuilder.box(screen_root, Vector3.ZERO, Vector3(19.2, 7.4, 0.7), Color("#080e1d"), Vector3.ZERO, 0.3)
	WorldBuilder.box(screen_root, Vector3(0, 0, 0.38), Vector3(18.5, 6.7, 0.05), Color("#101d36"), Vector3.ZERO, 0.24, Color("#326bb1"), 1.0)
	WorldBuilder.box(screen_root, Vector3(0, 2.65, 0.43), Vector3(18.0, 0.68, 0.04), Color("#193455"), Vector3.ZERO, 0.3, Color("#387fc0"), 0.7)
	var header := WorldBuilder.label3d(screen_root, "POKÉMON STADIUM  •  LIVE MATCH", Vector3(0, 2.65, 0.49), Color("#d9efff"), 34, 0.006, false)
	header.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	WorldBuilder.box(screen_root, Vector3(-4.78, -0.45, 0.43), Vector3(7.45, 4.15, 0.04), Color("#102d50"), Vector3.ZERO, 0.3, Color("#4a9eff"), 0.45)
	WorldBuilder.box(screen_root, Vector3(4.78, -0.45, 0.43), Vector3(7.45, 4.15, 0.04), Color("#3a1d2a"), Vector3.ZERO, 0.3, Color("#ff6b78"), 0.45)
	WorldBuilder.box(screen_root, Vector3(-8.35, -0.45, 0.46), Vector3(0.08, 3.5, 0.025), Color("#78c7ff"), Vector3.ZERO, 0.35, Color("#78c7ff"), 1.1)
	WorldBuilder.box(screen_root, Vector3(8.35, -0.45, 0.46), Vector3(0.08, 3.5, 0.025), Color("#ff8492"), Vector3.ZERO, 0.35, Color("#ff8492"), 1.1)
	WorldBuilder.box(screen_root, Vector3(-4.78, 0.24, 0.48), Vector3(6.65, 0.025, 0.02), Color("#568fca"), Vector3.ZERO, 0.3, Color("#568fca"), 0.65)
	WorldBuilder.box(screen_root, Vector3(4.78, 0.24, 0.48), Vector3(6.65, 0.025, 0.02), Color("#ca6675"), Vector3.ZERO, 0.3, Color("#ca6675"), 0.65)
	var player_tag := WorldBuilder.label3d(screen_root, "PLAYER", Vector3(-4.78, 1.05, 0.5), Color("#83cfff"), 27, 0.0055, false)
	player_tag.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_tag := WorldBuilder.label3d(screen_root, "CHALLENGER", Vector3(4.78, 1.05, 0.5), Color("#ff9aa5"), 27, 0.0055, false)
	opponent_tag.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_jumbotron_player_name = WorldBuilder.label3d(screen_root, "TRAINER", Vector3(-4.78, 0.52, 0.51), Color("#f1f8ff"), 42, 0.006, false)
	_jumbotron_player_name.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_jumbotron_player_pokemon = WorldBuilder.label3d(screen_root, "POKÉMON", Vector3(-4.78, -0.48, 0.51), Color("#ffffff"), 54, 0.006, false)
	_jumbotron_player_pokemon.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_jumbotron_opponent_name = WorldBuilder.label3d(screen_root, "CHALLENGER", Vector3(4.78, 0.52, 0.51), Color("#fff2f3"), 42, 0.006, false)
	_jumbotron_opponent_name.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_jumbotron_opponent_pokemon = WorldBuilder.label3d(screen_root, "POKÉMON", Vector3(4.78, -0.48, 0.51), Color("#ffffff"), 54, 0.006, false)
	_jumbotron_opponent_pokemon.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var versus := WorldBuilder.label3d(screen_root, "VS", Vector3(0, -0.12, 0.54), Color("#ffd34d"), 82, 0.009, false)
	versus.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	versus.outline_size = 10
	versus.outline_modulate = Color("#14233c")
	var player_caption := WorldBuilder.label3d(screen_root, "ACTIVE PARTNER", Vector3(-4.78, -1.3, 0.51), Color("#a5c6df"), 23, 0.0045, false)
	player_caption.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_caption := WorldBuilder.label3d(screen_root, "BATTLE PARTNER", Vector3(4.78, -1.3, 0.51), Color("#d6aab0"), 23, 0.0045, false)
	opponent_caption.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var featured_opponent := AssetLibrary.get_opponent_by_id("maya", GameState.regular_matches_completed(), GameState.regular_wins())
	if GameState.rocket_pending():
		featured_opponent = AssetLibrary.get_rocket_opponent(GameState.rocket_events_completed(), GameState.regular_matches_completed())
	_update_jumbotron_matchup(featured_opponent)
	# Screen glow.
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 9.6, -18.5)
	glow.light_color = Color("#4ea6ff")
	glow.light_energy = 2.2
	glow.omni_range = 16.0
	add_child(glow)

	# Side scoreboards.
	for side in [-1, 1]:
		var root := Node3D.new()
		root.position = Vector3(16.0 * side, 7.4, -12.0)
		root.rotation_degrees.y = -28.0 * side
		add_child(root)
		WorldBuilder.box(root, Vector3.ZERO, Vector3(4.4, 2.4, 0.35), Color("#0a1020"), Vector3.ZERO, 0.35)
		WorldBuilder.box(root, Vector3(0, 0, 0.22), Vector3(4.0, 2.0, 0.05), Color("#102a4c"), Vector3.ZERO, 0.2, Color("#2f7fc9"), 0.9)
		WorldBuilder.label3d(root, "ROCKET ALERT" if GameState.rocket_pending() else "ARENA LIVE", Vector3(0, 0.25, 0.3), Color("#ff9aa5") if GameState.rocket_pending() else Color("#8fe7ff"), 30, 0.005, false)

func _update_jumbotron_matchup(opponent: Dictionary) -> void:
	if _jumbotron_player_name == null or _jumbotron_player_pokemon == null or _jumbotron_opponent_name == null or _jumbotron_opponent_pokemon == null:
		return
	var trainer_name := GameState.trainer_name().strip_edges()
	if trainer_name == "":
		trainer_name = "Trainer"
	var player_species := AssetLibrary.get_pokemon(GameState.active_pokemon())
	var player_pokemon := player_species.display_name if player_species != null else "Pokémon"
	var opponent_name := str(opponent.get("name", "Arena Challenger"))
	var opponent_species := AssetLibrary.get_pokemon(str(opponent.get("pokemon", "pikachu")))
	var opponent_pokemon := opponent_species.display_name if opponent_species != null else "Pokémon"
	var display_override := str(opponent.get("display_override", ""))
	if display_override != "":
		opponent_pokemon = display_override
	_jumbotron_player_name.text = trainer_name.to_upper()
	_jumbotron_player_pokemon.text = player_pokemon.to_upper()
	_jumbotron_opponent_name.text = opponent_name.to_upper()
	_jumbotron_opponent_pokemon.text = opponent_pokemon.to_upper()

func _build_props() -> void:
	# Benches, ball crates and flags.
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.2
		WorldBuilder.bench(self, Vector3(cos(angle) * 13.0, 0.14, sin(angle) * 10.0), -rad_to_deg(angle) + 90.0)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var pos := Vector3(cos(angle) * 15.5, 0.2, sin(angle) * 12.5)
		WorldBuilder.cylinder(self, pos + Vector3(0, 0.55, 0), 0.09, 0.14, 1.1, Color("#26314a"), Vector3.ZERO, 0.5)
		WorldBuilder.sphere(self, pos + Vector3(0, 1.2, 0), 0.22, Color("#ffd05a"), Vector3(1, 1.1, 1), 0.3, Color("#ffd05a"), 1.6)
	# Flag banners.
	for side in [-1, 1]:
		for i in 3:
			var x: float = 6.0 * side + i * 2.4 * side
			WorldBuilder.box(self, Vector3(x, 4.6, -16.0), Vector3(1.4, 2.8, 0.08), Color("#ef3f52") if i % 2 == 0 else Color("#ffd05a"), Vector3.ZERO, 0.55)
	# Confetti-ish sparkle particles.
	var sparkles := CPUParticles3D.new()
	sparkles.position = Vector3(0, 5.0, -6.0)
	sparkles.amount = 80
	sparkles.lifetime = 7.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkles.emission_box_extents = Vector3(15.0, 5.0, 12.0)
	sparkles.direction = Vector3.DOWN
	sparkles.spread = 25.0
	sparkles.gravity = Vector3(0, -0.12, 0)
	sparkles.initial_velocity_min = 0.02
	sparkles.initial_velocity_max = 0.22
	sparkles.scale_amount_min = 0.018
	sparkles.scale_amount_max = 0.05
	var spark := SphereMesh.new()
	spark.radius = 1.0
	spark.height = 2.0
	spark.radial_segments = 6
	spark.rings = 3
	sparkles.mesh = spark
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.9, 0.55, 0.7)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.82, 0.4)
	spark_mat.emission_energy_multiplier = 2.0
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkles.material_override = spark_mat
	add_child(sparkles)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.05, 13.0)
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
	var pet := Interactable.new()
	companion_root.add_child(pet)
	pet.position = Vector3(0, 0.05, 0)
	pet.setup("Pet %s" % species.display_name, "Cheer your partner on", Color("#ffd05a"), _pet_companion, false)

func _spawn_challengers() -> void:
	_spawn_challenger("mira", "maya", Vector3(-10.2, 0, 8.0), 155.0, Color("#78e2ff"))
	_spawn_challenger("rowan", "leo", Vector3(10.2, 0, 8.0), 205.0, Color("#66e3a4"))
	_spawn_challenger("nova", "gale", Vector3(-10.2, 0, -8.0), 120.0, Color("#ffd05a"))
	_spawn_challenger("rex", "nyx", Vector3(10.2, 0, -8.0), 225.0, Color("#b28bff"))

func _spawn_challenger(trainer_id: String, opponent_id: String, pos: Vector3, yaw: float, accent: Color) -> void:
	var opponent := AssetLibrary.get_opponent_by_id(opponent_id, GameState.regular_matches_completed(), GameState.regular_wins())
	if opponent.is_empty():
		return
	var root := Node3D.new()
	root.name = "Challenger_%s" % opponent_id
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
	interact.setup(str(opponent.get("name", "Trainer")), "Challenge to a stadium battle", accent, func(_player: Node) -> void: _start_regular_battle(opponent_id), false)
	_npcs.append(root)

func _spawn_interactables() -> void:
	# Gate back to the playground.
	var gate_root := Node3D.new()
	gate_root.position = Vector3(0, 0, 15.2)
	add_child(gate_root)
	WorldBuilder.torus(gate_root, Vector3(0, 0.05, 0), 2.8, 3.2, Color("#78e2ff"), Vector3.ONE, Vector3.ZERO, Color("#78e2ff"), 0.8)
	WorldBuilder.cylinder(gate_root, Vector3(-3.2, 2.6, 0), 0.32, 0.42, 5.2, Color("#e6eaf5"), Vector3.ZERO, 0.5)
	WorldBuilder.cylinder(gate_root, Vector3(3.2, 2.6, 0), 0.32, 0.42, 5.2, Color("#e6eaf5"), Vector3.ZERO, 0.5)
	WorldBuilder.box(gate_root, Vector3(0, 5.2, 0), Vector3(7.0, 0.8, 0.6), Color("#ffd05a"), Vector3.ZERO, 0.5)
	WorldBuilder.label3d(gate_root, "STADIUM PLAYGROUND", Vector3(0, 5.4, 0.35), Color("#fff7dd"), 34, 0.0055, true)
	var gate := Interactable.new()
	gate_root.add_child(gate)
	gate.setup("Stadium Playground Gate", "Return to the training park", Color("#78e2ff"), _travel_to_playground, false)

	# Poké PC.
	var pc_root := Node3D.new()
	pc_root.position = Vector3(-11.0, 0, 9.0)
	pc_root.rotation_degrees.y = 42.0
	add_child(pc_root)
	WorldBuilder.box(pc_root, Vector3(0, 1.0, 0), Vector3(1.3, 2.0, 0.9), Color("#26314a"), Vector3.ZERO, 0.4)
	WorldBuilder.box(pc_root, Vector3(0, 1.15, 0.5), Vector3(1.0, 0.7, 0.08), Color("#78e2ff"), Vector3.ZERO, 0.2, Color("#78e2ff"), 1.1)
	WorldBuilder.box(pc_root, Vector3(0, 0.35, 0.5), Vector3(1.1, 0.18, 0.12), Color("#ffd05a"), Vector3.ZERO, 0.4)
	WorldBuilder.label3d(pc_root, "POKÉ PC", Vector3(0, 2.3, 0), Color("#c9f2ff"), 32, 0.0055, true)
	var pc := Interactable.new()
	pc_root.add_child(pc)
	pc.setup("Poké PC", "Manage your collection and partner", Color("#78e2ff"), _open_collection, false)

	# Announcer stand.
	var announce_root := Node3D.new()
	announce_root.position = Vector3(10.8, 0, 8.4)
	announce_root.rotation_degrees.y = 215.0
	add_child(announce_root)
	var announcer_data := AssetLibrary.get_trainer("sora")
	if announcer_data.is_empty():
		announcer_data = {"id": "sora", "accent": "#b28bff"}
	var announcer := TrainerModel.new()
	announce_root.add_child(announcer)
	announcer.setup(announcer_data)
	announcer.scale = Vector3.ONE * 1.14
	WorldBuilder.label3d(announce_root, "ANNOUNCER", Vector3(0, 2.2, 0), Color("#d9c8ff"), 28, 0.005, true)
	var announce := Interactable.new()
	announce_root.add_child(announce)
	announce.setup("Arena Announcer", "Hear the latest stadium news", Color("#b28bff"), _announcer_talk, false)


func _build_hud() -> void:
	hud = WorldHUD.new()
	add_child(hud)
	hud.setup(self, player, "BATTLE ARENA", "Floodlit stadium • Challengers and Rocket events", GameState.LOCATION_ARENA)
	hud.travel_requested.connect(_on_travel_requested)

func _show_intro() -> void:
	if GameState.rocket_pending():
		hud.show_banner("TEAM ROCKET ALERT", "THE ARENA IS UNDER SIEGE", "Stay sharp. Something is very wrong under the lights.", 4.5, UIKit.RED)
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree():
			UIKit.toast("The stadium doors lock behind you. Team Rocket is here.", UIKit.RED, 4.0)
	else:
		hud.show_banner("BATTLE ARENA", "UNDER THE LIGHTS", "Challenge the arena trainers. Win matches. Watch for Team Rocket.", 4.0, UIKit.CYAN)
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree():
			UIKit.toast("Talk to a challenger to start a stadium battle. The crowd is watching.", UIKit.GOLD, 4.0)

func _consume_last_result() -> void:
	var summary = GameState.ui_context.get("last_result", null)
	if summary is Dictionary and not summary.is_empty():
		GameState.ui_context.erase("last_result")
		hud.announce_result(summary)
		var won := bool(summary.get("won", false))
		var rocket := bool(summary.get("rocket", false))
		if rocket and won:
			hud.show_banner("ROCKET BADGE EARNED", "ARENA LIBERATED", "Team Rocket retreats. The crowd erupts for you.", 5.0, UIKit.GOLD)
			AudioManager.play_sfx("crowd_cheer", -4.0)
		elif rocket and not won:
			hud.show_banner("THE ARENA FALLS SILENT", "ROCKET GOT AWAY", "Regroup at the playground and come back stronger.", 5.0, UIKit.RED)
		elif bool(summary.get("rocket_pending", false)):
			await get_tree().create_timer(1.2).timeout
			if is_inside_tree() and GameState.rocket_pending() and not _rocket_started:
				_queue_rocket_event()

func _process(delta: float) -> void:
	_time += delta
	_pet_cooldown = maxf(0.0, _pet_cooldown - delta)
	_update_companion(delta)
	_cheer_timer -= delta
	if _cheer_timer <= 0.0:
		_cheer_timer = _rng.randf_range(11.0, 20.0)
		AudioManager.play_sfx("crowd_cheer", -14.0, _rng.randf_range(0.95, 1.05))

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
	UIKit.toast("%s is fired up for the arena!" % species.display_name, UIKit.GOLD, 2.6)

func _announcer_talk(_player: Node = null) -> void:
	var line := "The crowd loves a comeback. Keep your partner's PP in mind!"
	if GameState.rocket_pending():
		line = "Team Rocket is in the building! Get ready for a stadium battle, challenger!"
	elif GameState.matches_until_rocket() == 1:
		line = "One more match and Team Rocket will crawl out of the shadows. Stay ready."
	AudioManager.play_sfx("confirm")
	hud.show_banner("ARENA ANNOUNCER", "LIVE FROM THE BOOTH", line, 3.6, UIKit.GOLD)

func _open_collection() -> void:
	GameState.ui_context["return_scene"] = SCENE_PATH
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto("res://scenes/ui/collection.tscn", 0.4, "COLLECTION")

func _travel_to_playground() -> void:
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto_location(GameState.LOCATION_PLAYGROUND)

func _start_regular_battle(opponent_id: String, _player: Node = null) -> void:
	if SceneRouter.transitioning:
		return
	var opponent := AssetLibrary.get_opponent_by_id(opponent_id, GameState.regular_matches_completed(), GameState.regular_wins())
	if opponent.is_empty():
		UIKit.toast("That challenger is not ready yet.", UIKit.RED)
		return
	_update_jumbotron_matchup(opponent)
	GameState.pending_battle = {
		"rocket": false,
		"opponent": opponent,
		"return_scene": SCENE_PATH,
	}
	GameState.return_scene = SCENE_PATH
	AudioManager.play_sfx("confirm")
	await SceneRouter.goto("res://scenes/battle/battle_scene.tscn", 0.55, "BATTLE START")

func _on_travel_requested(location: String) -> void:
	if location == GameState.LOCATION_PLAYGROUND:
		await SceneRouter.goto_location(GameState.LOCATION_PLAYGROUND)

func _queue_rocket_event() -> void:
	if _rocket_started:
		return
	_rocket_started = true
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree():
		return
	if not GameState.rocket_pending() or SceneRouter.transitioning:
		_rocket_started = false
		return
	_start_rocket_event()

func _start_rocket_event() -> void:
	if not GameState.rocket_pending() or SceneRouter.transitioning:
		return
	if player != null:
		player.set_control_enabled(false)
		player.capture_mouse(false)
	AudioManager.play_sfx("rocket_alarm", -2.0)
	AudioManager.play_music("rocket", 0.7, true)
	hud.show_alert("TEAM ROCKET HAS TAKEN OVER THE ARENA!", 6.0)
	hud.show_banner("TEAM ROCKET", "THE ARENA IS UNDER SIEGE", "The lights dim. A shadow steps onto the open battle floor.", 4.6, UIKit.RED)
	await get_tree().create_timer(4.6).timeout
	if not is_inside_tree():
		return
	if not GameState.rocket_pending() or SceneRouter.transitioning:
		return
	var opponent := AssetLibrary.get_rocket_opponent(GameState.rocket_events_completed(), GameState.regular_matches_completed())
	if opponent.is_empty():
		UIKit.toast("Team Rocket slipped away this time...", UIKit.RED)
		if player != null:
			player.set_control_enabled(true)
			player.capture_mouse(true)
		return
	_update_jumbotron_matchup(opponent)
	GameState.pending_battle = {
		"rocket": true,
		"opponent": opponent,
		"return_scene": SCENE_PATH,
	}
	GameState.return_scene = SCENE_PATH
	await SceneRouter.goto(ROCKET_INTRO_SCENE, 0.6, "TEAM ROCKET")
