class_name AbilityResource
extends Resource
## Декларативное описание способности юнита (design: add-vertical-slice, D5).

@export var id: String = ""
@export var display_name: String = ""
## Радиус действия по манхэттенскому расстоянию на сетке.
@export var attack_range: int = 1
## Итоговый урон = damage юнита * damage_multiplier.
@export var damage_multiplier: float = 1.0
