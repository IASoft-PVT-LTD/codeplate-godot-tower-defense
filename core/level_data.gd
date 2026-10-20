class_name LevelData
extends RefCounted
## One level: its map, starting gold and lives, its waves, and optionally
## which towers it offers and a tip shown when it starts. Each wave is
## a list of groups `{enemy, count, gap, delay, route}` that spawn in parallel:
## after `delay` seconds, `count` enemies, one every `gap` seconds, walking
## the map's route `route` (0 if missing).

var id: String
var name: String
var map: Map
var start_gold: int
var lives: int
## Every enemy's health in this level is multiplied by this (difficulty knob).
var hp_mult := 1.0
var waves: Array
## Tower ids this level offers (level JSON "towers"); empty = every tower.
## Bring towers in one or two levels at a time so a new player isn't handed
## the whole list on level 1.
var towers: Array[String] = []
## A line shown under the level name when it starts and on the pause menu
## (level JSON "tip"), e.g. what a new tower or enemy does. "" = none.
var tip := ""


static func make(p_id: String, p_name: String, p_map: Map, p_gold: int, p_lives: int, p_waves: Array) -> LevelData:
	var l := LevelData.new()
	l.id = p_id
	l.name = p_name
	l.map = p_map
	l.start_gold = p_gold
	l.lives = p_lives
	l.waves = p_waves
	return l


## A copy of this level with another starting gold and health multiplier
## (tools/balance.gd's what-ifs; the content is untouched).
func with_changes(p_gold: int, p_hp_mult: float) -> LevelData:
	var l := LevelData.make(id, name, map, p_gold, lives, waves)
	l.hp_mult = p_hp_mult
	l.towers = towers
	l.tip = tip
	return l


## True if this level offers the tower `tower_id`.
func allows(tower_id: String) -> bool:
	return towers.is_empty() or tower_id in towers


## Every spawn of wave `index` (0-based) as [tick offset, enemy id, route], in order.
func wave_spawns(index: int) -> Array:
	var out: Array = []
	for g: Dictionary in waves[index].get("groups", []):
		var delay := float(g.get("delay", 0.0))
		var gap := float(g.get("gap", 1.0))
		for i: int in int(g["count"]):
			out.append([GameConfig.ticks(delay + gap * i), str(g["enemy"]), int(g.get("route", 0))])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out
