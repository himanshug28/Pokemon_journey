extends SceneTree
## Headless test: run an exhibition auto-battle and verify it actually plays out.

func _init() -> void:
	var godot_path := "C:/Users/Himanshu/AppData/Local/Temp/opencode/godot47/Godot_v4.7.2-stable_win64_console.exe"
	# Run quick test via scene loading simulation
	call_deferred("_run")

func _run() -> void:
	# Simulate
	var sim := BattleSim.new()
	var p := AssetLibrary.get_pokemon("pikachu")
	var e := AssetLibrary.get_pokemon("bulbasaur")
	sim.setup(p, 10, e, 10, 12345, false, {})
	var events_all: Array = []
	var turns := 0
	while not sim.finished and turns < 50:
		var pi := sim.choose_player_move()
		var ei := sim.choose_enemy_move()
		if pi < 0 or ei < 0:
			break
		var ev := sim.take_turn(pi, ei)
		events_all.append_array(ev)
		turns += 1
	print("TURNS:", turns)
	print("FINISHED:", sim.finished)
	print("WINNER:", sim.winner)
	print("EVENTS:", events_all.size())
	quit(0 if sim.finished and turns > 0 else 1)
