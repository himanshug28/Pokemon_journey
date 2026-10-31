extends SceneTree
## Diagnostic probe for the arena: captures several frames and reports camera/light state.

const OUT := "C:/Users/Himanshu/AppData/Local/Temp/opencode/shots"

var game_state: Node
var assets: Node

func _initialize() -> void:
	call_deferred("_run")

func _avg_luma(image: Image) -> float:
	var total := 0.0
	var count := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / maxf(1.0, float(count))

func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	image.save_png(path)
	print("PROBE SHOT ", name, " avg_luma=", snappedf(_avg_luma(image), 0.1))

func _run() -> void:
	for i in 5:
		await process_frame
	game_state = root.get_node_or_null("GameState")
	assets = root.get_node_or_null("AssetLibrary")
	game_state.data["trainer_id"] = "kai"
	game_state.data["trainer_name"] = "Ash"
	game_state.data["starter_id"] = "pikachu"
	game_state.data["active_pokemon"] = "pikachu"
	game_state.data["unlocked"] = ["pikachu"]
	game_state.has_save = true

	var arena = (load("res://scenes/arenas/battle_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	for i in 30:
		await process_frame
	_shot("probe_arena_30")

	var player = arena.get("player")
	var cam: Camera3D = player.get_camera() if player != null else null
	if cam != null:
		print("PROBE camera pos=", cam.global_position, " rot=", cam.global_rotation_degrees, " fov=", cam.fov)
	if player != null:
		print("PROBE player pos=", player.global_position, " pivot=", player.camera_pivot.global_position)

	var lights := 0
	for child in arena.get_children():
		if child is Light3D:
			lights += 1
			print("PROBE light ", child.get_class(), " pos=", child.position, " energy=", child.light_energy)
	print("PROBE direct light count=", lights)

	for i in 120:
		await process_frame
	_shot("probe_arena_150")

	# Free-camera vantage: look at the bowl from the gate, ignoring the player rig.
	var free_cam := Camera3D.new()
	arena.add_child(free_cam)
	free_cam.global_position = Vector3(0, 7.0, 26.0)
	free_cam.look_at(Vector3(0, 2.0, 0), Vector3.UP)
	free_cam.fov = 65.0
	free_cam.current = true
	for i in 30:
		await process_frame
	_shot("probe_arena_freecam")

	# Hide the player + companion to check occlusion.
	if player != null:
		player.visible = false
	var companion_root = arena.get("companion_root")
	if companion_root != null:
		companion_root.visible = false
	for i in 20:
		await process_frame
	_shot("probe_arena_noplayer")

	print("PROBE DONE")
	quit(0)
