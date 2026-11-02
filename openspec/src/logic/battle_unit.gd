class_name BattleUnit
extends RefCounted
## Юнит боя в логическом слое: статы + состояние хода (design D2).

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var id: String = ""
var display_name: String = ""
var team: int = TEAM_PLAYER
var hp: int = 1
var max_hp: int = 1
var damage: int = 1
var initiative: int = 0
var move_limit: int = 1
## Массив AbilityResource.
var abilities: Array = []
var cell := Vector2i.ZERO
var has_moved := false
var has_acted := false


static func from_resource(res: UnitResource, unit_team: int, start_cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = res.id
	unit.display_name = res.display_name
	unit.team = unit_team
	unit.hp = res.hp
	unit.max_hp = res.hp
	unit.damage = res.damage
	unit.initiative = res.initiative
	unit.move_limit = res.move_limit
	unit.abilities = res.abilities
	unit.cell = start_cell
	return unit


func is_alive() -> bool:
	return hp > 0
