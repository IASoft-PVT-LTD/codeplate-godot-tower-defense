class_name GameConfig
extends Resource
## Numbers that aren't per-item content. Towers, enemies and levels live in
## content/. Distances are in pixels (a map cell is 24 px), times in seconds.

@export_group("Rules")
## Gold back when selling a tower, as a share of everything spent on it.
@export var sell_refund: float = 0.7
## Seconds between waves once a wave has finished spawning.
@export var wave_gap: float = 14.0
## Calling the next wave early pays this much gold per second skipped.
@export var early_bonus_per_second: float = 1.5
## Lives left (as a share of the level's lives) for 3 and 2 stars; any win is 1.
@export var three_star_lives: float = 0.9
@export var two_star_lives: float = 0.5

@export_group("Balance targets")
## The balance check (test_every_level_is_fair in checks/tests/test_content.gd,
## and tools/balance.gd) lets a simple bot play every level. It must win each
## one with at least this share of lives left, so levels are fair...
@export var bot_min_lives: float = 0.5
## ...and a run where nobody builds must lose every level, so towers matter.
@export var idle_must_lose: bool = true

@export_group("Feel")
## Screen shake (pixels) when an enemy reaches the shrine.
@export var shake_leak: float = 3.0
## Game speeds the speed button cycles through. Fractions work (1.5 runs the
## sim 1.5x as fast); each must be above 0 and at most MAX_SPEED.
@export var speeds: PackedFloat32Array = [1.0, 2.0, 3.0]

## Fastest allowed speed: sim ticks per physics frame at most.
const MAX_SPEED := 8.0

const TICKS_PER_SECOND := 30
const DT := 1.0 / 30.0
const CELL := 24


static func ticks(seconds: float) -> int:
	return maxi(0, roundi(seconds * TICKS_PER_SECOND))


## Center of a map cell in map pixels.
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)


static func pixel_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
