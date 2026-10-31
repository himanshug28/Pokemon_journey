extends Node3D
## Cinematic 3D battle diorama. Runs BattleSim, animates its event stream and records the result.
##
## GameState.pending_battle carries {rocket, opponent, return_scene}. The battle scene
## consumes that dictionary so a scene reload can never replay the same fight.

const SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const PLAYER_MODEL_POS := Vector3(-3.35, 0.42, 0.45)
const ENEMY_MODEL_POS := Vector3(3.35, 0.42, -0.15)
const PLAYER_TRAINER_POS := Vector3(-6.15, 0.08, -1.75)
const ENEMY_TRAINER_POS := Vector3(6.15, 0.08, -1.75)

var sim: BattleSim
var rocket := false
var opponent: Dictionary = {}
var return_scene := GameState.SCENE_ARENA
var active_id := ""
var player_species: PokemonData
var enemy_species: PokemonData

var exhibition := false
var auto_battle := false
var _exhibition_rematch_button: Button
var _exhibition_change_button: Button

var player_model: PokemonModel
var enemy_model: PokemonModel
var player_trainer: TrainerModel
var enemy_trainer: TrainerModel

var _camera: Camera3D
var _camera_focus := Vector3(0, 1.2, 0)
var _shake_strength := 0.0
var _shake_time := 0.0

var _ui_layer: CanvasLayer
var _player_hp: HealthBar
var _enemy_hp: HealthBar
var _player_status: Label
var _enemy_status: Label
var _player_hp_value: Label
var _enemy_hp_value: Label
var _turn_label: Label
var _message_label: Label
var _message_speaker: Label
var _move_buttons: Array[Button] = []
var _battle_hint: Label
var _moves_card: PanelContainer
var _banner_layer: Control
var _banner_kicker: Label
var _banner_title: Label
var _banner_sub: Label

var _result_layer: Control
var _result_panel: PanelContainer
var _result_kicker: Label
var _result_title: Label
var _result_sub: Label
var _result_details: VBoxContainer
var _result_button: Button
var _result_menu_button: Button

var _busy := true
var _ended := false
var _leaving := false
var _last_move_type := "normal"
var _summary: Dictionary = {}
var _pending_battle_raw: Dictionary = {}

func _ready() -> void:
	_consume_pending_battle()
	_build_world()
	_build_models()
	_build_camera()
	_build_ui()
	_build_banner()
	_build_result_overlay()
	AudioManager.play_music("rocket" if rocket else "battle", 0.7, true)
	AudioManager.play_ambience("crowd" if not rocket else "stop", 0.6)
	if rocket:
		AudioManager.play_sfx("rocket_alarm", -5.0)
	call_deferred("_start_intro")
	set_process(true)

# ------------------------------------------------------------------ setup

