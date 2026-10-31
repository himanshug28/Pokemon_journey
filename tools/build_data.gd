extends SceneTree
## Regenerates the .tres species/move resources.
## Run: godot --headless --path . --script res://tools/build_data.gd

const MOVE_DEFS := {
	"flamethrower": {"name": "Flamethrower", "type": "fire", "power": 90, "acc": 100, "pp": 15, "effect": "burn", "chance": 10, "desc": "A searing stream of flame that may leave the target burned."},
	"air_slash": {"name": "Air Slash", "type": "flying", "power": 75, "acc": 95, "pp": 15, "crit": 1, "desc": "Sharp blades of wind with a high critical-hit chance."},
	"fire_fang": {"name": "Fire Fang", "type": "fire", "power": 65, "acc": 95, "pp": 15, "effect": "burn", "chance": 10, "desc": "Fiery fangs that may burn the target."},
	"slash": {"name": "Slash", "type": "normal", "power": 70, "acc": 100, "pp": 20, "crit": 1, "desc": "A quick, sharp claw strike with a high critical-hit chance."},
	"vine_whip": {"name": "Vine Whip", "type": "grass", "power": 45, "acc": 100, "pp": 25, "desc": "Tough vines lash the target."},
	"razor_leaf": {"name": "Razor Leaf", "type": "grass", "power": 55, "acc": 95, "pp": 25, "crit": 1, "desc": "Sharp leaves slice at the target with a high critical-hit chance."},
	"sludge": {"name": "Sludge", "type": "poison", "power": 65, "acc": 100, "pp": 20, "effect": "poison", "chance": 30, "desc": "Filthy sludge that may poison the target."},
	"synthesis": {"name": "Synthesis", "type": "grass", "power": 0, "acc": 100, "pp": 10, "effect": "heal", "chance": 100, "desc": "Bathes in sunlight to restore half of its max HP."},
	"shadow_ball": {"name": "Shadow Ball", "type": "ghost", "power": 80, "acc": 100, "pp": 15, "desc": "A shadowy orb of gathered gloom."},
	"sludge_bomb": {"name": "Sludge Bomb", "type": "poison", "power": 90, "acc": 100, "pp": 10, "effect": "poison", "chance": 30, "desc": "A burst of toxic sludge that may poison the target."},
	"dark_pulse": {"name": "Dark Pulse", "type": "dark", "power": 80, "acc": 100, "pp": 15, "desc": "A cruel wave of dark aura."},
	"lick": {"name": "Lick", "type": "ghost", "power": 30, "acc": 100, "pp": 30, "effect": "paralyze", "chance": 30, "desc": "A creepy lick that may paralyze the target."},
	"thunderbolt": {"name": "Thunderbolt", "type": "electric", "power": 90, "acc": 100, "pp": 15, "effect": "paralyze", "chance": 10, "desc": "A powerful bolt of electricity that may paralyze."},
	"quick_attack": {"name": "Quick Attack", "type": "normal", "power": 40, "acc": 100, "pp": 30, "priority": 1, "desc": "A fast strike that always goes first."},
	"electro_ball": {"name": "Electro Ball", "type": "electric", "power": 80, "acc": 100, "pp": 10, "desc": "Hurls a crackling sphere of electricity."},
	"thunder_wave": {"name": "Thunder Wave", "type": "electric", "power": 0, "acc": 90, "pp": 20, "effect": "paralyze", "chance": 100, "desc": "A weak jolt that paralyzes the target."},
	"water_gun": {"name": "Water Gun", "type": "water", "power": 40, "acc": 100, "pp": 25, "desc": "Squirts a precise jet of water."},
	"surf": {"name": "Surf", "type": "water", "power": 90, "acc": 100, "pp": 15, "desc": "A huge wave crashes down on the target."},
	"bite": {"name": "Bite", "type": "dark", "power": 60, "acc": 100, "pp": 25, "desc": "A vicious bite with dark energy."},
	"withdraw": {"name": "Withdraw", "type": "water", "power": 0, "acc": 100, "pp": 20, "effect": "buff_defense", "chance": 100, "desc": "Hides in its shell to sharply raise Defense."},
}

