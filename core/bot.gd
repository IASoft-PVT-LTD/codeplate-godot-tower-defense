class_name Bot
extends RefCounted
## A simple player for balance checks and tools/balance.gd. It builds towers
## in the content's order (towers.json "bot_order", or file order) on the
## free cells that cover the most path (of every route), upgrades
## when it has spare gold, and lets every wave come on its own timer.
## A thoughtful person does better, so "the bot wins" means "fair".

## Start upgrading once it has this many towers.
const UPGRADE_FROM := 8
## How often it thinks, in ticks.
const THINK_EVERY := 15


class Outcome:
	extends RefCounted
	var won: bool
	var lives: int
	var max_lives: int
	var stars: int
	var waves_cleared: int
	var towers: int
	var seconds: float


## Plays a whole level. `build` false = never build (the "idle" run).
## `on_wave` (optional) is called with the battle as each wave starts.
static func play(content: Content, config: GameConfig, level: LevelData, seed_value: int, build: bool = true, on_wave: Callable = Callable()) -> Outcome:
	var b := Battle.new(content, config, level, seed_value)
	var coverage := {} # range -> {cell: path samples in range}
	var order := 0
	if build:
		order = _think(b, coverage, order)
	b.call_wave()
	var limit := GameConfig.ticks(1800.0)
	while b.state == Battle.State.RUNNING and b.tick < limit:
		for e: SimEvent in b.step():
			if e.type == SimEvent.Type.WAVE_START and on_wave.is_valid():
				on_wave.call(b)
		if build and b.tick % THINK_EVERY == 0:
			order = _think(b, coverage, order)
	var o := Outcome.new()
	o.won = b.state == Battle.State.WON
	o.lives = b.lives
	o.max_lives = level.lives
	o.stars = b.stars()
	o.waves_cleared = b.wave if o.won else maxi(0, b.wave - 1)
	o.towers = b.towers.size()
	o.seconds = b.seconds()
	return o


## Spends gold: builds the next tower in the bot order if it can, otherwise
## upgrades. Returns the new position in the bot order.
static func _think(b: Battle, coverage: Dictionary, order: int) -> int:
	for guard: int in 20:
		var id := _next_tower(b, order)
		var cost := int(b.content.tower_level(id, 1)["cost"]) if not id.is_empty() else 1 << 30
		if b.towers.size() >= UPGRADE_FROM:
			var up := _best_upgrade(b, coverage)
			if up.x >= 0 and b.upgrade_cost(up) <= b.gold and b.upgrade_cost(up) <= cost:
				b.upgrade(up)
				continue
		if id.is_empty() or b.gold < cost:
			return order
		var cell := best_cell(b, id, coverage)
		if cell.x < 0 or not b.build(id, cell):
			return order
		order += 1
	return order


static func _next_tower(b: Battle, order: int) -> String:
	var list := b.content.bot_order
	for i: int in list.size():
		var id := list[(order + i) % list.size()]
		if not b.content.get_entry(id).is_empty() and b.level.allows(id):
			return id
	for t: Dictionary in b.content.towers:
		if b.level.allows(str(t["id"])):
			return str(t["id"])
	return ""


## The free buildable cell whose range covers the most path for this tower.
static func best_cell(b: Battle, tower_id: String, coverage: Dictionary) -> Vector2i:
	var reach := float(b.content.tower_level(tower_id, 1)["range"])
	var cov := _coverage(b.map, reach, coverage)
	var best := Vector2i(-1, -1)
	var best_n := 0
	for cell: Vector2i in cov:
		if not b.towers.has(cell) and cov[cell] > best_n:
			best_n = cov[cell]
			best = cell
	return best


## The tower worth upgrading most: lowest level, then best coverage.
static func _best_upgrade(b: Battle, coverage: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for cell: Vector2i in b.towers:
		if b.upgrade_cost(cell) < 0:
			continue
		var t := b.towers[cell]
		var reach := float(b.content.tower_level(t.type, t.level)["range"])
		var score := -t.level * 1000.0 + float(_coverage(b.map, reach, coverage).get(cell, 0))
		if score > best_score:
			best_score = score
			best = cell
	return best


## {cell: number of path sample points within `reach`} for every buildable cell.
static func _coverage(map: Map, reach: float, cache: Dictionary) -> Dictionary:
	if cache.has(reach):
		return cache[reach]
	var samples: Array[Vector2] = []
	for r: int in map.route_count():
		var d := 0.0
		while d <= map.route_lengths[r]:
			samples.append(map.position_at(d, r))
			d += 6.0
	var out := {}
	for y: int in map.height:
		for x: int in map.width:
			var cell := Vector2i(x, y)
			if map.kind(cell) != Map.Kind.BUILD:
				continue
			var c := GameConfig.cell_center(cell)
			var n := 0
			for p: Vector2 in samples:
				if c.distance_to(p) <= reach:
					n += 1
			out[cell] = n
	cache[reach] = out
	return out
