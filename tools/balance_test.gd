extends SceneTree
## Balance probe: simulates many AI-vs-AI battles for each starter/first-opponent pair.
## Run: godot --headless --path "C:\pokemon  journey" --script "res://tools/balance_test.gd"

var assets: Node

func _initialize() -> void:
	call_deferred("_run")

func _best_move(sim: BattleSim, for_player: bool) -> int:
	var attacker = sim.player if for_player else sim.enemy
	var defender = sim.enemy if for_player else sim.player
	var options: Array[int] = attacker.available_moves()
	if options.is_empty():
		return -1
	var best: int = options[0]
	var best_score := -999.0
	for index in options:
		var move: MoveData = attacker.moves[index]
		var score := 0.0
		if move.power > 0:
			var effectiveness := TypeChart.effectiveness(move.poke_type, defender.data.types())
			var stab := 1.35 if move.poke_type in attacker.data.types() else 1.0
			score = float(move.power) * effectiveness * stab * (float(move.accuracy) / 100.0)
		elif move.effect == "heal":
			score = 55.0 * (1.0 - attacker.hp_ratio())
		elif move.effect == "paralyze" or move.effect == "poison" or move.effect == "burn":
			score = 30.0 if not defender.has_status() else 5.0
		if score > best_score:
			best_score = score
			best = index
	return best

func _simulate(player_id: String, enemy_id: String, player_level: int, enemy_level: int, seed_value: int) -> bool:
	var sim := BattleSim.new()
	sim.setup(assets.get_pokemon(player_id), player_level, assets.get_pokemon(enemy_id), enemy_level, seed_value)
	var guard := 0
	while not sim.finished and guard < 200:
		guard += 1
		var p := _best_move(sim, true)
		var e := _best_move(sim, false)
		if p < 0 and e < 0:
			break
		sim.take_turn(p, e)
	return sim.winner == "player"

func _run() -> void:
	await process_frame
	assets = root.get_node_or_null("AssetLibrary")
	if assets == null:
		print("BALANCE FAIL: AssetLibrary missing")
		quit(1)
		return
	var starters := ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]
	var opponents := {"ben": "bulbasaur", "maya": "squirtle", "rin": "pikachu", "leo": "charizard", "nyx": "gengar", "gale": "charizard"}
	for starter in starters:
		for enemy_level in [4, 3]:
			var line := "BALANCE %-10s L5 vs L%d:" % [starter, enemy_level]
			for key in opponents:
				var wins := 0
				for s in 80:
					if _simulate(starter, opponents[key], 5, enemy_level, 1000 + s * 7):
						wins += 1
				line += "  %s=%d%%" % [key, int(round(100.0 * wins / 80.0))]
			print(line)
	print("BALANCE DONE")
	quit(0)
