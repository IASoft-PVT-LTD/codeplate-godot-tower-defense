# Architecture

```
content/ (towers, enemies, legend, levels) ──► Content (validated, maps parsed) ──┐
config/game_config.tres ──────────────────────────────────────────────────────────┤
                                                                                   ▼
BattleScreen (game/battle_screen.gd) owns one Battle (core/battle.gd)
   _physics_process, 30/s × speed:  units.remember(); events = battle.step()
                                    _on_event(e) → Audio, Fx, shake, HUD, result
   _process, every frame:           units.sync(t) draws, interpolated between ticks
   taps / keys → tap_cell(), build(), upgrade(), sell(), next_wave() → Battle
```

## core/ (the simulation)

Nothing in `core/` touches nodes, reads input or the clock, or uses the global random numbers. A battle is fully decided by its content, config, seed and commands, which is why the checks and the balance bot can play whole levels in milliseconds.

| File | Job |
|---|---|
| `battle.gd` | `Battle`: one level being played. Commands: `build()`, `upgrade()`, `sell()`, `set_target_mode()`, `call_wave()`. `step()` advances one tick: spawn due enemies, move enemies (slows, leaks, lives), towers fire (targeting modes), shots fly and hit (armor, splash, slow), splitters split, then wave flow (countdown, early bonus, clear, win). `stars()`, `snapshot()`. |
| `map.gd` | `Map`: parses an ASCII level with the legend, validates it (one spawn, one goal, one unforked path), and gives `position_at(distance)` along the path and `flight_position_at()` for flyers. |
| `content.gd` | Loads and validates `content/`. `Content.from_data({...})` builds made-up content for checks. |
| `level_data.gd` | `LevelData`: a level's map, gold, lives, `hp_mult` and waves; `wave_spawns(i)` lists a wave's spawns in order. |
| `entities.gd` | Plain data: `Enemy`, `Tower`, `Shot`. |
| `event.gd` | `SimEvent`: what a step reports (type, position, value, tag, target). |
| `bot.gd` | `Bot.play()` plays a whole level: builds in the order of `towers.json`'s `bot_order` on the cells covering the most path (of every route), upgrades once it has `UPGRADE_FROM` towers. Used by the balance check, `tools/balance.gd` and the screenshot hooks. |

### Enemies move by distance

Each enemy has `progress`: the pixels it has travelled. Its position comes from `Map.position_at(progress)` (or the straight flight line for flyers). That makes "first" targeting a comparison of remaining distance, and splitter children can start just behind their parent.

### States

`BUILDING` (nothing moves until the first wave is called) → `RUNNING` → `WON` or `LOST`. Commands work in `BUILDING` and `RUNNING`.

## game/ (the screen)

| File | Job |
|---|---|
| `battle_screen.gd` / `.tscn` | `BattleScreen`: the tick loop and speed (`take_ticks()`: whole ticks per frame, fractional speeds averaged exactly), input (taps open menus; keys act on the menu's cell or the hovered one), events to sound and effects, the range ring, the ghost of a tower being previewed and the hover cursor, finishing a level, Android's Back (`go_back()`) and pausing when the app goes to the background. `fit_layout()` places the HUD and scales the map on every resize; `cell_to_screen()`, `screen_to_cell()`, `cell_rect()`, `map_rect()` and `tap_target()` convert between cells and the screen. |
| `map_view.gd` | Tiles, decorations, the spawn and the goal. |
| `units_view.gd` | Towers (on a base, frame = level; with a `base` in the content, a turning head), enemies (one sprite each, flipped by direction or, with `view: top`, turned to their heading; tinted when slowed), shots (pooled by id), health bars. |
| `hud.gd` | Gold, lives, wave, START / NEXT (+bonus), speed, pause, announcements and the level's tip. A bar across the top, or a column at the right (`fit()`). |
| `cell_menu.gd` | The build menu (one button per tower the level offers) and the tower menu (upgrade, sell, targeting), with a line of the tower's numbers (`tower_text()`). Two-tap spending when `Game.confirms_spending()`. |
| `touch.gd` | `Touch`: grows buttons to the smallest touch target (`enlarge()`), two-tap buttons (`confirm()`), and helpers the checks use. |
| `result_panel.gd`, `pause_menu.gd`, `overlays.gd` | Victory/defeat, pause, and shared panel helpers. |
| `fx.gd` | Bursts, rays and floating text. |
| `sprites.gd` | Reads frame sizes, `scale` and `smooth` from `assets.json` and cuts strips into frames; every sprite the game draws is made through it. |

## autoload/

| File | Job |
|---|---|
| `game.gd` | Loads config and content, applies the UI theme, the default keys (`DEFAULT_KEYS`), saved progress and settings (`user://progress.json`: stars per level, sound, music and effects volume, fullscreen; `reset_progress()` clears the stars), unlocking (`is_unlocked`), `start_level()`, `goto_levels()`, `goto_title()`, `next_seed`. The phone plumbing: `go_back()` (Android's Back calls the current scene's), muting while the app is in the background, `safe_insets()` / `safe_rect()` / `bottom_limit()` / `min_touch_size()`, `is_touch()` and `confirms_spending()`. `ui_root()` gives CanvasLayers a theme-carrying root that covers the visible view. |
| `audio.gd` | Sounds by name with a per-sound `max_per_second` throttle, and looping music. Applies the volume settings. |

The title's Settings button opens `addons/codeplate/ui/settings_screen.gd` (`CodePlateSettings`): music and effects volume, fullscreen, reset progress (with a confirmation) and a Credits page built from `CREDITS.md`. It reads and sets `Game.music_volume`, `sfx_volume` and `fullscreen` through their `set_*()` functions, `save_settings()` and `reset_progress()`.

## Coordinates and time

- Map pixels: cell (x, y) covers `x*24 .. x*24+24`. `GameConfig.cell_center()` and `pixel_to_cell()` convert. On screen the map is scaled to `BattleScreen.cell_px` view units per cell and placed at `map_origin` (both set by `fit_layout()`): in a 480×270 window without the touch layout that is 24 (1:1) at (0, 30), below the HUD bar. Use the instance helpers (`cell_to_screen()` and friends), not fixed numbers.
- View units: the view is 480×270 on a 16:9 window and grows with the screen's shape (`window/stretch/aspect="expand"`): 600×270 on a 20:9 phone, 480×360 on a 4:3 tablet. Lay screens out from `get_viewport().get_visible_rect()` or `Game.safe_rect()`.
- 30 ticks per second (`physics/common/physics_ticks_per_second` and `GameConfig.TICKS_PER_SECOND` must match). Content times are seconds; `GameConfig.ticks()` converts.
