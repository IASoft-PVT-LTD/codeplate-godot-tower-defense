class_name LevelData
extends RefCounted
## One level: its map, starting gold and lives, and its waves. Each wave is
## a list of groups `{enemy, count, gap, delay}` that spawn in parallel:
## after `delay` seconds, `count` enemies, one every `gap` seconds.

var id: String
var name: String
var map: Map
var start_gold: int
var lives: int
## Every enemy's health in this level is multiplied by this (difficulty knob).
var hp_mult := 1.0
var waves: Array


static func make(p_id: String, p_name: String, p_map: Map, p_gold: int, p_lives: int, p_waves: Array) -> LevelData:
	var l := LevelData.new()
	l.id = p_id
	l.name = p_name
	l.map = p_map
	l.start_gold = p_gold
	l.lives = p_lives
	l.waves = p_waves
	return l


## Every spawn of wave `index` (0-based) as [tick offset, enemy id], in order.
func wave_spawns(index: int) -> Array:
	var out: Array = []
	for g: Dictionary in waves[index].get("groups", []):
		var delay := float(g.get("delay", 0.0))
		var gap := float(g.get("gap", 1.0))
		for i: int in int(g["count"]):
			out.append([GameConfig.ticks(delay + gap * i), str(g["enemy"])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out
