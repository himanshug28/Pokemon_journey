class_name PokemonData
extends Resource
## Static species data. Battle state lives in BattleSim so the resource stays immutable.

@export var id: String = ""
@export var display_name: String = ""
@export var dex_number: int = 0
@export_multiline var description: String = ""
@export_enum("normal", "fire", "water", "grass", "electric", "ghost", "poison", "flying", "dark") var primary_type: String = "normal"
@export var secondary_type: String = ""
@export var base_hp: int = 60
@export var attack: int = 60
@export var defense: int = 60
@export var speed: int = 60
@export var moves: Array[MoveData] = []
@export var body_color: Color = Color(0.95, 0.8, 0.35, 1)
@export var belly_color: Color = Color(1, 0.94, 0.75, 1)
@export var accent_color: Color = Color(1, 0.45, 0.2, 1)
@export var model_scale: float = 1.0
@export var model_path: String = ""
@export var battle_cry_pitch: float = 1.0
@export var unlock_regular_wins: int = -1
@export var unlock_rocket_wins: int = -1
@export var unlock_hint: String = ""

func types() -> Array[String]:
	var result: Array[String] = [primary_type]
	if secondary_type != "":
		result.append(secondary_type)
	return result

func type_label() -> String:
	if secondary_type == "":
		return primary_type.capitalize()
	return "%s / %s" % [primary_type.capitalize(), secondary_type.capitalize()]

func base_stat_total() -> int:
	return base_hp + attack + defense + speed

func is_unlocked(regular_wins: int, rocket_wins: int) -> bool:
	if unlock_regular_wins < 0 and unlock_rocket_wins < 0:
		return false
	if unlock_regular_wins >= 0 and regular_wins >= unlock_regular_wins:
		return true
	if unlock_rocket_wins >= 0 and rocket_wins >= unlock_rocket_wins:
		return true
	return false

func requirement_text() -> String:
	if unlock_hint != "":
		return unlock_hint
	var parts: Array[String] = []
	if unlock_regular_wins >= 0:
		parts.append("Win %d regular match%s" % [unlock_regular_wins, "" if unlock_regular_wins == 1 else "es"])
	if unlock_rocket_wins >= 0:
		parts.append("Defeat %d Team Rocket event%s" % [unlock_rocket_wins, "" if unlock_rocket_wins == 1 else "s"])
	return " or ".join(parts)
