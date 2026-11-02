class_name TurnQueue
extends RefCounted
## Очередь ходов по инициативе (design D4).
## При равной инициативе порядок детерминирован через seeded RNG.

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value > 0:
		rng.seed = seed_value


## Возвращает порядок раунда: сортировка по убыванию инициативы,
## равные — по детерминированному случайному ключу.
func build_round(units: Array) -> Array:
	var keyed: Array = []
	for unit: BattleUnit in units:
		keyed.append({
			"initiative": unit.initiative,
			"tie": rng.randi(),
			"unit": unit,
		})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["initiative"] != b["initiative"]:
			return a["initiative"] > b["initiative"]
		return a["tie"] < b["tie"]
	)
	var order: Array = []
	for entry: Dictionary in keyed:
		order.append(entry["unit"])
	return order
