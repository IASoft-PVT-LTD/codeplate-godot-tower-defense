extends CheckCase
## The rules in core/battle.gd, on a small made-up level so the numbers are
## easy to follow: a straight path 10 cells long, one tower of each kind.
## The made-up content has its own ids and its own map legend, so these checks
## keep working whatever the game's towers, enemies and map letters are.

## The map letters these checks use (test_content.gd uses it too).
const LEGEND := {
	".": {"kind": "build"},
	"#": {"kind": "block"},
	"S": {"kind": "spawn"},
	"P": {"kind": "path"},
	"G": {"kind": "goal"},
	"R": {"kind": "spawn", "route": 1},
	"Q": {"kind": "path", "route": 1},
}

const MAP := """
..........
SPPPPPPPPG
..........
"""


func _content(waves: Array, enemies: Array = []) -> Content:
	var errors: PackedStringArray = []
	var all_enemies: Array = [
		{"id": "dummy", "hp": 20, "speed": 24, "bounty": 5, "sprite": "x"},
		{"id": "tank", "hp": 50, "speed": 24, "bounty": 5, "armor": 4, "sprite": "x"},
		{"id": "bird", "hp": 20, "speed": 24, "bounty": 5, "flying": true, "sprite": "x"},
		{"id": "blob", "hp": 10, "speed": 24, "bounty": 5, "splits_into": "dummy", "split_count": 2, "sprite": "x"},
		{"id": "big", "hp": 20, "speed": 24, "bounty": 5, "lives": 5, "sprite": "x"},
	]
	all_enemies.append_array(enemies)
	var c := Content.from_data({
		"towers": {"towers": [
			{"id": "bow", "kind": "bullet", "sprite": "x", "levels": [
				{"cost": 50, "damage": 10, "range": 40, "rate": 2, "speed": 600},
				{"cost": 30, "damage": 20, "range": 40, "rate": 2, "speed": 600}]},
			{"id": "mortar", "kind": "splash", "targets": ["ground"], "sprite": "x", "levels": [
				{"cost": 50, "damage": 10, "range": 60, "rate": 1, "speed": 600, "splash": 30}]},
			{"id": "ice", "kind": "slow", "sprite": "x", "levels": [
				{"cost": 50, "damage": 1, "range": 60, "rate": 1, "speed": 600, "slow": 0.5, "slow_time": 2}]},
			{"id": "beam", "kind": "ray", "sprite": "x", "levels": [
				{"cost": 50, "damage": 5, "range": 60, "rate": 1}]},
		]},
		"enemies": {"enemies": all_enemies},
		"legend": {"tiles": LEGEND},
		"levels": [{"id": "t", "map": MAP, "start_gold": 100, "lives": 10, "waves": waves}],
	}, errors)
	assert(c != null, "\n".join(errors))
	return c


func _battle(waves: Array, gold: int = 100) -> Battle:
	var c := _content(waves)
	var cfg: GameConfig = Game.config.duplicate()
	var b := Battle.new(c, cfg, c.levels[0], 1)
	b.gold = gold
	return b


func _wave(enemy: String, count: int = 1, gap: float = 1.0) -> Dictionary:
	return {"groups": [{"enemy": enemy, "count": count, "gap": gap}]}


func _run(b: Battle, seconds: float) -> Array:
	var types := []
	for i: int in GameConfig.ticks(seconds):
		types.append_array(b.step().map(func(e: SimEvent) -> SimEvent.Type: return e.type))
	return types


func test_nothing_moves_until_the_first_wave_is_called() -> void:
	var b := _battle([_wave("dummy")])
	_run(b, 2.0)
	expect_eq(b.tick, 0, "no time passes while building")
	expect(b.call_wave(), "the first wave can be called")
	expect_eq(b.state, Battle.State.RUNNING, "running")
	expect(SimEvent.Type.SPAWN in _run(b, 0.1), "an enemy spawned")