const SPECIES := [
	{
		"id": "charizard", "name": "Charizard", "dex": 6, "types": ["fire", "flying"],
		"hp": 78, "atk": 84, "def": 78, "spd": 100,
		"moves": ["flamethrower", "air_slash", "fire_fang", "slash"],
		"body": "#f28b30", "belly": "#ffe0a3", "accent": "#38c7c4", "scale": 1.18, "pitch": 0.86,
		"unlock_regular": 3, "unlock_rocket": -1,
		"hint": "Win 3 regular matches",
		"desc": "A proud flame Pokémon. Its blazing tail burns brighter when it is ready for battle."
	},
	{
		"id": "bulbasaur", "name": "Bulbasaur", "dex": 1, "types": ["grass", "poison"],
		"hp": 45, "atk": 49, "def": 49, "spd": 45,
		"moves": ["vine_whip", "razor_leaf", "sludge", "synthesis"],
		"body": "#66c6a2", "belly": "#b8e8c8", "accent": "#4ea34f", "scale": 0.92, "pitch": 1.18,
		"unlock_regular": 1, "unlock_rocket": -1,
		"hint": "Win 1 regular match",
		"desc": "A gentle seed Pokémon that draws power from the bulb on its back."
	},
	{
		"id": "gengar", "name": "Gengar", "dex": 94, "types": ["ghost", "poison"],
		"hp": 60, "atk": 65, "def": 60, "spd": 110,
		"moves": ["shadow_ball", "sludge_bomb", "dark_pulse", "lick"],
		"body": "#6d5a9c", "belly": "#574683", "accent": "#ff4d6d", "scale": 1.0, "pitch": 0.72,
		"unlock_regular": 4, "unlock_rocket": 1,
		"hint": "Win 4 regular matches or defeat Team Rocket",
		"desc": "A mischievous shadow Pokémon that slips through the dark and loves a good scare."
	},
	{
		"id": "pikachu", "name": "Pikachu", "dex": 25, "types": ["electric"],
		"hp": 35, "atk": 55, "def": 40, "spd": 90,
		"moves": ["thunderbolt", "quick_attack", "electro_ball", "thunder_wave"],
		"body": "#ffd94a", "belly": "#ffe98a", "accent": "#ff5a5f", "scale": 0.86, "pitch": 1.42,
		"unlock_regular": 5, "unlock_rocket": 2,
		"hint": "Win 5 regular matches or defeat 2 Team Rocket events",
		"desc": "An energetic Electric-type with lightning in its cheeks and courage in its heart."
	},
	{
		"id": "squirtle", "name": "Squirtle", "dex": 7, "types": ["water"],
		"hp": 44, "atk": 48, "def": 65, "spd": 43,
		"moves": ["water_gun", "surf", "bite", "withdraw"],
		"body": "#65bff0", "belly": "#f5e3b0", "accent": "#a9713f", "scale": 0.9, "pitch": 1.26,
		"unlock_regular": 2, "unlock_rocket": -1,
		"hint": "Win 2 regular matches",
		"desc": "A cheerful turtle Pokémon that shelters in its shell and fires precise water jets."
	},
]

func _initialize() -> void:
	var MoveDataScript = load("res://scripts/data/move_data.gd")
	var PokemonDataScript = load("res://scripts/data/pokemon_data.gd")
	if MoveDataScript == null or PokemonDataScript == null:
		push_error("Could not load data scripts")
		quit(1)
		return

	var moves := {}
	for move_id in MOVE_DEFS:
		var def: Dictionary = MOVE_DEFS[move_id]
		var move: Resource = MoveDataScript.new()
		move.id = move_id
		move.display_name = def.get("name", move_id.capitalize())
		move.poke_type = def.get("type", "normal")
		move.power = int(def.get("power", 0))
		move.accuracy = int(def.get("acc", 100))
		move.max_pp = int(def.get("pp", 15))
		move.description = def.get("desc", "")
		move.effect = def.get("effect", "")
		move.effect_chance = int(def.get("chance", 100))
		move.priority = int(def.get("priority", 0))
		move.crit_bonus = int(def.get("crit", 0))
		move.fixed_damage = int(def.get("fixed", 0))
		var path := "res://data/moves/%s.tres" % move_id
		var err := ResourceSaver.save(move, path)
		if err != OK:
			push_error("Failed saving %s: %s" % [path, err])
		moves[move_id] = load(path)

	for species in SPECIES:
		var pokemon: Resource = PokemonDataScript.new()
		pokemon.id = species.id
		pokemon.display_name = species.name
		pokemon.dex_number = int(species.dex)
		pokemon.description = species.desc
		pokemon.primary_type = species.types[0]
		pokemon.secondary_type = species.types[1] if species.types.size() > 1 else ""
		pokemon.base_hp = int(species.hp)
		pokemon.attack = int(species.atk)
		pokemon.defense = int(species.def)
		pokemon.speed = int(species.spd)
		var move_list: Array[MoveData] = []
		for move_id in species.moves:
			move_list.append(moves[move_id])
		pokemon.moves = move_list
		pokemon.body_color = Color(species.body)
		pokemon.belly_color = Color(species.belly)
		pokemon.accent_color = Color(species.accent)
		pokemon.model_scale = float(species.scale)
		pokemon.battle_cry_pitch = float(species.pitch)
		pokemon.unlock_regular_wins = int(species.unlock_regular)
		pokemon.unlock_rocket_wins = int(species.unlock_rocket)
		pokemon.unlock_hint = species.hint
		pokemon.model_path = "res://assets/models/%s.glb" % species.id
		var path := "res://data/pokemon/%s.tres" % species.id
		var err := ResourceSaver.save(pokemon, path)
		if err != OK:
			push_error("Failed saving %s: %s" % [path, err])
		print("Wrote ", path)
	print("Data generation complete: %d species, %d moves" % [SPECIES.size(), MOVE_DEFS.size()])
	quit(0)
