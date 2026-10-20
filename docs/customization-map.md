# Customization map

| I want to… | Change | Recipe |
|---|---|---|
| Re-theme the whole game | sprites, tiles, names in `content/`, title, `project.godot` | `recipes/retheme.md` |
| Add or change a tower | `content/towers.json` | `recipes/add-tower.md` |
| A new kind of tower (chain, gold mine, aura) | `core/battle.gd` `_fire_towers()`, `Content.TOWER_KINDS` | `recipes/add-tower.md` |
| Add or change an enemy | `content/enemies.json` | `recipes/add-enemy.md` |
| Enemies that heal, shield or teleport | `core/battle.gd` `_move_enemies()` | `recipes/add-enemy.md` |
| A new level or map | `content/levels/level_NN.txt` + `.json` | `recipes/add-level.md` |
| Two or more spawns and paths | `content/legend.json` (`R`, `Q`), the map, a wave group's `route` | `recipes/add-second-path.md` |
| A tower whose head turns, shots from the barrel's end | `content/towers.json` (`base`, `muzzle`) | `recipes/add-tower.md` |
| Top-down enemies | `content/enemies.json` (`view`) | `recipes/add-enemy.md` |
| Art made for another cell size, smooth art | `assets.json` (`scale`, `smooth`) | `recipes/retheme.md` |
| Cut an art pack's atlas into strips | `tools/import_atlas.gd` | `recipes/retheme.md` |
| The order the balance bot builds in | `content/towers.json` (`bot_order`) | `recipes/tune-balance.md` |
| New map characters (water, bridges, props) | `content/legend.json`, `assets/tiles/` | `recipes/add-level.md` |
| Waves, bosses, a level's difficulty | `content/levels/level_NN.json` (`waves`, `hp_mult`) | `recipes/edit-waves.md` |
| Easier or harder overall | gold, bounties, enemy health; targets in config | `recipes/tune-balance.md` |
| Sell refund, time between waves, early bonus | Rules group in config | `recipes/tune-balance.md` |
| How stars are earned | `three_star_lives`, `two_star_lives` | — |
| Game speeds (fractions like 1.5 work) | `speeds` in config | — |
| A tap-to-cast spell | `core/battle.gd` command + HUD button | `recipes/add-spell.md` |
| Endless mode | `core/battle.gd` wave flow, level select | `recipes/add-endless-mode.md` |
| Phone layout: button size, the bottom strip, tap snapping, two taps to spend | Phones and tablets group in config (`touch_ui`, `min_touch_share`, `bottom_clear_fraction`, `tap_snap`, `confirm_spending`) | `recipes/add-touch-polish.md` |
| Which towers a level offers, a tip when it starts | `content/levels/level_NN.json` (`towers`, `tip`) | `recipes/add-level.md` |
| A logo before the title | Splash group in config (`splash_image`, `splash_text`), `ui/splash.tscn` | — |
| What Android's Back button does | `go_back()` in each scene (`autoload/game.gd` routes it) | `recipes/add-touch-polish.md` |
| The HUD (a bar, or a column on wide phones) | `game/hud.gd`, `BattleScreen.fit_layout()` | — |
| Colors, button styles, font | `ui/theme.tres`, `assets/ui/font.*` | `recipes/retheme.md` |
| Keys | `DEFAULT_KEYS` in `autoload/game.gd` | — |
| Sounds and music | `assets/audio/`, `autoload/audio.gd` | `recipes/replace-sounds-and-music.md` |
| Build for desktop, web or phones | export presets | `recipes/export.md` |
| Export for Android (package name, icons, version, debug APK) | `export_presets.cfg`, `assets/launcher/*.png` | `recipes/export-android.md` |
| Music and effects volume, fullscreen, credits | `CREDITS.md`; settings in `autoload/game.gd` (the screen itself is in `addons/codeplate/ui/`) | — |