func _consume_pending_battle() -> void:
	var pending: Dictionary = GameState.pending_battle.duplicate(true)
	GameState.pending_battle = {}
	_pending_battle_raw = pending.duplicate(true)
	if pending.is_empty():
		pending = {
			"rocket": false,
			"opponent": AssetLibrary.get_opponent_for_match(GameState.regular_matches_completed(), GameState.regular_wins()),
			"return_scene": GameState.current_location_scene(),
		}
	_pending_battle_raw = pending.duplicate(true)
	rocket = bool(pending.get("rocket", false))
	exhibition = bool(pending.get("exhibition", false))
	auto_battle = bool(pending.get("auto", exhibition))
	opponent = pending.get("opponent", {})
	if not opponent is Dictionary:
		opponent = {}
	if opponent.is_empty() and not exhibition:
		opponent = {
			"id": "arena_challenger",
			"name": "Arena Challenger",
			"title": "Stadium Regular",
			"pokemon": "pikachu",
			"level": 5,
			"intro": "Let's put on a show for the crowd!",
			"defeat": "What a battle!",
			"accent": "#78e2ff",
			"xp": 60,
		}
	if exhibition and opponent.is_empty():
		var p_id := str(pending.get("player_species", ""))
		var e_id := str(pending.get("enemy_species", ""))
		opponent = {
			"id": "exhibition_opponent",
			"name": AssetLibrary.get_pokemon(e_id).display_name if AssetLibrary.get_pokemon(e_id) != null else "Opponent",
			"title": "Exhibition",
			"pokemon": e_id if e_id != "" else "pikachu",
			"level": int(pending.get("enemy_level", 5)),
			"intro": "Let the exhibition match begin!",
			"defeat": "A great showing!",
			"accent": "#ffd05a",
			"xp": 0,
		}
	return_scene = str(pending.get("return_scene", GameState.current_location_scene()))
	if return_scene == "" or not ResourceLoader.exists(return_scene):
		return_scene = GameState.current_location_scene()

	if exhibition:
		var requested_player := str(pending.get("player_species", ""))
		if requested_player != "":
			active_id = requested_player
		else:
			active_id = GameState.active_pokemon()
	else:
		active_id = GameState.active_pokemon()
	player_species = AssetLibrary.get_pokemon(active_id)
	if player_species == null:
		var unlocked := GameState.unlocked_pokemon()
		active_id = unlocked[0] if unlocked.size() > 0 else "pikachu"
		player_species = AssetLibrary.get_pokemon(active_id)
	if player_species == null:
		player_species = AssetLibrary.get_pokemon("pikachu")

	var enemy_id := str(opponent.get("pokemon", "pikachu"))
	enemy_species = AssetLibrary.get_pokemon(enemy_id)
	if enemy_species == null:
		enemy_species = AssetLibrary.get_pokemon("pikachu")
	if enemy_species == null:
		enemy_species = player_species

	if rocket and not exhibition:
		var shadow := enemy_species.duplicate(true) as PokemonData
		if shadow != null:
			var override_name := str(opponent.get("display_override", ""))
			if override_name == "":
				override_name = "Shadow " + enemy_species.display_name
			shadow.display_name = override_name
			shadow.body_color = shadow.body_color.darkened(0.46)
			shadow.belly_color = shadow.belly_color.darkened(0.52)
			shadow.accent_color = Color("#b28bff")
			enemy_species = shadow

	var player_level := int(GameState.xp_progress(active_id).get("level", 5))
	if exhibition:
		player_level = int(pending.get("player_level", player_level))
	var enemy_level := int(opponent.get("level", maxi(4, player_level)))
	sim = BattleSim.new()
	sim.setup(player_species, player_level, enemy_species, enemy_level, Time.get_ticks_msec(), rocket and not exhibition, opponent)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#02040c")
	sky_material.sky_horizon_color = Color("#152447")
	sky_material.sky_curve = 0.08
	sky_material.ground_bottom_color = Color("#04060c")
	sky_material.ground_horizon_color = Color("#101a32")
	sky_material.sun_angle_max = 4.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color("#0a1630")
	env.fog_light_energy = 0.5
	env.fog_density = 0.008
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.15
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-54, 28, 0)
	key.light_color = Color("#cfe2ff")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 42.0
	key.shadow_bias = 0.04
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -150, 0)
	fill.light_color = Color("#5c8cff")
	fill.light_energy = 0.35
	add_child(fill)

	# Green battle pitch with painted markings. The raised blue rear platform has been removed;
	# the existing seating and crowd now frame an open, continuous field.
	WorldBuilder.cylinder(self, Vector3(0, -0.5, 0), 14.0, 14.6, 0.9, Color("#111a21"), Vector3.ZERO, 0.85)
	WorldBuilder.cylinder(self, Vector3(0, -0.01, 0), 12.0, 12.0, 0.14, Color("#176b43"), Vector3.ZERO, 0.8)
	WorldBuilder.cylinder(self, Vector3(0, 0.02, 0), 9.0, 9.0, 0.05, Color("#2aaa59"), Vector3.ZERO, 0.72)
	WorldBuilder.torus(self, Vector3(0, 0.075, 0), 8.82, 8.94, Color("#eff9e8"), Vector3.ONE, Vector3.ZERO)
	WorldBuilder.box(self, Vector3(0, 0.078, 0), Vector3(17.65, 0.018, 0.075), Color("#eff9e8"), Vector3.ZERO, 0.7, Color("#eff9e8"), 0.12, false)
	WorldBuilder.torus(self, Vector3(0, 0.082, 0), 3.15, 3.24, Color("#eff9e8"), Vector3.ONE, Vector3.ZERO)
	# Flat Poké Ball center mark; all parts sit flush to the pitch with no collision.
	WorldBuilder.cylinder(self, Vector3(0, 0.075, 0), 1.7, 1.7, 0.035, Color("#f7f8ef"), Vector3.ZERO, 0.5)
	_build_ground_half_disc(Vector3.ZERO, 1.66, Color("#ef4054"))
	WorldBuilder.torus(self, Vector3(0, 0.096, 0), 1.58, 1.68, Color("#263141"), Vector3.ONE, Vector3.ZERO)
	WorldBuilder.box(self, Vector3(0, 0.114, 0), Vector3(3.25, 0.025, 0.11), Color("#263141"), Vector3.ZERO, 0.55, Color("#263141"), 0.15, false)
	WorldBuilder.cylinder(self, Vector3(0, 0.125, 0), 0.48, 0.48, 0.05, Color("#263141"), Vector3.ZERO, 0.4)
	WorldBuilder.cylinder(self, Vector3(0, 0.158, 0), 0.27, 0.27, 0.025, Color("#f7f8ef"), Vector3.ZERO, 0.4)
	# A flat, non-colliding Pokémon wordmark keeps the midfield branded and clear for combat.
	var field_logo := WorldBuilder.label3d(self, "Pokémon", Vector3(0, 0.075, 4.0), Color("#2867d6"), 132, 0.011, false)
	field_logo.rotation_degrees.x = -90.0
	field_logo.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	field_logo.outline_size = 24
	field_logo.outline_modulate = Color("#ffd34d")
	field_logo.modulate = Color("#2867d6")

	# Battle positions - clear positions on open floor
	_build_platform(PLAYER_MODEL_POS + Vector3(0, -0.01, 0), Color("#4a9eff"))
	_build_platform(ENEMY_MODEL_POS + Vector3(0, -0.01, 0), Color("#ff6b6b") if rocket else Color("#ffd93d"))

	# Keep the seating, crowd and stadium structures around the pitch; no rear floor slab.
	for i in 2:
		var radius := 11.5 + float(i) * 0.9
		var y := 0.8 + float(i) * 0.7
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius - 0.6
		mesh.outer_radius = radius + 0.6
		mesh.rings = 48
		mesh.ring_segments = 6
		var tier := MeshInstance3D.new()
		tier.mesh = mesh
		tier.position = Vector3(0, y, -4.0)
		tier.material_override = WorldBuilder.material(Color("#1a2642").lerp(Color("#2a3f66"), float(i) / 2.0), 0.82)
		add_child(tier)
	WorldBuilder.crowd(self, Vector3(0, 0, -4.0), 10.5, 7.5, 2, 32, 1.6, 0.84)

	# Live stadium display with the current trainer / Pokémon matchup.
	var screen_root := Node3D.new()
	screen_root.position = Vector3(0, 6.8, -10.5)
	add_child(screen_root)
	WorldBuilder.box(screen_root, Vector3.ZERO, Vector3(13.0, 5.6, 0.5), Color("#080e1d"), Vector3.ZERO, 0.32)
	WorldBuilder.box(screen_root, Vector3(0, 0, 0.27), Vector3(12.55, 5.15, 0.04), Color("#101d36"), Vector3.ZERO, 0.24, Color("#326bb1"), 1.0)
	WorldBuilder.box(screen_root, Vector3(0, 2.1, 0.31), Vector3(12.15, 0.58, 0.04), Color("#193455"), Vector3.ZERO, 0.3, Color("#387fc0"), 0.7)
	var header := WorldBuilder.label3d(screen_root, "POKÉMON STADIUM  •  LIVE MATCH", Vector3(0, 2.1, 0.36), Color("#d9efff"), 28, 0.005, false)
	header.font = load("res://assets/fonts/LilitaOne-Regular.ttf")

	# Broad side panels keep both names legible while the central VS badge stays distinct.
	WorldBuilder.box(screen_root, Vector3(-3.22, -0.35, 0.31), Vector3(5.45, 3.65, 0.04), Color("#102d50"), Vector3.ZERO, 0.3, Color("#4a9eff"), 0.48)
	WorldBuilder.box(screen_root, Vector3(3.22, -0.35, 0.31), Vector3(5.45, 3.65, 0.04), Color("#3a1d2a"), Vector3.ZERO, 0.3, Color("#ff6b78"), 0.48)
	WorldBuilder.box(screen_root, Vector3(-5.82, -0.35, 0.34), Vector3(0.08, 3.1, 0.03), Color("#78c7ff"), Vector3.ZERO, 0.35, Color("#78c7ff"), 1.1)
	WorldBuilder.box(screen_root, Vector3(5.82, -0.35, 0.34), Vector3(0.08, 3.1, 0.03), Color("#ff8492"), Vector3.ZERO, 0.35, Color("#ff8492"), 1.1)
	WorldBuilder.box(screen_root, Vector3(-3.22, 0.3, 0.36), Vector3(4.8, 0.025, 0.02), Color("#568fca"), Vector3.ZERO, 0.3, Color("#568fca"), 0.65)
	WorldBuilder.box(screen_root, Vector3(3.22, 0.3, 0.36), Vector3(4.8, 0.025, 0.02), Color("#ca6675"), Vector3.ZERO, 0.3, Color("#ca6675"), 0.65)
	var player_tag := WorldBuilder.label3d(screen_root, "PLAYER", Vector3(-3.22, 0.92, 0.38), Color("#83cfff"), 22, 0.0045, false)
	player_tag.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_tag := WorldBuilder.label3d(screen_root, "CHALLENGER", Vector3(3.22, 0.92, 0.38), Color("#ff9aa5"), 22, 0.0045, false)
	opponent_tag.font = load("res://assets/fonts/LilitaOne-Regular.ttf")

	# Live matchup text uses the actual battle state, including Rocket display overrides.
	var p_name := GameState.trainer_name()
	var p_mon := sim.player.display_name() if sim != null else ""
	var e_name := str(opponent.get("name", "Challenger"))
	var e_mon := sim.enemy.display_name() if sim != null else ""
	var player_name := WorldBuilder.label3d(screen_root, p_name.to_upper(), Vector3(-3.22, 0.58, 0.39), Color("#f1f8ff"), 30, 0.0045, false)
	player_name.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var player_pokemon := WorldBuilder.label3d(screen_root, p_mon.to_upper(), Vector3(-3.22, -0.22, 0.39), Color("#ffffff"), 42, 0.005, false)
	player_pokemon.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_name := WorldBuilder.label3d(screen_root, e_name.to_upper(), Vector3(3.22, 0.58, 0.39), Color("#fff2f3"), 30, 0.0045, false)
	opponent_name.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_pokemon := WorldBuilder.label3d(screen_root, e_mon.to_upper(), Vector3(3.22, -0.22, 0.39), Color("#ffffff"), 42, 0.005, false)
	opponent_pokemon.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var versus := WorldBuilder.label3d(screen_root, "VS", Vector3(0, -0.32, 0.43), Color("#ffd34d"), 66, 0.007, false)
	versus.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	versus.outline_size = 9
	versus.outline_modulate = Color("#14233c")
	var live_caption := WorldBuilder.label3d(screen_root, "ACTIVE PARTNER", Vector3(-3.22, -1.03, 0.39), Color("#a5c6df"), 18, 0.004, false)
	live_caption.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var opponent_caption := WorldBuilder.label3d(screen_root, "BATTLE PARTNER", Vector3(3.22, -1.03, 0.39), Color("#d6aab0"), 18, 0.004, false)
	opponent_caption.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var screen_light := OmniLight3D.new()
	screen_light.position = Vector3(0, 6.5, -8.6)
	screen_light.light_color = Color("#4ea6ff")
	screen_light.light_energy = 2.4
	screen_light.omni_range = 14.0
	add_child(screen_light)

	# Floodlights aimed at each side of the field.
	WorldBuilder.spotlight(self, Vector3(-6.5, 7.0, 6.5), PLAYER_MODEL_POS + Vector3(0, 0.8, 0), Color("#9fe8ff"), 9.0, 24.0, 28.0)
	WorldBuilder.spotlight(self, Vector3(6.5, 7.0, 6.5), ENEMY_MODEL_POS + Vector3(0, 0.8, 0), Color("#ffd9a0") if not rocket else Color("#ff7a9a"), 9.0, 24.0, 28.0)
	WorldBuilder.spotlight(self, Vector3(0, 9.0, -6.0), Vector3(0, 0.5, 0), Color("#7ea8ff"), 4.0, 26.0, 40.0)

	# Floating dust / sparks.
	var dust := CPUParticles3D.new()
	dust.position = Vector3(0, 1.0, 0)
	dust.amount = 60
	dust.lifetime = 7.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(11.0, 3.5, 8.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.gravity = Vector3(0, 0.04, 0)
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.22
	dust.scale_amount_min = 0.012
	dust.scale_amount_max = 0.035
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 1.0
	dust_mesh.height = 2.0
	dust_mesh.radial_segments = 5
	dust_mesh.rings = 3
	dust.mesh = dust_mesh
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(1.0, 0.9, 0.6, 0.55)
	dust_mat.emission_enabled = true
	dust_mat.emission = Color(1.0, 0.85, 0.45)
	dust_mat.emission_energy_multiplier = 1.8
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.material_override = dust_mat
	add_child(dust)

func _build_ground_half_disc(center: Vector3, radius: float, color: Color) -> void:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	const SEGMENTS := 48
	for i in range(SEGMENTS + 1):
		var angle := PI + PI * float(i) / float(SEGMENTS)
		vertices.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	for i in range(SEGMENTS):
		indices.append(0)
		indices.append(i + 2)
		indices.append(i + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mark := MeshInstance3D.new()
	mark.mesh = mesh
	mark.material_override = material
	mark.position = center + Vector3(0, 0.095, 0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)

func _build_platform(center: Vector3, accent: Color) -> void:
	# Simple battle platform
	WorldBuilder.cylinder(self, center + Vector3(0, -0.08, 0), 2.0, 2.2, 0.28, Color("#141b26"), Vector3.ZERO, 0.62)
	WorldBuilder.cylinder(self, center + Vector3(0, -0.01, 0), 1.6, 1.8, 0.09, Color("#222d3d"), Vector3.ZERO, 0.58)
	WorldBuilder.torus(self, center + Vector3(0, 0.07, 0), 1.4, 1.55, accent, Vector3.ONE, Vector3.ZERO, accent, 1.05)

func _build_models() -> void:
	player_model = PokemonModel.new()
	add_child(player_model)
	player_model.setup(player_species)
	player_model.position = PLAYER_MODEL_POS + Vector3(0, 0.25, 0)
	player_model.rotation_degrees.y = -125.0
	player_model.visible = true
	player_model.show()
	player_model.set_process(true)

	enemy_model = PokemonModel.new()
	add_child(enemy_model)
	enemy_model.setup(enemy_species)
	enemy_model.position = ENEMY_MODEL_POS + Vector3(0, 0.25, 0)
	enemy_model.rotation_degrees.y = 125.0
	enemy_model.visible = true
	enemy_model.show()
	enemy_model.set_process(true)

	player_trainer = TrainerModel.new()
	add_child(player_trainer)
	player_trainer.setup(_player_trainer_data())
	player_trainer.position = PLAYER_TRAINER_POS
	player_trainer.rotation_degrees.y = 62.0
	player_trainer.scale = Vector3.ONE * 1.08

	enemy_trainer = TrainerModel.new()
	add_child(enemy_trainer)
	enemy_trainer.setup(_enemy_trainer_data())
	enemy_trainer.position = ENEMY_TRAINER_POS
	enemy_trainer.rotation_degrees.y = -62.0
	enemy_trainer.scale = Vector3.ONE * 1.08

	if player_model != null:
		player_model.visible = true
		player_model.show()
		player_model.rotation_degrees.y = -125.0
		player_model.position = PLAYER_MODEL_POS + Vector3(0, 0.25, 0)
		if player_model.scale.length() < 0.001:
			player_model.scale = Vector3.ONE
		player_model.set_process(true)
	if enemy_model != null:
		enemy_model.visible = true
		enemy_model.show()
		enemy_model.rotation_degrees.y = 125.0
		enemy_model.position = ENEMY_MODEL_POS + Vector3(0, 0.25, 0)
		if enemy_model.scale.length() < 0.001:
			enemy_model.scale = Vector3.ONE
		enemy_model.set_process(true)

	if rocket:
		_add_shadow_aura()

func _player_trainer_data() -> Dictionary:
	var trainer := AssetLibrary.get_trainer(GameState.trainer_id())
	if trainer.is_empty():
		trainer = {"id": "kai", "name": GameState.trainer_name(), "accent": "#ffd05a"}
	return trainer

func _enemy_trainer_data() -> Dictionary:
	var accent := str(opponent.get("accent", "#ff5c67"))
	return {
		"id": "challenger_" + str(opponent.get("id", "arena")),
		"name": str(opponent.get("name", "Challenger")),
		"title": str(opponent.get("title", "Arena Challenger")),
		"skin": "#e2b08a",
		"hair": "#1c1822",
		"hairstyle": "short",
		"outfit": "coat",
		"cap": false,
		"cap_color": accent,
		"shirt": "#191724",
		"jacket": "#3a1220" if rocket else "#24304c",
		"pants": "#14121c",
		"shoes": accent,
		"accent": accent,
		"backpack": "#2a1420",
		"glasses": true,
	}

func _add_shadow_aura() -> void:
	var aura := OmniLight3D.new()
	aura.position = ENEMY_MODEL_POS + Vector3(0, 1.0, 0)
	aura.light_color = Color("#9b5cff")
	aura.light_energy = 2.4
	aura.omni_range = 6.0
	add_child(aura)

	var particles := CPUParticles3D.new()
	particles.position = ENEMY_MODEL_POS + Vector3(0, 1.0, 0)
	particles.amount = 34
	particles.lifetime = 2.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.25
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0, 0.55, 0)
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.55
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.07
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.62, 0.34, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color("#9b5cff")
	mat.emission_energy_multiplier = 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = mat
	add_child(particles)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.near = 0.01
	_camera.far = 500.0
	_camera.position = Vector3(0, 5.2, 14.0)
	_camera_focus = Vector3(0, 1.6, 0)
	add_child(_camera)
	_camera.look_at(_camera_focus, Vector3.UP)
	_camera.current = true

# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 30
	top.offset_right = -30
	top.offset_top = 24
	top.offset_bottom = 136
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var top_row := UIKit.hbox(18)
	top.add_child(top_row)
	top_row.add_child(_build_hp_card(true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	top_row.add_child(_build_hp_card(false))

	var turn_anchor := CenterContainer.new()
	turn_anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	turn_anchor.offset_left = -190
	turn_anchor.offset_right = 190
	turn_anchor.offset_top = 142
	turn_anchor.offset_bottom = 186
	turn_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(turn_anchor)
	var turn_panel := UIKit.panel(Color(0.035, 0.06, 0.13, 0.92), Color(0.55, 0.88, 1.0, 0.28), 12)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_anchor.add_child(turn_panel)
	_turn_label = UIKit.label("TURN 1", 14, UIKit.CYAN)
	_turn_label.add_theme_constant_override("letter_spacing", 3)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_panel.add_child(_turn_label)

	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 30
	bottom.offset_right = -30
	bottom.offset_top = -292
	bottom.offset_bottom = -24
	root.add_child(bottom)
	var bottom_row := UIKit.hbox(18)
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(bottom_row)

	var message_card := UIKit.panel(Color(0.025, 0.045, 0.1, 0.96), Color(0.55, 0.88, 1.0, 0.3), 18)
	message_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(message_card)
	var message_box := UIKit.vbox(6)
	message_card.add_child(message_box)
	var message_head := UIKit.hbox(10)
	message_box.add_child(message_head)
	var message_ball := UIKit.pokeball(24, 0.5, Color("#ffd05a"))
	message_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_head.add_child(message_ball)
	_message_speaker = UIKit.label("BATTLE", 13, Color(0.7, 0.88, 1.0, 0.78))
	_message_speaker.add_theme_constant_override("letter_spacing", 3)
	_message_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_head.add_child(_message_speaker)
	_message_label = UIKit.label("", 21, UIKit.PAPER, true)
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_message_label.custom_minimum_size = Vector2(0, 116)
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_box.add_child(_message_label)
	_battle_hint = UIKit.small("Click a move or press 1–4", Color(0.66, 0.8, 1.0, 0.55))
	message_box.add_child(_battle_hint)

	_moves_card = UIKit.panel(Color(0.035, 0.06, 0.13, 0.97), Color(0.55, 0.88, 1.0, 0.28), 18)
	_moves_card.custom_minimum_size = Vector2(640, 0)
	_moves_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(_moves_card)
	var moves_box := UIKit.vbox(8)
	_moves_card.add_child(moves_box)
	var moves_head := UIKit.hbox(8)
	moves_box.add_child(moves_head)
	moves_head.add_child(UIKit.small("CHOOSE A MOVE", Color(0.68, 0.86, 1.0, 0.7)))
	var moves_line := UIKit.separator(Color(1, 1, 1, 0.08), 1)
	moves_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moves_head.add_child(moves_line)
	moves_head.add_child(UIKit.small("PP MATTERS", Color(0.6, 0.72, 0.9, 0.4)))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moves_box.add_child(grid)
	for i in 4:
		var button := UIKit.button("", "glass", "", 82)
		button.custom_minimum_size = Vector2(0, 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_move_pressed.bind(i))
		grid.add_child(button)
		_move_buttons.append(button)
	var footer := UIKit.hbox(8)
	moves_box.add_child(footer)
	footer.add_child(UIHelpers.key_hint("1-4", "Moves"))
	footer.add_child(UIHelpers.key_hint("ESC", "Forfeit"))
	var footer_flex := Control.new()
	footer_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_flex)
	footer.add_child(UIKit.small("Every turn matters", Color(0.6, 0.72, 0.9, 0.4)))

	if exhibition or auto_battle:
		if _moves_card != null:
			_moves_card.visible = false
		_battle_hint.text = "AUTO BATTLE"

	_refresh_hp_cards()
	_refresh_status_chips()
	_update_move_buttons()

func _build_hp_card(is_player: bool) -> PanelContainer:
	var card := UIKit.panel(Color(0.025, 0.045, 0.1, 0.94), Color(0.55, 0.88, 1.0, 0.26) if is_player else Color(1, 0.45, 0.5, 0.28), 16)
	card.custom_minimum_size = Vector2(500, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(12)
	card.add_child(row)
	var ball := UIKit.pokeball(44, 0.35, Color("#78e2ff") if is_player else (Color("#ff334d") if rocket else Color("#ffd05a")))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ball)
	var box := UIKit.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head := UIKit.hbox(8)
	box.add_child(head)
	var name_label := UIKit.label(sim.player.display_name() if is_player else sim.enemy.display_name(), 22, UIKit.PAPER)
	head.add_child(name_label)
	var level_label := UIKit.label("Lv. %d" % (sim.player.level if is_player else sim.enemy.level), 14, Color(0.75, 0.88, 1.0, 0.8))
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(level_label)
	var flex := Control.new()
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(flex)
	var status := UIKit.label("", 11, Color("#ff9aa5"))
	status.add_theme_constant_override("letter_spacing", 1)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(status)
	var types := UIHelpers.type_row((sim.player if is_player else sim.enemy).data.types(), true)
	box.add_child(types)
	var bar := UIKit.health_bar(1, 1, false, true)
	box.add_child(bar)
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp_label := UIKit.small("", Color(0.72, 0.84, 1.0, 0.65))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hp_label)
	if is_player:
		_player_hp = bar
		_player_status = status
		_player_hp_value = hp_label
	else:
		_enemy_hp = bar
		_enemy_status = status
		_enemy_hp_value = hp_label
	return card

func _refresh_hp_cards() -> void:
	if sim == null:
		return
	_update_hp_display("player", sim.player.hp, sim.player.max_hp)
	_update_hp_display("enemy", sim.enemy.hp, sim.enemy.max_hp)

func _update_hp_display(side: String, current_hp: int, maximum_hp: int, instant: bool = false) -> HealthBar:
	var bar: HealthBar
	var value_label: Label
	if side == "player":
		bar = _player_hp
		value_label = _player_hp_value
	elif side == "enemy":
		bar = _enemy_hp
		value_label = _enemy_hp_value
	else:
		return null
	if bar == null:
		return null
	bar.set_values(current_hp, maximum_hp, instant)
	if value_label != null:
		value_label.text = "%d / %d HP" % [current_hp, maximum_hp]
	return bar

func _refresh_status_chips() -> void:
	if sim == null:
		return
	_player_status.text = sim.player.status_label()
	_player_status.visible = _player_status.text != ""
	_enemy_status.text = sim.enemy.status_label()
	_enemy_status.visible = _enemy_status.text != ""

func _update_move_buttons() -> void:
	if sim == null:
		return
	for i in _move_buttons.size():
		var button := _move_buttons[i]
		if i >= sim.player.moves.size():
			button.visible = false
			continue
		button.visible = true
		var move := sim.player.moves[i]
		var pp := sim.player.pp[i]
		var power_text := "Power %d" % move.power if move.power > 0 else "Status"
		button.text = "%d   %s\n%s  •  %s  •  %d/%d PP" % [i + 1, move.display_name, move.poke_type.capitalize(), power_text, pp, move.max_pp]
		button.tooltip_text = move.description
		button.disabled = _busy or _ended or pp <= 0
		var type_color := TypeChart.type_color(move.poke_type)
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		if normal != null:
			normal.border_color = Color(type_color.r, type_color.g, type_color.b, 0.5)
			normal.set_border_width_all(2)
		var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
		if hover != null:
			hover.border_color = type_color
			hover.set_border_width_all(2)

func _build_banner() -> void:
	_banner_layer = Control.new()
	_banner_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.modulate = Color(1, 1, 1, 0)
	_banner_layer.visible = false
	_ui_layer.add_child(_banner_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(center)
	var panel := UIKit.panel(Color(0.02, 0.035, 0.08, 0.9), Color(0.6, 0.9, 1.0, 0.24), 22)
	panel.custom_minimum_size = Vector2(840, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := UIKit.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	_banner_kicker = UIKit.label("", 14, Color(0.75, 0.9, 1.0, 0.8))
	_banner_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_kicker.add_theme_constant_override("letter_spacing", 5)
	box.add_child(_banner_kicker)
	_banner_title = UIKit.title("", 64, UIKit.GOLD)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_title)
	_banner_sub = UIKit.label("", 18, Color(0.86, 0.93, 1.0, 0.9))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_sub)

func _build_result_overlay() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.visible = false
	_ui_layer.add_child(_result_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.015, 0.04, 0.86)
	_result_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)
	_result_panel = UIKit.panel(Color(0.035, 0.06, 0.13, 0.98), Color(0.55, 0.88, 1.0, 0.3), 26)
	_result_panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(_result_panel)
	var box := UIKit.vbox(10)
	_result_panel.add_child(box)
	var head := UIKit.hbox(14)
	box.add_child(head)
	var ball := UIKit.pokeball(58, 0.5, Color("#ffd05a"))
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ball)
	var head_box := UIKit.vbox(0)
	head.add_child(head_box)
	_result_kicker = UIKit.label("BATTLE COMPLETE", 13, Color(0.7, 0.88, 1.0, 0.7))
	_result_kicker.add_theme_constant_override("letter_spacing", 3)
	head_box.add_child(_result_kicker)
	_result_title = UIKit.title("VICTORY!", 66, UIKit.GOLD)
	head_box.add_child(_result_title)
	_result_sub = UIKit.label("", 17, Color(0.84, 0.92, 1.0, 0.9), true)
	_result_sub.custom_minimum_size = Vector2(0, 26)
	box.add_child(_result_sub)
	box.add_child(UIKit.separator(Color(1, 1, 1, 0.08), 1))
	_result_details = UIKit.vbox(8)
	box.add_child(_result_details)
	box.add_child(UIKit.spacer(4))
	var actions := UIKit.hbox(10)
	box.add_child(actions)
	_result_button = UIKit.button("Return to the Arena", "primary", "", 54)
	_result_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_button.pressed.connect(_leave_battle)
	actions.add_child(_result_button)
	_result_menu_button = UIKit.button("Main Menu", "ghost", "", 54)
	_result_menu_button.custom_minimum_size = Vector2(180, 54)
	_result_menu_button.pressed.connect(_to_main_menu)
	actions.add_child(_result_menu_button)

