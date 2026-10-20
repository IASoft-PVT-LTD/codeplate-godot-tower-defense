# Godot Tower Defense: agent brief

You are building a game for the user, starting from this template. This brief tells you how the project works, what to ask before changing anything, the rules that keep it working, and how to check every change. Read it all once. Then follow **Interview** before your first edit.

## Start here

This folder is a complete tower defense game, "Lantern Keep", in **Godot 4.7**. It uses GDScript only, a 480×270 pixel-art view scaled up (it grows with the screen's shape, so there are no black bars), and mouse, keyboard or touch. On a phone or tablet it switches to a touch layout: thumb-sized buttons, nothing under the camera cutout or the gesture bar, a map scaled to fit, and two taps to spend gold.

- **Core loop:** enemies walk a path from a cave to the shrine. Tap a tile to build a tower, tap a tower to upgrade or sell it, and start each wave (early for bonus gold). Every enemy that gets through costs lives. The tower menus show each tower's numbers (damage, range, rate), and a level can bring towers in one at a time and show a tip when it starts.
- **Content:**
  - 4 towers with 3 levels each: arrow, splash mortar, frost (slows) and a sun ray that ignores armor.
  - 7 enemies: grunt, runner, armored, flyer (ignores the path), splitter, its spawn, and a boss.
  - 6 levels with stars.
- **Data:** maps are **ASCII text** in `content/levels/`; towers, enemies, waves and gold are **JSON**.
- **Progress:** stars per level, saved, and each level unlocks the next.
- **Screens:** an optional splash logo, title, settings and credits (music and effects volume, fullscreen, reset progress, the credits page), level select, the battle with its HUD, pause and results. Android's Back button pauses a level, then goes back a screen; on the title it asks before leaving.
- **Feel:** 1×/2×/3× speed (any speeds, fractions too, in the config), range rings, hit and splash effects, gold popups, screen shake on leaks.
- **A balance bot** plays every level fast-forward. A check fails if it can't win a level with half its lives left, or with enemies 5% tougher, or if a level can be won without building anything.

**Verify any change** by running both commands from this folder. Both must pass, and the second must end with `CODEPLATE CHECKS: PASS`:

```
godot --headless --path . --import
godot --headless --path . --script res://addons/codeplate/checks/run.gd
```

**Finding Godot.** `godot` in this brief stands for a Godot **4.7.x** binary. Find one in this order and use the first that works:

1. **The `GODOT` environment variable.** CodePlate's own tools use it, so it's often set already: `echo $GODOT` (bash/zsh) or `echo $env:GODOT` (PowerShell).
2. **PATH:** `where godot*` (Windows cmd), `Get-Command godot*` (PowerShell), `which godot godot4` (macOS/Linux).
3. **Typical install paths:**
   - **Windows:** `C:\Program Files\Godot\`, `%LOCALAPPDATA%\Programs\Godot\`, `%USERPROFILE%\scoop\apps\godot\current\`, Steam's `steamapps\common\Godot Engine\`, or a folder like `C:\Godot\`. Use the `Godot_v4.7.x-stable_win64_console.exe` build that sits next to the plain `.exe`: only the console build prints output to your terminal.
   - **macOS:** `/Applications/Godot.app/Contents/MacOS/Godot` (or under `~/Applications/`). Homebrew (`brew install --cask godot`) puts `godot` on PATH.
   - **Linux:** `~/.local/bin/`, `/usr/local/bin/` or `/usr/bin/` (`godot`, `godot4`), the downloaded `Godot_v4.7.x-stable_linux.x86_64`, Flatpak (`flatpak run org.godotengine.Godot`) or Snap (`/snap/bin/godot-4`).
4. **Check the version:** `<binary> --version` must start with `4.7`. Don't use Godot 3.x or another 4.x minor version.
5. **None found?** Ask the user to install Godot 4.7 from godotengine.org and tell you the path.

Once you've found it, write the path in `docs/project.md` so later sessions don't search again.

## Interview

Before you change anything, read `docs/project.md`. If it still contains `<!-- codeplate:project-stub -->`, interview the user first. Ask only what you need, in one short message, and suggest defaults so they can just say "yes":

1. **Theme.** What is being defended, from what, and where? What's the game called? Example: "a candy castle from ants", "a space station from asteroids and drones".
2. **Towers and enemies.** Re-theme the 4 towers and 7 enemies, or design new ones? Any special tower (chain lightning, money farm) or enemy (healer, shielded)?
3. **Levels.** How many, and how long? Keep the 6 maps re-themed, or new layouts?
4. **Assets.** Does the user have art and sound? Where? The placeholders are free to ship.
5. **Extras.** Any of: tap-to-cast spells, endless mode, more than one spawn and path per map? Each has a recipe. Hero units and achievements have no recipe yet: plan them with the user as new features.
6. **Platforms.** Desktop, web or mobile? For phones, see **Phones and tablets** below.

Then replace the stub in `docs/project.md` with their answers as short decisions, and remove the marker. Keep adding decisions there as they're made; it's how the next session knows what was agreed.

Work in small steps. Make one change, verify it, show the result (see **Seeing your work**), then continue.

`README.md` and `codeplate.json` describe the template. Once the user has named their game, rewrite `README.md` for their game and set `config/name` in `project.godot`. Keep `codeplate.json`, `LICENSE.md` and `CREDITS.md`.

## Architecture

See `docs/architecture.md` for details.

| Folder | What lives there |
|---|---|
| `content/` | **The game's content:** `towers.json`, `enemies.json`, `legend.json` (map characters), and `levels/level_NN.txt` (the map) + `level_NN.json` (gold, lives, waves). Every field is explained in `docs/content.md`. |
| `core/` | **The simulation, with no nodes.** `Battle` holds one level being played and every rule, stepped 30 times a second (`step()`, `build()`, `upgrade()`, `sell()`, `call_wave()`). `Map` parses and validates ASCII maps. `Content` loads and validates everything. `LevelData`, `Entities` and `SimEvent` are plain data. `Bot` plays levels for balance checks. |
| `game/` | **The battle screen.** `battle_screen.gd` (`BattleScreen`) steps the battle, handles taps and keys, and turns events into sound and effects. `map_view.gd` and `units_view.gd` draw. `hud.gd`, `cell_menu.gd`, `result_panel.gd` and `pause_menu.gd` are the UI. `touch.gd` sizes buttons for thumbs and makes two-tap buttons. `fx.gd` holds the effects. |
| `ui/` | Splash, title, level select, `theme.tres`. The title's Settings button opens the shared settings + credits screen from `addons/codeplate/`. |
| `autoload/` | `Game` (config, content, saved stars, settings, unlocking, controls, scene changes, Android's Back button, the safe area and the touch layout) and `Audio`. |
| `config/game_config.tres` | Numbers that aren't per-item: sell refund, wave gap, early-call bonus, star thresholds, **balance targets**, the touch layout, the splash, speeds, feel. |
| `addons/codeplate/` | Shared CodePlate tooling: the check runner, `CheckCase`, project-wide checks, the screenshot tool and the settings + credits screen. **Don't edit it.** |
| `tools/` | `balance.gd` (balance report, with `gold=`, `hp=`, `margin=1` and `tune=1` what-ifs), `import_atlas.gd` (cuts strips out of a TexturePacker atlas) and `screenshot_hooks.gd`. |

How the pieces connect:
- `BattleScreen._physics_process` calls `battle.step()` once per tick at 1×, twice at 2×, and alternately once and twice at 1.5× (`take_ticks()` keeps fractional speeds exact).
- The step returns `SimEvent`s (FIRE, HIT, SPLASH, KILL, LEAK, BUILD, WAVE_START, WIN…). `_on_event()` plays sounds and effects.
- Taps and keys call `BattleScreen` commands (`tap_cell`, `build`, `upgrade`, `sell`, `next_wave`), which call `Battle`.
- `UnitsView` reads the battle every frame and draws it, interpolating between ticks. It never changes the battle.
- The battle uses its own seeded random numbers, so the same seed and commands always give the same battle.

## Rules

1. **Rules live in `core/battle.gd`, content lives in `content/`, and `game/` only shows them.**
   - Never compute damage, gold or movement in `game/`.
   - New towers, enemies, levels and waves are data edits when they use an existing kind.
   - A new tower kind or enemy behavior is a code change in `Battle` plus `Content` validation (see the recipes).
2. **All non-content numbers live in `config/game_config.gd` and `.tres`.** Add new tunables there, with defaults.
3. **Keep the simulation deterministic.** In `core/`, use `battle.rng` for randomness (never `randf()`), never read the clock or `Input`, and use `GameConfig.DT` for time. `test_same_seed_same_battle` guards this.
4. **Every level must be fair.** `test_every_level_is_fair` lets the bot play each level. After changing towers, enemies, waves or gold, run `tools/balance.gd` and keep every level winnable by the bot with `bot_min_lives` of its lives, also with enemies `bot_hp_margin` tougher (`tune=1` shows where a level tips over), and unwinnable without towers. If the user wants a harder game, lower the target in the config, and say so.
5. **Maps are text.** Edit `content/levels/level_NN.txt` by hand: every row the same width, one `G`, and for each route one spawn (`S`, or `R` for route 1) joined to `G` by one path without forks (path rows or columns side by side count as a fork). A map with only `S` and `P` is one route. The checks report the route, row and column of any mistake. **Change a level's map only when the user asks for that level:** a new level is the safe default, and a second road in an existing one is their call (`docs/recipes/add-second-path.md`).
6. **Every file under `assets/` is listed in `assets.json`.** Sprites named in `content/` must exist and be listed; a tower's sprite needs a frame per level.
7. **Use typed GDScript.** `:=` from a Dictionary or Array value is an error here, so write the type: `var dmg: float = s["damage"]`. Keep scenes as text, and use no C#.
8. **Keep the template's licensing clean.** Use only the user's own assets, assets they give you, or CC0 assets. Record each new asset's `license` and `credit` in `assets.json`, and don't paste code from tutorials or other projects. `CodePlate-original` marks only the template's own placeholders. For art or sound you make for the user, or files they give you, set `license` to `user-owned` and put their name (their game, team or company) in `credit`; say in `use` if it's a generated placeholder. The add-on's check accepts only `CodePlate-original`, `CC0-1.0`, `OFL-1.1` (for `kind: font`) and `user-owned`. Every file under `assets/` must be listed, so keep a font's licence text outside it, in `licenses/` (say `licenses/MyFont-OFL.txt`): it ships with the game through the presets' `*.txt` filter.
9. **Never weaken a check to make it pass.** If the user changed a rule that a check tests, update that check and say so.
10. **Add checks for new rules.** For a new tower kind, enemy behavior or command, add a check to `checks/tests/test_battle.gd`, using the small made-up level there.
11. **Keep the CodePlate credit.** This template's free license (`LICENSE.md`) asks that anything the user shares shows "Built with CodePlate (codeplate.io)" where people can see it. It's the first line of `CREDITS.md`, which players see on title > Settings > Credits, and a check fails if it goes missing. Keep it when you rebrand. The credit is only optional if `LICENSE.md` is the **CodePlate Pro License**: a copy downloaded with an active CodePlate paid plan comes with it, and names its license ID in `CODEPLATE-LICENSE.txt`. If the user asks to remove the credit and `LICENSE.md` is still the free license, tell them that.

## Verify

1. **Run the two check commands.** Every engine or script error printed during a check fails that check.
2. **After content or balance changes,** run `godot --headless --path . --script res://tools/balance.gd` and read the report. Add `level=level_03 waves=1` to see the bot's gold, lives and towers at each wave. Tell the user what changed, e.g. "level 3 now ends with 12/20 lives instead of 16".
3. **Look at it.** Take a screenshot (see **Seeing your work**), then open the PNG and look. Check that:
   - new sprites are the right size and face the right way
   - towers and enemies stand out from the map
   - the HUD and menus fit
4. **Tell the user** what changed, show the screenshot, and suggest they play it (`godot --path .`). You can't feel the game; ask how it plays.

The checks cover:
- every rule in `Battle`: waiting for the first wave, walking and leaking, losing, building, upgrading, selling, bounty, armor, splash, slow, flyers, splitters, targeting modes, wave timing and the early bonus, winning and stars
- determinism, map and content validation, and every level's fairness
- the real scenes: title, settings and credits (the credit line is shown), level select and unlocking, tapping to build, the tower menu, HUD buttons, game speeds (fractions are exact), pause, winning (stars saved), losing, a crowded battle
- phones (`test_phone.gd`): every screen at four phone and tablet shapes with a cutout and gesture bar (button size, the safe area, the bottom strip, buildable cells), taps beside a cell, two-tap spending, Android's Back on every screen, pausing when the app goes to the background, the splash hook, the Android preset
- the level curve: towers brought in one at a time with a tip, and flyers with room to fly
- `assets.json` and every `res://` path

## Phones and tablets

The game runs on phones as it is (`docs/recipes/export-android.md` builds an APK). With the touch layout on (`touch_ui` in the config; on touch screens by default) it follows these rules, and anything you add should too (`docs/recipes/add-touch-polish.md`):

- **The safe area.** Nothing the player presses goes under a camera cutout, a rounded corner or the gesture bar: lay screens out inside `Game.safe_rect()` and follow resizes. The view's size changes with the screen's shape, so never place things for exactly 480×270.
- **The bottom strip.** Buttons and buildable map cells end above `Game.bottom_limit()`: the bottom 15% stays clear.
- **48 dp.** Buttons are at least `Game.min_touch_size()`. Call `Touch.enlarge()` on a new screen.
- **The map scales.** `BattleScreen.fit_layout()` sizes and places it. Get screen positions from the instance helpers (`cell_to_screen()`, `screen_to_cell()`, `cell_rect()`, `map_rect()`), never from a fixed origin.
- **Two taps to spend.** Anything that costs gold or a tower uses `Touch.confirm()` when `Game.confirms_spending()`.
- **Back.** Android's Back calls the current scene's `go_back()`. A new scene needs one, and Back must never quit the game mid-level.
- **No tooltips.** A touch screen never shows `tooltip_text`, so put what the player needs on screen.

`checks/tests/test_phone.gd` checks every screen at four phone and tablet shapes. To see a screen as a phone does, add `touch=1 size=2400x1080 safe=24,0,0,10` to a screenshot command.

## Recipes

- `docs/recipes/retheme.md`: new theme, towers, enemies, tiles, title and names.
- `docs/recipes/add-tower.md`: a new tower, including a new kind (chain lightning, gold mine).
- `docs/recipes/add-enemy.md`: a new enemy, including a new behavior (healer, shield, teleport).
- `docs/recipes/add-level.md`: a new map and its waves.
- `docs/recipes/add-second-path.md`: more than one spawn, each with its own path; waves pick a path.
- `docs/recipes/edit-waves.md`: waves, groups, bosses and difficulty per level.
- `docs/recipes/tune-balance.md`: easier or harder, with the balance report.
- `docs/recipes/add-spell.md`: a tap-to-cast ability with a cooldown (meteor, freeze).
- `docs/recipes/add-endless-mode.md`: waves that never end, with a high score.
- `docs/recipes/add-touch-polish.md`: the touch layout's settings (button size, the bottom strip, tap snapping, two-tap spending) and new screens on phones.
- `docs/recipes/replace-sounds-and-music.md`: sounds and music.
- `docs/recipes/export.md`: build for desktop, web or mobile.
- `docs/recipes/export-android.md`: export a debug APK for a phone or emulator (the preset is included); package name, icons, and what a Play release needs.

**Credits** live in `CREDITS.md`, shown on title > Settings > Credits (the shared screen in `addons/codeplate/ui/`). Keep its first line, "Built with CodePlate (codeplate.io)", and add a line for every asset the user brings in.

`docs/content.md` explains every field and the map format, and `docs/customization-map.md` answers "I want to change X — which file?".

## Seeing your work

The screenshot tool needs a real window, so **don't** pass `--headless`:

```
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=title
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=settings
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=levels stars=2
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=battle level=1 wave=3 wait=1
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=battle level=2 menu=build
godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=battle level=2 wave=3 touch=1 size=2400x1080 safe=24,0,0,10
```

- `level=N` picks the level; `wave=N` lets the bot build and play until wave N starts (`walk=S` lets it run S more seconds), so the shot shows a busy battle. To see a group with a `delay` (a boss), make `walk` longer than the delay plus a few seconds of walking. The bot can't lose while fast-forwarding to the shot.
- `menu=build` or `menu=tower` opens a menu; `stars=N` pretends every level has N stars.
- `screen=settings` and `screen=credits` show the settings screen and its credits page over the title.
- `touch=1` turns the touch layout on, `size=WxH` sets the window (2400x1080 is a 20:9 phone, 2048x1536 a 4:3 tablet), and `safe=L,T,R,B` pretends a camera cutout and gesture bar (insets in view units).

The PNG goes to `shots/`. Open it and look.

## Common pitfalls

- **New sprite not found:** list it in `assets.json`, then run the import command.
- **"the path branches":** two path cells side by side make a fork. Leave a non-path cell between parallel stretches.
- **A `--script` file (`tools/*.gd`, the screenshot hooks) can't name classes whose code uses `Game` or `Audio`** (like `BattleScreen`). Use `get()` and `call()`. `Battle`, `Bot` and `Content` are fine.
- **A tool hangs with no output:** a script failed to compile. Read the first `SCRIPT ERROR` and fix it.
- **Shot art must point right.** The view rotates it toward the target.
- **The user finds a level too easy or too hard, but the bot is fine:** the bot builds from a fixed list. Ask what they felt, change the waves or gold, and adjust the targets if needed.
