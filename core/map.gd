class_name Map
extends RefCounted
## A level's grid, parsed from an ASCII file with content/legend.json.
## One spawn (S), one goal (G), and a single path of path cells joining them
## with no branches. Ground enemies walk the path's cell centers; flyers go
## straight from spawn to goal.

enum Kind { BUILD, PATH, BLOCK }

var width := 0
var height := 0
## Kind per cell, row by row.
var kinds: Array[Kind] = []
## Tile art name per cell ("grass", "path", "rock"...), from the legend.
var tiles: PackedStringArray = []
## Decoration frame per cell (cells without one are absent).
var decor: Dictionary[Vector2i, int] = {}
var spawn := Vector2i(-1, -1)
var goal := Vector2i(-1, -1)
## Cell centers from spawn to goal, in map pixels.
var waypoints: Array[Vector2] = []
## Distance along the path at each waypoint.
var _dist: PackedFloat32Array = []
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
				m.tiles.append("rock")
				continue
			var entry: Dictionary = legend[ch]
			var kind := str(entry.get("kind", "block"))
			match kind:
				"build": m.kinds.append(Kind.BUILD)
				"path", "spawn", "goal": m.kinds.append(Kind.PATH)
				_: m.kinds.append(Kind.BLOCK)
			m.tiles.append(str(entry.get("tile", "grass")))
			if entry.has("decor"):
				m.decor[Vector2i(x, y)] = int(entry["decor"])
			if kind == "spawn":
				if m.spawn.x >= 0:
					errors.append("%s: more than one spawn" % where)
				m.spawn = Vector2i(x, y)
			elif kind == "goal":
				if m.goal.x >= 0:
					errors.append("%s: more than one goal" % where)
				m.goal = Vector2i(x, y)
	if m.spawn.x < 0:
		errors.append("%s: no spawn" % where)
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


## Where a ground enemy is after travelling `distance` pixels along the path.
func position_at(distance: float) -> Vector2:
	if distance <= 0.0:
		return waypoints[0]
	for i: int in range(1, waypoints.size()):
		if distance <= _dist[i]:
			var t := (distance - _dist[i - 1]) / (_dist[i] - _dist[i - 1])
			return waypoints[i - 1].lerp(waypoints[i], t)
	return waypoints[-1]


## Where a flyer is after travelling `distance` pixels.
func flight_position_at(distance: float) -> Vector2:
	var a := GameConfig.cell_center(spawn)
	var b := GameConfig.cell_center(goal)
	return a.lerp(b, clampf(distance / flight_length, 0.0, 1.0))


## Follows path cells from the spawn to the goal; every step must have
## exactly one way forward.
func _trace_path(errors: PackedStringArray, where: String) -> void:
	var seen: Dictionary[Vector2i, bool] = {spawn: true}
	var cell := spawn
	waypoints = [GameConfig.cell_center(cell)]
	while cell != goal:
		var next: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var n := cell + d
			if kind(n) == Kind.PATH and not seen.has(n):
				next.append(n)
		if next.is_empty():
			errors.append("%s: the path stops at row %d col %d before reaching the goal" % [where, cell.y + 1, cell.x + 1])
			return
		if next.size() > 1:
			errors.append("%s: the path branches at row %d col %d (paths can't fork)" % [where, cell.y + 1, cell.x + 1])
			return
		cell = next[0]
		seen[cell] = true
		waypoints.append(GameConfig.cell_center(cell))
	var path_cells := 0
	for k: Kind in kinds:
		path_cells += int(k == Kind.PATH)
	if path_cells != seen.size():
		errors.append("%s: %d path cells aren't on the route from spawn to goal" % [where, path_cells - seen.size()])
	_dist = [0.0]
	for i: int in range(1, waypoints.size()):
		_dist.append(_dist[i - 1] + waypoints[i - 1].distance_to(waypoints[i]))
	path_length = _dist[-1]
	flight_length = GameConfig.cell_center(spawn).distance_to(GameConfig.cell_center(goal))
