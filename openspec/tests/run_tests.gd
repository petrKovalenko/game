extends SceneTree
## Headless-раннер тестов логики боя (замена GUT для среза — без внешних зависимостей).
## Запуск: godot --headless --path . --script res://tests/run_tests.gd
## Код выхода: 0 — все проверки пройдены, 1 — есть провалы.

var checks := 0
var failures := 0


func _initialize() -> void:
	_test_grid()
	_test_pathfinding()
	_test_reachable()
	_test_turn_queue()
	_test_combat()
	_test_end_conditions()
	_test_ai()
	print("---")
	print("Проверок: %d, провалов: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func assert_true(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok  - " + label)
	else:
		failures += 1
		printerr("  FAIL- " + label)


func _make_unit(team: int, hp: int, dmg: int, init: int, move: int, cell: Vector2i,
		attack_range: int = 1, mult: float = 1.0) -> BattleUnit:
	var ability := AbilityResource.new()
	ability.id = "a%d" % checks
	ability.display_name = "Тест"
	ability.attack_range = attack_range
	ability.damage_multiplier = mult
	var unit := BattleUnit.new()
	unit.id = "unit_%d_%d" % [team, cell.x]
	unit.display_name = unit.id
	unit.team = team
	unit.hp = hp
	unit.max_hp = hp
	unit.damage = dmg
	unit.initiative = init
	unit.move_limit = move
	unit.abilities = [ability]
	unit.cell = cell
	return unit


func _make_engine(seed_value: int, size: int = 6) -> BattleEngine:
	return BattleEngine.new(seed_value, BattleGrid.new(size, size))


# ---------- Тесты ----------

func _test_grid() -> void:
	print("[BattleGrid]")
	var grid := BattleGrid.new(5, 5)
	assert_true(grid.in_bounds(Vector2i(0, 0)), "угол (0,0) в границах")
	assert_true(grid.in_bounds(Vector2i(4, 4)), "угол (4,4) в границах")
	assert_true(not grid.in_bounds(Vector2i(5, 0)), "(5,0) вне границ")
	assert_true(not grid.in_bounds(Vector2i(-1, 2)), "(-1,2) вне границ")
	grid.blocked[Vector2i(2, 2)] = true
	assert_true(not grid.is_passable(Vector2i(2, 2)), "заблокированная клетка непроходима")
	assert_true(not grid.is_passable(Vector2i(9, 9)), "клетка вне границ непроходима")
	assert_true(grid.is_passable(Vector2i(2, 1)), "обычная клетка проходима")


func _test_pathfinding() -> void:
	print("[BattleGrid.find_path]")
	var grid := BattleGrid.new(5, 5)
	for y in 4:
		grid.blocked[Vector2i(2, y)] = true
	var path := grid.find_path(Vector2i(0, 0), Vector2i(4, 0))
	assert_true(not path.is_empty(), "путь вокруг стены найден")
	if not path.is_empty():
		assert_true(path.size() > 4, "путь длиннее прямого (обход стены)")
		assert_true(path[path.size() - 1] == Vector2i(4, 0), "путь заканчивается целью")
	var no_path := grid.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_true(no_path.is_empty(), "цель-стена: путь не найден")
	var occupied := {Vector2i(0, 1): true, Vector2i(1, 1): true}
	var around := grid.find_path(Vector2i(0, 0), Vector2i(0, 2), occupied)
	assert_true(not around.is_empty(), "путь огибает занятые клетки")


func _test_reachable() -> void:
	print("[BattleGrid.reachable_cells]")
	var grid := BattleGrid.new(5, 5)
	var reachable := grid.reachable_cells(Vector2i(0, 0), 2)
	assert_true(reachable.has(Vector2i(2, 0)), "клетка на дистанции 2 достижима")
	assert_true(not reachable.has(Vector2i(3, 0)), "клетка на дистанции 3 недостижима")
	assert_true(not reachable.has(Vector2i(0, 0)), "старт не входит в результат")
	var occupied := {Vector2i(1, 0): true, Vector2i(0, 1): true}
	var blocked_reach := grid.reachable_cells(Vector2i(0, 0), 2, occupied)
	assert_true(blocked_reach.is_empty(), "занятые соседние клетки отсекают зону")


