# Content reference

All content is in `content/`. `Content` validates it at startup and in the checks; errors name the file and the entry (and the row and column for maps). Sprite paths are relative to the project (`assets/...`) and must be listed in `assets.json`.

## towers.json

```json
{"id": "arrow", "name": "Lantern Archer", "icon": 0, "kind": "bullet", "targets": ["ground", "air"],
 "sprite": "assets/towers/arrow.png", "shot": "assets/projectiles/arrow.png", "sound": "arrow",
 "description": "Quick arrows at one enemy. Hits flyers.",
 "levels": [{"cost": 60, "damage": 7, "range": 64, "rate": 1.6, "speed": 300}, ...]}
```

| Field | Meaning |
|---|---|
| `id` | Unique across towers and enemies. The build menu and number keys 1–9 follow the file's order. |
| `name`, `description` | Shown in the menus. |
| `icon` | Frame in `assets/ui/tower_icons.png` (24×24). |
| `kind` | `bullet`, `splash`, `slow` or `ray` (below). |
| `targets` | `["ground"]`, `["air"]` or both (default both). |
| `sprite` | A strip with one 24×32 frame per level, base at the bottom. Drawn on `assets/towers/base.png`. |
| `shot` | Projectile art pointing right (rotated toward the target); for `ray`, a short beam strip stretched to the target. |
| `sound` | A name from `SOUNDS` in `autoload/audio.gd`, played when it fires. Optional. |
| `levels` | One object per level. Level 1's `cost` is the build price; later levels' `cost` is the upgrade price. |

Fields per level, by kind:

| Kind | Behavior | Fields |
|---|---|---|
| `bullet` | A homing shot at one enemy. | `cost`, `damage`, `range` (px), `rate` (shots/s), `speed` (px/s) |
| `splash` | A shell that damages every enemy it can target within `splash` px of where it lands. | the `bullet` fields + `splash` |
| `slow` | A shot that also slows its target to `slow`× speed for `slow_time` seconds (the strongest slow wins). | the `bullet` fields + `slow`, `slow_time` |
| `ray` | Instant hit; **ignores armor**. | `cost`, `damage`, `range`, `rate` |

Damage against armor: `max(1, damage − armor)`, except rays. A map cell is 24 px, so a `range` of 64 reaches about 2.5 cells.

## enemies.json

```json
{"id": "armored", "name": "Oni Beetle", "sprite": "assets/enemies/armored.png", "hp": 80, "speed": 20, "armor": 4, "bounty": 15}
```

| Field | Meaning |
|---|---|
| `sprite` | A walk strip facing right (the view flips it). |
| `hp` | Health (× the level's `hp_mult`). |
| `speed` | px/s along the path. 24 = one cell a second. |
| `bounty` | Gold for a kill. |
| `armor` | Optional. Taken off each non-ray hit. |
| `lives` | Optional (default 1). Lives lost if it reaches the goal. |
| `flying` | Optional. Flies straight from spawn to goal, ignoring the path; only towers with `"air"` in `targets` can hit it. |
| `splits_into`, `split_count` | Optional. When killed, spawns `split_count` of that enemy where it died. |
| `boss` | Optional. A bigger health bar and a "BOSS WAVE!" announcement. |

## legend.json

Maps characters in the level files to cells:

```json
{"tiles": {".": {"kind": "build", "tile": "grass"}, "P": {"kind": "path", "tile": "path"},
           "S": {"kind": "spawn", "tile": "path"}, "G": {"kind": "goal", "tile": "path"},
           "#": {"kind": "block", "tile": "rock"}, "T": {"kind": "block", "tile": "grass", "decor": 0}}}
```

- `kind`: `build` (towers allowed), `path`, `spawn`, `goal` or `block`.
- `tile`: the art `assets/tiles/<tile>.png` (a strip of variants; one is picked per cell).
- `decor`: optional frame of `assets/tiles/decor.png` drawn on top.

## levels/level_NN.txt (maps)

```
......T...b...Bm..B.
..........b.........
SPPPPPP......PPPPPPG
......P......P......
```

- Every row is the same width. The template's maps are 20×10, which fills the 480×240 area below the HUD; bigger maps need a camera (see `add-level.md`).
- Exactly one `S` and one `G`, joined by one path with **no forks**. Two path cells side by side count as a fork, so leave a gap between parallel stretches.
- Levels are played in file-name order.

## levels/level_NN.json

```json
{"name": "Mossy Steps", "start_gold": 180, "lives": 20, "hp_mult": 1.0,
 "waves": [{"groups": [{"enemy": "grunt", "count": 10, "gap": 1.0, "delay": 0},
                       {"enemy": "runner", "count": 8, "gap": 1.0, "delay": 3}]}]}
```

| Field | Meaning |
|---|---|
| `name` | Shown on the level card and at the start. |
| `start_gold`, `lives` | The starting purse and lives. |
| `hp_mult` | Optional (default 1). Multiplies every enemy's health in this level: an easy difficulty knob. |
| `waves[].groups[]` | Groups in a wave spawn in parallel: after `delay` seconds, `count` of `enemy`, one every `gap` seconds. |

The first wave starts when the player presses START. After a wave finishes spawning, the next one starts `wave_gap` seconds later (config), or earlier if the player calls it, for `early_bonus_per_second` gold per second skipped. The level is won when the last wave is cleared.