func test_enemies_walk_the_path_and_leaking_costs_lives() -> void:
	var b := _battle([_wave("dummy"), _wave("big")])
	b.call_wave()
	var path := b.map.path_length # 9 cells = 216 px at 24 px/s = 9 s
	_run(b, 1.0)
	expect(absf(b.enemies[0].progress - 24.0) < 1.0, "walked 24 px in a second (%.1f)" % b.enemies[0].progress)
	var seen := _run(b, path / 24.0)
	expect(SimEvent.Type.LEAK in seen, "it leaked")
	expect_eq(b.lives, 9, "one life lost")
	b.call_wave() # the next wave, early
	_run(b, path / 24.0 + 1.0)
	expect_eq(b.lives, 4, "a big enemy costs its \"lives\" (5)")


func test_losing_every_life_loses() -> void:
	var b := _battle([_wave("big", 3, 0.5)])
	b.call_wave()
	var seen := _run(b, 15.0)
	expect(SimEvent.Type.LOSE in seen, "a LOSE event")
	expect_eq(b.state, Battle.State.LOST, "lost")
	expect_eq(b.lives, 0, "no lives below zero")
	expect(not b.build("bow", Vector2i(3, 0)), "no building after the end")


func test_building_upgrading_and_selling() -> void:
	var b := _battle([_wave("dummy")], 100)
	expect(b.build_problem("bow", Vector2i(3, 1)).contains("can't build"), "not on the path")
	expect(b.build("bow", Vector2i(3, 0)), "built on grass")
	expect_eq(b.gold, 50, "paid 50")
	expect(b.build_problem("bow", Vector2i(3, 0)).contains("already"), "not on top of a tower")
	expect(b.build_problem("beam", Vector2i(4, 0)).is_empty(), "can afford another")
	b.gold = 10
	expect(b.build_problem("beam", Vector2i(4, 0)).contains("gold"), "not without gold")
	b.gold = 30
	expect_eq(b.upgrade_cost(Vector2i(3, 0)), 30, "upgrade costs level 2's cost")
	expect(b.upgrade(Vector2i(3, 0)), "upgraded")
	expect_eq(b.upgrade_cost(Vector2i(3, 0)), -1, "max level")
	expect_eq(b.sell(Vector2i(3, 0)), floori(80 * Game.config.sell_refund), "sold for the refund share of 80 spent")
	expect(not b.towers.has(Vector2i(3, 0)), "the tower is gone")


func test_a_tower_kills_and_pays_its_bounty() -> void:
	var b := _battle([_wave("dummy")], 50)
	b.build("bow", Vector2i(4, 0))
	b.call_wave()
	var seen := _run(b, 8.0)
	expect(SimEvent.Type.FIRE in seen and SimEvent.Type.HIT in seen, "fired and hit")
	expect_eq(b.kills, 1, "one kill")
	expect_eq(b.gold, 5, "paid the bounty")
	expect_eq(b.lives, 10, "nothing leaked")


func test_armor_reduces_hits_but_rays_ignore_it() -> void:
	var b := _battle([_wave("tank")])
	b.call_wave()
	_run(b, 0.1)
	var tank := b.enemies[0]
	b._damage(tank, 10.0, "bow", false)
	expect_eq(tank.hp, 44.0, "10 - 4 armor = 6")
	b._damage(tank, 2.0, "bow", false)
	expect_eq(tank.hp, 43.0, "never below 1")
	b._damage(tank, 5.0, "beam", true)
	expect_eq(tank.hp, 38.0, "rays ignore armor")


