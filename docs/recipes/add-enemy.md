# Add an enemy

Use when the user wants a new enemy: one built from the existing behaviors (JSON and art only), or one with a new behavior such as healing, shielding or teleporting (code).

## Using existing behaviors
1. Add an entry to `content/enemies.json`: `id`, `name`, `sprite`, `hp`, `speed`, `bounty`, and optionally `armor`, `lives`, `flying`, `splits_into` + `split_count`, `boss`, `view`. See `docs/content.md`.
2. Art: a walk strip facing right, listed in `assets.json`. For top-down art (seen from above, like an ant or a car) set `"view": "top"`: the enemy is centred on its spot and turns to face the way it walks, so draw it pointing right. The default `"side"` stands the art on its spot and flips it left or right.
3. Put it in waves (`content/levels/*.json`). An enemy no wave uses never appears.
4. Run `tools/balance.gd`.

Guide: 24 px/s is one cell a second. Armor beats fast, weak shots (arrows); rays ignore it. Flyers skip the path, so they're dangerous on long, winding maps.

## A new behavior (example: a healer that mends nearby enemies)
1. Add fields to `content/enemies.json`, e.g. `"heal": 4, "heal_range": 40`, and validate them in `Content.from_data()` if they need checking.
2. Copy them onto the enemy in `Battle._spawn()`: add `var heal := 0.0` and `var heal_range := 0.0` to `Entities.Enemy`.
3. Apply it in `Battle._move_enemies()`, once a second for example:
   ```gdscript
   if e.heal > 0.0 and tick % GameConfig.TICKS_PER_SECOND == 0:
   	for o: Entities.Enemy in enemies:
   		if o != e and o.hp > 0.0 and o.pos.distance_to(e.pos) <= e.heal_range:
   			o.hp = minf(o.max_hp, o.hp + e.heal)
   ```
   Other ideas: a shield that absorbs the first N damage (in `_damage()`), a dash (multiply speed for a few ticks on a timer), teleport (jump `progress` forward), stealth (skip it in `_pick_target()` unless a tower has `"reveals": true`).
4. Emit an event if the player should see it (a green burst on healing), and handle it in `BattleScreen._on_event()`.
5. Use `rng`, never `randf()`.
6. Add a check in `checks/tests/test_battle.gd`: add the enemy to `_content()`, damage a neighbour, step a second, and assert it healed.

## Verify
1. Run the checks.
2. Run `tools/balance.gd`.
3. Screenshot a battle at a wave where the enemy appears.
