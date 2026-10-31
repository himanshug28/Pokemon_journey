class_name BattleSim
extends RefCounted
## Deterministic turn-based battle engine. Produces an event stream for the battle UI.

const DAMAGE_SCALE := 0.8
const MAX_DAMAGE_PER_HIT_RATIO := 0.36

var player: BattleCombatant
var enemy: BattleCombatant
var rng := RandomNumberGenerator.new()
var finished := false
var winner := ""
var turn_count := 0
var rocket := false
var opponent_info: Dictionary = {}

func setup(player_species: PokemonData, player_level: int, enemy_species: PokemonData, enemy_level: int, seed_value: int = 0, is_rocket: bool = false, info: Dictionary = {}) -> void:
	player = BattleCombatant.new()
	player.setup(player_species, player_level)
	enemy = BattleCombatant.new()
	enemy.setup(enemy_species, enemy_level)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	finished = false
	winner = ""
	turn_count = 0
	rocket = is_rocket
	opponent_info = info

func choose_enemy_move() -> int:
	return choose_move_for(enemy, player)


func choose_player_move() -> int:
	return choose_move_for(player, enemy)


func choose_move_for(attacker: BattleCombatant, defender: BattleCombatant) -> int:
	var options := attacker.available_moves()
	if options.is_empty():
		return -1
	if rng.randf() < 0.18:
		return options[rng.randi_range(0, options.size() - 1)]
	var best_index: int = options[0]
	var best_score := -999.0
	for index in options:
		var move := attacker.moves[index]
		var score := 0.0
		if move.power > 0:
			var effectiveness := TypeChart.effectiveness(move.poke_type, defender.data.types())
			var stab := 1.35 if move.poke_type in attacker.data.types() else 1.0
			score = float(move.power) * effectiveness * stab * (float(move.accuracy) / 100.0)
		elif move.effect == "heal":
			score = 55.0 * (1.0 - attacker.hp_ratio())
		elif move.effect == "buff_attack" or move.effect == "buff_defense":
			score = 28.0 if int(attacker.stages.get("attack", 0)) < 2 else 4.0
		elif move.effect == "lower_speed":
			score = 22.0
		elif move.effect == "paralyze" or move.effect == "poison" or move.effect == "burn":
			score = 30.0 if not defender.has_status() else 5.0
		score += rng.randf_range(-7.0, 7.0)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func take_turn(player_move_index: int, enemy_move_index: int) -> Array:
	var events: Array = []
	if finished:
		return events
	turn_count += 1
	events.append({"type": "turn_start", "turn": turn_count})
	var player_move: MoveData = player.moves[player_move_index] if player_move_index >= 0 and player_move_index < player.moves.size() else null
	var enemy_move: MoveData = enemy.moves[enemy_move_index] if enemy_move_index >= 0 and enemy_move_index < enemy.moves.size() else null
	if player_move == null and enemy_move == null:
		finished = true
		winner = "enemy"
		events.append({"type": "end", "winner": winner})
		return events
	var player_first := true
	if player_move != null and enemy_move != null:
		var player_priority := player_move.priority
		var enemy_priority := enemy_move.priority
		if player_priority == enemy_priority:
			player_first = player.effective_speed() >= enemy.effective_speed()
			if is_equal_approx(player.effective_speed(), enemy.effective_speed()):
				player_first = rng.randf() < 0.5
		else:
			player_first = player_priority > enemy_priority

	var first_is_player := player_first
	for i in 2:
		if finished:
			break
		var is_player_turn := first_is_player if i == 0 else not first_is_player
		if is_player_turn:
			if player.is_alive():
				_resolve_move(player, enemy, player_move, player_move_index, true, events)
		else:
			if enemy.is_alive():
				_resolve_move(enemy, player, enemy_move, enemy_move_index, false, events)
		_check_faint(events)

	if not finished:
		_apply_end_of_turn(player, true, events)
		if not finished:
			_apply_end_of_turn(enemy, false, events)
		_check_faint(events)

	var player_out_of_pp := player_move == null or player_move_index < 0 or player_move_index >= player.pp.size() or player.pp[player_move_index] <= 0
	var enemy_out_of_pp := enemy_move == null or enemy_move_index < 0 or enemy_move_index >= enemy.pp.size() or enemy.pp[enemy_move_index] <= 0
	if not finished and player_out_of_pp and enemy_out_of_pp:
		finished = true
		winner = "enemy"
		events.append({"type": "message", "text": "Both Pokémon are out of usable moves..."})
		events.append({"type": "end", "winner": winner})
	return events