# ------------------------------------------------------------------ battle intro

func _start_intro() -> void:
	if not is_inside_tree():
		return
	_busy = true
	_update_move_buttons()
	if rocket:
		await _show_banner("TEAM ROCKET EVENT", "THE ARENA IS UNDER SIEGE", "The lights dim. A shadow steps onto the centre stage.", UIKit.RED, 1.8)
	else:
		await _show_banner("STADIUM CHALLENGE", "BATTLE START", "%s steps into the spotlight." % str(opponent.get("name", "Challenger")), UIKit.CYAN, 1.4)
	if not is_inside_tree():
		return
	await _move_camera(Vector3(-5.4, 2.6, 6.2), Vector3(-3.0, 1.2, 0), 0.8)
	player_trainer.play_throw()
	await _wait(0.25)
	AudioManager.play_sfx("pokeball_open", -3.0)
	player_model.visible = true
	player_model.play_entrance()
	AudioManager.play_cry(player_species.id, player_species.battle_cry_pitch)
	await _wait(0.75)
	if not is_inside_tree():
		return
	await _move_camera(Vector3(5.4, 2.6, 6.2), Vector3(3.0, 1.2, 0), 0.8)
	enemy_trainer.play_throw()
	await _wait(0.25)
	AudioManager.play_sfx("pokeball_open", -3.0)
	enemy_model.visible = true
	enemy_model.play_entrance()
	AudioManager.play_cry(enemy_species.id, enemy_species.battle_cry_pitch)
	await _wait(0.75)
	if not is_inside_tree():
		return
	await _move_camera(Vector3(0, 7.5, 22.0), Vector3(0, 2.5, 0), 0.9)
	if player_model != null and enemy_model != null:
		player_model.look_at(Vector3(enemy_model.global_position.x, player_model.global_position.y, enemy_model.global_position.z), Vector3.UP)
		enemy_model.look_at(Vector3(player_model.global_position.x, enemy_model.global_position.y, enemy_model.global_position.z), Vector3.UP)
		player_model.rotation_degrees.x = 0.0
		player_model.rotation_degrees.z = 0.0
		enemy_model.rotation_degrees.x = 0.0
		enemy_model.rotation_degrees.z = 0.0
	_message_speaker.text = "BATTLE"
	if rocket and not exhibition:
		await _say(str(opponent.get("intro", "Team Rocket has taken over the arena!")), 0.9)
	elif exhibition:
		await _say("Exhibition Match!", 0.6)
	else:
		await _say("%s wants to battle!" % str(opponent.get("name", "The challenger")), 0.7)
	await _say("Go! %s!" % sim.player.display_name(), 0.45)
	await _say("%s sent out %s!" % [str(opponent.get("name", "Challenger")), sim.enemy.display_name()], 0.55)
	if rocket and not exhibition:
		await _say("This is a Team Rocket event battle. Give it everything you have!", 0.8)
	elif exhibition:
		await _say("Watch them battle!", 0.15)
	else:
		await _say("What will %s do?" % sim.player.display_name(), 0.15)
	if exhibition or auto_battle:
		_busy = true
		_update_move_buttons()
		_update_turn_label()
		await _start_auto_battle()
		return
	_busy = false
	_update_move_buttons()
	_update_turn_label()

