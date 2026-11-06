# Design: fix-turn-handoff

## Root Cause

Поток ходов: [`end_turn()`](../../src/logic/battle_engine.gd:64) инкрементирует `turn_index` и при выходе за пределы `round_order` вызывает [`_start_round()`](../../src/logic/battle_engine.gd:191), который сбрасывает `turn_index = -1`. Затем `end_turn()` безусловно выполняет `round_order[turn_index]` с индексом `-1`:

```gdscript
# battle_engine.gd, end_turn() — проблемный фрагмент
turn_index += 1
if turn_index >= round_order.size():
    _start_round()                      # turn_index = -1
var unit: BattleUnit = round_order[turn_index]  # round_order[-1] → ПОСЛЕДНИЙ юнит нового раунда
...
turn_started.emit(unit)                 # сигнал для одного юнита...
```

Последствия:

1. `turn_started` излучается для последнего юнита нового раунда, но [`active_unit()`](../../src/logic/battle_engine.gd:49) возвращает `null` (ветка `turn_index < 0`) — рассинхрон логики и представления.
2. В [`src/scenes/battle.gd`](../../src/scenes/battle.gd:288) `_run_ai()` прерывается проверкой `engine.active_unit() != unit`; ход игрока невозможен, т.к. `_handle_tap` и `_on_end_turn_pressed` требуют ненулевой `active_unit()` с `TEAM_PLAYER`. Итог — дедлок на старте каждого нового раунда.
3. Рекурсивный пропуск мёртвых юнитов маскирует баг только если «выбранный» через `[-1]` юнит мёртв.

## Fix

Минимальная правка в `end_turn()`: после перехода на новый раунд явно устанавливать `turn_index = 0`:

```gdscript
turn_index += 1
if turn_index >= round_order.size():
    _start_round()
    turn_index = 0
```

`_start_round()` сохраняет `turn_index = -1` (используется как «ещё не ходили» при `start_battle()`), инвариант: после `end_turn()` `active_unit()` всегда возвращает юнит, для которого излучён `turn_started`.

Рекурсивный пропуск мёртвых (`end_turn()` внутри себя) сохраняется: инкремент с `turn_index = 0` идёт по новому порядку корректно.

## Alternatives

- **Переписать очередь на «вынуть из очереди»** (pop-модель вместо индекса) — чище, но меняет публичный контракт (`turn_index`, `round_order`), на который опираются тесты и представление. Отклонено как избыточное для багфикса.
- **Гард в представлении** (обрабатывать `turn_started` при `active_unit() == null`) — лечит симптом, не причину; рассинхрон остаётся. Отклонено.

## Risks

- Низкий риск: правка локальна, поведение внутри раунда не меняется, seed-детерминизм ([`TurnQueue.build_round`](../../src/logic/turn_queue.gd:16)) не затрагивается.
- Регрессия покрывается новым тестом полного цикла раунда.