func _resolve_move(attacker: BattleCombatant, defender: BattleCombatant, move: MoveData, move_index: int, is_player: bool, events: Array) -> void:
	if move == null:
		return
	if move_index < 0 or move_index >= attacker.pp.size():
		return
	if attacker.pp[move_index] <= 0:
		events.append({"type": "message", "text": "%s has no PP left for %s!" % [attacker.display_name(), move.display_name]})
		return
	attacker.pp[move_index] = maxi(0, attacker.pp[move_index] - 1)
	var side := "player" if is_player else "enemy"
	var target := "enemy" if is_player else "player"
	# Paralysis can steal the turn.
	if attacker.status == "paralyze" and rng.randf() < 0.25:
		events.append({"type": "message", "text": "%s is paralyzed and can't move!" % attacker.display_name()})
		return
	events.append({
		"type": "attack",
		"side": side,
		"target": target,
		"move_name": move.display_name,
		"move_type": move.poke_type,
	})
	events.append({"type": "message", "text": "%s used %s!" % [attacker.display_name(), move.display_name]})

	# Accuracy check.
	if move.accuracy < 100 and rng.randf() * 100.0 >= float(move.accuracy):
		events.append({"type": "message", "text": "%s's attack missed!" % attacker.display_name()})
		return

	if move.power <= 0:
		var effect_text := _apply_move_effect(attacker, defender, move, is_player)
		if effect_text != "":
			events.append({"type": "message", "text": effect_text})
		return

	var effectiveness := TypeChart.effectiveness(move.poke_type, defender.data.types())
	if effectiveness <= 0.0:
		events.append({"type": "message", "text": TypeChart.effectiveness_label(effectiveness)})
		return
	var crit_chance := 0.0625 + float(move.crit_bonus) * 0.0625
	var crit := rng.randf() < crit_chance
	var damage := _calculate_damage(attacker, defender, move, effectiveness, crit)
	var dealt := defender.take_damage(damage)
	events.append({
		"type": "damage",
		"side": target,
		"amount": dealt,
		"effectiveness": effectiveness,
		"crit": crit,
		"hp": defender.hp,
		"max_hp": defender.max_hp,
	})
	if crit:
		events.append({"type": "message", "text": "A critical hit!"})
	var eff_text := TypeChart.effectiveness_label(effectiveness)
	if eff_text != "":
		events.append({"type": "message", "text": eff_text})
	if move.effect != "" and rng.randf() * 100.0 < float(move.effect_chance):
		var extra := _apply_move_effect(attacker, defender, move, is_player)
		if extra != "":
			events.append({"type": "message", "text": extra})

func _calculate_damage(attacker: BattleCombatant, defender: BattleCombatant, move: MoveData, effectiveness: float, crit: bool) -> int:
	var stab := 1.5 if move.poke_type in attacker.data.types() else 1.0
	var base_damage := float(move.fixed_damage)
	if move.fixed_damage <= 0:
		var level_factor := 2.0 * float(attacker.level) / 5.0 + 2.0
		base_damage = (level_factor * float(move.power) * attacker.effective_attack() / maxf(1.0, defender.effective_defense())) / 50.0 + 2.0
	var variance := rng.randf_range(0.92, 1.0)
	var critical_multiplier := 1.5 if crit else 1.0
	var damage := maxi(1, int(round(base_damage * stab * effectiveness * critical_multiplier * variance * DAMAGE_SCALE)))
	var max_hit := maxi(1, int(round(float(defender.max_hp) * MAX_DAMAGE_PER_HIT_RATIO)))
	return mini(damage, max_hit)

func _apply_move_effect(attacker: BattleCombatant, defender: BattleCombatant, move: MoveData, is_player: bool) -> String:
	var target := defender
	var side := "enemy" if is_player else "player"
	match move.effect:
		"heal":
			var healed := attacker.heal(int(attacker.max_hp * 0.5))
			return "%s recovered %d HP!" % [attacker.display_name(), healed]
		"buff_attack":
			attacker.stages["attack"] = clampi(int(attacker.stages["attack"]) + 1, -3, 3)
			return "%s's Attack rose!" % attacker.display_name()
		"buff_defense":
			attacker.stages["defense"] = clampi(int(attacker.stages["defense"]) + 1, -3, 3)
			return "%s's Defense rose!" % attacker.display_name()
		"lower_speed":
			defender.stages["speed"] = clampi(int(defender.stages["speed"]) - 1, -3, 3)
			return "%s's Speed fell!" % defender.display_name()
		"burn", "poison", "paralyze":
			if target.has_status():
				return "%s is already affected!" % target.display_name()
			if move.effect == "burn" and "fire" in target.data.types():
				return "It doesn't affect %s..." % target.display_name()
			if move.effect == "poison" and ("poison" in target.data.types() or "grass" in target.data.types()):
				return "It doesn't affect %s..." % target.display_name()
			if move.effect == "paralyze" and "electric" in target.data.types():
				return "It doesn't affect %s..." % target.display_name()
			target.status = move.effect
			match move.effect:
				"burn": return "%s was burned!" % target.display_name()
				"poison": return "%s was poisoned!" % target.display_name()
				"paralyze": return "%s is paralyzed! It may be unable to move!" % target.display_name()
		_:
			return ""
	return ""

func _apply_end_of_turn(combatant: BattleCombatant, is_player: bool, events: Array) -> void:
	if not combatant.is_alive() or not combatant.has_status():
		return
	var side := "player" if is_player else "enemy"
	var damage := 0
	var text := ""
	if combatant.status == "burn":
		damage = maxi(1, int(combatant.max_hp / 16.0))
		text = "%s is hurt by its burn!" % combatant.display_name()
	elif combatant.status == "poison":
		damage = maxi(1, int(combatant.max_hp / 8.0))
		text = "%s is hurt by poison!" % combatant.display_name()
	if damage > 0:
		var dealt := combatant.take_damage(damage)
		events.append({"type": "message", "text": text})
		events.append({
			"type": "status_damage",
			"side": side,
			"amount": dealt,
			"status": combatant.status,
			"hp": combatant.hp,
			"max_hp": combatant.max_hp,
		})

func _check_faint(events: Array) -> void:
	if finished:
		return
	if not enemy.is_alive():
		finished = true
		winner = "player"
		events.append({"type": "faint", "side": "enemy"})
		events.append({"type": "end", "winner": "player"})
		return
	if not player.is_alive():
		finished = true
		winner = "enemy"
		events.append({"type": "faint", "side": "player"})
		events.append({"type": "end", "winner": "enemy"})

func reward_xp(won: bool) -> int:
	var base := int(opponent_info.get("xp", 70))
	var level_bonus := int(enemy.level) * 2
	var amount := base + level_bonus
	if rocket:
		amount = int(amount * 1.35)
	if not won:
		amount = int(amount * 0.35)
	return maxi(1, amount)