func test_splash_hits_a_group_but_not_flyers() -> void:
	var b := _battle([{"groups": [{"enemy": "dummy", "count": 3, "gap": 0.2}, {"enemy": "bird", "count": 1, "gap": 1}]}])
	b.build("mortar", Vector2i(3, 0))
	b.call_wave()
	var hits := 0
	for i: int in GameConfig.ticks(5.0):
		var events := b.step()
		if events.any(func(e: SimEvent) -> bool: return e.type == SimEvent.Type.SPLASH):
			hits = events.filter(func(e: SimEvent) -> bool: return e.type == SimEvent.Type.HIT).size()
			break
	expect(hits >= 2, "one shell hit several ground enemies (%d)" % hits)
	var bird := b.enemies.filter(func(e: Entities.Enemy) -> bool: return e.flying)
	expect(bird.size() == 1 and bird[0].hp == bird[0].max_hp, "the flyer is untouched (ground-only tower)")


func test_frost_slows() -> void:
	var b := _battle([_wave("dummy")])
	b.build("ice", Vector2i(2, 0))
	b.call_wave()
	var seen := _run(b, 1.5)
	expect(SimEvent.Type.SLOW in seen, "a SLOW event")
	var e := b.enemies[0]
	expect_eq(e.slow, 0.5, "half speed")
	var before := e.progress
	_run(b, 1.0)
	expect(absf(e.progress - before - 12.0) < 1.0, "moves 12 px a second while slowed (%.1f)" % (e.progress - before))


func test_flyers_take_the_short_way() -> void:
	var b := _battle([_wave("bird")])
	b.call_wave()
	_run(b, 0.1)
	var bird := b.enemies[0]
	expect(bird.flying, "it flies")
	expect(b.remaining(bird) <= b.map.flight_length, "it heads straight for the goal")


func test_splitters_split() -> void:
	var b := _battle([_wave("blob")])
	b.call_wave()
	_run(b, 0.5)
	b._damage(b.enemies[0], 99.0, "beam", true)
	var kinds := b.enemies.filter(func(e: Entities.Enemy) -> bool: return e.hp > 0.0).map(func(e: Entities.Enemy) -> String: return e.type)
	expect_eq(kinds, ["dummy", "dummy"], "two dummies took its place")


func test_targeting_modes() -> void:
	var b := _battle([{"groups": [{"enemy": "dummy", "count": 1, "gap": 1}, {"enemy": "tank", "count": 1, "gap": 1, "delay": 1.5}]}])
	b.call_wave()
	_run(b, 2.0)
	b.build("bow", Vector2i(2, 0))
	var t := b.towers[Vector2i(2, 0)]
	var from := GameConfig.cell_center(t.cell)
	var targets: Array = ["ground", "air"]
	var first := b._pick_target(t, from, 999.0, targets)
	expect_eq(first.type, "dummy", "first = closest to the goal")
	t.target_mode = "last"
	expect_eq(b._pick_target(t, from, 999.0, targets).type, "tank", "last")
	t.target_mode = "strong"
	expect_eq(b._pick_target(t, from, 999.0, targets).type, "tank", "strong = most health")


func test_waves_follow_on_and_calling_early_pays() -> void:
	var b := _battle([_wave("dummy"), _wave("dummy"), _wave("dummy")])
	b.call_wave()
	_run(b, 0.5)
	expect(b.seconds_to_next_wave() > 0.0, "the next wave is counting down")
	var bonus := b.early_bonus()
	var gold := b.gold
	expect(bonus > 0 and b.call_wave(), "can call it early for %d gold" % bonus)
	expect_eq(b.gold, gold + bonus, "paid the bonus")
	expect_eq(b.wave, 2, "wave 2 started")
	_run(b, 0.5)
	_run(b, Game.config.wave_gap + 0.1)
	expect_eq(b.wave, 3, "wave 3 came on its own after the gap")


func test_clearing_every_wave_wins_with_stars() -> void:
	var b := _battle([_wave("dummy", 2, 0.5)], 100)
	b.build("bow", Vector2i(4, 0))
	b.build("bow", Vector2i(6, 0))
	b.call_wave()
	var seen := _run(b, 20.0)
	expect(SimEvent.Type.WIN in seen, "a WIN event")
	expect_eq(b.state, Battle.State.WON, "won")
	expect_eq(b.stars(), 3, "3 stars with every life left")
	b.lives = 6
	expect_eq(b.stars(), 2, "2 stars at 60% lives")
	b.lives = 1
	expect_eq(b.stars(), 1, "1 star for any win")


