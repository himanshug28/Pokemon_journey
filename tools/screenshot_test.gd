extends SceneTree
## Captures real rendered screenshots of key scenes so the visual result can be
## checked without playing manually. Run windowed (not headless):
##   godot --path "C:\pokemon  journey" --fixed-fps 60 --script "res://tools/screenshot_test.gd"
## Images are written to the temp folder; the game quits when done.

const OUT_DIR := "C:/Users/Himanshu/AppData/Local/Temp/opencode/shots"

var game_state: Node
var assets: Node

const SHOTS := [
	{"name": "main_menu", "path": "res://scenes/ui/main_menu.tscn", "frames": 150, "menu": true},
	{"name": "playground", "path": "res://scenes/arenas/stadium_playground.tscn", "frames": 150, "menu": false},
	{"name": "arena", "path": "res://scenes/arenas/battle_arena.tscn", "frames": 150, "menu": false},
	{"name": "battle", "path": "res://scenes/battle/battle_scene.tscn", "frames": 300, "menu": false, "battle": true},
	{"name": "rocket_intro", "path": "res://scenes/battle/rocket_intro.tscn", "frames": 120, "menu": false, "rocket": true},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for i in 5:
		await process_frame
	game_state = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	if game_state == null or assets == null:
		print("SHOT FAIL: autoloads missing")
		quit(1)
		return

	game_state.data["trainer_id"] = "kai"
	game_state.data["trainer_name"] = "Ash"
	game_state.data["starter_id"] = "pikachu"
	game_state.data["active_pokemon"] = "pikachu"
	game_state.data["unlocked"] = ["pikachu", "charizard", "bulbasaur"]
	game_state.data["regular_matches_completed"] = 0
	game_state.data["rocket_pending"] = false
	game_state.has_save = true

	for shot in SHOTS:
		var path := str(shot["path"])
		var packed := load(path) as PackedScene
		if packed == null:
			print("SHOT FAIL load: ", path)
			continue
		game_state.pending_battle = {}
		if bool(shot.get("battle", false)):
			game_state.pending_battle = {
				"rocket": false,
				"opponent": assets.get_opponent_for_match(0, 0),
				"return_scene": "res://scenes/arenas/stadium_playground.tscn",
			}
		elif bool(shot.get("rocket", false)):
			game_state.pending_battle = {
				"rocket": true,
				"opponent": assets.get_rocket_opponent(0, 2),
				"return_scene": "res://scenes/arenas/battle_arena.tscn",
			}
		var instance := packed.instantiate()
		root.add_child(instance)
		for i in int(shot["frames"]):
			await process_frame
		var image := root.get_texture().get_image()
		var out_path := "%s/%s.png" % [OUT_DIR, str(shot["name"])]
		var err := image.save_png(out_path)
		print("SHOT: ", shot["name"], " -> ", out_path, " err=", err)
		instance.queue_free()
		for i in 5:
			await process_frame
	print("SHOT DONE")
	quit(0)
