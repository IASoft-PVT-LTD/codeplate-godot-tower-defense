# Add a second path (more spawns)

Use when the user wants enemies to come from more than one cave: two or more spawns, each with its own path to the shared goal, and waves that say which path each group takes.

The map format grows a **route** number. Route 0 is today's `S` and `P`. Route 1 uses new letters, `R` (its spawn) and `Q` (its path). Each route is traced on its own, so paths may run side by side or cross each other's neighbourhood; they only meet at the goal `G`.

1. **Legend.** Add the route-1 letters to `content/legend.json` under `"tiles"`:
   ```json
   "R": {"kind": "spawn", "tile": "path", "route": 1},
   "Q": {"kind": "path", "tile": "path", "route": 1}
   ```
   For a third route, add two more letters with `"route": 2`, and so on.
2. **Map: store routes** (`core/map.gd`). Add these fields after `var spawn := Vector2i(-1, -1)`:
   ```gdscript
   ## Spawn cell per route; route 0's is `spawn`. A legend entry's "route" puts a
   ## spawn or path letter on another route, and every route is its own path to
   ## the shared goal.
   var spawns: Dictionary[int, Vector2i] = {}
   ## Route number of each path cell.
   var route_at: Dictionary[Vector2i, int] = {}
   ## Per route: cell centers (Array[Vector2]), distance at each, and lengths.
   var route_waypoints: Array[Array] = []
   var route_dist: Array[PackedFloat32Array] = []
   var route_lengths: PackedFloat32Array = []
   var flight_lengths: PackedFloat32Array = []
   ```
   In `parse()`, replace the `if kind == "spawn":` block (the one that reports "more than one spawn") with:
   ```gdscript
   			var route := int(entry.get("route", 0))
   			if kind == "path":
   				m.route_at[Vector2i(x, y)] = route
   			if kind == "spawn":
   				if m.spawns.has(route):
   					errors.append("%s: more than one spawn for route %d" % [where, route])
   				m.spawns[route] = Vector2i(x, y)
   				if route == 0:
   					m.spawn = Vector2i(x, y)
   ```
3. **Map: positions per route.** Replace `position_at()` and `flight_position_at()` with:
   ```gdscript
   ## Where a ground enemy on `route` is after travelling `distance` pixels.
   func position_at(distance: float, route: int = 0) -> Vector2:
   	var points: Array = route_waypoints[route]
   	var dist: PackedFloat32Array = route_dist[route]
   	if distance <= 0.0:
   		return points[0]
   	for i: int in range(1, points.size()):
   		if distance <= dist[i]:
   			var t := (distance - dist[i - 1]) / (dist[i] - dist[i - 1])
   			return (points[i - 1] as Vector2).lerp(points[i], t)
   	return points[-1]


   ## Where a flyer from `route`'s spawn is after travelling `distance` pixels.
   func flight_position_at(distance: float, route: int = 0) -> Vector2:
   	var a := GameConfig.cell_center(spawns[route])
   	var b := GameConfig.cell_center(goal)
   	return a.lerp(b, clampf(distance / flight_lengths[route], 0.0, 1.0))
   ```
