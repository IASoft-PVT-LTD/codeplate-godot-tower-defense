# Tune the balance

Use when the user says a level is too easy or too hard, or a tower is too strong or useless.

1. **Get the report first:**
   ```
   godot --headless --path . --script res://tools/balance.gd
   godot --headless --path . --script res://tools/balance.gd -- level=level_03 waves=1
   ```
   Each row shows the bot's result, lives left, stars and towers, and the "idle" run (nobody builds) that must lose. `waves=1` prints the bot's gold, lives and towers as each wave starts, which shows where it falls behind.

   **What-ifs without editing a file:** `gold=300` plays the level with another starting gold, `hp=1.3` with another health multiplier, and `margin=1` also finds the least starting gold the bot needs to keep `bot_min_lives` (it prints "slack", the level's gold divided by that: higher is more forgiving). Use them to size a change before you make it:
   ```
   godot --headless --path . --script res://tools/balance.gd -- level=level_02 gold=200 hp=1.2
   godot --headless --path . --script res://tools/balance.gd -- margin=1
   ```
   **Find the cliff edge.** The bot's result can jump from "untouched" to "lost" over a few percent of enemy health, so a level that passes may be one small change from failing. `tune=1` plays the level at `hp_mult` 0.6 to 1.6 in 0.05 steps and prints the bot's lives at each:
   ```
   godot --headless --path . --script res://tools/balance.gd -- level=level_05 tune=1
   ```
   Pick an `hp_mult` in a steady stretch with at least one or two winning steps above it. The fairness check plays every level again with enemies `bot_hp_margin` (5%) tougher and fails a level on the edge.
2. **Change one kind of thing at a time** (gold, then enemies, then towers, then waves), run the report after each change, and say what each did. Don't stack several changes and report only the end result:
   - **Gold:** `start_gold` per level, `bounty` per enemy, `sell_refund` and `early_bonus_per_second` in the config. A starved economy (the bot sitting on 1–2 towers for several waves) is the most common problem.
   - **Enemies:** `hp`, `speed`, `armor`, or a level's `hp_mult`.
   - **Towers:** `cost`, `damage`, `rate`, `range`. Range matters most on winding maps.
   - **Waves:** `count`, `gap`, and `delay` between groups.
   - **Time between waves:** `wave_gap`.
3. **The targets** in the config's Balance targets group: `bot_min_lives` (the bot must keep this share of lives on every level), `bot_hp_margin` (it must still win with enemies this much tougher), `idle_must_lose`, and `min_flight_cells` (how far flyers must fly). For a harsher game, lower `bot_min_lives` and tell the user.
4. Report to the user in plain words, e.g. "level 4 now ends with 10/20 lives instead of 15; the flyer waves bite harder".

## Verify
1. Run the checks; `test_every_level_is_fair` must pass.
2. Ask the user to play the changed levels. The bot can't judge fun, and it builds in the order of `"bot_order"` in `content/towers.json`.
