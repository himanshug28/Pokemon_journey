extends Node
## Persistent player profile, progression, unlocks, settings and battle bookkeeping.

signal state_changed
signal progression_changed
signal pokemon_unlocked(pokemon_id: String)
signal save_written
signal settings_applied

const SAVE_PATH := "user://pokemon_journey_save.json"
const BACKUP_PATH := "user://pokemon_journey_save.backup.json"
const SAVE_VERSION := 2
const POKEMON_ORDER: Array[String] = ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]
const STARTERS: Array[String] = ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]
const LOCATION_PLAYGROUND := "playground"
const LOCATION_ARENA := "arena"
const SCENE_PLAYGROUND := "res://scenes/arenas/stadium_playground.tscn"
const SCENE_ARENA := "res://scenes/arenas/battle_arena.tscn"
const SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"

var data: Dictionary = {}
var has_save := false
var last_save_error := ""
var pending_flow := "new" # "new" or "change"
var pending_battle: Dictionary = {}
var return_scene := SCENE_ARENA
var ui_context: Dictionary = {}

func _ready() -> void:
	_setup_input()
	load_game()
	_apply_fullscreen()
	# AudioManager reads these values once its own _ready runs.

func _default_data() -> Dictionary:
	var xp := {}
	for id in POKEMON_ORDER:
		xp[id] = 0
	return {
		"version": SAVE_VERSION,
		"trainer_id": "",
		"trainer_name": "",
		"starter_id": "",
		"unlocked": [],
		"active_pokemon": "",
		"xp": xp,
		"regular_matches_completed": 0,
		"regular_wins": 0,
		"rocket_pending": false,
		"rocket_events_completed": 0,
		"rocket_wins": 0,
		"rocket_badges": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"current_location": LOCATION_PLAYGROUND,
		"settings": {
			"music": 0.62,
			"sfx": 0.8,
			"fullscreen": false,
			"camera_sensitivity": 0.0024,
		},
		"tutorial_seen": false,
		"playground_tip_seen": false,
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
	}

func _setup_input() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("interact", [KEY_E, KEY_ENTER])
	_add_action("pause_game", [KEY_ESCAPE])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("battle_move_1", [KEY_1])
	_add_action("battle_move_2", [KEY_2])
	_add_action("battle_move_3", [KEY_3])
	_add_action("battle_move_4", [KEY_4])

func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	var joy := InputEventJoypadButton.new()
	match action:
		"jump":
			joy.button_index = JOY_BUTTON_A
		"interact":
			joy.button_index = JOY_BUTTON_X
		"pause_game":
			joy.button_index = JOY_BUTTON_START
		_:
			return
	InputMap.action_add_event(action, joy)

# ------------------------------------------------------------------ save / load

