# Upgrading a project to a newer template version

Use when a game started from an older version of this template should take the fixes in a newer one. `codeplate.json` names the version a project started from.

## How

1. Get both versions of the template: the one the project started from (keep its zip) and the new one.
2. Commit the project first, so every step can be undone.
3. For each file listed below for the versions in between, compare the old template's copy with the project's:
   - **The project never changed it:** copy the new template's file over it.
   - **The project changed it:** merge the two sets of changes. With git, a three-way merge per file does this: `git merge-file project/<file> old-template/<file> new-template/<file>` keeps the project's edits and adds the template's, and marks the conflicts to resolve by hand. A newer template often already does what the project added by hand (a feature both wrote); then keep the template's version and put back only what is the project's own.
   - **New in the template:** copy it in.
4. Don't copy the template's placeholder art, levels, `docs/project.md`, `README.md` or `CREDITS.md` over the project's own.
5. Copy the whole `addons/codeplate/` folder from the new template; projects shouldn't edit it.
6. Read the behaviour changes for each version below and check the project against them.
7. Run both check commands from `AGENTS.md`, then take the screenshots listed for each version.

## 1.4.1 (add-on)

**Changed:** the whole `addons/codeplate/` folder, `codeplate.json`, `ui/title.gd`.

**Behaviour changes:**
- **Back on the settings screen.** `CodePlateSettings.go_back()` goes one step back, as its Back button does: the Credits page goes to the settings page, the settings page closes the screen. The title's `go_back()` (Android Back) now calls it instead of pressing the screen's `BackButton` by name. A screen the project added that opens Settings should do the same.
- **The settings fit check** is now `test_settings_fit_the_project_view` (it was `test_settings_fit_a_short_wide_view`). It fits the settings screen into the project's own viewport size, and also turned on its side when `display/window/handheld/orientation` is sensor, instead of always 1280×720. A portrait game can now raise its theme's button size without failing it. The Fullscreen, Credits and Reset row is only asked for on a view under 800 px tall.
- **The runtime-data check** (`test_export_presets_ship_runtime_data`) no longer counts files under `store/`, `android/` or any folder that holds a `.gdignore` as game data, so store listing texts, art source packs and Godot's Android build template can sit in the project without being shipped. Data the game reads at runtime must stay outside those folders.

**Look at:** `screen=credits`, then press Back once: the settings page should show; press it again and Settings should close.

## 1.4.0 (phones)

**Changed:** `AGENTS.md`, `README.md`, `.gitignore`, `project.godot`, `export_presets.cfg`, `autoload/game.gd`, `config/game_config.gd`, `config/game_config.tres`, `core/battle.gd`, `core/bot.gd`, `core/content.gd`, `core/level_data.gd`, `game/battle_screen.gd`, `game/cell_menu.gd`, `game/hud.gd`, `game/overlays.gd`, `game/pause_menu.gd`, `game/result_panel.gd`, `game/units_view.gd`, `ui/title.gd`, `ui/level_select.gd`, `ui/level_select.tscn`, `tools/balance.gd`, `tools/screenshot_hooks.gd`, `checks/tests/test_battle.gd`, `checks/tests/test_content.gd`, `checks/tests/test_game.gd`, the template's levels (`content/levels/level_0*.json`: `towers`, `tip`, and level 5's `hp_mult`), and the docs (`docs/architecture.md`, `docs/content.md`, `docs/customization-map.md`, recipes `add-level`, `add-second-path`, `add-touch-polish`, `export-android`, `tune-balance`).

**New:** `UPGRADING.md`, `game/touch.gd`, `ui/splash.gd`, `ui/splash.tscn`, `checks/tests/test_phone.gd`.

