class_name UnitView
extends Node2D
## Векторное представление юнита: кружок команды + полоса HP.

var unit: BattleUnit
var color := Color.WHITE


func setup(p_unit: BattleUnit, p_color: Color) -> void:
	unit = p_unit
	color = p_color
	_redraw()


func _draw() -> void:
	if unit == null:
		return
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 2.0)
	var ratio := clampf(float(unit.hp) / float(unit.max_hp), 0.0, 1.0)
	draw_rect(Rect2(-16, -27, 32, 5), Color(0, 0, 0, 0.6))
	var hp_color := Color(0.2, 0.85, 0.3) if ratio > 0.35 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(-16, -27, 32.0 * ratio, 5), hp_color)


func refresh() -> void:
	_redraw()


func _redraw() -> void:
	queue_redraw()
