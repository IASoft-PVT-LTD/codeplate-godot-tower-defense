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
## The bot must also win with every enemy this much tougher (0.05 = 5% more
## health), so no level sits on a cliff edge where a little more health
## turns a comfortable win into a loss. `tune=1` in tools/balance.gd shows
## where the edge is.
@export_range(0.0, 0.5, 0.01) var bot_hp_margin: float = 0.05
## Flying enemies go straight from their spawn to the goal. On levels that
## send them, every route's straight line must be at least this many cells
## long, or they arrive before any tower gets a shot.
@export var min_flight_cells: float = 8.0

@export_group("Phones and tablets")
## The touch layout: thumb-sized buttons, the HUD as a column when that leaves
## a bigger map, buildable cells kept above the bottom strip, taps that snap
## to the nearest cell. "auto" uses it on touch screens and mobile exports,
## "always" everywhere (handy for testing on a computer), "off" never.
@export_enum("auto", "always", "off") var touch_ui: String = "auto"
## Smallest touch target, as a share of the view's height: 0.134 is 48 dp on
## a phone 360 dp tall in landscape (the smallest common one).
@export_range(0.05, 0.3, 0.001) var min_touch_share: float = 0.134
## With the touch layout, every button and every buildable map cell ends at
## least this share of the view's height above the bottom edge (and clear of
## the gesture bar), where a resting thumb or a swipe home doesn't take it.
@export_range(0.0, 0.4, 0.01) var bottom_clear_fraction: float = 0.15
## With the touch layout, a tap this far off a buildable cell or a tower (in
## cells, from the cell's edge) still picks it.
@export_range(0.0, 1.0, 0.05) var tap_snap: float = 0.6
## Building, upgrading and selling take two taps: the first shows the tower,
## its range and its numbers, the second (within confirm_seconds) spends the
## gold. "touch" = with the touch layout only, "always", or "off".
@export_enum("touch", "always", "off") var confirm_spending: String = "touch"
@export_range(0.5, 10.0, 0.5) var confirm_seconds: float = 3.0

@export_group("Splash")
## A logo shown before the title (ui/splash.tscn), e.g. your studio's.
## Empty = no splash: the game opens straight on the title.
@export_file("*.png", "*.svg", "*.webp") var splash_image: String = ""
## A line under the logo ("Made by ..."). Empty = none.
@export var splash_text: String = ""
## Seconds the splash shows, fades included. A tap or key skips it.
@export_range(0.5, 5.0, 0.1) var splash_seconds: float = 1.5
## The splash's background. Match project.godot's boot_splash/bg_color so the
## hand-over from the engine's boot screen is seamless.
@export var splash_color: Color = Color(0.07, 0.07, 0.14, 1)

@export_group("Feel")
## Screen shake (map pixels) when an enemy reaches the shrine.
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
