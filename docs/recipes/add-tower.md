# Add a tower

Use when the user wants a new tower: one of the existing kinds with new numbers and art (JSON only), or a new kind such as chain lightning or a gold mine (code).

## Using an existing kind
1. Add an entry to `content/towers.json`: `id`, `name`, `description`, `icon`, `kind` (`bullet`, `splash`, `slow`, `ray`), `targets`, `sprite`, `shot`, `sound`, and `levels` (usually 3). Fields are in `docs/content.md`.
2. Art: a 24×32-per-level strip, a shot pointing right, and a new frame at the end of `assets/ui/tower_icons.png` (update its `frames` in `assets.json`).
3. The build menu shows towers in file order; number keys 1–9 build them in that order. More than 5 towers make the menu wide: consider two rows in `CellMenu.open_build()` (a `GridContainer` with 3 columns).
4. Let the bot use it: add its id to `Bot.BUILD_ORDER` in `core/bot.gd`.
5. Run `tools/balance.gd`. A strong new tower makes every level easier.

## A new kind (example: "chain" lightning that jumps between enemies)
1. Add `"chain"` to `Content.TOWER_KINDS` and its fields to `Content.KIND_FIELDS` in `core/content.gd`, e.g. `["cost", "damage", "range", "rate", "jumps", "jump_range"]`.
2. Fire it in `Battle._fire_towers()` (`core/battle.gd`). Like `ray`, it can hit at once:
   ```gdscript
   if kind == "chain":
   	var hit: Array[Entities.Enemy] = [target]
   	var at := target
   	for j: int in int(s["jumps"]):
   		var next: Entities.Enemy = null
   		for e: Entities.Enemy in enemies:
   			if e.hp > 0.0 and e not in hit and e.pos.distance_to(at.pos) <= float(s["jump_range"]):
   				next = e
   				break
   		if next == null:
   			break
   		hit.append(next)
   		at = next
   	for e: Entities.Enemy in hit:
   		_damage(e, float(s["damage"]), t.type, false)
   	continue
   ```
   Use `rng` for any randomness. Emit extra events (e.g. a new `SimEvent.Type.CHAIN` with `pos` and `target`) so the view can draw each jump.
3. Draw it in `BattleScreen._on_event()`: `fx.ray()` between each pair works for lightning.
4. **Towers that don't attack** (a gold mine): give them a kind with `["cost", "gold", "rate"]`, and in `_fire_towers()` add gold on the cooldown instead of picking a target. The bot won't value it; leave it out of `BUILD_ORDER`.
5. Add a check in `checks/tests/test_battle.gd`: put the tower in `_content()`, line up enemies with a wave, and assert the hits (or the gold).
6. Document the kind in `docs/content.md`.

## Verify
1. Run the checks.
2. Run `tools/balance.gd` and report the change.
3. Screenshot `screen=battle level=N wave=M` with the tower in `Bot.BUILD_ORDER` (or temporarily first) so the bot builds it.
