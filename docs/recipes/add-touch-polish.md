# Tune the touch layout for phones

Use when the game targets phones and tablets, or the user wants to change how it plays with a thumb. The template already has a touch layout; this recipe is about its settings and about keeping new screens in line with it.

## What the template does on a touch screen

`touch_ui` in `config/game_config.tres` turns the touch layout on: `"auto"` (touch screens and mobile exports), `"always"` (also on a computer, for testing) or `"off"`. With it on:

- **The safe area.** Nothing the player presses sits under a camera cutout, a rounded corner or the gesture bar. `Game.safe_insets()` reads them from the phone (in view units); `Game.safe_rect()` is the visible view minus them. Every screen lays itself out inside it on each resize.
- **The bottom strip.** Every button, and every buildable map cell, ends at least `bottom_clear_fraction` (0.15) of the screen's height above the bottom edge, where a resting thumb or a swipe home would take the tap. `Game.bottom_limit()` gives the line. Path and decoration cells may go lower.
- **48 dp targets.** Buttons are at least `min_touch_share` (0.134) of the view's height: 48 dp on a phone 360 dp tall in landscape, the smallest common one. Each screen calls `Touch.enlarge(self)` once built. A map cell can't be that big and still fit 20 columns, so a tap up to `tap_snap` (0.6) of a cell off a buildable cell or a tower still picks it (`BattleScreen.tap_target()`).
- **The HUD** is a bar across the top, or a column at the right when that leaves a bigger map (wide phones). `BattleScreen.fit_layout()` decides on every resize and scales the map into the rest. Cell positions on screen come from the instance helpers `cell_to_screen()`, `screen_to_cell()`, `cell_rect()` and `map_rect()`.
- **Two taps to spend.** With `confirm_spending` `"touch"` (the default), Build, Upgrade and Sell take two taps (`Touch.confirm()`): the first lights the button, shows the tower's range and a ghost of it on the map, and its numbers in the menu; a second tap within `confirm_seconds` does it. Tapping the cell again or anywhere off the menu cancels. The targeting button is one tap. `"always"` does the same with a mouse; `"off"` builds on one tap everywhere.
- **Tower numbers.** A touch screen never shows a tooltip, so the cell menu has a line under its buttons with the tower's damage, range in tiles, shots per second and specials (`CellMenu.tower_text()`, built from `content/towers.json`).

Sizes are in view units. The view is 480x270 on a 16:9 window and grows with the screen's shape (`window/stretch/aspect="expand"`): 600x270 on a 20:9 phone, 480x360 on a 4:3 tablet. How many millimetres a cell is depends on the phone, so judge sizes in dp, as above.

## Steps

1. **Ask what to change**, in the user's words ("the buttons feel small", "I keep selling by accident"), and map it to a setting: `min_touch_share`, `bottom_clear_fraction`, `tap_snap`, `confirm_spending`, `confirm_seconds`. Change the setting in `config/game_config.tres`, not the code.
2. **A new screen or overlay** follows the same rules: take its root from `Game.ui_root(layer)` (a CanvasLayer) or anchor it full-rect, place its buttons inside `Game.safe_rect()` and above `Game.bottom_limit()`, call `Touch.enlarge()` once built, and give it a `go_back()` if it is a scene of its own (Android's Back calls the current scene's). Connect the viewport's `size_changed` to a `_fit()` like `ui/level_select.gd`'s.
3. **A new spending button** (a spell, a hero) uses `Touch.confirm(button, "CAST?", action, preview)` when `Game.confirms_spending()` is true, like `CellMenu.open_build()`.
4. **Landscape only.** The game is landscape by default. A portrait game needs `display/window/handheld/orientation` in `project.godot` and a new look at every layout, since the HUD and the map assume a wide screen.
5. **Checks.** `checks/tests/test_phone.gd` opens every screen at four phone and tablet shapes with a pretend cutout and gesture bar, and fails on a button that is too small, outside the safe area, overlapping another or in the bottom strip, and on a buildable cell in the bottom strip. Add a new screen to `test_menus_fit_phones_and_tablets()`.

## Verify

1. Run the checks.
2. Screenshot the battle and its menus as a phone sees them: `screen=battle menu=build touch=1 size=2400x1080 safe=24,0,0,10`, then `menu=tower`, and `screen=battle touch=1 size=2048x1536` for a tablet.
3. If a phone or emulator is around, export to Android (`export-android.md`) and try it with a thumb; otherwise say it's untested on a device.
