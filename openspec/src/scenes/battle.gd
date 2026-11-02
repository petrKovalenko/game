extends Node2D
## Сцена боя вертикального среза (spec: tactical-combat + game-shell).
## Тонкий адаптер: вся игровая логика — в BattleEngine (design D2).

const TILE_W := 64.0
const TILE_H := 32.0
const GRID_W := 8
const GRID_H := 8
const ORIGIN := Vector2(420.0, 120.0)

const UNIT_RESOURCES := {
	"warrior": preload("res://src/data/units/warrior.tres"),
	"archer": preload("res://src/data/units/archer.tres"),
	"grunt": preload("res://src/data/units/grunt.tres"),
}
const UnitViewScript := preload("res://src/scenes/unit_view.gd")

var engine: BattleEngine
var selected_unit: BattleUnit = null
var selected_ability: AbilityResource = null
var unit_views: Dictionary = {}
var is_busy := false

var _turn_label: Label
var _abilities_box: HBoxContainer
var _overlay: ColorRect
var _overlay_label: Label


func _ready() -> void:
	_build_grid_visuals()
	_build_battle()
	_build_ui()
	engine.start_battle()


# ---------- Построение ----------

func _build_grid_visuals() -> void:
	var grid := BattleGrid.new(GRID_W, GRID_H)
	# Визуальные препятствия ставятся в _build_battle в логической сетке;
	# здесь рисуем только базовые тайлы по общим правилам проходимости.
	for x in GRID_W:
		for y in GRID_H:
			var cell := Vector2i(x, y)
			var base_color := Color(0.5, 0.6, 0.72) if (x + y) % 2 == 0 else Color(0.55, 0.65, 0.78)
			var tile := _make_diamond(cell, base_color)
			tile.z_index = x + y
			add_child(tile)


func _build_battle() -> void:
	var grid := BattleGrid.new(GRID_W, GRID_H)
	for obstacle: Vector2i in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		grid.blocked[obstacle] = true
		var rock := _make_diamond(obstacle, Color(0.35, 0.33, 0.3))
		rock.z_index = 50 + obstacle.x + obstacle.y
		add_child(rock)
	engine = BattleEngine.new(12345, grid)
	var roster := [
		[UNIT_RESOURCES["warrior"], BattleUnit.TEAM_PLAYER, Vector2i(1, 2)],
		[UNIT_RESOURCES["archer"], BattleUnit.TEAM_PLAYER, Vector2i(2, 1)],
		[UNIT_RESOURCES["grunt"], BattleUnit.TEAM_ENEMY, Vector2i(6, 5)],
		[UNIT_RESOURCES["grunt"], BattleUnit.TEAM_ENEMY, Vector2i(6, 6)],
	]
	for entry: Array in roster:
		var res: UnitResource = entry[0]
		var unit := BattleUnit.from_resource(res, entry[1], entry[2])
		engine.units.append(unit)
		var view: UnitView = UnitViewScript.new()
		view.setup(unit, res.color)
		view.position = cell_to_pixel(unit.cell)
		view.z_index = 100 + unit.cell.x + unit.cell.y
		add_child(view)
		unit_views[unit] = view
	engine.turn_started.connect(_on_turn_started, CONNECT_DEFERRED)
	engine.unit_moved.connect(_on_unit_moved)
	engine.unit_damaged.connect(_on_unit_damaged)
	engine.battle_ended.connect(_on_battle_ended, CONNECT_DEFERRED)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_turn_label = Label.new()
	_turn_label.position = Vector2(24, 12)
	_turn_label.text = "Подготовка боя..."
	layer.add_child(_turn_label)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_right = -8.0
	panel.offset_top = -84.0
	panel.offset_bottom = -8.0
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_abilities_box = HBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 12)
	_abilities_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_abilities_box)

	var end_btn := Button.new()
	end_btn.text = "Завершить ход"
	end_btn.custom_minimum_size = Vector2(190, 56)
	end_btn.pressed.connect(_on_end_turn_pressed)
	row.add_child(end_btn)

	# Оверлей результата (spec: условия завершения боя).
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	layer.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_overlay_label = Label.new()
	_overlay_label.text = ""
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_label)

	var restart := Button.new()
	restart.text = "Заново"
	restart.custom_minimum_size = Vector2(200, 56)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)


# ---------- Изометрия ----------

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(
		(float(cell.x - cell.y)) * TILE_W * 0.5,
		(float(cell.x + cell.y)) * TILE_H * 0.5
	)


func pixel_to_cell(point: Vector2) -> Vector2i:
	var local := point - ORIGIN
	var fx := local.x / (TILE_W * 0.5)
	var fy := local.y / (TILE_H * 0.5)
	return Vector2i(roundi((fx + fy) * 0.5), roundi((fy - fx) * 0.5))


func _make_diamond(cell: Vector2i, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-TILE_W * 0.5, 0.0),
		Vector2(0.0, -TILE_H * 0.5),
		Vector2(TILE_W * 0.5, 0.0),
		Vector2(0.0, TILE_H * 0.5),
	])
	poly.color = color
	poly.position = cell_to_pixel(cell)
	return poly


func _highlight_cells(cells: Array, color: Color) -> void:
	for cell: Vector2i in cells:
		var poly := _make_diamond(cell, color)
		poly.z_index = 200 + cell.x + cell.y
		poly.set_meta("highlight", true)
		add_child(poly)