4. **Map: trace every route.** Replace `_trace_path()` with:
   ```gdscript
   ## Follows each route's path cells from its spawn to the goal; every step must
   ## have exactly one way forward on that route.
   func _trace_path(errors: PackedStringArray, where: String) -> void:
   	var on_a_route: Dictionary[Vector2i, bool] = {}
   	for r: int in spawns.size():
   		if not spawns.has(r):
   			errors.append("%s: no spawn for route %d (routes are numbered 0, 1, 2... without gaps)" % [where, r])
   			return
   		var cell: Vector2i = spawns[r]
   		var seen: Dictionary[Vector2i, bool] = {cell: true}
   		var points: Array[Vector2] = [GameConfig.cell_center(cell)]
   		while cell != goal:
   			var next: Array[Vector2i] = []
   			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
   				var n := cell + d
   				if (n == goal or route_at.get(n, -1) == r) and not seen.has(n):
   					next.append(n)
   			if next.is_empty():
   				errors.append("%s: route %d: the path stops at row %d col %d before reaching the goal" % [where, r, cell.y + 1, cell.x + 1])
   				return
   			if next.size() > 1:
   				errors.append("%s: route %d: the path branches at row %d col %d (paths can't fork)" % [where, r, cell.y + 1, cell.x + 1])
   				return
   			cell = next[0]
   			seen[cell] = true
   			points.append(GameConfig.cell_center(cell))
   		on_a_route.merge(seen)
   		var dist := PackedFloat32Array([0.0])
   		for i: int in range(1, points.size()):
   			dist.append(dist[i - 1] + points[i - 1].distance_to(points[i]))
   		route_waypoints.append(points)
   		route_dist.append(dist)
   		route_lengths.append(dist[-1])
   		flight_lengths.append(GameConfig.cell_center(spawns[r]).distance_to(GameConfig.cell_center(goal)))
   	var path_cells := 0
   	for k: Kind in kinds:
   		path_cells += int(k == Kind.PATH)
   	if path_cells != on_a_route.size():
   		errors.append("%s: %d path cells aren't on the route from a spawn to the goal" % [where, path_cells - on_a_route.size()])
   	waypoints = route_waypoints[0]
   	_dist = route_dist[0]
   	path_length = route_lengths[0]
   	flight_length = flight_lengths[0]
   ```
   The last four lines keep `waypoints`, `path_length` and `flight_length` meaning route 0, so code that reads them still works. Update the class comment at the top of the file (it still says "one spawn").
5. **Enemies remember their route.** In `core/entities.gd`, add to `class Enemy` after `var boss := false`:
   ```gdscript
   	## Which of the map's routes it walks (0 = the first).
   	var route := 0
   ```
6. **Waves say which route.** In `core/level_data.gd` `wave_spawns()`, append the group's route to each spawn (and update the doc comment to `[tick offset, enemy id, route]`):
   ```gdscript
   			out.append([GameConfig.ticks(delay + gap * i), str(g["enemy"]), int(g.get("route", 0))])
   ```
7. **Battle uses the route** (`core/battle.gd`):
   - `_start_wave()`: `_pending.append([tick + int(s[0]), s[1], s[2]])` (and the comment on `_pending`).
   - `_spawn_due()`: replace the `_spawn(...)` line with
     ```gdscript
     		var p: Array = _pending.pop_front()
     		_spawn(str(p[1]), 0.0, int(p[2]))
     ```
   - `_spawn()`: make it `func _spawn(type: String, progress: float, route: int = 0) -> void:` and set `e.route = route` just before `e.pos = _position(e)`.
   - `_position()`: `return map.flight_position_at(e.progress, e.route) if e.flying else map.position_at(e.progress, e.route)`
   - `remaining()`: `return (map.flight_lengths[e.route] if e.flying else map.route_lengths[e.route]) - e.progress`
   - Splitters: in `_damage()`, pass the route on: `_spawn(into, maxf(0.0, e.progress - rng.randf_range(0.0, 12.0)), e.route)`.
8. **Validate wave routes** (`core/content.gd` `from_data()`), right after the `"count" must be at least 1` check:
   ```gdscript
   				var route := int(g.get("route", 0))
   				if map != null and (route < 0 or route >= map.route_lengths.size()):
   					errors.append("%s.json: wave %d: route %d isn't on the map (it has %d)" % [where, wi + 1, route, map.route_lengths.size()])
   ```
9. **The bot covers every route.** In `core/bot.gd` `_coverage()`, replace the `while d <= map.path_length:` sampling loop (and its `var d := 0.0`) with:
   ```gdscript
   	for r: int in map.route_lengths.size():
   		var d := 0.0
   		while d <= map.route_lengths[r]:
   			samples.append(map.position_at(d, r))
   			d += 6.0
   ```