func test_same_seed_same_battle() -> void:
	# Determinism: balance checks and bug reports rely on it.
	var level := Game.content.levels[Game.content.levels.size() - 1]
	var snaps: Array = []
	for i: int in 2:
		var b := Battle.new(Game.content, Game.config, level, 99)
		var cov := {}
		var order := Bot._think(b, cov, 0)
		b.call_wave()
		for t: int in GameConfig.ticks(90.0):
			b.step()
			if b.tick % Bot.THINK_EVERY == 0:
				order = Bot._think(b, cov, order)
		snaps.append(b.snapshot())
	expect_eq(snaps[0], snaps[1], "two battles with the same seed and commands match")
	expect(int(snaps[0]["kills"]) > 0, "and something happened")


# --- Routes: several spawns, each with its own path to the goal -----------------

## Route 0 runs along the bottom row; route 1 along the top and down the right side.
const TWO_ROUTES := """
RQQQQQ
.....Q
SPPPPG
"""

## Route 1 along the top and down the right; route 0 along the bottom, 5 rows away.
const FAR_ROUTES := """
RQQQQQQQQQ
.........Q
.........Q
.........Q
.........Q
SPPPPPPPPG
"""

const FIXTURE_ENEMIES: Array = [
	{"id": "dummy", "hp": 20, "speed": 24, "bounty": 5, "sprite": "x"},
	{"id": "blob", "hp": 10, "speed": 24, "bounty": 5, "splits_into": "dummy", "split_count": 2, "sprite": "x"},
	{"id": "bird", "hp": 20, "speed": 24, "bounty": 5, "flying": true, "sprite": "x"},
]


func _level_content(map: String, waves: Array, towers: Dictionary = {"towers": []}, gold: int = 0) -> Content:
	var errors: PackedStringArray = []
	var c := Content.from_data({
		"towers": towers,
		"enemies": {"enemies": FIXTURE_ENEMIES},
		"legend": {"tiles": LEGEND},
		"levels": [{"id": "fixture", "map": map, "start_gold": gold, "lives": 10, "waves": waves}],
	}, errors)
	assert(c != null, "\n".join(errors))
	return c


func _two_route_battle(waves: Array) -> Battle:
	var c := _level_content(TWO_ROUTES, waves)
	return Battle.new(c, Game.config.duplicate(), c.levels[0], 1)


func test_a_second_route_walks_its_own_path() -> void:
	var b := _two_route_battle([{"groups": [{"enemy": "dummy", "count": 1, "route": 1}]}])
	expect_eq(b.map.route_count(), 2, "the map has two routes")
	expect(b.map.route_lengths[1] > b.map.route_lengths[0], "route 1 is the longer way round")
	b.call_wave()
	_run(b, 0.2)
	if not expect_eq(b.enemies.size(), 1, "the enemy spawned"):
		return
	var e := b.enemies[0]
	expect_eq(e.route, 1, "it walks route 1")
	expect(e.pos.y < GameConfig.CELL, "it starts at route 1's spawn, on the top row")
	_run(b, 4.0)
	expect(e.pos.y < GameConfig.CELL, "after 4 s it is still on the top row")
	_run(b, 6.0) # route 1 is 7 cells: 168 px at 24 px/s = 7 s
	expect_eq(b.lives, 9, "it reached the goal along route 1 and cost a life")


