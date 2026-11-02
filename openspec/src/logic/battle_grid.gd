class_name BattleGrid
extends RefCounted
## Логическая сетка боя: проходимость, границы, поиск пути (design D3).
## Чистая логика без зависимости от Node-сцены (design D2).

var width: int
var height: int
## Ключи Vector2i — непроходимые клетки (препятствия).
var blocked: Dictionary = {}


func _init(p_width: int = 8, p_height: int = 8) -> void:
	width = p_width
	height = p_height


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func is_passable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not blocked.has(cell)


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next := cell + offset
		if is_passable(next):
			result.append(next)
	return result


## BFS-поиск пути от start до goal. occupied — клетки, занятые юнитами
## (непроходимы, кроме start и goal). Возвращает путь без start; [] если пути нет.
func find_path(start: Vector2i, goal: Vector2i, occupied: Dictionary = {}) -> Array[Vector2i]:
	if start == goal or not is_passable(goal):
		return []
	var came_from: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			break
		for next in neighbors(current):
			if came_from.has(next):
				continue
			if occupied.has(next) and next != goal:
				continue
			came_from[next] = current
			queue.append(next)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		path.push_front(cursor)
		cursor = came_from[cursor]
	return path


## Все клетки в пределах бюджета шагов от start (BFS по дистанции).
## occupied исключаются. Start в результат не входит.
func reachable_cells(start: Vector2i, budget: int, occupied: Dictionary = {}) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var d: int = dist[current]
		if d >= budget:
			continue
		for next in neighbors(current):
			if dist.has(next) or occupied.has(next):
				continue
			dist[next] = d + 1
			queue.append(next)
	dist.erase(start)
	return dist
