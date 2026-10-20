# Add a level

Use when the user wants a new map with its own waves, or a redesigned map.

1. **Map.** Copy `content/levels/level_06.txt` to `level_07.txt` and edit it as text:
   - 20 columns × 10 rows fills the screen below the HUD. The battle screen scales the map to the screen, so on a phone the cells are smaller than on a computer.
   - `S` spawn, `G` goal, `P` path, `.` buildable, other characters from `content/legend.json` (rocks, water, props).
   - One path, no forks: parallel stretches need a non-path cell between them.
   - Longer, winding paths give towers more time; flyers ignore the path, so long paths make flyers relatively stronger.
   - Flyers cross in a straight line from the spawn to `G`. On a level that sends them, keep that line at least `min_flight_cells` (8) cells long, or they arrive before a tower gets a shot; `test_flyers_have_room_to_fly` checks it.
   - On phones the bottom 15% of the screen stays clear of anything the player taps, and that includes buildable cells. A bottom row of path, water or decoration lets the map be drawn bigger there.
2. **Settings and waves.** Copy `level_06.json` to `level_07.json`: `name`, `start_gold`, `lives`, `hp_mult`, `waves` (see `edit-waves.md`), and optionally `towers` (the towers it offers) and `tip` (a line shown when it starts). A level that brings in a new tower or enemy should say what it does in its `tip`.
3. Levels are played in file-name order, and each unlocks the next. The level select adds a card on its own.
4. **New map characters:** add them to `content/legend.json` (a `kind`, a `tile`, maybe a `decor` frame) and the tile art to `assets/tiles/`.
5. **Bigger maps** (more than 20×10): add a `Camera2D` to `BattleScreen` that the player drags, offset the input math (`screen_to_cell()` must add the camera position), and clamp it to the map. Keep the HUD on its CanvasLayer.
6. Run `tools/balance.gd -- level=level_07 waves=1` and tune until the bot wins with lives to spare. `tune=1` sweeps the level's `hp_mult`: pick a value with a few steps of wins above it, since the fairness check also plays it with enemies `bot_hp_margin` (5%) tougher.

## Verify
1. Run the checks: map errors name the row and column, and `test_every_level_is_fair` plays the new level.
2. Screenshot `screen=battle level=7 wave=3`, the same with `touch=1 size=2400x1080 safe=24,0,0,10` (a phone), and `screen=levels stars=2`.