func _show_banner(kicker: String, heading: String, subtitle: String, color: Color, hold: float = 1.4) -> void:
	if _banner_layer == null:
		return
	_banner_kicker.text = kicker.to_upper()
	_banner_title.text = heading
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner_layer.visible = true
	_banner_layer.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_banner_layer, "modulate:a", 1.0, 0.28)
	await tw.finished
	await _wait(hold)
	if _banner_layer == null:
		return
	var out := create_tween()
	out.tween_property(_banner_layer, "modulate:a", 0.0, 0.32)
	await out.finished
	_banner_layer.visible = false

# ------------------------------------------------------------------ turn flow

func _start_auto_battle() -> void:
	if _ended or sim == null:
		return
	_busy = true
	_update_move_buttons()
	_message_speaker.text = "AUTO BATTLE"
	await _say("AUTO BATTLE IN PROGRESS", 0.4)
	while not sim.finished and not _ended and is_inside_tree():
		await _wait(0.6)
		if sim.finished or _ended:
			break
		var player_index := sim.choose_player_move()
		var enemy_index := sim.choose_enemy_move()
		if player_index < 0 and enemy_index < 0:
			break
		if player_index < 0:
			player_index = enemy_index
		if enemy_index < 0:
			enemy_index = player_index
		AudioManager.play_sfx("confirm", -7.0)
		var events := sim.take_turn(player_index, enemy_index)
		await _play_events(events)
		if not is_inside_tree():
			return
		_refresh_hp_cards()
		_refresh_status_chips()
		if sim.finished:
			break
	if not _ended and is_inside_tree():
		await _finish_battle()


