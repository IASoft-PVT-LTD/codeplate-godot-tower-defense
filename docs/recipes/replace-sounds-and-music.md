# Replace sounds and music

Use when the user has their own sound effects or music, or wants new sounds for new events.

Sounds are named in `SOUNDS` in `autoload/audio.gd`. `BattleScreen._on_event()` (`game/battle_screen.gd`) plays them for game events: `hit`, `enemy_die`, `leak`, `build`, `upgrade`, `sell`, `wave_start`, `coin` (calling a wave early), `wave_clear`, `win`, `lose`. Towers play the sound named by their `sound` field in `content/towers.json`. Buttons play `click`.

1. **Replace a sound:** overwrite `assets/audio/<name>.wav` (or use `.ogg` and update the path in `SOUNDS`). Update `license`/`credit` in `assets.json`, then re-import.
2. **Add a sound:** add the file, a `SOUNDS` entry and an `assets.json` entry, and a line in `CREDITS.md` if it isn't your own. For a tower, set its `sound`; for an event, call `Audio.play(&"name")` in `_on_event()`.
3. **Frequent sounds** (hits, shots, kills) pass `max_per_second` to `Audio.play()` so a full map of towers doesn't make a wall of noise, especially at 3× speed. Keep them short (under 0.2 s) and soft.
4. **Music:** `MUSIC` maps `title` (title and level select) and `battle` to files.
   - `.ogg` loops automatically. `.wav` loops the whole file.
   - `MUSIC_DB` in `audio.gd` is the music level at 100%. Players set music and effects volume on the settings screen (title > Settings); `Audio` applies `Game.music_volume` and `Game.sfx_volume`, so new sounds need nothing extra.
   - Lengths that are a whole number of beats loop without a click.

## Verify
1. Run the checks; the add-on checks every path and `assets.json`.
2. You can't hear it. Ask the user to play and confirm the volume balance.
