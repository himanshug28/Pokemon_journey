extends SceneTree
## One-turn regression check for symmetric damage and both on-screen HP bars.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("DAMAGE FAIL: ", message)

func _run() -> void:
	for i in 5:
		await process_frame
	var game_state = root.get_node_or_null("GameState")
	var assets = root.get_node_or_null("AssetLibrary")
	if game_state == null or assets == null:
		_fail("autoloads missing")
		quit(1)
		return

	# Seed only in-memory state; one turn is not allowed to finish or save a battle.
	game_state.data["trainer_id"] = "kai"
	game_state.data["trainer_name"] = "Damage Tester"
	game_state.data["active_pokemon"] = "pikachu"
	game_state.data["starter_id"] = "pikachu"
	game_state.data["unlocked"] = ["pikachu"]
	game_state.has_save = true
	game_state.pending_battle = {
		"rocket": false,
		"opponent": assets.get_opponent_by_id("maya", 0, 0),
		"return_scene": "res://scenes/arenas/stadium_playground.tscn",
	}

	var battle = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var intro_ready := false
	for i in 60 * 40:
		if not bool(battle.get("_busy")):
			intro_ready = true
			break
		await process_frame
	if not intro_ready:
		_fail("battle intro did not finish")
		battle.queue_free()
		quit(1)
		return

	# Lock the opponent to a guaranteed damaging move so this checks both attack directions.
	for i in range(1, battle.sim.enemy.pp.size()):
		battle.sim.enemy.pp[i] = 0
	var enemy_before: int = battle.sim.enemy.hp
	var player_before: int = battle.sim.player.hp
	battle._on_move_pressed(1)
	var turn_ready := false
	for i in 60 * 20:
		if not bool(battle.get("_busy")) or bool(battle.get("_ended")):
			turn_ready = true
			break
		await process_frame
	if not turn_ready:
		_fail("first turn did not resolve")
	else:
		if battle.sim.enemy.hp >= enemy_before:
			_fail("player's selected move did not reduce opponent HP")
		if battle.sim.player.hp >= player_before:
			_fail("opponent's move did not reduce player HP")
		if not is_equal_approx(battle._enemy_hp.value, float(battle.sim.enemy.hp)):
			_fail("opponent health bar value is out of sync")
		if not is_equal_approx(battle._player_hp.value, float(battle.sim.player.hp)):
			_fail("player health bar value is out of sync")
		if battle._enemy_hp_value.text != "%d / %d HP" % [battle.sim.enemy.hp, battle.sim.enemy.max_hp]:
			_fail("opponent HP text is out of sync")
		if battle._player_hp_value.text != "%d / %d HP" % [battle.sim.player.hp, battle.sim.player.max_hp]:
			_fail("player HP text is out of sync")

	battle.queue_free()
	await process_frame
	print("DAMAGE DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