func _on_move_pressed(index: int) -> void:
	if _busy or _ended or sim == null or sim.finished:
		return
	if exhibition or auto_battle:
		return
	if index < 0 or index >= sim.player.pp.size() or sim.player.pp[index] <= 0:
		return
	_busy = true
	_update_move_buttons()
	AudioManager.play_sfx("confirm", -6.0)
	var enemy_index := sim.choose_enemy_move()
	var events := sim.take_turn(index, enemy_index)
	await _play_events(events)
	if not is_inside_tree():
		return
	_refresh_hp_cards()
	_refresh_status_chips()
	if sim.finished:
		await _finish_battle()
		return
	_busy = false
	_update_move_buttons()
	await _say("What will %s do?" % sim.player.display_name(), 0.1)

func _play_events(events: Array) -> void:
	for event in events:
		if not is_inside_tree():
			return
		var kind := str(event.get("type", ""))
		match kind:
			"turn_start":
				_update_turn_label()
			"attack":
				_last_move_type = str(event.get("move_type", "normal"))
				await _play_attack(str(event.get("side", "player")))
			"message":
				await _say(str(event.get("text", "")), 0.42)
			"damage":
				await _play_damage(event)
			"status_damage":
				await _play_status_damage(event)
			"faint":
				await _play_faint(str(event.get("side", "enemy")))
			"end":
				return