func test_route_zero_is_the_default_and_a_split_keeps_its_route() -> void:
	var b := _two_route_battle([{"groups": [{"enemy": "dummy", "count": 1}, {"enemy": "blob", "count": 1, "route": 1}]}])
	b.call_wave()
	_run(b, 0.2)
	var routes := b.enemies.map(func(e: Entities.Enemy) -> int: return e.route)
	routes.sort()
	expect_eq(routes, [0, 1], "a group without \"route\" walks route 0")
	var blob: Entities.Enemy = b.enemies.filter(func(e: Entities.Enemy) -> bool: return e.type == "blob")[0]
	b._damage(blob, 99.0, "beam", true)
	var kids := b.enemies.filter(func(e: Entities.Enemy) -> bool: return e.type == "dummy" and e.hp > 0.0 and e.route == 1)
	expect_eq(kids.size(), 2, "what a splitter on route 1 splits into walks route 1 too")


func test_flyers_fly_from_their_own_spawn() -> void:
	var b := _two_route_battle([{"groups": [{"enemy": "bird", "count": 1, "route": 1}]}])
	b.call_wave()
	_run(b, 0.1)
	var bird := b.enemies[0]
	expect(bird.pos.y < GameConfig.CELL, "a flyer on route 1 starts at route 1's spawn")
	expect(absf(b.remaining(bird) - b.map.flight_lengths[1]) < 6.0, "and its distance to go is route 1's straight line")


func test_a_wave_on_a_route_the_map_lacks_is_an_error() -> void:
	var errors: PackedStringArray = []
	var c := Content.from_data({
		"towers": {"towers": []},
		"enemies": {"enemies": FIXTURE_ENEMIES},
		"legend": {"tiles": LEGEND},
		"levels": [{"id": "one", "map": MAP, "waves": [{"groups": [{"enemy": "dummy", "count": 1, "route": 1}]}]}],
	}, errors)
	expect(c == null and Array(errors).any(func(m: String) -> bool: return m.contains("route 1 isn't on the map")),
		"a wave group on route 1 of a one-route map is reported (got %s)" % [errors])


func test_a_single_route_map_is_route_zero() -> void:
	var b := _battle([_wave("dummy")])
	expect_eq(b.map.route_count(), 1, "one spawn, one route")
	expect_eq(b.map.path_length, b.map.route_lengths[0], "path_length is route 0's length")
	expect_eq(b.map.flight_length, b.map.flight_lengths[0], "flight_length is route 0's straight line")
	expect_eq(b.map.position_at(30.0), b.map.position_at(30.0, 0), "position_at() without a route is route 0")


# --- The balance bot reads its build order from the content ----------------------

## Towers with ids the template doesn't use, as after a re-theme.
func _bot_towers(order: Variant = null) -> Dictionary:
	var towers := {"towers": [
		{"id": "zap", "kind": "bullet", "sprite": "x", "levels": [{"cost": 40, "damage": 10, "range": 40, "rate": 2, "speed": 600}]},
		{"id": "boom", "kind": "splash", "sprite": "x", "targets": ["ground"], "levels": [
			{"cost": 60, "damage": 10, "range": 50, "rate": 1, "speed": 600, "splash": 24}]},
	]}
	if order != null:
		towers["bot_order"] = order
	return towers


func test_the_bot_order_comes_from_the_content() -> void:
	var waves := [{"groups": [{"enemy": "dummy", "count": 6, "gap": 1.0}]}]
	var c := _level_content(MAP, waves, _bot_towers(), 200)
	expect_eq(Array(c.bot_order), ["zap", "boom"], "without \"bot_order\" the bot builds in file order")
	var o := Bot.play(c, Game.config, c.levels[0], 1)
	expect(o.won and o.towers > 0, "the bot builds and wins with renamed towers (%d towers)" % o.towers)
	c = _level_content(MAP, waves, _bot_towers(["boom"]), 200)
	var b := Battle.new(c, Game.config, c.levels[0], 1)
	Bot._think(b, {}, 0)
	expect(not b.towers.is_empty() and b.towers.values().all(func(t: Entities.Tower) -> bool: return t.type == "boom"),
		"with \"bot_order\": [\"boom\"] it builds only boom towers")
	var errors: PackedStringArray = []
	Content.from_data({"towers": _bot_towers(["zap", "laser"]), "enemies": {"enemies": FIXTURE_ENEMIES},
		"legend": {"tiles": LEGEND}, "levels": []}, errors)
	expect(Array(errors).any(func(m: String) -> bool: return m.contains("bot_order names \"laser\"")),
		"an id in bot_order that isn't a tower is reported (got %s)" % [errors])


