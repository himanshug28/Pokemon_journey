extends SceneTree
## Headless functional test of the battle loop and Team Rocket cinematic.
## Run with:
##   godot --headless --fixed-fps 60 --path "C:\pokemon  journey" --script "res://tools/gameplay_test.gd"
## Uses fixed 60 fps so timers advance quickly and deterministically.

var game_state: Node
var assets: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("GAMEPLAY FAIL: ", message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _wait_until(instance: Object, property: String, expected: Variant, cap: int) -> bool:
	for i in cap:
		if not is_instance_valid(instance):
			return false
		if instance.get(property) == expected:
			return true
		await process_frame
	return false

func _wait_turn(instance: Object, cap: int) -> void:
	## A finished battle keeps _busy true, so stop on either idle or ended.
	for i in cap:
		if not is_instance_valid(instance):
			return
		if instance.get("_ended") or not instance.get("_busy"):
			return
		await process_frame

func _run() -> void:
	await _frames(3)
	game_state = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if game_state == null or assets == null:
		_fail("autoloads missing")
		quit(1)
		return

	game_state.data["trainer_id"] = "kai"
	game_state.data["trainer_name"] = "Smoke Tester"
	game_state.data["starter_id"] = "pikachu"
	game_state.data["active_pokemon"] = "pikachu"
	game_state.data["unlocked"] = ["pikachu", "charizard"]
	game_state.data["regular_matches_completed"] = 0
	game_state.data["rocket_pending"] = false
	game_state.has_save = true

	# ---------------------------------------------------------- battle loop
	game_state.pending_battle = {
		"rocket": false,
		"opponent": assets.get_opponent_for_match(0, 0),
		"return_scene": "res://scenes/arenas/stadium_playground.tscn",
	}
	var battle = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	print("GAMEPLAY: battle instanced, waiting for intro")
	if not await _wait_until(battle, "_busy", false, 60 * 40):
		_fail("battle intro never finished")
	else:
		print("GAMEPLAY: intro finished, player=", battle.sim.player.display_name(), " enemy=", battle.sim.enemy.display_name())
		var enemy_hp_before: int = battle.sim.enemy.hp
		var player_hp_before: int = battle.sim.player.hp
		battle._on_move_pressed(0)
		await _wait_turn(battle, 60 * 30)
		var resolved: bool = bool(battle.get("_ended")) or not bool(battle.get("_busy"))
		if not resolved:
			_fail("turn never resolved (busy stuck)")
		else:
			var enemy_hp_after: int = battle.sim.enemy.hp
			var player_hp_after: int = battle.sim.player.hp
			print("GAMEPLAY: turn resolved. enemy hp ", enemy_hp_before, " -> ", enemy_hp_after,
				", player hp ", player_hp_before, " -> ", player_hp_after,
				", ended=", battle.get("_ended"))
			if enemy_hp_after == enemy_hp_before and player_hp_after == player_hp_before and not battle.get("_ended"):
				_fail("no HP changed after a full turn")

		# Keep fighting until the battle resolves, then verify the result overlay.
		var turns := 1
		while not battle.get("_ended") and turns < 40:
			if battle.get("_busy"):
				await _wait_turn(battle, 60 * 20)
			var choice := -1
			for i in battle.sim.player.pp.size():
				if battle.sim.player.pp[i] > 0:
					choice = i
					break
			if choice < 0 or battle.get("_ended"):
				break
			battle._on_move_pressed(choice)
			turns += 1
			await _wait_turn(battle, 60 * 20)

		if not battle.get("_ended"):
			_fail("battle never reached a result after %d turns" % turns)
		else:
			# The result panel appears after a short victory/defeat beat.
			for i in 60 * 12:
				var layer: Control = battle.get("_result_layer")
				if layer != null and layer.visible:
					break
				await process_frame
			var result_layer: Control = battle.get("_result_layer")
			var summary: Dictionary = battle.get("_summary")
			print("GAMEPLAY: battle ended after ", turns, " turns, winner=", battle.sim.winner,
				", result_visible=", result_layer != null and result_layer.visible,
				", summary_keys=", summary.keys())
			if result_layer == null or not result_layer.visible:
				_fail("result overlay not shown after battle end")
			if summary.is_empty():
				_fail("battle summary was not recorded")

		battle.queue_free()
		await _frames(3)

	# ---------------------------------------------------------- rocket intro
	game_state.pending_battle = {
		"rocket": true,
		"opponent": assets.get_rocket_opponent(0, 2),
		"return_scene": "res://scenes/arenas/battle_arena.tscn",
	}
	var intro = (load("res://scenes/battle/rocket_intro.tscn") as PackedScene).instantiate()
	root.add_child(intro)
	await _frames(20)
	intro._skip_to_end()
	await _frames(5)
	var button: Button = intro.get("_battle_button")
	if button == null or not button.visible:
		_fail("rocket intro did not reveal the Begin Battle button")
	else:
		print("GAMEPLAY: rocket intro skip-to-end ok, lines=", intro.get("_lines").size())
	if game_state.pending_battle.is_empty():
		_fail("rocket intro consumed pending_battle (battle scene would get a random opponent)")
	else:
		print("GAMEPLAY: pending_battle preserved for battle scene")
	intro.queue_free()
	await _frames(3)

	# ---------------------------------------------------------- rocket battle
	game_state.pending_battle = {
		"rocket": true,
		"opponent": assets.get_rocket_opponent(0, 2),
		"return_scene": "res://scenes/arenas/battle_arena.tscn",
	}
	var rocket_battle = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	root.add_child(rocket_battle)
	if not await _wait_until(rocket_battle, "_busy", false, 60 * 40):
		_fail("rocket battle intro never finished")
	else:
		print("GAMEPLAY: rocket battle ready, enemy=", rocket_battle.sim.enemy.display_name(),
			", rocket=", rocket_battle.get("rocket"))
		if not rocket_battle.get("rocket"):
			_fail("rocket battle lost its rocket flag")
	rocket_battle.queue_free()
	await _frames(3)

	print("GAMEPLAY DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
