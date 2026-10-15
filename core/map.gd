class_name Map
extends RefCounted
## A level's grid, parsed from an ASCII file with content/legend.json.
## One goal (G) and one or more routes. Each route has one spawn and a single
## path of path cells joining it to the goal with no branches. Route 0 is the
## legend's plain spawn and path letters (S, P); a legend entry with
## "route": 1 (R, Q) puts a spawn or path cell on route 1, and so on.
## Ground enemies walk their route's cell centers; flyers go straight from
## their route's spawn to the goal.

enum Kind { BUILD, PATH, BLOCK }

## Tile art name for a legend entry without "tile".
const DEFAULT_TILE := "grass"

var width := 0
var height := 0
## Kind per cell, row by row.
var kinds: Array[Kind] = []
## Tile art name per cell ("grass", "path", "rock"...), from the legend.
var tiles: PackedStringArray = []
## Decoration frame per cell (cells without one are absent).
var decor: Dictionary[Vector2i, int] = {}
## Route 0's spawn (the same as spawns[0]).
var spawn := Vector2i(-1, -1)
var goal := Vector2i(-1, -1)
## Spawn cell per route number.
var spawns: Dictionary[int, Vector2i] = {}
## Route number of each path cell (spawn and goal cells aren't in it).
var route_at: Dictionary[Vector2i, int] = {}
## Per route: cell centers from its spawn to the goal (map pixels), the
## distance along the path at each, the path's length and the straight
## flight's length.
var route_waypoints: Array[Array] = []
var route_dist: Array[PackedFloat32Array] = []
var route_lengths: PackedFloat32Array = []
var flight_lengths: PackedFloat32Array = []
## Route 0's waypoints and lengths (single-route code can keep using these).
var waypoints: Array[Vector2] = []
var path_length := 0.0
var flight_length := 0.0


## Parses `text` (one line per row). Problems go to `errors` as "row R col C: ..."
## messages; returns null if there are any.
static func parse(text: String, legend: Dictionary, errors: PackedStringArray, where: String = "map") -> Map:
	var start := errors.size()
	var m := Map.new()
	var rows: PackedStringArray = []
	for line: String in text.replace("\r", "").split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.rstrip(" "))
	if rows.is_empty():
		errors.append("%s: is empty" % where)
		return null
	m.height = rows.size()
	m.width = rows[0].length()
	for y: int in m.height:
		if rows[y].length() != m.width:
			errors.append("%s: row %d is %d wide, expected %d (every row must be the same width)" % [where, y + 1, rows[y].length(), m.width])
			return null
		for x: int in m.width:
			var ch := rows[y][x]
			if not legend.has(ch):
				errors.append("%s: row %d col %d: '%s' isn't in content/legend.json" % [where, y + 1, x + 1, ch])
				m.kinds.append(Kind.BLOCK)
				m.tiles.append(DEFAULT_TILE)
				continue
			var entry: Dictionary = legend[ch]
			var kind := str(entry.get("kind", "block"))
			match kind:
				"build": m.kinds.append(Kind.BUILD)
				"path", "spawn", "goal": m.kinds.append(Kind.PATH)
				_: m.kinds.append(Kind.BLOCK)
			m.tiles.append(str(entry.get("tile", DEFAULT_TILE)))
			if entry.has("decor"):
				m.decor[Vector2i(x, y)] = int(entry["decor"])
			var route := int(entry.get("route", 0))
			if kind == "path":
				m.route_at[Vector2i(x, y)] = route
			elif kind == "spawn":
				if m.spawns.has(route):
					errors.append("%s: more than one spawn%s" % [where, "" if route == 0 else " for route %d" % route])
				m.spawns[route] = Vector2i(x, y)
				if route == 0:
					m.spawn = Vector2i(x, y)
			elif kind == "goal":
				if m.goal.x >= 0:
					errors.append("%s: more than one goal" % where)
				m.goal = Vector2i(x, y)
	if m.spawn.x < 0:
		errors.append("%s: no spawn" % where)
	else:
		for r: int in m.spawns.size():
			if not m.spawns.has(r):
				errors.append("%s: no spawn for route %d (routes are numbered 0, 1, 2... without gaps)" % [where, r])
	if m.goal.x < 0:
		errors.append("%s: no goal" % where)
	if errors.size() == start:
		m._trace_path(errors, where)
	return m if errors.size() == start else null


func kind(cell: Vector2i) -> Kind:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return Kind.BLOCK
	return kinds[cell.y * width + cell.x]


func tile(cell: Vector2i) -> String:
	return tiles[cell.y * width + cell.x]


## How many routes (spawns with their own path) the map has.
func route_count() -> int:
	return route_lengths.size()


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


## Follows each route's path cells from its spawn to the goal; every step must
## have exactly one way forward on that route. Cells of other routes don't
## count, so two routes may run side by side.
func _trace_path(errors: PackedStringArray, where: String) -> void:
	var on_a_route: Dictionary[Vector2i, bool] = {}
	for r: int in spawns.size():
		var label := "" if spawns.size() == 1 else "route %d: " % r
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
				errors.append("%s: %sthe path stops at row %d col %d before reaching the goal" % [where, label, cell.y + 1, cell.x + 1])
				return
			if next.size() > 1:
				errors.append("%s: %sthe path branches at row %d col %d (paths can't fork)" % [where, label, cell.y + 1, cell.x + 1])
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
		errors.append("%s: %d path cells aren't on the route from %s to the goal" % [where, path_cells - on_a_route.size(),
			"spawn" if spawns.size() == 1 else "a spawn"])
		return
	waypoints.assign(route_waypoints[0])
	path_length = route_lengths[0]
	flight_length = flight_lengths[0]
