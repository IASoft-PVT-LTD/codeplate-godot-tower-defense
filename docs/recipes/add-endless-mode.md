# Add endless mode

Use when the user wants a mode where waves keep coming, each a bit tougher, and the score is how many you survive.

1. **Generated waves.** Give `LevelData` an `endless := false` flag (from `"endless": true` in the level JSON). In `Battle`, when `endless` and the scripted waves run out, build the next wave instead of winning:
   ```gdscript
   func _endless_wave(n: int) -> Dictionary:
   	var kinds := ["grunt", "runner", "armored", "flyer", "splitter"]
   	var groups: Array = []
   	for i: int in 1 + n / 4:
   		groups.append({"enemy": kinds[rng.randi_range(0, kinds.size() - 1)], "count": 8 + n, "gap": maxf(0.3, 1.0 - n * 0.03), "delay": i * 3.0})
   	return {"groups": groups}
   ```
   Append it to `level.waves` before `_start_wave()`, and scale health with the wave number (e.g. multiply `max_hp` by `1.0 + 0.08 * wave` in `_spawn()` when endless). Use `rng` so runs stay deterministic.
2. **Never win.** `total_waves()` should return a large number for the HUD ("WAVE 12"), and `_wave_flow()` must skip the WIN branch when endless.
3. **Score.** On LOSE, record `wave` as the best for that level in `autoload/game.gd` (a `best_wave` dictionary saved next to `stars`). Show it on the result panel and the level card.
4. **A level for it.** Add `content/levels/level_endless.txt` + `.json` with `"endless": true`, or a separate button on the level select that loads an existing map with the flag set.
5. **Checks.** `test_battle.gd`: an endless level keeps starting waves past its list and never wins. The fairness check should skip endless levels (they can't be won); make that explicit in `test_every_level_is_fair`.

## Verify
1. Run the checks.
2. Run the bot on the endless level and report how far it gets.