func _test_turn_queue() -> void:
	print("[TurnQueue]")
	var engine_a := _make_engine(777)
	var engine_b := _make_engine(777)
	var units := [
		_make_unit(BattleUnit.TEAM_PLAYER, 10, 2, 5, 1, Vector2i(0, 0)),
		_make_unit(BattleUnit.TEAM_PLAYER, 10, 2, 9, 1, Vector2i(0, 1)),
		_make_unit(BattleUnit.TEAM_ENEMY, 10, 2, 5, 1, Vector2i(3, 3)),
		_make_unit(BattleUnit.TEAM_ENEMY, 10, 2, 1, 1, Vector2i(4, 4)),
	]
	engine_a.units = units
	engine_b.units = units
	engine_a.start_battle()
	engine_b.start_battle()
	assert_true(engine_a.round_order[0].initiative == 9, "первый ходит юнит с инициативой 9")
	assert_true(engine_a.round_order[engine_a.round_order.size() - 1].initiative == 1,
			"последний — юнит с инициативой 1")
	var same := true
	for i in engine_a.round_order.size():
		if engine_a.round_order[i].id != engine_b.round_order[i].id:
			same = false
	assert_true(same, "одинаковый seed даёт одинаковый порядок раунда")


func _test_combat() -> void:
	print("[BattleEngine.use_ability]")
	var engine := _make_engine(1)
	var hero := _make_unit(BattleUnit.TEAM_PLAYER, 20, 5, 9, 2, Vector2i(0, 0), 3)
	var foe := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(2, 0), 1)
	engine.units = [hero, foe]
	var ability: AbilityResource = hero.abilities[0]
	assert_true(engine.ability_targets(hero, ability).has(foe),
			"цель на дистанции 2 в радиусе 3 доступна")
	var dealt := engine.use_ability(hero, ability, foe)
	assert_true(dealt == 5, "урон равен damage * multiplier (5)")
	assert_true(foe.hp == 15, "HP цели уменьшился до 15")
	assert_true(hero.has_acted, "флаг has_acted установлен")
	var out := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(4, 4), 1)
	engine.units = [hero, out]
	assert_true(engine.ability_targets(hero, ability).is_empty(),
			"цель вне радиуса недоступна")
	assert_true(engine.use_ability(hero, ability, out) == -1,
			"использование вне радиуса возвращает -1")
	assert_true(out.hp == 20, "HP цели вне радиуса не изменился")


func _test_end_conditions() -> void:
	print("[BattleEngine._check_end]")
	var engine := _make_engine(3)
	var hero := _make_unit(BattleUnit.TEAM_PLAYER, 20, 10, 9, 2, Vector2i(0, 0), 1)
	var foe := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(1, 0), 1)
	engine.units = [hero, foe]
	foe.hp = 5
	engine.use_ability(hero, hero.abilities[0], foe)
	assert_true(foe.hp == 0, "HP врага обнулился")
	assert_true(engine.battle_over, "бой завершён")
	assert_true(engine.winner == BattleUnit.TEAM_PLAYER, "победа игрока")
	var engine2 := _make_engine(4)
	var hero2 := _make_unit(BattleUnit.TEAM_PLAYER, 5, 10, 9, 2, Vector2i(0, 0), 1)
	var foe2 := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(1, 0), 1)
	engine2.units = [hero2, foe2]
	engine2.use_ability(foe2, foe2.abilities[0], hero2)
	assert_true(engine2.battle_over, "поражение: бой завершён")
	assert_true(engine2.winner == BattleUnit.TEAM_ENEMY, "победа врага")


func _test_ai() -> void:
	print("[BattleEngine.run_ai_turn]")
	# ИИ атакует, когда герой в радиусе.
	var engine := _make_engine(5)
	var hero := _make_unit(BattleUnit.TEAM_PLAYER, 20, 5, 9, 2, Vector2i(0, 0), 1)
	var foe := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(1, 0), 1)
	engine.units = [hero, foe]
	var action := engine.run_ai_turn(foe)
	assert_true(action["attacked"], "ИИ атакует героя в радиусе")
	assert_true(hero.hp == 15, "герой получил урон 5")
	# ИИ сближается, когда герой вне радиуса.
	var engine2 := _make_engine(6)
	var hero2 := _make_unit(BattleUnit.TEAM_PLAYER, 20, 5, 9, 2, Vector2i(4, 4), 1)
	var foe2 := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 2, Vector2i(0, 0), 1)
	engine2.units = [hero2, foe2]
	var before := foe2.cell
	var action2 := engine2.run_ai_turn(foe2)
	assert_true(action2["moved"], "ИИ переместился к герою")
	assert_true(BattleEngine.manhattan(foe2.cell, hero2.cell)
			< BattleEngine.manhattan(before, hero2.cell), "дистанция до героя сократилась")
	# ИИ атакует после сближения, если радиус позволяет.
	var engine3 := _make_engine(7)
	var hero3 := _make_unit(BattleUnit.TEAM_PLAYER, 20, 5, 9, 2, Vector2i(3, 1), 1)
	var foe3 := _make_unit(BattleUnit.TEAM_ENEMY, 20, 5, 4, 3, Vector2i(0, 0), 1)
	engine3.units = [hero3, foe3]
	var action3 := engine3.run_ai_turn(foe3)
	assert_true(action3["moved"] and action3["attacked"],
			"ИИ сблизился и атаковал в тот же ход")