**Behaviour changes:**
- **The view fills the screen.** `project.godot` switches to `window/stretch/mode="canvas_items"` with `aspect="expand"`: a wider screen shows a wider view, a taller one a taller view, instead of black bars, and everything is drawn at the screen's resolution. `2d/snap/snap_2d_transforms_to_pixel` is off and `UnitsView` no longer rounds positions, so enemies move smoothly when the map is scaled up. `Game.ui_root()` now covers the visible view and follows resizes: overlays the project added that were laid out for exactly 480×270 need anchors or a `_fit()` like `ui/level_select.gd`'s.
- **The map scales.** `BattleScreen.MAP_ORIGIN` is gone. `fit_layout()` places the HUD and scales the map on every resize, and `cell_to_screen()` and `screen_to_cell()` are now **instance** methods (with `cell_rect()`, `map_rect()` and `tap_target()`). Code or checks that called `BattleScreen.cell_to_screen()` on the class must call it on the battle screen. In a 480×270 window without the touch layout the map is still 1:1 at (0, 30).
- **The touch layout** (`touch_ui`, on touch screens by default): the safe area (`Game.safe_insets()`), buttons of at least 48 dp (`min_touch_share`, `Touch.enlarge()`), buttons and buildable cells above the bottom 15% (`bottom_clear_fraction`), taps that snap to a nearby cell (`tap_snap`), and a HUD column at the right on wide phones. A project that moved HUD buttons by hand should redo that in `Hud.fit()`.
- **Two taps to spend.** With the touch layout, Build, Upgrade and Sell take two taps (`confirm_spending`, `confirm_seconds`). Build buttons the player can't afford stay tappable on touch screens (the price turns red) so the tower can still be looked at. Checks that press a menu button once and expect a tower should press again when `Touch.is_armed()` (see `_press()` in `test_game.gd`).
- **Tower numbers** show in the cell menu (`CellMenu.tower_text()`). `open_build()` and `open_tower()` now take the cell's rectangle and the area the menu may use, not a screen point.
- **Android Back** no longer quits (`quit_on_go_back=false`). It calls the current scene's `go_back()`: the battle pauses, then leaves for the level select; the level select goes to the title; the title closes Settings or asks before leaving. A scene the project added needs a `go_back()`. Leaving the app mid-level opens the pause menu and mutes the sound until the app returns.
- **The splash hook.** The game starts on `ui/splash.tscn`, which shows `splash_image` and `splash_text` from the config, or goes straight to the title when both are empty (the default). The engine's boot image is off (`boot_splash/show_image=false`).
- **Levels** may list the towers they offer (`"towers"`) and a `"tip"`. The template's levels bring the frost lantern in on level 2 and the sun mirror on level 3. Projects without these fields offer every tower, as before.
- **Balance checks.** `test_every_level_is_fair` also plays every level with enemies `bot_hp_margin` (5%) tougher; a level on a cliff edge now fails (`tools/balance.gd -- tune=1` finds a steadier `hp_mult`). New checks: `test_towers_come_in_one_at_a_time` (with `towers` set, at most one new tower per level after the first, with a `tip`) and `test_flyers_have_room_to_fly` (`min_flight_cells`).
- **Checks no longer depend on the template's content.** `test_battle.gd`'s view checks build their own tower and enemy from plain defaults (side-view, no `base` or `muzzle` unless the check adds them) with their own legend, and take the base art from the game's towers; `test_game.gd`'s number-keys check opens the first level that offers every tower.
- **Export presets:** a second Android preset, "Android test APK" (arm64-v8a and x86_64, for emulators); both Android presets set `screen/edge_to_edge=true` and every `permissions/*` to false, and every preset leaves `codeplate.json` and `package.json` out. `android/` is git-ignored.
- **Licences:** rule 8 in `AGENTS.md` now matches the add-on's check: art made for the user, or given by them, is `"license": "user-owned"` with their name in `credit`. A font's licence text goes in `licenses/`, outside `assets/`.

**Look at:** `screen=title`, `screen=levels stars=2`, `screen=battle wave=3` and `screen=battle menu=build`, each plain (a 1440x810 window), with `touch=1 size=2400x1080 safe=24,0,0,10`, and with `touch=1 size=2048x1536`.

## 1.3.0

**Changed or new:** `.gitignore`, `.editorconfig`, `.gitattributes`, `AGENTS.md`, `codeplate.json`, the whole `addons/codeplate/` folder, `assets.json`, `checks/tests/` (`test_battle`, `test_content`, `test_game`, `test_settings`), `content/legend.json`, `content/towers.json`, `core/battle.gd`, `core/bot.gd`, `core/content.gd`, `core/entities.gd`, `core/event.gd`, `core/level_data.gd`, `core/map.gd`, `game/battle_screen.gd`, `game/fx.gd`, `game/hud.gd`, `game/map_view.gd`, `game/sprites.gd`, `game/units_view.gd`, `project.godot`, `export_presets.cfg`, `tools/balance.gd`, new `tools/import_atlas.gd`, `docs/architecture.md`, `docs/content.md`, `docs/customization-map.md`, recipes `add-enemy`, `add-second-path`, `add-tower`, `export`, `retheme`, `tune-balance`, and the `.gdignore` files in `docs/`, `export/` and `shots/`.

**Behaviour changes:**
- **More than one road per map.** `R` and `Q` in `content/legend.json` mark route 1's spawn and path; a wave group's `"route"` picks the road. Flyers fly from their route's spawn.
- **Art scale comes from `assets.json`.** Each entry may have `scale` and `smooth`; every sprite goes through `Sprites.style()`. Art drawn at another cell size no longer needs resizing by hand.
- **Turning towers and enemies.** A tower with a `"base"` draws that base fixed and its sprite as a head that turns to its target; `"muzzle"` lists a barrel length per level, and shots leave from its end. An enemy with `"view": "top"` is seen from above and turns to its heading.
- **The bot's build order** moved to `"bot_order"` in `content/towers.json`.
- **Balance what-ifs:** `tools/balance.gd` takes `gold=`, `hp=` and `margin=1` without editing a file.
- **Atlases:** `tools/import_atlas.gd` cuts strips out of a TexturePacker atlas.
- **The add-on's asset check** accepts only `CodePlate-original`, `CC0-1.0`, `OFL-1.1` and `user-owned` as licences. A project that put its game's name in `license` must change those entries to `user-owned` (the name goes in `credit`).

**Look at:** every screen, and a battle with the project's own towers and enemies, to catch art drawn at the wrong size or facing the wrong way.
