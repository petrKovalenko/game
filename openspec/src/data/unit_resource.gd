class_name UnitResource
extends Resource
## Декларативное описание класса героя или типа врага (design: add-vertical-slice, D5).
## Правка данных не должна требовать изменения кода.

@export var id: String = ""
@export var display_name: String = ""
@export var hp: int = 10
@export var damage: int = 1
## Очередь ходов: больше инициатива — раньше ход в раунде.
@export var initiative: int = 5
## Лимит клеток перемещения за ход.
@export var move_limit: int = 2
## Массив AbilityResource.
@export var abilities: Array = []
## Цвет представления в векторном рендере среза.
@export var color: Color = Color.WHITE
