class_name Content
extends RefCounted
## Towers, enemies, the map legend and the levels from content/, validated.
## Errors name the file and the entry. See docs/content.md.

const DIR := "res://content"
const TOWER_KINDS := ["bullet", "splash", "slow", "ray"]
## Fields each tower kind needs on every level.
const KIND_FIELDS := {
	"bullet": ["cost", "damage", "range", "rate", "speed"],
	"splash": ["cost", "damage", "range", "rate", "speed", "splash"],
	"slow": ["cost", "damage", "range", "rate", "speed", "slow", "slow_time"],
	"ray": ["cost", "damage", "range", "rate"],
}
const ENEMY_FIELDS := ["hp", "speed", "bounty", "sprite"]
## How an enemy's art is drawn: "side" (stands, flips to face its way) or
## "top" (seen from above, turns to its heading).
const ENEMY_VIEWS := ["side", "top"]

var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var legend: Dictionary = {}
## Tower ids in the order the balance bot builds them (repeats). From
## towers.json "bot_order"; without it, every tower once in file order.
var bot_order: Array[String] = []
var levels: Array[LevelData] = []
var _by_id: Dictionary = {}


static func load_dir(dir: String, errors: PackedStringArray) -> Content:
	var data := {}
	for name: String in ["towers", "enemies", "legend"]:
		var parsed: Variant = _read_json(dir.path_join(name + ".json"), errors)
		if parsed != null:
			data[name] = parsed
	if not errors.is_empty():
		return null
	var level_files: Array = []
	var level_dir := dir.path_join("levels")
	for f: String in DirAccess.get_files_at(level_dir):
		if f.ends_with(".txt"):
			level_files.append(f.get_basename())
	level_files.sort()
	data["levels"] = []
	for base: String in level_files:
		var info: Variant = _read_json(level_dir.path_join(base + ".json"), errors)
		var map_text := FileAccess.get_file_as_string(level_dir.path_join(base + ".txt"))
		if info is Dictionary:
			(info as Dictionary)["id"] = base
			(info as Dictionary)["map"] = map_text
			data["levels"].append(info)
	if not errors.is_empty():
		return null
	return from_data(data, errors)