func _clear_highlights() -> void:
	for node in get_children():
		if node is Polygon2D and node.get_meta("highlight", false):
			node.queue_free()


# ---------- Ввод (spec: тач-ввод) ----------

func _unhandled_input(event: InputEvent) -> void:
	if is_busy or engine.battle_over:
		return
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)


func _handle_tap(screen_pos: Vector2) -> void:
	var world_pos := get_canvas_transform().affine_inverse() * screen_pos
	var cell := pixel_to_cell(world_pos)
	if not engine.grid.in_bounds(cell):
		return
	var active := engine.active_unit()
	if active == null or active.team != BattleUnit.TEAM_PLAYER:
		return
	var tapped_unit := engine.unit_at(cell)

	# Выбор цели для выбранной способности.
	if selected_ability != null and selected_unit != null:
		if tapped_unit != null \
				and engine.ability_targets(selected_unit, selected_ability).has(tapped_unit):
			engine.use_ability(selected_unit, selected_ability, tapped_unit)
			selected_ability = null
			_refresh_all()
			_after_player_action()
		else:
			selected_ability = null
			_refresh_all()
		return

	# Выбор своего активного юнита.
	if tapped_unit == active and selected_unit != tapped_unit:
		selected_unit = tapped_unit
		selected_ability = null
		_refresh_all()
		return

	# Перемещение выбранного юнита (spec: перемещение в пределах лимита).
	if selected_unit != null and tapped_unit == null and not selected_unit.has_moved:
		if engine.move_unit(selected_unit, cell):
			_refresh_all()
			_after_player_action()
			return
		return

	# Тап мимо — сброс выбора.
	if tapped_unit == null:
		selected_unit = null
		selected_ability = null
		_refresh_all()


func _after_player_action() -> void:
	if engine.battle_over:
		return
	if selected_unit != null and selected_unit.has_moved and selected_unit.has_acted:
		selected_unit = null
		selected_ability = null
		engine.end_turn()


func _on_end_turn_pressed() -> void:
	if engine.battle_over or is_busy:
		return
	var active := engine.active_unit()
	if active == null or active.team != BattleUnit.TEAM_PLAYER:
		return
	selected_unit = null
	selected_ability = null
	engine.end_turn()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


# ---------- Обновление UI и реакция на сигналы ----------

func _on_turn_started(unit: BattleUnit) -> void:
	if engine.battle_over:
		return
	_turn_label.text = "Раунд %d — Ход: %s" % [engine.round_number, unit.display_name]
	selected_unit = null
	selected_ability = null
	_refresh_all()
	if unit.team == BattleUnit.TEAM_ENEMY:
		_run_ai(unit)


func _run_ai(unit: BattleUnit) -> void:
	is_busy = true
	await get_tree().create_timer(0.5).timeout
	if engine.battle_over or engine.active_unit() != unit:
		is_busy = false
		return
	engine.run_ai_turn(unit)
	await get_tree().create_timer(0.4).timeout
	if not engine.battle_over:
		engine.end_turn()
	is_busy = false


func _on_unit_moved(unit: BattleUnit, _path: Array) -> void:
	var view: UnitView = unit_views.get(unit)
	if view == null:
		return
	var tween := create_tween()
	tween.tween_property(view, "position", cell_to_pixel(unit.cell), 0.25)
	view.z_index = 100 + unit.cell.x + unit.cell.y


func _on_unit_damaged(target: BattleUnit, _amount: int) -> void:
	var view: UnitView = unit_views.get(target)
	if view != null:
		view.refresh()


func _on_battle_ended(battle_winner: int) -> void:
	if battle_winner == BattleUnit.TEAM_PLAYER:
		_overlay_label.text = "Победа!"
	else:
		_overlay_label.text = "Поражение"
	_overlay.visible = true
	_refresh_all()


func _refresh_all() -> void:
	_clear_highlights()
	_refresh_highlights()
	_refresh_panel()


func _refresh_highlights() -> void:
	if engine.battle_over or selected_unit == null:
		return
	if selected_ability != null:
		var target_cells: Array = []
		for target: BattleUnit in engine.ability_targets(selected_unit, selected_ability):
			target_cells.append(target.cell)
		_highlight_cells(target_cells, Color(0.9, 0.25, 0.2, 0.55))
	elif not selected_unit.has_moved:
		var occupied := engine.occupied_cells()
		occupied.erase(selected_unit.cell)
		_highlight_cells(
			engine.grid.reachable_cells(selected_unit.cell, selected_unit.move_limit, occupied).keys(),
			Color(0.3, 0.5, 0.9, 0.5)
		)


func _refresh_panel() -> void:
	for child in _abilities_box.get_children():
		child.queue_free()
	if engine.battle_over or selected_unit == null or selected_unit.has_acted:
		return
	for ability: AbilityResource in selected_unit.abilities:
		var btn := Button.new()
		btn.text = "%s (рад. %d)" % [ability.display_name, ability.attack_range]
		btn.custom_minimum_size = Vector2(180, 56)
		btn.disabled = selected_ability == ability
		btn.pressed.connect(_on_ability_pressed.bind(ability))
		_abilities_box.add_child(btn)


func _on_ability_pressed(ability: AbilityResource) -> void:
	selected_ability = ability
	_refresh_all()