func load_game() -> bool:
	data = _default_data()
	has_save = false
	last_save_error = ""
	var loaded := _read_json(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read_json(BACKUP_PATH)
	if loaded.is_empty():
		_reconcile_rocket_state()
		return false
	_merge_defaults(loaded)
	data = loaded
	_normalize_loaded_data()
	has_save = str(data.get("trainer_id", "")) != ""
	_reconcile_rocket_state()
	state_changed.emit()
	return has_save

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_save_error = "Could not open %s" % path
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_save_error = "Save file is not valid JSON."
		return {}
	return parsed

func _merge_defaults(source: Dictionary) -> void:
	var defaults := _default_data()
	for key in defaults:
		if not source.has(key):
			source[key] = defaults[key]
		elif typeof(defaults[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			var nested: Dictionary = source[key]
			var nested_defaults: Dictionary = defaults[key]
			for nested_key in nested_defaults:
				if not nested.has(nested_key):
					nested[nested_key] = nested_defaults[nested_key]
			source[key] = nested
	var xp: Dictionary = source.get("xp", {})
	for id in POKEMON_ORDER:
		if not xp.has(id):
			xp[id] = 0
	source["xp"] = xp

func _normalize_loaded_data() -> void:
	var unlocked: Array = data.get("unlocked", [])
	var clean: Array[String] = []
	for id in unlocked:
		if str(id) in POKEMON_ORDER and not clean.has(str(id)):
			clean.append(str(id))
	var starter := str(data.get("starter_id", ""))
	if starter != "" and not clean.has(starter):
		clean.append(starter)
	data["unlocked"] = clean
	if starter == "" and clean.size() > 0:
		data["starter_id"] = clean[0]
	var active := str(data.get("active_pokemon", ""))
	if active == "" or not clean.has(active):
		data["active_pokemon"] = starter if starter != "" else (clean[0] if clean.size() > 0 else "")
	data["regular_matches_completed"] = maxi(0, int(data.get("regular_matches_completed", 0)))
	data["regular_wins"] = maxi(0, int(data.get("regular_wins", 0)))
	data["rocket_events_completed"] = maxi(0, int(data.get("rocket_events_completed", 0)))
	data["rocket_wins"] = maxi(0, int(data.get("rocket_wins", 0)))
	data["rocket_badges"] = maxi(0, int(data.get("rocket_badges", 0)))
	data["version"] = SAVE_VERSION

func _reconcile_rocket_state() -> void:
	var completed := int(data.get("regular_matches_completed", 0))
	var events_done := int(data.get("rocket_events_completed", 0))
	var due := completed >= 2 and completed % 2 == 0 and events_done < int(completed / 2)
	data["rocket_pending"] = due

func save_game() -> bool:
	if str(data.get("trainer_id", "")) == "":
		return false
	data["updated_at"] = Time.get_datetime_string_from_system()
	data["version"] = SAVE_VERSION
	if FileAccess.file_exists(SAVE_PATH):
		var existing := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if existing != null:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(existing.get_as_text())
				backup.close()
			existing.close()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_save_error = "Could not write save file (error %s)." % FileAccess.get_open_error()
		push_warning(last_save_error)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	has_save = true
	save_written.emit()
	return true

func reset_journey() -> void:
	data = _default_data()
	has_save = false
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state_changed.emit()
	progression_changed.emit()

func delete_save() -> void:
	reset_journey()

# ------------------------------------------------------------------ profile

func set_trainer(trainer_id: String, trainer_name: String) -> void:
	data["trainer_id"] = trainer_id
	data["trainer_name"] = trainer_name
	has_save = true
	save_game()
	state_changed.emit()

func trainer_id() -> String:
	return str(data.get("trainer_id", ""))

func trainer_name() -> String:
	return str(data.get("trainer_name", "Trainer"))

func starter_id() -> String:
	return str(data.get("starter_id", ""))

func choose_starter(pokemon_id: String) -> void:
	if not pokemon_id in STARTERS:
		return
	data["starter_id"] = pokemon_id
	data["active_pokemon"] = pokemon_id
	var unlocked: Array = data.get("unlocked", [])
	if not unlocked.has(pokemon_id):
		unlocked.append(pokemon_id)
	data["unlocked"] = unlocked
	data["current_location"] = LOCATION_PLAYGROUND
	save_game()
	state_changed.emit()
	progression_changed.emit()

func active_pokemon() -> String:
	var active := str(data.get("active_pokemon", ""))
	if active == "":
		var unlocked := unlocked_pokemon()
		return unlocked[0] if unlocked.size() > 0 else ""
	return active

func set_active_pokemon(pokemon_id: String) -> bool:
	if not is_unlocked(pokemon_id):
		return false
	data["active_pokemon"] = pokemon_id
	save_game()
	state_changed.emit()
	return true

func unlocked_pokemon() -> Array[String]:
	var result: Array[String] = []
	for id in POKEMON_ORDER:
		if is_unlocked(id):
			result.append(id)
	return result

func is_unlocked(pokemon_id: String) -> bool:
	var unlocked: Array = data.get("unlocked", [])
	return str(pokemon_id) in unlocked

func get_xp(pokemon_id: String) -> int:
	var xp: Dictionary = data.get("xp", {})
	return int(xp.get(pokemon_id, 0))

func level_for_xp(xp: int) -> int:
	var level := 5
	var remaining := maxi(0, xp)
	var need := _xp_needed_for_level(level)
	while remaining >= need and level < 100:
		remaining -= need
		level += 1
		need = _xp_needed_for_level(level)
	return level

func _xp_needed_for_level(level: int) -> int:
	return 70 + level * 28

func xp_progress(pokemon_id: String) -> Dictionary:
	var xp := get_xp(pokemon_id)
	var level := level_for_xp(xp)
	var consumed := 0
	for l in range(5, level):
		consumed += _xp_needed_for_level(l)
	var need := _xp_needed_for_level(level)
	return {
		"level": level,
		"xp": xp,
		"current": xp - consumed,
		"needed": need,
		"ratio": float(xp - consumed) / float(need),
	}

func add_xp(pokemon_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return {"old_level": level_for_xp(get_xp(pokemon_id)), "new_level": level_for_xp(get_xp(pokemon_id)), "levels": 0, "xp": get_xp(pokemon_id)}
	var old_level := level_for_xp(get_xp(pokemon_id))
	var xp: Dictionary = data.get("xp", {})
	xp[pokemon_id] = int(xp.get(pokemon_id, 0)) + amount
	data["xp"] = xp
	var new_level := level_for_xp(int(xp[pokemon_id]))
	return {
		"old_level": old_level,
		"new_level": new_level,
		"levels": maxi(0, new_level - old_level),
		"xp": int(xp[pokemon_id]),
		"amount": amount,
	}

func check_unlocks() -> Array[String]:
	var newly: Array[String] = []
	var unlocked: Array = data.get("unlocked", [])
	for id in POKEMON_ORDER:
		if unlocked.has(id):
			continue
		var species: PokemonData = AssetLibrary.get_pokemon(id)
		if species != null and species.is_unlocked(regular_wins(), rocket_wins()):
			unlocked.append(id)
			newly.append(id)
	data["unlocked"] = unlocked
	if newly.size() > 0:
		progression_changed.emit()
		for id in newly:
			pokemon_unlocked.emit(id)
		save_game()
	return newly

func regular_wins() -> int:
	return int(data.get("regular_wins", 0))

func regular_matches_completed() -> int:
	return int(data.get("regular_matches_completed", 0))

func rocket_wins() -> int:
	return int(data.get("rocket_wins", 0))

func rocket_events_completed() -> int:
	return int(data.get("rocket_events_completed", 0))

func rocket_badges() -> int:
	return int(data.get("rocket_badges", 0))

func rocket_pending() -> bool:
	return bool(data.get("rocket_pending", false))

func matches_until_rocket() -> int:
	if rocket_pending():
		return 0
	var completed := regular_matches_completed()
	var next_threshold := (int(completed / 2) + 1) * 2
	return maxi(1, next_threshold - completed)

func record_battle(result: Dictionary) -> Dictionary:
	## result: {won, rocket, opponent_level, xp, opponent_name, active_id}
	var won := bool(result.get("won", false))
	var rocket := bool(result.get("rocket", false))
	var active_id := str(result.get("active_id", active_pokemon()))
	var xp_amount := int(result.get("xp", 0))
	var summary := {
		"won": won,
		"rocket": rocket,
		"xp": 0,
		"level_up": {},
		"unlocked": [],
		"rocket_pending": false,
		"badges": 0,
	}
	if won:
		data["battles_won"] = int(data.get("battles_won", 0)) + 1
	else:
		data["battles_lost"] = int(data.get("battles_lost", 0)) + 1

	if rocket:
		data["rocket_events_completed"] = rocket_events_completed() + 1
		data["rocket_pending"] = false
		if won:
			data["rocket_wins"] = rocket_wins() + 1
			data["rocket_badges"] = rocket_badges() + 1
			summary["badges"] = 1
	else:
		data["regular_matches_completed"] = regular_matches_completed() + 1
		if won:
			data["regular_wins"] = regular_wins() + 1
		# A Rocket event is due after every two completed regular matches.
		var completed := regular_matches_completed()
		var events_done := rocket_events_completed()
		if completed >= 2 and completed % 2 == 0 and events_done < int(completed / 2):
			data["rocket_pending"] = true

	if xp_amount > 0 and active_id != "":
		var level_result := add_xp(active_id, xp_amount)
		summary["xp"] = xp_amount
		summary["level_up"] = level_result

	if won:
		summary["unlocked"] = check_unlocks()
	else:
		# Losses do not grant unlocks, but a completed match can still arm a Rocket event.
		pass
	summary["rocket_pending"] = rocket_pending()
	save_game()
	progression_changed.emit()
	state_changed.emit()
	return summary

# ------------------------------------------------------------------ locations/settings

func current_location() -> String:
	return str(data.get("current_location", LOCATION_PLAYGROUND))

func set_location(location: String) -> void:
	if location != LOCATION_PLAYGROUND and location != LOCATION_ARENA:
		return
	data["current_location"] = location
	save_game()
	state_changed.emit()

func location_scene(location: String) -> String:
	return SCENE_ARENA if location == LOCATION_ARENA else SCENE_PLAYGROUND

func current_location_scene() -> String:
	return location_scene(current_location())

func settings() -> Dictionary:
	return data.get("settings", {})

func get_setting(key: String, fallback = null):
	var s: Dictionary = data.get("settings", {})
	return s.get(key, fallback)

func set_setting(key: String, value) -> void:
	var s: Dictionary = data.get("settings", {})
	s[key] = value
	data["settings"] = s
	save_game()
	settings_applied.emit()

func apply_settings() -> void:
	_apply_fullscreen()
	settings_applied.emit()

func _apply_fullscreen() -> void:
	var fullscreen := bool(get_setting("fullscreen", false))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func mark_tutorial_seen() -> void:
	data["tutorial_seen"] = true
	save_game()

func tutorial_seen() -> bool:
	return bool(data.get("tutorial_seen", false))

func set_playground_tip_seen() -> void:
	data["playground_tip_seen"] = true
	save_game()

func playground_tip_seen() -> bool:
	return bool(data.get("playground_tip_seen", false))

func summary_line() -> String:
	if not has_save:
		return "No journey started yet"
	return "%s  •  %d wins  •  %d badges" % [trainer_name(), int(data.get("battles_won", 0)), rocket_badges()]