func test_every_id_in_the_bot_order_is_a_tower() -> void:
	var ids := Game.content.towers.map(func(t: Dictionary) -> String: return str(t["id"]))
	expect(not Game.content.bot_order.is_empty(), "the bot has towers to build")
	for id: String in Game.content.bot_order:
		expect(id in ids, "bot_order's \"%s\" is in towers.json" % id)


func test_the_bot_covers_every_route() -> void:
	var c := _level_content(FAR_ROUTES, [
		{"groups": [{"enemy": "dummy", "count": 4, "gap": 1.0}, {"enemy": "dummy", "count": 4, "gap": 1.0, "route": 1}]},
		{"groups": [{"enemy": "dummy", "count": 6, "gap": 0.8, "route": 1}]}], _bot_towers(), 240)
	var cov := Bot._coverage(c.levels[0].map, 30.0, {})
	expect(int(cov.get(Vector2i(1, 1), 0)) > 0, "a cell next to route 1 only is worth building on")
	var o := Bot.play(c, Game.config, c.levels[0], 1)
	expect(o.won and o.lives >= 8, "the bot defends both routes (won: %s, %d/10 lives)" % [o.won, o.lives])
	var idle := Bot.play(c, Game.config, c.levels[0], 1, false)
	expect(not idle.won, "and the level can't be won without towers")


# --- Balance what-ifs (tools/balance.gd gold= hp= margin=1) ----------------------

func test_balance_what_ifs_change_only_a_copy() -> void:
	var level := Game.content.levels[0]
	var gold := level.start_gold
	var copy := level.with_changes(777, level.hp_mult * 2.0)
	expect_eq(level.start_gold, gold, "the level itself is untouched")
	var b := Battle.new(Game.content, Game.config, copy, 1)
	expect_eq(b.gold, 777, "a battle of the copy starts with gold=777")
	var id := str(Game.content.enemies[0]["id"])
	b._spawn(id, 0.0)
	expect(is_equal_approx(b.enemies[0].max_hp, float(Game.content.get_entry(id)["hp"]) * level.hp_mult * 2.0), "and with hp= health")
	var c := _level_content(MAP, [{"groups": [{"enemy": "dummy", "count": 8, "gap": 0.6}]}], _bot_towers(), 300)
	var need: int = load("res://tools/balance.gd").least_gold(c, Game.config, c.levels[0])
	var o := Bot.play(c, Game.config, c.levels[0].with_changes(need, 1.0), 1)
	expect(need > 0 and need < 300 and o.won, "margin=1 finds the least gold the bot needs (%d)" % need)


# --- Turning turret heads, the end of the barrel, top-down enemies ---------------

## A straight road down the left column.
const ROAD_DOWN := """
S..
P..
P..
G..
"""
## ROAD_DOWN's own legend, so the checks don't depend on the game's legend.json.
const ROAD_LEGEND := {
	".": {"kind": "build", "tile": "build"},
	"P": {"kind": "path", "tile": "path"},
	"S": {"kind": "spawn", "tile": "path"},
	"G": {"kind": "goal", "tile": "path"},
}