static func _read_json(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: missing" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Builds content from parsed JSON (checks pass small made-up content).
## `data.levels` is a list of {id, map (ASCII text), name, start_gold, lives, waves}.
static func from_data(data: Dictionary, errors: PackedStringArray) -> Content:
	var start := errors.size()
	var c := Content.new()
	var ids := {}
	var add_id := func(file: String, e: Variant) -> bool:
		if not e is Dictionary or str(e.get("id", "")).is_empty():
			errors.append("%s: every entry needs an \"id\"" % file)
			return false
		if ids.has(e["id"]):
			errors.append("%s: id \"%s\" is used twice" % [file, e["id"]])
			return false
		ids[e["id"]] = true
		return true

	for t: Variant in data.get("towers", {}).get("towers", []):
		if not add_id.call("towers.json", t):
			continue
		var where := "towers.json \"%s\"" % t["id"]
		var kind := str(t.get("kind", ""))
		if kind not in TOWER_KINDS:
			errors.append("%s: kind must be one of %s" % [where, ", ".join(TOWER_KINDS)])
			continue
		if str(t.get("sprite", "")).is_empty():
			errors.append("%s: needs a \"sprite\" (its art in assets/towers/)" % where)
		if t.has("base") and str(t["base"]).is_empty():
			errors.append("%s: \"base\" must be an art path (or leave it out for the shared plinth)" % where)
		if t.has("muzzle") and (not t["muzzle"] is Array or (t["muzzle"] as Array).size() != t.get("levels", []).size()):
			errors.append("%s: \"muzzle\" must list one barrel length per level (%d)" % [where, t.get("levels", []).size()])
		var targets: Array = t.get("targets", ["ground", "air"])
		if targets.is_empty() or targets.any(func(x: Variant) -> bool: return str(x) not in ["ground", "air"]):
			errors.append("%s: \"targets\" must list \"ground\" and/or \"air\"" % where)
		var levels: Array = t.get("levels", [])
		if levels.is_empty():
			errors.append("%s: needs at least one entry in \"levels\"" % where)
		for i: int in levels.size():
			for f: String in KIND_FIELDS[kind]:
				if not levels[i].has(f):
					errors.append("%s: level %d is missing \"%s\" (a %s tower needs %s)" % [where, i + 1, f, kind, ", ".join(KIND_FIELDS[kind])])
		c.towers.append(t)

	for e: Variant in data.get("enemies", {}).get("enemies", []):
		if not add_id.call("enemies.json", e):
			continue
		for f: String in ENEMY_FIELDS:
			if not e.has(f):
				errors.append("enemies.json \"%s\": missing \"%s\"" % [e["id"], f])
		if str(e.get("view", "side")) not in ENEMY_VIEWS:
			errors.append("enemies.json \"%s\": \"view\" must be \"side\" or \"top\"" % e["id"])
		c.enemies.append(e)
	var enemy_ids := c.enemies.map(func(e: Dictionary) -> String: return str(e["id"]))
	for e: Dictionary in c.enemies:
		var into := str(e.get("splits_into", ""))
		if not into.is_empty() and into not in enemy_ids:
			errors.append("enemies.json \"%s\": splits_into \"%s\" isn't an enemy" % [e["id"], into])

	c.legend = data.get("legend", {}).get("tiles", {})
	for ch: String in c.legend:
		if ch.length() != 1:
			errors.append("legend.json: key \"%s\" must be a single character" % ch)
		var kind := str((c.legend[ch] as Dictionary).get("kind", ""))
		if kind not in ["build", "path", "block", "spawn", "goal"]:
			errors.append("legend.json \"%s\": kind must be build, path, block, spawn or goal" % ch)
		var route: Variant = (c.legend[ch] as Dictionary).get("route", 0)
		if not (route is float or route is int) or int(route) < 0 or float(route) != int(route):
			errors.append("legend.json \"%s\": \"route\" must be a whole number, 0 or more" % ch)

	for l: Variant in data.get("levels", []):
		var where := "levels/%s" % l.get("id", "?")
		var map := Map.parse(str(l.get("map", "")), c.legend, errors, where + ".txt")
		var waves: Array = l.get("waves", [])
		if waves.is_empty():
			errors.append("%s.json: needs at least one wave" % where)
		for wi: int in waves.size():
			var groups: Array = waves[wi].get("groups", [])
			if groups.is_empty():
				errors.append("%s.json: wave %d has no groups" % [where, wi + 1])
			for g: Dictionary in groups:
				if str(g.get("enemy", "")) not in enemy_ids:
					errors.append("%s.json: wave %d: enemy \"%s\" isn't in enemies.json" % [where, wi + 1, g.get("enemy", "")])
				if int(g.get("count", 0)) < 1:
					errors.append("%s.json: wave %d: \"count\" must be at least 1" % [where, wi + 1])
				var route := int(g.get("route", 0))
				if map != null and (route < 0 or route >= map.route_count()):
					errors.append("%s.json: wave %d: route %d isn't on the map (it has %d)" % [where, wi + 1, route, map.route_count()])
		var offered: Variant = l.get("towers", [])
		if not offered is Array:
			errors.append("%s.json: \"towers\" must be a list of tower ids (or leave it out for every tower)" % where)
			offered = []
		var tip: Variant = l.get("tip", "")
		if not tip is String:
			errors.append("%s.json: \"tip\" must be text" % where)
			tip = ""
		if map != null:
			var ld := LevelData.make(str(l.get("id", "")), str(l.get("name", l.get("id", ""))), map,
				int(l.get("start_gold", 100)), int(l.get("lives", 20)), waves)
			ld.hp_mult = float(l.get("hp_mult", 1.0))
			for id: Variant in offered:
				ld.towers.append(str(id))
			ld.tip = str(tip)
			c.levels.append(ld)

	var tower_ids: Array[String] = []
	for t: Dictionary in c.towers:
		tower_ids.append(str(t["id"]))
	var order: Variant = data.get("towers", {}).get("bot_order", tower_ids)
	if not order is Array or ((order as Array).is_empty() and not tower_ids.is_empty()):
		errors.append("towers.json: \"bot_order\" must list tower ids (or leave it out for file order)")
	else:
		for id: Variant in order:
			if str(id) not in tower_ids:
				errors.append("towers.json: bot_order names \"%s\", which isn't a tower" % id)
			c.bot_order.append(str(id))

	for ld: LevelData in c.levels:
		for id: String in ld.towers:
			if id not in tower_ids:
				errors.append("levels/%s.json: \"towers\" names \"%s\", which isn't in towers.json" % [ld.id, id])

	for list: Array in [c.towers, c.enemies]:
		for e: Dictionary in list:
			c._by_id[str(e["id"])] = e
	return c if errors.size() == start else null


func get_entry(id: String) -> Dictionary:
	return _by_id.get(id, {})


## A tower's stats at a level (1-based), clamped to its last level.
func tower_level(id: String, level: int) -> Dictionary:
	var levels: Array = get_entry(id).get("levels", [{}])
	return levels[clampi(level - 1, 0, levels.size() - 1)]


## How far (view pixels) the end of a tower's barrel is from its centre at a
## level, from its optional "muzzle" list; 0 without one.
func muzzle(id: String, level: int) -> float:
	var list: Array = get_entry(id).get("muzzle", [])
	if list.is_empty():
		return 0.0
	return float(list[clampi(level - 1, 0, list.size() - 1)])


func tower_max_level(id: String) -> int:
	return get_entry(id).get("levels", []).size()


func level_index(id: String) -> int:
	for i: int in levels.size():
		if levels[i].id == id:
			return i
	return -1
