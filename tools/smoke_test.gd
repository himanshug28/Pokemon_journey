extends SceneTree
## Headless smoke test: instantiates every core scene and reports runtime failures.
## Run with:
##   godot --headless --path "C:\pokemon  journey" --script "res://tools/smoke_test.gd"
## Autoloads are resolved through the scene tree because --script mode does not
## expose them as global identifiers at compile time.

const SCENES: Array[String] = [
	"res://scenes/ui/loading_screen.tscn",
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/trainer_select.tscn",
	"res://scenes/ui/starter_select.tscn",
	"res://scenes/ui/collection.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/arenas_screen.tscn",
	"res://scenes/arenas/stadium_playground.tscn",
	"res://scenes/arenas/battle_arena.tscn",
	"res://scenes/battle/battle_scene.tscn",
	"res://scenes/battle/rocket_intro.tscn",
]

var game_state: Node
var assets: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("SMOKE FAIL: ", message)

func _run() -> void:
	await process_frame
	await process_frame
	await process_frame

	game_state = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if game_state == null:
		_fail("GameState autoload missing")
		quit(1)
		return
	if assets == null:
		_fail("AssetLibrary autoload missing")
		quit(1)
		return

	print("SMOKE: GameState ok, species=", assets.pokemon.size())

	# Seed a deterministic in-memory journey so scenes do not redirect to menus.
	game_state.data["trainer_id"] = "kai"
	game_state.data["trainer_name"] = "Smoke Tester"
	game_state.data["starter_id"] = "pikachu"
	game_state.data["active_pokemon"] = "pikachu"
	game_state.data["unlocked"] = ["pikachu", "charizard"]
	game_state.data["regular_matches_completed"] = 0
	game_state.data["rocket_pending"] = false
	game_state.has_save = true

	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("could not load " + path)
			continue

		game_state.pending_battle = {}
		if path.contains("battle_scene"):
			game_state.pending_battle = {
				"rocket": false,
				"opponent": assets.get_opponent_for_match(0, 0),
				"return_scene": "res://scenes/arenas/stadium_playground.tscn",
			}
		elif path.contains("rocket_intro"):
			game_state.pending_battle = {
				"rocket": true,
				"opponent": assets.get_rocket_opponent(0, 2),
				"return_scene": "res://scenes/arenas/battle_arena.tscn",
			}

		var instance := packed.instantiate()
		if instance == null:
			_fail("could not instantiate " + path)
			continue

		root.add_child(instance)
		for i in 60:
			await process_frame

		if not is_instance_valid(instance):
			_fail("scene freed itself unexpectedly: " + path)
		else:
			print("SMOKE OK: ", path)
			instance.queue_free()
		await process_frame
		await process_frame

	print("SMOKE DONE: ", failures.size(), " failure(s)")
	quit(0 if failures.is_empty() else 1)