## The game's first tower and first enemy on ROAD_DOWN, stripped to plain
## defaults (a tower with no "base" or "muzzle", a side-view walking enemy),
## then with the extra fields. A null extra removes the field. So the checks
## hold whatever the game's own first tower and enemy look like.
func _view_content(tower_extra: Dictionary, enemy_extra: Dictionary) -> Content:
	var errors: PackedStringArray = []
	var tower: Dictionary = (Game.content.towers[0] as Dictionary).duplicate(true)
	tower.erase("base")
	tower.erase("muzzle")
	_merge(tower, tower_extra)
	var enemy: Dictionary = (Game.content.enemies[0] as Dictionary).duplicate(true)
	for f: String in ["splits_into", "flying", "boss"]:
		enemy.erase(f)
	enemy["view"] = "side"
	_merge(enemy, enemy_extra)
	var c := Content.from_data({
		"towers": {"towers": [tower]},
		"enemies": {"enemies": [enemy]},
		"legend": {"tiles": ROAD_LEGEND},
		"levels": [{"id": "road", "map": ROAD_DOWN, "start_gold": 500, "lives": 10,
			"waves": [{"groups": [{"enemy": enemy["id"], "count": 2, "gap": 1.0}]}]}],
	}, errors)
	assert(c != null, "\n".join(errors))
	return c


func _merge(d: Dictionary, extra: Dictionary) -> void:
	for k: Variant in extra:
		if extra[k] == null:
			d.erase(k)
		else:
			d[k] = extra[k]


## Art for a turret's fixed base: a base one of the game's towers uses, else
## UnitsView's shared plinth, else the tower's own art (any picture will do).
func _any_base() -> String:
	for t: Dictionary in Game.content.towers:
		if t.has("base"):
			return str(t["base"])
	if ResourceLoader.exists("res://" + UnitsView.BASE) or FileAccess.file_exists("res://" + UnitsView.BASE):
		return UnitsView.BASE
	return str(Game.content.towers[0]["sprite"])


## One barrel length per level of the game's first tower: `first`, then one
## more per level.
func _muzzle(first: float, step: float = 1.0) -> Array:
	var out: Array = []
	for i: int in (Game.content.towers[0]["levels"] as Array).size():
		out.append(first + step * i)
	return out


## A battle on ROAD_DOWN with one tower built beside the road, and a view of it.
func _view_battle(c: Content) -> Array:
	var b := Battle.new(c, Game.config.duplicate(), c.levels[0], 1)
	b.gold = 1000
	b.build(str(c.towers[0]["id"]), Vector2i(1, 1))
	var view := UnitsView.new()
	tree.root.add_child(view)
	view.setup(b)
	view.sync(1.0)
	b.call_wave()
	return [b, view]


## Steps until a tower fires (the head snaps like the battle screen does) and
## returns that FIRE event, or null.
func _step_until_fire(b: Battle, view: UnitsView, seconds: float) -> SimEvent:
	for i: int in GameConfig.ticks(seconds):
		view.remember()
		for e: SimEvent in b.step():
			if e.type == SimEvent.Type.FIRE:
				view.snap_head(Vector2i((e.pos / GameConfig.CELL).floor()))
				view.sync(0.0)
				return e
		view.sync(1.0)
	return null


func test_an_aimed_turret_head_turns_to_its_target() -> void:
	var c := _view_content({"base": _any_base(), "muzzle": _muzzle(8)}, {})
	var made := _view_battle(c)
	var b: Battle = made[0]
	var view: UnitsView = made[1]
	var cell := Vector2i(1, 1)
	var head := view.tower_sprite(cell)
	expect_eq(head.rotation, 0.0, "the head starts facing right")
	var fire := _step_until_fire(b, view, 8.0)
	if not expect(fire != null, "the tower fired at the enemy on the road"):
		view.queue_free()
		return
	var want := (b.towers[cell].aim - GameConfig.cell_center(cell)).angle()
	expect(absf(want) > 0.3, "the target is not straight ahead of the head (%.2f rad)" % want)
	expect(absf(angle_difference(head.rotation, want)) < 0.02, "the head turned to its target: %.2f, wanted %.2f" % [head.rotation, want])
	expect(not head.flip_h, "a turning head is rotated, not flipped")
	view.queue_free()


