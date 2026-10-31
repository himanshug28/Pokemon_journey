extends SceneTree
## Team Rocket event test: pending flag -> arena auto-cue -> cinematic -> battle ->
## event consumed and saved. Run:
##   godot --headless --fixed-fps 60 --path "C:\pokemon  journey" --script "res://tools/rocket_test.gd"

var gs: Node
var assets: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("ROCKET FAIL: ", message)

func _wait_scene(needle: String, cap: int) -> Node:
	for i in cap:
		var scene := current_scene
		if scene != null and scene.scene_file_path.contains(needle):
			return scene
		await process_frame
	return null

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _settle() -> void:
	var router := root.get_node("SceneRouter")
	for i in 900:
		if not bool(router.transitioning):
			return
		await process_frame

func _run() -> void:
	await _frames(5)
	gs = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if gs == null or assets == null:
		_fail("autoloads missing")
		quit(1)
		return

	gs.data["trainer_id"] = "kai"
	gs.data["trainer_name"] = "Rocket Tester"
	gs.data["starter_id"] = "pikachu"
	gs.data["active_pokemon"] = "pikachu"
	gs.data["unlocked"] = ["pikachu"]
	gs.data["regular_matches_completed"] = 2
	gs.data["regular_wins"] = 1
	gs.data["rocket_pending"] = true
	gs.data["rocket_events_completed"] = 0
	gs.data["rocket_wins"] = 0
	gs.data["rocket_badges"] = 0
	gs.data["location"] = gs.LOCATION_ARENA
	gs.has_save = true

	var arena := (load("res://scenes/arenas/battle_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	current_scene = arena
	print("ROCKET: arena open, pending=", gs.rocket_pending())

	var intro := await _wait_scene("rocket_intro", 60 * 20)
	if intro == null:
		_fail("arena did not auto-cue the Team Rocket cinematic")
		print("ROCKET DONE: ", failures.size(), " failure(s)")
		quit(1)
		return
	print("ROCKET: cinematic open, lines=", intro.get("_lines").size())
	await _settle()
	intro._skip_to_end()
	await _frames(5)
	if gs.pending_battle.is_empty():
		_fail("cinematic consumed pending_battle")
	intro._begin_battle()

	var battle := await _wait_scene("battle_scene", 60 * 20)
	if battle == null:
		_fail("cinematic did not hand off to the battle")
	else:
		for i in 60 * 40:
			if not bool(battle.get("_busy")):
				break
			await process_frame
		if not bool(battle.get("rocket")):
			_fail("rocket battle lost its rocket flag")
		print("ROCKET: battle vs ", battle.sim.enemy.display_name(), " rocket=", battle.get("rocket"))
		if not str(battle.sim.enemy.display_name()).begins_with("Shadow"):
			_fail("rocket enemy is not a shadow variant")
		# Force a quick win to exercise the reward path.
		battle.sim.enemy.hp = 1
		var choice := -1
		for i in battle.sim.player.pp.size():
			if battle.sim.player.pp[i] > 0:
				choice = i
				break
		if choice < 0:
			_fail("player has no usable move")
		else:
			battle._on_move_pressed(choice)
			for i in 60 * 30:
				if bool(battle.get("_ended")):
					break
				await process_frame
			if not bool(battle.get("_ended")):
				_fail("rocket battle never ended")
			else:
				print("ROCKET: result winner=", battle.sim.winner,
					", events_done=", gs.rocket_events_completed(),
					", pending=", gs.rocket_pending(),
					", badges=", gs.rocket_badges())
				if gs.rocket_events_completed() != 1:
					_fail("rocket_events_completed did not increment")
				if gs.rocket_pending():
					_fail("rocket_pending stayed true after the event")
				if battle.sim.winner == "player" and gs.rocket_badges() != 1:
					_fail("rocket win did not award a badge")

	print("ROCKET DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
