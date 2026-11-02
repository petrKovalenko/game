class_name BattleEngine
extends RefCounted
## Ядро боя: очередь, перемещение, способности, ИИ, условия завершения (design D2, D4, D6-логика).
## Управление потоком ходов (end_turn) — ответственность представления.

signal unit_moved(unit: BattleUnit, path: Array)
signal unit_damaged(target: BattleUnit, amount: int)
signal turn_started(unit: BattleUnit)
signal battle_ended(winner: int)

var grid: BattleGrid
var units: Array = []
var queue: TurnQueue
var round_order: Array = []
var turn_index := -1
var round_number := 0
var battle_over := false
var winner := -1


func _init(seed_value: int = 0, p_grid: BattleGrid = null) -> void:
	queue = TurnQueue.new(seed_value)
	grid = p_grid if p_grid != null else BattleGrid.new(8, 8)


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func occupied_cells() -> Dictionary:
	var result: Dictionary = {}
	for unit: BattleUnit in units:
		if unit.is_alive():
			result[unit.cell] = true
	return result


func unit_at(cell: Vector2i) -> BattleUnit:
	for unit: BattleUnit in units:
		if unit.is_alive() and unit.cell == cell:
			return unit
	return null


func alive_units(team: int) -> Array:
	return units.filter(func(u: BattleUnit) -> bool: return u.is_alive() and u.team == team)


func active_unit() -> BattleUnit:
	if turn_index < 0 or turn_index >= round_order.size():
		return null
	return round_order[turn_index]


## Начало боя: формирует первый раунд и передаёт ход первому юниту.
func start_battle() -> void:
	battle_over = false
	round_number = 0
	_start_round()
	end_turn()


## Передача хода следующему живому юниту (или новый раунд).
func end_turn() -> void:
	if battle_over:
		return
	if _check_end():
		return
	turn_index += 1
	if turn_index >= round_order.size():
		_start_round()
	var unit: BattleUnit = round_order[turn_index]
	if not unit.is_alive():
		end_turn()
		return
	unit.has_moved = false
	unit.has_acted = false
	turn_started.emit(unit)


## Перемещение в пределах лимита (spec: tactical-combat).
func move_unit(unit: BattleUnit, target: Vector2i) -> bool:
	if battle_over or not unit.is_alive() or unit.has_moved:
		return false
	var occupied := occupied_cells()
	occupied.erase(unit.cell)
	if not grid.reachable_cells(unit.cell, unit.move_limit, occupied).has(target):
		return false
	var path := grid.find_path(unit.cell, target, occupied)
	if path.is_empty():
		return false
	unit.cell = target
	unit.has_moved = true
	unit_moved.emit(unit, path)
	return true


## Живые враги в радиусе способности.
func ability_targets(unit: BattleUnit, ability: AbilityResource) -> Array:
	var targets: Array = []
	if battle_over or not unit.is_alive() or unit.has_acted:
		return targets
	for other: BattleUnit in units:
		if other.is_alive() and other.team != unit.team \
				and manhattan(unit.cell, other.cell) <= ability.attack_range:
			targets.append(other)
	return targets


## Применение способности. Возвращает урон или -1, если применение невозможно.
func use_ability(unit: BattleUnit, ability: AbilityResource, target: BattleUnit) -> int:
	if not ability_targets(unit, ability).has(target):
		return -1
	var amount := maxi(1, int(round(float(unit.damage) * ability.damage_multiplier)))
	target.hp = maxi(0, target.hp - amount)
	unit.has_acted = true
	unit_damaged.emit(target, amount)
	_check_end()
	return amount


## Ход ИИ: атака лучшей способностью, иначе сближение с ближайшим героем
## и атака после сближения (spec: tactical-combat, ИИ противника).
func run_ai_turn(unit: BattleUnit) -> Dictionary:
	var result := {
		"moved": false,
		"attacked": false,
		"target": null,
		"damage": 0,
	}
	if battle_over or not unit.is_alive():
		return result
	# 1. Попытка атаки с максимальным уроном.
	var best_target: BattleUnit = null
	var best_ability: AbilityResource = null
	var best_damage := 0
	for ability: AbilityResource in unit.abilities:
		for target: BattleUnit in ability_targets(unit, ability):
			var dmg := maxi(1, int(round(float(unit.damage) * ability.damage_multiplier)))
			if best_target == null or dmg > best_damage:
				best_target = target
				best_ability = ability
				best_damage = dmg
	if best_target != null:
		var dealt := use_ability(unit, best_ability, best_target)
		result["attacked"] = true
		result["target"] = best_target
		result["damage"] = dealt
		return result
	# 2. Сближение с ближайшим героем.
	var heroes := alive_units(BattleUnit.TEAM_PLAYER)
	if heroes.is_empty():
		return result
	var nearest: BattleUnit = heroes[0]
	var nearest_dist := manhattan(unit.cell, nearest.cell)
	for hero: BattleUnit in heroes:
		var d := manhattan(unit.cell, hero.cell)
		if d < nearest_dist:
			nearest = hero
			nearest_dist = d
	var occupied := occupied_cells()
	occupied.erase(unit.cell)
	var reachable := grid.reachable_cells(unit.cell, unit.move_limit, occupied)
	var best_cell := Vector2i(-9999, -9999)
	var best_dist := nearest_dist
	for candidate: Vector2i in reachable.keys():
		var d := manhattan(candidate, nearest.cell)
		if d < best_dist:
			best_dist = d
			best_cell = candidate
	if best_cell.x > -9000:
		var path := grid.find_path(unit.cell, best_cell, occupied)
		if not path.is_empty():
			unit.cell = best_cell
			unit.has_moved = true
			result["moved"] = true
			unit_moved.emit(unit, path)
	# 3. Атака после сближения, если цель в радиусе.
	for ability: AbilityResource in unit.abilities:
		var targets := ability_targets(unit, ability)
		if not targets.is_empty():
			var first: BattleUnit = targets[0]
			var dealt := use_ability(unit, ability, first)
			result["attacked"] = true
			result["target"] = first
			result["damage"] = dealt
			break
	return result


func _start_round() -> void:
	round_number += 1
	round_order = queue.build_round(units)
	turn_index = -1


## Завершение боя при уничтожении всех юнитов одной стороны (spec: tactical-combat).
func _check_end() -> bool:
	if battle_over:
		return true
	var players_alive := not alive_units(BattleUnit.TEAM_PLAYER).is_empty()
	var enemies_alive := not alive_units(BattleUnit.TEAM_ENEMY).is_empty()
	if players_alive and enemies_alive:
		return false
	battle_over = true
	winner = BattleUnit.TEAM_PLAYER if players_alive else BattleUnit.TEAM_ENEMY
	battle_ended.emit(winner)
	return true
