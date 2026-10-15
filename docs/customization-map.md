# Customization map

| I want to… | Change | Recipe |
|---|---|---|
| Re-theme the whole game | sprites, tiles, names in `content/`, title, `project.godot` | `recipes/retheme.md` |
| Add or change a tower | `content/towers.json` | `recipes/add-tower.md` |
| A new kind of tower (chain, gold mine, aura) | `core/battle.gd` `_fire_towers()`, `Content.TOWER_KINDS` | `recipes/add-tower.md` |
| Add or change an enemy | `content/enemies.json` | `recipes/add-enemy.md` |
| Enemies that heal, shield or teleport | `core/battle.gd` `_move_enemies()` | `recipes/add-enemy.md` |
| A new level or map | `content/levels/level_NN.txt` + `.json` | `recipes/add-level.md` |
| Two or more spawns and paths | `content/legend.json`, `core/map.gd`, `core/battle.gd` | `recipes/add-second-path.md` |
| New map characters (water, bridges, props) | `content/legend.json`, `assets/tiles/` | `recipes/add-level.md` |
| Waves, bosses, a level's difficulty | `content/levels/level_NN.json` (`waves`, `hp_mult`) | `recipes/edit-waves.md` |
| Easier or harder overall | gold, bounties, enemy health; targets in config | `recipes/tune-balance.md` |
| Sell refund, time between waves, early bonus | Rules group in config | `recipes/tune-balance.md` |
| How stars are earned | `three_star_lives`, `two_star_lives` | — |
| Game speeds (fractions like 1.5 work) | `speeds` in config | — |
| A tap-to-cast spell | `core/battle.gd` command + HUD button | `recipes/add-spell.md` |
| Endless mode | `core/battle.gd` wave flow, level select | `recipes/add-endless-mode.md` |
| Phone-friendly controls | `game/cell_menu.gd`, `game/battle_screen.gd` | `recipes/add-touch-polish.md` |
| The HUD | `game/hud.gd` | — |
| Colors, button styles, font | `ui/theme.tres`, `assets/ui/font.*` | `recipes/retheme.md` |
| Keys | `DEFAULT_KEYS` in `autoload/game.gd` | — |
| Sounds and music | `assets/audio/`, `autoload/audio.gd` | `recipes/replace-sounds-and-music.md` |
| Build for desktop, web or phones | export presets | `recipes/export.md` |
| Export for Android (package name, icons, version, debug APK) | `export_presets.cfg`, `assets/launcher/*.png` | `recipes/export-android.md` |
| Music and effects volume, fullscreen, credits | `CREDITS.md`; settings in `autoload/game.gd` (the screen itself is in `addons/codeplate/ui/`) | — |
