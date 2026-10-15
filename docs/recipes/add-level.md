# Add a level

Use when the user wants a new map with its own waves, or a redesigned map.

1. **Map.** Copy `content/levels/level_06.txt` to `level_07.txt` and edit it as text:
   - 20 columns × 10 rows fills the screen below the HUD.
   - `S` spawn, `G` goal, `P` path, `.` buildable, other characters from `content/legend.json` (rocks, water, props).
   - One path, no forks: parallel stretches need a non-path cell between them.
   - Longer, winding paths give towers more time; flyers ignore the path, so long paths make flyers relatively stronger.
2. **Settings and waves.** Copy `level_06.json` to `level_07.json`: `name`, `start_gold`, `lives`, `hp_mult`, `waves` (see `edit-waves.md`).
3. Levels are played in file-name order, and each unlocks the next. The level select adds a card on its own.
4. **New map characters:** add them to `content/legend.json` (a `kind`, a `tile`, maybe a `decor` frame) and the tile art to `assets/tiles/`.
5. **Bigger maps** (more than 20×10): add a `Camera2D` to `BattleScreen` that the player drags, offset the input math (`screen_to_cell()` must add the camera position), and clamp it to the map. Keep the HUD on its CanvasLayer.
6. Run `tools/balance.gd -- level=level_07 waves=1` and tune until the bot wins with lives to spare.

## Verify
1. Run the checks: map errors name the row and column, and `test_every_level_is_fair` plays the new level.
2. Screenshot `screen=battle level=7 wave=3` and `screen=levels stars=2`.
