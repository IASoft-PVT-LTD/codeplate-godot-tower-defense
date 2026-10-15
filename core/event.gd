class_name SimEvent
extends RefCounted
## Something that happened in a battle tick. The views turn events into
## sounds, effects and HUD updates; checks assert on them.

enum Type {
	SPAWN, ## an enemy entered (`tag` = enemy id)
	FIRE, ## a tower fired (`tag` = tower id; `target` = where it aimed)
	HIT, ## an enemy took damage (`value` = amount, `tag` = tower id)
	SPLASH, ## a splash shell burst (`value` = radius)
	SLOW, ## an enemy was slowed
	KILL, ## an enemy died (`tag` = enemy id, `value` = bounty)
	LEAK, ## an enemy reached the goal (`value` = lives lost)
	BUILD, UPGRADE, SELL, ## tower changes (`tag` = tower id, `value` = gold)
	WAVE_START, ## a wave began (`value` = wave number, 1-based; `tag` = "early" if called early)
	WAVE_CLEAR, ## every enemy of every wave so far is gone
	WIN, LOSE,
}

var type: Type
var pos: Vector2
var value: float
var tag: String
var target: Vector2


static func make(p_type: Type, p_pos: Vector2, p_value: float = 0.0, p_tag: String = "", p_target: Vector2 = Vector2.ZERO) -> SimEvent:
	var e := SimEvent.new()
	e.type = p_type
	e.pos = p_pos
	e.value = p_value
	e.tag = p_tag
	e.target = p_target
	return e
