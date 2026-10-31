class_name BattleCombatant
extends RefCounted
## Mutable battle state for one Pokémon. Species resources stay untouched.

var data: PokemonData
var level := 5
var max_hp := 40
var hp := 40
var attack := 60
var defense := 60
var speed := 60
var moves: Array[MoveData] = []
var pp: Array[int] = []
var status := ""
var stages := {"attack": 0, "defense": 0, "speed": 0}
var fainted := false

func setup(species: PokemonData, battle_level: int) -> void:
	data = species
	level = maxi(1, battle_level)
	max_hp = int((species.base_hp * 2.0 + 34.0) * float(level) / 50.0) + level + 22
	hp = max_hp
	attack = species.attack + level * 2
	defense = species.defense + level * 2
	speed = species.speed + level * 2
	moves = species.moves.duplicate()
	pp.clear()
	for move in moves:
		pp.append(move.max_pp)
	status = ""
	stages = {"attack": 0, "defense": 0, "speed": 0}
	fainted = false

func display_name() -> String:
	return data.display_name if data != null else "Pokémon"

func is_alive() -> bool:
	return hp > 0 and not fainted

func hp_ratio() -> float:
	return clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)

func stage_multiplier(stat: String) -> float:
	var stage := int(stages.get(stat, 0))
	if stage >= 0:
		return 1.0 + stage * 0.5
	return 1.0 / (1.0 + absf(float(stage)) * 0.5)

func effective_attack() -> float:
	var value := float(attack) * stage_multiplier("attack")
	if status == "burn":
		value *= 0.75
	return value

func effective_defense() -> float:
	return float(defense) * stage_multiplier("defense")

func effective_speed() -> float:
	var value := float(speed) * stage_multiplier("speed")
	if status == "paralyze":
		value *= 0.5
	return value

func take_damage(amount: int) -> int:
	var dealt := clampi(amount, 0, hp)
	hp -= dealt
	if hp <= 0:
		hp = 0
		fainted = true
	return dealt

func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 0, max_hp)
	if hp > 0:
		fainted = false
	return hp - before

func has_status() -> bool:
	return status != ""

func status_label() -> String:
	match status:
		"burn": return "BURN"
		"poison": return "POISON"
		"paralyze": return "PARALYZED"
		_: return ""

func available_moves() -> Array[int]:
	var result: Array[int] = []
	for i in moves.size():
		if pp[i] > 0:
			result.append(i)
	return result
