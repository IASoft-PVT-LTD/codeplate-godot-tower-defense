# Re-theme the game

Use when the user wants their own setting, towers, enemies and names, e.g. "a candy castle defended from ants".

1. **Name.** Set `config/name` in `project.godot`; the title shows it. Set `package/name` in the Android preset of `export_presets.cfg` to the same (a check wants them equal). The save folder is `config/custom_user_dir_name` (it ships as `lantern-keep`): set it to a slug of the new name now if nobody has played yet, and never change it once players have saves. Change the tagline and hint in `ui/title.tscn`, and the window icon `assets/ui/icon.png`.
2. **Tiles.** `assets/tiles/grass.png`, `path.png`, `rock.png`, `water.png` are strips of 24×24 variants. Keep variants of one tile seamless with each other. Paths look best with a slightly darker rim. `decor.png` holds props that block building; `spawn.png` and `goal.png` mark the ends.
3. **Towers.** Each tower's `sprite` is a strip with one 24×32 frame per level (base on the bottom 24 px), drawn on `assets/towers/base.png`. Make each level visibly grander. Update `assets/ui/tower_icons.png` (24×24, in `icon` order) and the names and descriptions in `content/towers.json`.
4. **Shots.** `shot` art points right; the view rotates it. Ray towers stretch a short horizontal beam strip.
5. **Enemies.** Walk strips facing right, any frame size (update `assets.json`). Rename them in `content/enemies.json`. Keep silhouettes distinct and contrasting with the path. Seen from above? Set `"view": "top"` on the enemy (`docs/content.md`).
   - **Art made for another cell size.** The map cell is 24 px. For art drawn at 48 px, give its `assets.json` entry `"scale": 0.5` (default 1) and, for smooth art that shouldn't stay crisp, `"smooth": true` (default false: nearest-neighbour). Every sprite the game draws from that asset follows, with no code change. Ask the user whether to shrink the files themselves or use `scale`.
   - **Art in an atlas.** `tools/import_atlas.gd` cuts strips out of a TexturePacker JSON atlas ("hash" or "array" format): `godot --headless --path . --script res://tools/import_atlas.gd -- atlas=art/pack.json map=art/mapping.json`, where the mapping file lists each strip and its frames in order, like `{"assets/enemies/scout.png": ["scout_0", "scout_1"]}`. It checks that the frames are the same size and prints the `width`, `height` and `frames` to put in `assets.json`.
6. **Effects and UI.** `assets/fx/`, `assets/ui/icons.png` (coin, heart, flag, play, fast, pause), `star.png`, `lock.png`, `title_bg.png`, `ui/theme.tres`, the font.
7. **Texts.** Level `name`s in `content/levels/*.json`; result texts in `game/result_panel.gd`.
8. Record every new asset in `assets.json` with its `license` and `credit`, and add a line to `CREDITS.md` (players see it on title > Settings > Credits). Keep its first line, the CodePlate credit.

## Verify
1. Run the import and the checks: they catch missing files, unlisted assets and towers with too few frames.
2. Screenshots: `screen=title`, `screen=levels stars=2`, `screen=battle level=1 wave=3`, `screen=battle level=2 menu=build`. Check that enemies stand out on the path, towers read at every level, and the menus fit.
