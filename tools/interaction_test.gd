extends SceneTree
## Interaction test: exercises every Interactable callback in both worlds through the
## same path the player uses (Interactable.interact(player)).
##
## This covers the Callable arity/binding bugs where a callback received the player
## object in the slot of an opponent id, or received an argument it does not declare.
##
## Run:
##   godot --headless --fixed-fps 60 --path "C:\pokemon  journey" --script "res://tools/interaction_test.gd"
## This writes to the normal save slot; restore your save afterwards.

var gs: Node
var assets: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("INTERACT FAIL: ", message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _settle() -> void:
	var router := root.get_node("SceneRouter")
	for i in 900:
		if not bool(router.transitioning):
			return
		await process_frame

func _wait_scene(needle: String, cap: int) -> Node:
	for i in cap:
		var scene := current_scene
		if scene != null and scene.scene_file_path.contains(needle):
			return scene
		await process_frame
	return null

func _find(scene: Node, title: String) -> Interactable:
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var interact := node as Interactable
		if interact != null and interact.title == title:
			return interact
		for child in node.get_children():
			stack.append(child)
	return null

func _use(scene: Node, title: String) -> bool:
	var interact := _find(scene, title)
	if interact == null:
		_fail("interactable not found: " + title)
		return false
	var player: Node = scene.get("player")
	if player == null:
		_fail("scene has no player for interaction: " + title)
		return false
	interact.interact(player)
	print("INTERACT: used ", title)
	return true

func _run() -> void:
	await _frames(5)
	gs = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if gs == null or assets == null:
		_fail("autoloads missing")
		quit(1)
		return

	gs.data["trainer_id"] = "kai"
	gs.data["trainer_name"] = "Interact Tester"
	gs.data["starter_id"] = "pikachu"
	gs.data["active_pokemon"] = "pikachu"
	gs.data["unlocked"] = ["pikachu", "bulbasaur"]
	gs.data["regular_matches_completed"] = 0
	gs.data["regular_wins"] = 0
	gs.data["rocket_pending"] = false
	gs.has_save = true

	# ---------------------------------------------------------- playground
	await root.get_node("SceneRouter").goto(gs.SCENE_PLAYGROUND, 0.05, "PLAYGROUND")
	var playground := await _wait_scene("stadium_playground", 60 * 15)
	if playground == null:
		_fail("could not open the playground")
		quit(1)
		return
	await _settle()
	await _frames(60)

	# Zero-argument callbacks (these used to raise "Expected 0 argument(s)").
	_use(playground, "Pet Pikachu")
	await _frames(10)
	_use(playground, "Training Tips")
	await _frames(10)
	_use(playground, "Rest Tent")
	await _frames(10)
	if not gs.pending_battle.is_empty():
		_fail("a non-battle interaction queued a battle")

	# Poké PC navigates to the collection and back.
	if _use(playground, "Poké PC"):
		var collection := await _wait_scene("collection", 60 * 12)
		if collection == null:
			_fail("Poké PC did not open the collection")
		else:
			print("INTERACT: Poké PC opened the collection")
			await _settle()
			await root.get_node("SceneRouter").goto(gs.SCENE_PLAYGROUND, 0.05, "BACK")
			playground = await _wait_scene("stadium_playground", 60 * 15)
			if playground == null:
				_fail("could not return to the playground")
				quit(1)
				return
			await _settle()
			await _frames(60)

	# NPC challenge: bound-id callback (the reported crash).
	if _use(playground, "Youngster Ben"):
		var battle := await _wait_scene("battle_scene", 60 * 15)
		if battle == null:
			_fail("NPC challenge did not open the battle scene")
		else:
			for i in 60 * 40:
				if not bool(battle.get("_busy")):
					break
				await process_frame
			var opponent: Dictionary = battle.get("opponent")
			print("INTERACT: playground battle vs ", battle.sim.enemy.display_name(),
				" opponent=", str(opponent.get("name", "?")),
				" rocket=", battle.get("rocket"))
			if str(opponent.get("name", "")) != "Youngster Ben":
				_fail("battle used the wrong opponent: " + str(opponent.get("name", "")))
			if bool(battle.get("rocket")):
				_fail("a regular NPC challenge started a Rocket battle")
			battle.queue_free()
			await _frames(5)

	# Gate travel back to a fresh playground, then into the arena.
	await root.get_node("SceneRouter").goto(gs.SCENE_PLAYGROUND, 0.05, "PLAYGROUND")
	playground = await _wait_scene("stadium_playground", 60 * 15)
	if playground == null:
		_fail("could not reopen the playground")
		quit(1)
		return
	await _settle()
	await _frames(60)
	if _use(playground, "Battle Arena Gate"):
		var arena := await _wait_scene("battle_arena", 60 * 15)
		if arena == null:
			_fail("the playground gate did not travel to the arena")
			print("INTERACT DONE: ", failures.size(), " failure(s)")
			quit(1)
			return
		print("INTERACT: gate travel reached the arena")
		await _settle()
		await _frames(90)

		# ---------------------------------------------------------- arena
		_use(arena, "Pet Pikachu")
		await _frames(10)
		_use(arena, "Arena Announcer")
		await _frames(10)

		if _use(arena, "Camper Maya"):
			var arena_battle := await _wait_scene("battle_scene", 60 * 15)
			if arena_battle == null:
				_fail("arena challenge did not open the battle scene")
			else:
				for i in 60 * 40:
					if not bool(arena_battle.get("_busy")):
						break
					await process_frame
				var arena_opponent: Dictionary = arena_battle.get("opponent")
				print("INTERACT: arena battle vs ", arena_battle.sim.enemy.display_name(),
					" opponent=", str(arena_opponent.get("name", "?")))
				if str(arena_opponent.get("name", "")) != "Camper Maya":
					_fail("arena battle used the wrong opponent: " + str(arena_opponent.get("name", "")))
				arena_battle.queue_free()
				await _frames(5)

	print("INTERACT DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