10. **A cave at every spawn.** In `game/map_view.gd`, replace the four `spawn` sprite lines with a loop:
    ```gdscript
    	for cell: Vector2i in map.spawns.values():
    		var spawn := Sprite2D.new()
    		spawn.texture = Sprites.texture(SPAWN)
    		spawn.position = GameConfig.cell_center(cell)
    		add_child(spawn)
    ```
11. **A level with two routes.** Add `content/levels/level_07.txt` (or edit an existing map). Route 1 needs its own `R` and `Q` cells reaching `G` from a different side than route 0:
    ```
    ..R...........T.....
    ..Q.........b.......
    ..QQQQQQQ.........B.
    ........Q.....~.....
    ........QQQQQQQQQQQQ
    .T.................Q
    SPPPPP.............Q
    .....P....m........Q
    .....PPPPPPPPPPPPPPG
    L..........g.......L
    ```
    In `level_07.json`, give each wave group a `"route"` (0 or 1; missing means 0), e.g. `{"enemy": "grunt", "count": 8, "gap": 1.2, "route": 1}`. Alternate routes between groups so both paths need towers. Then run `tools/balance.gd -- level=level_07` and adjust `start_gold` and the waves until the bot wins with at least half its lives and loses without towers (a version of this level with 400 gold, 8 waves and no boss passed with 20/20).
12. **Add a check** to `checks/tests/test_battle.gd`:
    ```gdscript
    func test_a_second_route_walks_its_own_path() -> void:
    	var errors: PackedStringArray = []
    	var level := {"id": "two", "map": "RQQQQQ\n.....Q\nSPPPPG", "start_gold": 0, "lives": 10,
    		"waves": [{"groups": [{"enemy": "dummy", "count": 1, "route": 1}]}]}
    	var data := {
    		"towers": {"towers": [{"id": "bow", "kind": "bullet", "sprite": "x", "levels": [
    			{"cost": 50, "damage": 10, "range": 40, "rate": 2, "speed": 600}]}]},
    		"enemies": {"enemies": [{"id": "dummy", "hp": 20, "speed": 24, "bounty": 5, "sprite": "x"}]},
    		"legend": {"tiles": Game.content.legend},
    		"levels": [level],
    	}
    	var c := Content.from_data(data, errors)
    	if not expect(c != null, "a two-route level is valid: %s" % [errors]):
    		return
    	expect_eq(c.levels[0].map.route_lengths.size(), 2, "the map has two routes")
    	var b := Battle.new(c, Game.config.duplicate(), c.levels[0], 1)
    	b.call_wave()
    	_run(b, 0.2)
    	if not expect_eq(b.enemies.size(), 1, "the enemy spawned"):
    		return
    	var e := b.enemies[0]
    	expect_eq(e.route, 1, "it walks route 1")
    	expect(e.pos.y < GameConfig.CELL, "it starts at route 1's spawn, on the top row")
    	_run(b, 10.0) # route 1 is 7 cells: 168 px at 24 px/s
    	expect_eq(b.lives, 9, "it reached the goal along route 1")
    	level["waves"] = [{"groups": [{"enemy": "dummy", "count": 1, "route": 2}]}]
    	errors.clear()
    	expect(Content.from_data(data, errors) == null and Array(errors).any(func(m: String) -> bool: return m.contains("route 2 isn't on the map")),
    		"a wave on a route the map doesn't have is an error")
    ```
13. **Docs.** In `docs/content.md`, document the legend's `route` field, `R`/`Q`, and the wave group's `route`. In `AGENTS.md` rule 5, change "one `S`" and "one path" to "one spawn and one path per route".

## Verify

1. Run the checks: the new check, map validation (each route must reach `G` without forking) and `test_every_level_is_fair` must pass.
2. Run `tools/balance.gd` and tell the user how the new level plays.
3. Take `screen=battle level=7 wave=4 walk=6 wait=1` and look: a cave at each spawn, enemies on both paths, and towers covering both.
