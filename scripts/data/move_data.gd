class_name MoveData
extends Resource
## A single battle move. Stored as a .tres resource so designers can tune values.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("normal", "fire", "water", "grass", "electric", "ghost", "poison", "flying", "dark") var poke_type: String = "normal"
@export_range(0, 250, 1) var power: int = 0
@export_range(0, 100, 1) var accuracy: int = 100
@export_range(1, 40, 1) var max_pp: int = 15
@export_multiline var description: String = ""
## Optional secondary effect: burn, poison, paralyze, heal, buff_attack, buff_defense, lower_speed.
@export var effect: String = ""
@export_range(0, 100, 1) var effect_chance: int = 100
@export var priority: int = 0
@export_range(0, 3, 1) var crit_bonus: int = 0
@export var fixed_damage: int = 0

func effect_label() -> String:
	match effect:
		"burn": return "May burn"
		"poison": return "May poison"
		"paralyze": return "May paralyze"
		"heal": return "Restores HP"
		"buff_attack": return "Raises Attack"
		"buff_defense": return "Raises Defense"
		"lower_speed": return "Lowers Speed"
		_: return ""
