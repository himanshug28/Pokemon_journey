extends SceneTree
## End-to-end flow test through the real scenes and SceneRouter:
## menu -> trainer -> starter -> playground -> battle -> result -> playground ->
## arena -> collection/settings/arenas -> back.
## Run with:
##   godot --headless --fixed-fps 60 --path "C:\pokemon  journey" --script "res://tools/flow_test.gd"
## This writes to the user save; restore the backup afterwards.

var gs: Node
var assets: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("FLOW FAIL: ", message)

func _wait_scene(needle: String, cap: int) -> Node:
	for i in cap:
		var scene := current_scene
		if scene != null and scene.scene_file_path.contains(needle):
			return scene
		await process_frame
	return null

func _wait_turn(instance: Object, cap: int) -> void:
	for i in cap:
		if not is_instance_valid(instance):
			return
		if bool(instance.get("_ended")) or not bool(instance.get("_busy")):
			return
		await process_frame

func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene

func _settle() -> void:
	## SceneRouter flips current_scene mid-fade; wait for the transition to finish
	## so the next goto() call is not ignored.
	var router := root.get_node("SceneRouter")
	for i in 900:
		if not bool(router.transitioning):
			return
		await process_frame

func _run() -> void:
	for i in 5:
		await process_frame
	gs = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if gs == null or assets == null:
		_fail("autoloads missing")
		quit(1)
		return

	# Start from a clean journey but keep the autoload state consistent.
	gs.data["trainer_id"] = ""
	gs.data["trainer_name"] = ""
	gs.data["starter_id"] = ""
	gs.data["active_pokemon"] = ""
	gs.data["unlocked"] = []
	gs.data["regular_matches_completed"] = 0
	gs.data["regular_wins"] = 0
	gs.data["rocket_events_completed"] = 0
	gs.data["rocket_pending"] = false
	gs.data["badges"] = 0
	gs.data["xp"] = {}
	gs.data["location"] = gs.LOCATION_PLAYGROUND
	gs.has_save = true

	# ---------------------------------------------------------- loading -> menu
	var loading := _open("res://scenes/ui/loading_screen.tscn")
	await process_frame
	if loading == null:
		_fail("loading screen failed to open")
		quit(1)
		return
	var menu := await _wait_scene("main_menu", 60 * 40)
	if menu == null:
		_fail("loading screen did not reach the main menu")
		print("FLOW DONE: ", failures.size(), " failure(s)")
		quit(1)
		return
	await _settle()
	print("FLOW: loading screen reached main menu")

	# ---------------------------------------------------------- trainer select
	await gs.get_node("/root/SceneRouter").goto("res://scenes/ui/trainer_select.tscn", 0.05, "TRAINER")
	var trainer_scene := await _wait_scene("trainer_select", 60 * 10)
	if trainer_scene == null:
		_fail("did not reach trainer select")
	else:
		await _settle()
		trainer_scene.get("_name_edit").text = "Flow Tester"
		trainer_scene._on_start()
		print("FLOW: trainer select accepted")

	# ---------------------------------------------------------- starter select
	var starter_scene := await _wait_scene("starter_select", 60 * 10)
	if starter_scene == null:
		_fail("did not reach starter select")
	else:
		await _settle()
		var species: Array = starter_scene.get("_species")
		var pick := 0
		for i in species.size():
			if species[i].id == "pikachu":
				pick = i
		starter_scene._select(pick, false)
		starter_scene._on_choose()
		print("FLOW: starter chosen: ", species[pick].id)

	# ---------------------------------------------------------- playground
	var playground := await _wait_scene("stadium_playground", 60 * 12)
	if playground == null:
		_fail("did not reach the playground")
		print("FLOW DONE: ", failures.size(), " failure(s)")
		quit(1)
		return
	await _settle()
	await _frames(90)
	var player = playground.get("player")
	if player == null:
		_fail("playground has no player")
	else:
		print("FLOW: playground player at ", player.global_position)
		if player.global_position.y < -0.5:
			_fail("player fell through the playground floor")
		Input.action_press("move_forward")
		await _frames(45)
		Input.action_release("move_forward")
		var moved: Vector3 = player.global_position
		print("FLOW: after walking -> ", moved)
		if moved.distance_to(Vector3(0, 0.05, 13.5)) < 0.2:
			_fail("player did not move with move_forward")
		if moved.y < -0.5:
			_fail("player fell while walking")
	if gs.active_pokemon() != "pikachu":
		_fail("active partner is not pikachu after choosing starter")

	# ---------------------------------------------------------- battle
	playground._start_regular_battle("ben", playground.get("player"))
	var battle := await _wait_scene("battle_scene", 60 * 15)
	if battle == null:
		_fail("did not reach the battle scene")
	else:
		if not await _wait_until_busy(battle, false, 60 * 40):
			_fail("battle intro never finished")
		else:
			print("FLOW: battle started vs ", battle.sim.enemy.display_name())
			var turns := 0
			while not bool(battle.get("_ended")) and turns < 40:
				var choice := -1
				for i in battle.sim.player.pp.size():
					if battle.sim.player.pp[i] > 0:
						choice = i
						break
				if choice < 0:
					break
				battle._on_move_pressed(choice)
				turns += 1
				await _wait_turn(battle, 60 * 20)
			if not bool(battle.get("_ended")):
				_fail("battle did not end")
			else:
				print("FLOW: battle ended after ", turns, " turns, winner=", battle.sim.winner,
					", completed=", gs.regular_matches_completed(), ", wins=", gs.regular_wins())
				if gs.regular_matches_completed() != 1:
					_fail("regular_matches_completed did not increment")
				# Wait for the result panel, then leave through the real button path.
				for i in 60 * 12:
					var layer: Control = battle.get("_result_layer")
					if layer != null and layer.visible:
						break
					await process_frame
				battle._leave_battle()
				var back := await _wait_scene("stadium_playground", 60 * 15)
				if back == null:
					_fail("did not return to the playground after battle")
				else:
					print("FLOW: returned to playground, rocket_pending=", gs.rocket_pending())
					await _settle()

	# ---------------------------------------------------------- arena
	await gs.get_node("/root/SceneRouter").goto_location(gs.LOCATION_ARENA)
	var arena := await _wait_scene("battle_arena", 60 * 15)
	if arena == null:
		_fail("did not reach the battle arena")
	else:
		await _settle()
		await _frames(120)
		var arena_player = arena.get("player")
		if arena_player == null:
			_fail("arena has no player")
		else:
			print("FLOW: arena player at ", arena_player.global_position)
			if arena_player.global_position.y < -0.5:
				_fail("player fell through the arena floor")
			Input.action_press("move_forward")
			await _frames(45)
			Input.action_release("move_forward")
			var arena_moved: Vector3 = arena_player.global_position
			print("FLOW: arena walk -> ", arena_moved)
			if arena_moved.y < -0.5:
				_fail("player fell while walking in the arena")
			if arena_moved.distance_to(Vector3(0, 0.1, 13.0)) < 0.2:
				_fail("player did not move in the arena")

	# ---------------------------------------------------------- sub screens
	await _settle()
	gs.ui_context["return_scene"] = gs.SCENE_ARENA
	await gs.get_node("/root/SceneRouter").goto("res://scenes/ui/collection.tscn", 0.05, "COLLECTION")
	var collection := await _wait_scene("collection", 60 * 10)
	if collection == null:
		_fail("did not reach collection")
	else:
		await _settle()
		await _frames(30)
		print("FLOW: collection open, cards=", collection.get("_cards").size())

	gs.ui_context["return_scene"] = gs.SCENE_MAIN_MENU
	await gs.get_node("/root/SceneRouter").goto("res://scenes/ui/settings.tscn", 0.05, "SETTINGS")
	var settings := await _wait_scene("settings", 60 * 10)
	if settings == null:
		_fail("did not reach settings")
	else:
		await _settle()
		await _frames(20)
		print("FLOW: settings open")

	await gs.get_node("/root/SceneRouter").goto("res://scenes/ui/arenas_screen.tscn", 0.05, "ARENAS")
	var arenas := await _wait_scene("arenas_screen", 60 * 10)
	if arenas == null:
		_fail("did not reach arenas screen")
	else:
		await _settle()
		await _frames(20)
		print("FLOW: arenas screen open")

	print("FLOW DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _wait_until_busy(instance: Object, expected: bool, cap: int) -> bool:
	for i in cap:
		if not is_instance_valid(instance):
			return false
		if bool(instance.get("_busy")) == expected:
			return true
		await process_frame
	return false
