# Edit waves

Use when the user wants different enemies per wave, bosses, harder or easier levels, or a different pace between waves.

Waves live in each level's `content/levels/level_NN.json` (fields in `docs/content.md`).

1. **Find the change below** and make it in the level's JSON (or the config, for pacing):
   - **A wave** is a list of groups that spawn in parallel. A group is `count` of one `enemy`, one every `gap` seconds, after `delay` seconds.
   - **Mixing:** give the second group a `delay` so it arrives behind the first (runners behind armor are nasty).
   - **A boss wave:** a group with one `boss` enemy, usually with escorts and a `delay` so the boss comes mid-wave. The HUD announces "BOSS WAVE!".
   - **Pacing between waves:** `wave_gap` in the config (seconds after a wave finishes spawning). Players can call the next wave early for `early_bonus_per_second` gold per second skipped.
   - **Difficulty per level:** `hp_mult` scales every enemy's health in that level; `start_gold` and `lives` set the margin.
   - **Two paths:** a group's `"route"` picks its path once the map has more than one (`add-second-path.md`).
2. **Health per wave:** the template has none. To make later waves tougher without new enemies, add an optional `"hp_mult"` to a wave, read it in `LevelData.wave_spawns()` (return it with each spawn), and multiply it in `Battle._spawn()`.
3. **Run `tools/balance.gd`** for the level and the checks (see **Verify**).

## Verify
1. Run the checks: validation catches unknown enemies and empty waves, and the fairness check replays the level.
2. Run `tools/balance.gd -- level=level_NN waves=1` and report where the bot loses lives.
3. Screenshot `screen=battle level=N wave=M walk=8` during the changed wave.