func test_pulse_shots_leave_from_the_end_of_the_barrel() -> void:
	var c := _view_content({"base": _any_base(), "muzzle": _muzzle(30, 0)}, {})
	var made := _view_battle(c)
	var b: Battle = made[0]
	var view: UnitsView = made[1]
	var fire := _step_until_fire(b, view, 8.0)
	if not expect(fire != null and not b.shots.is_empty(), "the tower fired a shot"):
		view.queue_free()
		return
	var shot: Entities.Shot = b.shots[b.shots.size() - 1]
	var barrel := c.muzzle(shot.tower, shot.level)
	expect_eq(barrel, 30.0, "level 1's barrel is 30 px long (longer than a shot flies in its first tick)")
	var sprite := view.shot_sprite(shot.id)
	expect(sprite != null, "the shot is drawn")
	if sprite != null:
		expect(absf(sprite.position.distance_to(shot.origin) - barrel) < 1.5,
			"the shot starts %.1f px from the tower's centre, at the barrel's end (%.0f px)" % [sprite.position.distance_to(shot.origin), barrel])
		var along := (shot.target_pos - shot.origin).normalized()
		expect((sprite.position - shot.origin).normalized().dot(along) > 0.98, "and on the line to the target")
	# Without "muzzle" a shot leaves from the centre, as before.
	var plain := _view_battle(_view_content({}, {}))
	var pb: Battle = plain[0]
	var pview: UnitsView = plain[1]
	if _step_until_fire(pb, pview, 8.0) != null and not pb.shots.is_empty():
		var s: Entities.Shot = pb.shots[pb.shots.size() - 1]
		expect(pview.shot_sprite(s.id).position.distance_to(s.pos) < 1.5, "no \"muzzle\": the shot is drawn where it is, not pushed out")
	view.queue_free()
	pview.queue_free()


## What's wrong with a tower's "muzzle" against its head art: a barrel can't be
## longer than half the art's width (the head is centred on the cell and
## points right).
func _barrel_problems(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var half := Sprites.view_size(str(d["sprite"])).x * 0.5
	for i: int in (d.get("muzzle", []) as Array).size():
		var m := float(d["muzzle"][i])
		if m < 0.0 or m > half + 1.0:
			out.append("%s: level %d barrel %.0f px doesn't fit its art (%.0f px wide)" % [d["id"], i + 1, m, half * 2.0])
	return out


func test_barrel_lengths_fit_the_head_art() -> void:
	for d: Dictionary in Game.content.towers:
		for problem: String in _barrel_problems(d):
			expect(false, problem)
	var fixture := (Game.content.towers[0] as Dictionary).duplicate(true)
	fixture["muzzle"] = [Sprites.view_size(str(fixture["sprite"])).x + 8.0]
	expect_eq(_barrel_problems(fixture).size(), 1, "a barrel longer than its art is reported")
	fixture["muzzle"] = [1.0]
	expect(_barrel_problems(fixture).is_empty(), "a barrel that fits passes")


func test_a_top_down_enemy_turns_to_its_heading() -> void:
	var made := _view_battle(_view_content({}, {"view": "top"}))
	var b: Battle = made[0]
	var view: UnitsView = made[1]
	for i: int in GameConfig.ticks(1.5):
		view.remember()
		b.step()
		view.sync(1.0)
	if not expect(not b.enemies.is_empty(), "an enemy is on the road"):
		view.queue_free()
		return
	var sprite := view.enemy_sprite(b.enemies[0].id)
	expect(absf(angle_difference(sprite.rotation, PI * 0.5)) < 0.05, "walking down, it faces down: %.2f rad" % sprite.rotation)
	view.queue_free()
	var side := _view_battle(_view_content({}, {}))
	var sb: Battle = side[0]
	var sview: UnitsView = side[1]
	for i: int in GameConfig.ticks(1.5):
		sview.remember()
		sb.step()
		sview.sync(1.0)
	expect_eq(sview.enemy_sprite(sb.enemies[0].id).rotation, 0.0, "a side-view enemy is never rotated")
	sview.queue_free()
