# Polish touch controls for phones

Use when the game targets phones: tapping already works (tap a tile for the build menu, a tower for its menu, and the HUD buttons), and these steps make it comfortable on a small screen.

1. **Bigger targets.** The view is 480×270 scaled up, so a 24 px cell is about 7 mm on a phone. Make the build buttons in `CellMenu.open_build()` larger (`custom_minimum_size`), and consider showing the menu centered at the bottom of the screen instead of beside the cell.
2. **Confirm before building.** First tap selects a tower button and shows its range at the cell; second tap on the same button builds. Keep a `pending_tower` in `CellMenu`.
3. **Long-press for info.** In `BattleScreen._unhandled_input()`, start a timer on press; if it's held 0.5 s on a tower, show its stats panel (damage, rate, kills) instead of the menu.
4. **Drag to build.** Drag a tower icon from a bottom bar onto the map: on release, `build(id, screen_to_cell(pos))`. Show the range ring while dragging.
5. **Landscape only.** Set `display/window/handheld/orientation` in `project.godot`.
6. **Checks.** Simulate touches with `mouse_button()` in `checks/tests/test_game.gd` (Godot emulates touch from the mouse): a two-tap build, a long-press opening the info panel.

## Verify
1. Run the checks.
2. Screenshot the menus with `menu=build` and `menu=tower`.
3. Ask the user to try it on a phone (export to web, open the page on the phone).
