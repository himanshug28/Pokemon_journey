class_name TypeChart
extends RefCounted
## Type colors, labels and the damage multiplier chart used by BattleSim.

const TYPE_COLORS := {
	"normal": Color("#9aa3b5"),
	"fire": Color("#ff7043"),
	"water": Color("#3fa9ff"),
	"grass": Color("#56c96a"),
	"electric": Color("#f7cf3a"),
	"ghost": Color("#8b6bd9"),
	"poison": Color("#b25cc9"),
	"flying": Color("#7fc7f5"),
	"dark": Color("#5b5670"),
}

const TYPE_DARK := {
	"normal": Color("#3b4256"),
	"fire": Color("#7a2416"),
	"water": Color("#113d70"),
	"grass": Color("#17552c"),
	"electric": Color("#6b5304"),
	"ghost": Color("#33225f"),
	"poison": Color("#4e1c5c"),
	"flying": Color("#1d4a6b"),
	"dark": Color("#1f1c2b"),
}

const CHART := {
	"normal": {"ghost": 0.0},
	"fire": {"grass": 2.0, "fire": 0.5, "water": 0.5, "flying": 0.5},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5},
	"grass": {"water": 2.0, "fire": 0.5, "grass": 0.5, "poison": 0.5, "flying": 0.5},
	"electric": {"water": 2.0, "flying": 2.0, "electric": 0.5, "grass": 0.5},
	"ghost": {"ghost": 2.0, "dark": 0.5, "normal": 0.0},
	"poison": {"grass": 2.0, "poison": 0.5, "ghost": 0.5},
	"flying": {"grass": 2.0, "electric": 0.5},
	"dark": {"ghost": 2.0, "dark": 0.5},
}

static func effectiveness(attack_type: String, defender_types: Array) -> float:
	var multiplier := 1.0
	var row: Dictionary = CHART.get(attack_type, {})
	for defender_type in defender_types:
		multiplier *= float(row.get(str(defender_type), 1.0))
	return multiplier

static func effectiveness_label(multiplier: float) -> String:
	if multiplier <= 0.0:
		return "It doesn't affect the target..."
	if multiplier > 1.0:
		return "It's super effective!"
	if multiplier < 1.0:
		return "It's not very effective..."
	return ""

static func type_color(poke_type: String) -> Color:
	return TYPE_COLORS.get(poke_type, Color("#9aa3b5"))

static func type_dark(poke_type: String) -> Color:
	return TYPE_DARK.get(poke_type, Color("#303649"))

static func type_name(poke_type: String) -> String:
	return poke_type.capitalize()
