# Add a spell (tap-to-cast ability)

Use when the user wants an ability the player triggers, with a cooldown. The example is a **meteor** that hits everything in a circle, with a 30-second cooldown.

1. **Config.** In `config/game_config.gd` (+ `.tres`): `meteor_damage := 60.0`, `meteor_radius := 36.0`, `meteor_cooldown := 30.0`.
2. **Rule.** In `core/battle.gd`, add a cooldown and a command:
   ```gdscript
   var meteor_ready_tick := 0

   func cast_meteor(at: Vector2) -> bool:
   	if state != State.RUNNING or tick < meteor_ready_tick:
   		return false
   	meteor_ready_tick = tick + GameConfig.ticks(config.meteor_cooldown)
   	for e: Entities.Enemy in enemies.duplicate():
   		if e.hp > 0.0 and e.pos.distance_to(at) <= config.meteor_radius:
   			_damage(e, config.meteor_damage, "meteor", true)
   	_emit(SimEvent.Type.SPLASH, at, config.meteor_radius, "meteor")
   	return true
   ```
   `at` is in map pixels. The cooldown counts ticks, so it follows game speed and pause.
3. **HUD.** Add a button to `game/hud.gd` that shows the cooldown (`(meteor_ready_tick - tick) * GameConfig.DT`) and emits `spell_pressed`.
4. **Aiming.** In `BattleScreen`, the button sets `aiming = true`. The next map tap calls `battle.cast_meteor(GameConfig.cell_center(cell))` instead of `tap_cell()`. Show the radius with the range ring while aiming. Escape cancels.
5. **Feel.** Handle the event: `fx.burst(Fx.BOOM, ...)` scaled up, a shake, a sound.
6. **Checks.** `test_battle.gd`: casting hurts enemies in the circle and not outside, and a second cast during the cooldown fails. `test_game.gd`: pressing the button and tapping casts.

## Verify
1. Run the checks.
2. The bot doesn't cast spells, so the balance report is unchanged. Tell the user it makes levels easier for people.
3. Screenshot a battle with the button visible.
