# Tune the balance

Use when the user says a level is too easy or too hard, or a tower is too strong or useless.

1. **Get the report first:**
   ```
   godot --headless --path . --script res://tools/balance.gd
   godot --headless --path . --script res://tools/balance.gd -- level=level_03 waves=1
   ```
   Each row shows the bot's result, lives left, stars and towers, and the "idle" run (nobody builds) that must lose. `waves=1` prints the bot's gold, lives and towers as each wave starts, which shows where it falls behind.
2. **Change one thing at a time,** then run the report again:
   - **Gold:** `start_gold` per level, `bounty` per enemy, `sell_refund` and `early_bonus_per_second` in the config. A starved economy (the bot sitting on 1–2 towers for several waves) is the most common problem.
   - **Enemies:** `hp`, `speed`, `armor`, or a level's `hp_mult`.
   - **Towers:** `cost`, `damage`, `rate`, `range`. Range matters most on winding maps.
   - **Waves:** `count`, `gap`, and `delay` between groups.
   - **Time between waves:** `wave_gap`.
3. **The targets** in the config's Balance targets group: `bot_min_lives` (the bot must keep this share of lives on every level) and `idle_must_lose`. For a harsher game, lower `bot_min_lives` and tell the user.
4. Report to the user in plain words, e.g. "level 4 now ends with 10/20 lives instead of 15; the flyer waves bite harder".

## Verify
1. Run the checks; `test_every_level_is_fair` must pass.
2. Ask the user to play the changed levels. The bot can't judge fun, and it builds from a fixed list.