func _update_turn_label() -> void:
	if _turn_label == null or sim == null:
		return
	var prefix := "TEAM ROCKET  •  " if rocket else ""
	_turn_label.text = "%sTURN %d" % [prefix, maxi(1, sim.turn_count)]

func _play_attack(side: String) -> void:
	var model: PokemonModel = player_model if side == "player" else enemy_model
	var other: PokemonModel = enemy_model if side == "player" else player_model
	var trainer: TrainerModel = player_trainer if side == "player" else enemy_trainer
	if model == null:
		return
	if model != null:
		model.look_at(Vector3(other.global_position.x, model.global_position.y, other.global_position.z), Vector3.UP)
	if other != null:
		other.look_at(Vector3(model.global_position.x, other.global_position.y, other.global_position.z), Vector3.UP)
	if trainer != null:
		trainer.set_move_speed(2.4)
	model.play_attack(_last_move_type)
	AudioManager.play_sfx("whoosh", -5.0, 1.08 if side == "player" else 0.9)
	var base := model.position
	var direction := 1.0 if side == "player" else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "position", base + Vector3(2.6 * direction, 0.45, 0.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if other != null:
		tw.tween_property(other, "position", other.position + Vector3(-0.18 * direction, 0.12, -0.08), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(model, "position", base, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if other != null:
		tw2.tween_property(other, "position", ENEMY_MODEL_POS if side == "player" else PLAYER_MODEL_POS, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await tw2.finished
	if model != null:
		model.rotation_degrees.y = -125.0 if side == "player" else 125.0
	if other != null:
		other.rotation_degrees.y = 125.0 if side == "player" else -125.0
	if trainer != null:
		trainer.set_move_speed(1.0)

func _play_damage(event: Dictionary) -> void:
	var side := str(event.get("side", "enemy"))
	var model: PokemonModel = player_model if side == "player" else enemy_model
	var attacker_side := "enemy" if side == "player" else "player"
	var attacker: PokemonModel = player_model if attacker_side == "player" else enemy_model
	var bar := _update_hp_display(side, int(event.get("hp", 0)), int(event.get("max_hp", 1)))
	var effectiveness := float(event.get("effectiveness", 1.0))
	var crit := bool(event.get("crit", false))
	if model != null:
		model.look_at(Vector3(attacker.global_position.x, model.global_position.y, attacker.global_position.z), Vector3.UP)
	if attacker != null:
		attacker.look_at(Vector3(model.global_position.x, attacker.global_position.y, attacker.global_position.z), Vector3.UP)
	if model != null:
		model.play_hit(effectiveness)
		var hit_tw := create_tween()
		hit_tw.set_parallel(true)
		hit_tw.tween_property(model, "position", model.position + Vector3(0.28 if side == "enemy" else -0.28, 0.18, -0.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tw.chain().tween_property(model, "position", ENEMY_MODEL_POS if side == "enemy" else PLAYER_MODEL_POS, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if bar != null:
		bar.flash()
	_shake(0.32 if effectiveness > 1.0 or crit else 0.18, 0.38)
	AudioManager.play_hit(effectiveness)
	if model != null:
		_spawn_burst(model.get_effect_global_position(), TypeChart.type_color(_last_move_type), 32 if effectiveness > 1.0 else 20)
	_refresh_hp_cards()
	_refresh_status_chips()
	await _wait(0.48)
	if model != null:
		model.rotation_degrees.y = 125.0 if side == "enemy" else -125.0

func _play_status_damage(event: Dictionary) -> void:
	var side := str(event.get("side", "enemy"))
	var model: PokemonModel = player_model if side == "player" else enemy_model
	var bar := _update_hp_display(side, int(event.get("hp", 0)), int(event.get("max_hp", 1)))
	if model != null:
		model.play_hit(0.8)
	if bar != null:
		bar.flash()
	AudioManager.play_sfx("weak_hit", -3.0)
	if model != null:
		_spawn_burst(model.get_effect_global_position(), Color("#b28bff"), 14)
	_refresh_hp_cards()
	_refresh_status_chips()
	await _wait(0.45)

func _play_faint(side: String) -> void:
	var model: PokemonModel = player_model if side == "player" else enemy_model
	if model != null:
		model.play_faint()
	AudioManager.play_sfx("faint", -2.0)
	if side == "enemy":
		_update_hp_display(side, 0, sim.enemy.max_hp)
	else:
		_update_hp_display(side, 0, sim.player.max_hp)
	_refresh_hp_cards()
	await _wait(1.05)

# ------------------------------------------------------------------ result

func _finish_battle() -> void:
	if _ended:
		return
	_ended = true
	_busy = true
	_update_move_buttons()
	_refresh_hp_cards()
	_refresh_status_chips()
	var won := sim.winner == "player"
	if won:
		if player_trainer != null:
			player_trainer.play_victory()
		if enemy_trainer != null:
			enemy_trainer.play_defeat()
		if player_model != null:
			player_model.play_victory()
		AudioManager.play_music("victory", 0.5, true)
		AudioManager.play_sfx("crowd_cheer", -2.0)
	else:
		if player_trainer != null:
			player_trainer.play_defeat()
		if enemy_trainer != null:
			enemy_trainer.play_victory()
		if enemy_model != null:
			enemy_model.play_victory()
		AudioManager.play_music("defeat", 0.5, true)
	if exhibition:
		_summary = {
			"won": won,
			"rocket": false,
			"xp": 0,
			"level_up": {},
			"unlocked": [],
			"rocket_pending": false,
			"badges": 0,
			"exhibition": true,
		}
		GameState.ui_context["last_result"] = _summary
	else:
		var xp_amount := sim.reward_xp(won)
		_summary = GameState.record_battle({
			"won": won,
			"rocket": rocket,
			"xp": xp_amount,
			"opponent_name": str(opponent.get("name", "Challenger")),
			"active_id": active_id,
			"opponent_level": sim.enemy.level,
		})
		GameState.ui_context["last_result"] = _summary
	await _wait(1.25)
	if not is_inside_tree():
		return
	_show_result(_summary, won)

func _show_result(summary: Dictionary, won: bool) -> void:
	if _result_layer == null:
		return
	_result_details.get_children().map(func(child): child.queue_free())
	var xp := int(summary.get("xp", 0))
	var level_up: Dictionary = summary.get("level_up", {})
	var unlocked: Array = summary.get("unlocked", [])
	var badges := int(summary.get("badges", 0))

	_result_kicker.text = "EXHIBITION MATCH" if exhibition else ("TEAM ROCKET EVENT" if rocket else "BATTLE COMPLETE")
	if exhibition and won:
		_result_title.text = "VICTORY!"
		_result_title.add_theme_color_override("font_color", UIKit.GOLD)
		_result_sub.text = "%s wins the exhibition match!" % sim.player.display_name()
	elif exhibition and not won:
		_result_title.text = "DEFEAT"
		_result_title.add_theme_color_override("font_color", UIKit.RED)
		_result_sub.text = "%s wins the exhibition match!" % sim.enemy.display_name()
	elif rocket and won:
		_result_title.text = "ARENA LIBERATED"
		_result_title.add_theme_color_override("font_color", UIKit.GOLD)
		_result_sub.text = "Team Rocket retreats. The crowd erupts for you."
	elif rocket:
		_result_title.text = "ROCKET GOT AWAY"
		_result_title.add_theme_color_override("font_color", UIKit.RED)
		_result_sub.text = "The arena falls silent. Regroup and come back stronger."
	elif won:
		_result_title.text = "VICTORY!"
		_result_title.add_theme_color_override("font_color", UIKit.GOLD)
		_result_sub.text = "%s and %s win the crowd." % [GameState.trainer_name(), sim.player.display_name()]
	else:
		_result_title.text = "DEFEAT"
		_result_title.add_theme_color_override("font_color", UIKit.RED)
		_result_sub.text = "Your partner still grew from the battle. Try again."

	if exhibition:
		var ex_row := UIKit.hbox(10)
		_result_details.add_child(ex_row)
		ex_row.add_child(UIKit.small("EXHIBITION", Color(0.7, 0.88, 1.0, 0.65)))
		var ex_flex := Control.new()
		ex_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ex_row.add_child(ex_flex)
		ex_row.add_child(UIKit.label("%s vs %s" % [sim.player.display_name(), sim.enemy.display_name()], 20, UIKit.PAPER))
		var note := UIKit.small("No XP, unlocks, or progression changes from exhibition matches.", Color(0.64, 0.76, 0.94, 0.62))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_result_details.add_child(note)
	else:
		var xp_row := UIKit.hbox(10)
		_result_details.add_child(xp_row)
		xp_row.add_child(UIKit.small("EXPERIENCE GAINED", Color(0.68, 0.84, 1.0, 0.65)))
		var xp_flex := Control.new()
		xp_flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_row.add_child(xp_flex)
		xp_row.add_child(UIKit.label("+%d XP" % xp, 26, UIKit.MINT if won else Color("#ffd05a")))

		var levels := int(level_up.get("levels", 0))
		if levels > 0:
			var level_row := UIKit.panel(Color(0.14, 0.1, 0.02, 0.8), Color(1, 0.82, 0.35, 0.4), 12)
			var level_box := UIKit.hbox(10)
			level_row.add_child(level_box)
			level_box.add_child(UIKit.pokeball(26, 1.2, Color("#ffd05a")))
			level_box.add_child(UIKit.label("LEVEL UP!  Lv. %d → Lv. %d" % [int(level_up.get("old_level", 5)), int(level_up.get("new_level", 5))], 18, UIKit.GOLD))
			_result_details.add_child(level_row)
			AudioManager.play_sfx("level_up", -2.0)

		for id in unlocked:
			var species := AssetLibrary.get_pokemon(str(id))
			if species == null:
				continue
			var unlock_row := UIKit.panel(Color(0.03, 0.12, 0.09, 0.9), Color(0.4, 1.0, 0.7, 0.4), 12)
			var unlock_box := UIKit.hbox(10)
			unlock_row.add_child(unlock_box)
			var mini := UIKit.silhouette(species.id, Color(0.4, 1.0, 0.72, 0.35))
			mini.custom_minimum_size = Vector2(46, 46)
			unlock_box.add_child(mini)
			var unlock_text := UIKit.vbox(0)
			unlock_box.add_child(unlock_text)
			unlock_text.add_child(UIKit.small("NEW PARTNER UNLOCKED", Color(0.55, 1.0, 0.75, 0.75)))
			unlock_text.add_child(UIKit.label(species.display_name, 22, Color("#c8ffe0")))
			_result_details.add_child(unlock_row)
			AudioManager.play_sfx("unlock", -2.0)

		if badges > 0:
			var badge_row := UIKit.panel(Color(0.12, 0.02, 0.05, 0.9), Color(1, 0.3, 0.4, 0.45), 12)
			var badge_box := UIKit.hbox(10)
			badge_row.add_child(badge_box)
			badge_box.add_child(UIKit.pokeball(26, 1.6, Color("#ff334d")))
			badge_box.add_child(UIKit.label("ROCKET BADGE EARNED  •  Total %d" % GameState.rocket_badges(), 18, Color("#ff9aa5")))
			_result_details.add_child(badge_row)

		if unlocked.is_empty() and levels == 0:
			var note := UIKit.small("Win regular matches to unlock new partners and fill your collection.", Color(0.64, 0.76, 0.94, 0.62))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_result_details.add_child(note)

		if bool(summary.get("rocket_pending", false)):
			var next := UIKit.small("Team Rocket is already plotting their next move. Two more matches will draw them out.", Color(0.9, 0.7, 0.74, 0.8))
			next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_result_details.add_child(next)

	if exhibition:
		if _result_button != null:
			_result_button.text = "Rematch"
			_result_button.pressed.disconnect(_leave_battle)
			_result_button.pressed.connect(_exhibition_rematch)
		if _result_menu_button != null:
			_result_menu_button.text = "Change Fighters"
			_result_menu_button.pressed.disconnect(_to_main_menu)
			_result_menu_button.pressed.connect(_exhibition_change_fighters)
	else:
		_result_button.text = _return_button_text()

	_result_layer.visible = true
	_result_layer.modulate = Color(1, 1, 1, 0)
	_result_panel.scale = Vector2(0.94, 0.94)
	_result_panel.pivot_offset = _result_panel.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_result_layer, "modulate:a", 1.0, 0.35)
	tw.tween_property(_result_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_result_button.grab_focus()

func _return_button_text() -> String:
	if return_scene.contains("battle_arena"):
		return "Return to the Battle Arena"
	if return_scene.contains("stadium_playground"):
		return "Return to the Stadium Playground"
	return "Return to Your Journey"


func _exhibition_rematch() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play_sfx("confirm")
	var pending := _pending_battle_raw.duplicate(true)
	pending["exhibition"] = true
	pending["auto"] = true
	pending["return_scene"] = "res://scenes/ui/exhibition.tscn"
	GameState.pending_battle = pending
	SceneRouter.goto(SCENE_PATH, 0.5, "REMATCH")


func _exhibition_change_fighters() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play_sfx("confirm")
	SceneRouter.goto("res://scenes/ui/exhibition.tscn", 0.5, "EXHIBITION")


func _leave_battle() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play_sfx("confirm")
	SceneRouter.goto(return_scene, 0.55, "RETURNING")

func _to_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.ui_context.erase("last_result")
	SceneRouter.goto_main_menu()

# ------------------------------------------------------------------ input / camera / fx

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event.is_action_pressed("pause_game"):
		if _busy:
			return
		_forfeit()
		get_viewport().set_input_as_handled()
		return
	if _busy:
		return
	if event.is_action_pressed("battle_move_1"):
		_on_move_pressed(0)
	elif event.is_action_pressed("battle_move_2"):
		_on_move_pressed(1)
	elif event.is_action_pressed("battle_move_3"):
		_on_move_pressed(2)
	elif event.is_action_pressed("battle_move_4"):
		_on_move_pressed(3)

func _forfeit() -> void:
	if _ended or _busy:
		return
	AudioManager.play_sfx("cancel")
	_message_speaker.text = "BATTLE"
	await _say("You forfeit the match. Your partner still learned something.", 0.6)
	sim.finished = true
	sim.winner = "enemy"
	await _finish_battle()

func _process(delta: float) -> void:
	if _camera != null:
		if _shake_time > 0.0:
			_shake_time = maxf(0.0, _shake_time - delta)
			_camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength
			_camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength
			_shake_strength = maxf(0.0, _shake_strength - delta * 1.8)
		else:
			_camera.h_offset = lerpf(_camera.h_offset, 0.0, clampf(delta * 10.0, 0.0, 1.0))
			_camera.v_offset = lerpf(_camera.v_offset, 0.0, clampf(delta * 10.0, 0.0, 1.0))
			_shake_strength = 0.0
		if player_model != null and enemy_model != null and not _ended:
			var mid := (player_model.global_position + enemy_model.global_position) * 0.5
			_camera_focus = mid + Vector3(0, 2.5, 0)
		_camera.look_at(_camera_focus, Vector3.UP)

func _shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)

func _set_camera_focus(value: Vector3) -> void:
	_camera_focus = value

func _move_camera(position_value: Vector3, focus: Vector3, duration: float) -> void:
	if _camera == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_camera, "position", position_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_camera_focus, _camera_focus, focus, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if _camera != null:
		_camera.look_at(_camera_focus, Vector3.UP)

func _say(text: String, hold: float = 0.5) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.visible_ratio = 0.0
	var duration := clampf(float(text.length()) * 0.012, 0.12, 0.5)
	var tw := create_tween()
	tw.tween_property(_message_label, "visible_ratio", 1.0, duration)
	await tw.finished
	await _wait(hold)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _spawn_burst(world_position: Vector3, color: Color, count: int = 20) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = count
	particles.lifetime = 0.75
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3(0, -3.0, 0)
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 4.2
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.075
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = mat
	add_child(particles)
	particles.global_position = world_position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
