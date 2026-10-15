class_name Entities
extends RefCounted
## Plain data for the things in a battle. The rules live in Battle; views
## only read these.


class Enemy:
	extends RefCounted
	var id: int
	var type: String
	var hp: float
	var max_hp: float
	var speed: float
	var armor: float
	var bounty: int
	var lives: int
	var flying := false
	var boss := false
	## Pixels travelled along the path (or the flight line).
	var progress := 0.0
	var pos := Vector2.ZERO
	## Speed multiplier while slowed, and ticks of slow left.
	var slow := 1.0
	var slow_ticks := 0
	var flash := 0


class Tower:
	extends RefCounted
	var type: String
	var cell: Vector2i
	var level := 1
	## Gold spent on it so far (build + upgrades), for the sell refund.
	var spent := 0
	var cooldown := 0
	## "first", "last", "strong" or "close".
	var target_mode := "first"
	## Where it aimed last (views turn the barrel toward it).
	var aim := Vector2.ZERO


class Shot:
	extends RefCounted
	var id: int
	var tower: String
	var pos: Vector2
	var target_id: int
	## Where it's heading if the target is gone.
	var target_pos: Vector2
	var speed: float
	var damage: float
	var splash := 0.0
	var slow := 1.0
	var slow_ticks := 0
	var done := false
