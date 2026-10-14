extends CheckCase
## The rules in core/battle.gd, on a small made-up level so the numbers are
## easy to follow: a straight path 10 cells long, one tower of each kind.

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
		"legend": {"tiles": Game.content.legend},
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
