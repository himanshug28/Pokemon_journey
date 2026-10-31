extends Node
## Central registry for species resources, move resources, trainers and opponents.

const POKEMON_IDS: Array[String] = ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]
const POKEMON_PATHS := {
	"charizard": "res://data/pokemon/charizard.tres",
	"bulbasaur": "res://data/pokemon/bulbasaur.tres",
	"gengar": "res://data/pokemon/gengar.tres",
	"pikachu": "res://data/pokemon/pikachu.tres",
	"squirtle": "res://data/pokemon/squirtle.tres",
}
const MOVE_IDS: Array[String] = [
	"flamethrower", "air_slash", "fire_fang", "slash",
	"vine_whip", "razor_leaf", "sludge", "synthesis",
	"shadow_ball", "sludge_bomb", "dark_pulse", "lick",
	"thunderbolt", "quick_attack", "electro_ball", "thunder_wave",
	"water_gun", "surf", "bite", "withdraw",
]

var pokemon: Dictionary = {}
var moves: Dictionary = {}
var trainers: Array = []
var opponents: Array = []
var rocket_opponents: Array = []
var loaded := false
var load_errors: Array[String] = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	if loaded:
		return
	for id in POKEMON_IDS:
		var res = load(POKEMON_PATHS[id])
		if res is PokemonData:
			pokemon[id] = res
		else:
			load_errors.append("Missing species resource: %s" % POKEMON_PATHS[id])
	for move_id in MOVE_IDS:
		var path := "res://data/moves/%s.tres" % move_id
		var res = load(path)
		if res is MoveData:
			moves[move_id] = res
		else:
			load_errors.append("Missing move resource: %s" % path)
	trainers = _load_array("res://data/trainers.json")
	opponents = _load_array("res://data/opponents.json")
	rocket_opponents = _load_array("res://data/rocket.json")
	loaded = true
	for error in load_errors:
		push_warning(error)

func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		load_errors.append("Missing data file: %s" % path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_errors.append("Could not open: %s" % path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	load_errors.append("Invalid JSON array: %s" % path)
	return []

func get_pokemon(id: String) -> PokemonData:
	if not loaded:
		load_all()
	return pokemon.get(id, null) as PokemonData

func get_move(id: String) -> MoveData:
	if not loaded:
		load_all()
	return moves.get(id, null) as MoveData

func all_pokemon() -> Array[PokemonData]:
	var result: Array[PokemonData] = []
	for id in POKEMON_IDS:
		var p := get_pokemon(id)
		if p != null:
			result.append(p)
	return result

func get_trainer(id: String) -> Dictionary:
	for trainer in trainers:
		if str(trainer.get("id", "")) == id:
			return trainer
	return {}

func trainer_ids() -> Array[String]:
	var result: Array[String] = []
	for trainer in trainers:
		result.append(str(trainer.get("id", "")))
	return result

func get_opponent_for_match(completed: int, wins: int) -> Dictionary:
	if opponents.is_empty():
		return {}
	var index := completed % opponents.size()
	return get_opponent_by_id(str((opponents[index] as Dictionary).get("id", "")), completed, wins)

func get_opponent_by_id(opponent_id: String, completed: int, wins: int) -> Dictionary:
	for entry in opponents:
		if not entry is Dictionary:
			continue
		var base: Dictionary = entry
		if str(base.get("id", "")) != opponent_id:
			continue
		var result: Dictionary = base.duplicate(true)
		var level := clampi(4 + int(completed / 2) + int(result.get("level_offset", 0)), 4, 60)
		result["level"] = level
		result["xp"] = int(result.get("xp", 60)) + wins * 4
		result["rocket"] = false
		return result
	return get_opponent_for_match_fallback(completed, wins)

func get_opponent_for_match_fallback(completed: int, wins: int) -> Dictionary:
	if opponents.is_empty():
		return {}
	var index := completed % opponents.size()
	var base: Dictionary = (opponents[index] as Dictionary).duplicate(true)
	var level := clampi(4 + int(completed / 2) + int(base.get("level_offset", 0)), 4, 60)
	base["level"] = level
	base["xp"] = int(base.get("xp", 60)) + wins * 4
	base["rocket"] = false
	return base

func get_rocket_opponent(events_done: int, completed: int) -> Dictionary:
	if rocket_opponents.is_empty():
		return {}
	var index := events_done % rocket_opponents.size()
	var base: Dictionary = (rocket_opponents[index] as Dictionary).duplicate(true)
	var level := clampi(6 + int(completed / 2) + int(base.get("level_offset", 0)), 6, 70)
	base["level"] = level
	base["rocket"] = true
	return base

func optional_model_path(id: String) -> String:
	var path := "res://assets/models/%s.glb" % id
	if ResourceLoader.exists(path):
		return path
	return ""

func optional_trainer_model_path(id: String) -> String:
	var path := "res://assets/models/trainer_%s.glb" % id
	if ResourceLoader.exists(path):
		return path
	return ""

func asset_status_report() -> String:
	var lines: Array[String] = []
	lines.append("Species loaded: %d/%d" % [pokemon.size(), POKEMON_IDS.size()])
	lines.append("Moves loaded: %d/%d" % [moves.size(), MOVE_IDS.size()])
	lines.append("Trainers: %d" % trainers.size())
	lines.append("Regular opponents: %d" % opponents.size())
	lines.append("Rocket opponents: %d" % rocket_opponents.size())
	if load_errors.is_empty():
		lines.append("No asset errors.")
	else:
		for error in load_errors:
			lines.append("WARNING: " + error)
	return "\n".join(lines)
