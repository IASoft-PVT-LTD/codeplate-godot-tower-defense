class_name Battle
extends RefCounted
## One level being played, stepped 30 times a second. Holds the gold, lives,
## towers, enemies and shots, and every rule. No nodes, no clock, no Input;
## randomness only from `rng`, so the same seed and the same commands always
## give the same battle.
##
##   var b := Battle.new(content, config, content.levels[0], seed)
##   b.build("arrow", Vector2i(4, 3))
##   b.call_wave()
##   while b.state == Battle.State.RUNNING:
##       for e: SimEvent in b.step(): ...

enum State { BUILDING, RUNNING, WON, LOST }
const TARGET_MODES: Array[String] = ["first", "last", "strong", "close"]

var content: Content
var config: GameConfig
var level: LevelData
var map: Map
var rng := RandomNumberGenerator.new()
var state: State = State.BUILDING
var tick := 0
var gold := 0
var lives := 0
## Waves started so far (the current wave number, 1-based).
var wave := 0
var kills := 0
var enemies: Array[Entities.Enemy] = []
var towers: Dictionary[Vector2i, Entities.Tower] = {}
var shots: Array[Entities.Shot] = []

var _pending: Array = [] # [tick due, enemy id], sorted
var _next_wave_tick := -1
var _cleared_wave := 0
var _next_enemy_id := 1
var _next_shot_id := 1
var _events: Array[SimEvent] = []


func _init(p_content: Content, p_config: GameConfig, p_level: LevelData, battle_seed: int) -> void:
	content = p_content
	config = p_config
	level = p_level
	map = level.map
	rng.seed = battle_seed
	gold = level.start_gold
	lives = level.lives


func total_waves() -> int:
	return level.waves.size()


func seconds() -> float:
	return tick * GameConfig.DT


## Seconds until the next wave starts on its own, or -1 if it isn't counting
## down (before the first wave, while a wave is still spawning, after the last).
func seconds_to_next_wave() -> float:
	if _next_wave_tick < 0:
		return -1.0
	return maxf(0.0, (_next_wave_tick - tick) * GameConfig.DT)


## Gold paid right now for calling the next wave early.
func early_bonus() -> int:
	var s := seconds_to_next_wave()
	return roundi(s * config.early_bonus_per_second) if s > 0.0 else 0


## 3, 2 or 1 stars for a won battle (0 otherwise), from the lives left.
func stars() -> int:
	if state != State.WON:
		return 0
	var share := float(lives) / float(level.lives)
	if share >= config.three_star_lives:
		return 3
	return 2 if share >= config.two_star_lives else 1


# --- Commands ---------------------------------------------------------------

## Starts the next wave: the first one (the battle waits for it), or the next
## one early while the countdown runs (for a gold bonus). False if it can't.
func call_wave() -> bool:
	if state == State.BUILDING:
		state = State.RUNNING
		_start_wave("")
		return true
	if state != State.RUNNING or _next_wave_tick < 0:
		return false
	var bonus := early_bonus()
	gold += bonus
	_start_wave("early")
	return true


## Why a tower can't be built there ("" if it can).
func build_problem(tower_id: String, cell: Vector2i) -> String:
	if state == State.WON or state == State.LOST:
		return "the battle is over"
	if content.get_entry(tower_id).is_empty():
		return "no tower \"%s\"" % tower_id
	if map.kind(cell) != Map.Kind.BUILD:
		return "can't build there"
	if towers.has(cell):
		return "a tower is already there"
	if gold < int(content.tower_level(tower_id, 1)["cost"]):
		return "not enough gold"
	return ""


func build(tower_id: String, cell: Vector2i) -> bool:
	if not build_problem(tower_id, cell).is_empty():
		return false
	var cost := int(content.tower_level(tower_id, 1)["cost"])
	var t := Entities.Tower.new()
	t.type = tower_id
	t.cell = cell
	t.spent = cost
	t.aim = GameConfig.cell_center(cell) + Vector2.RIGHT
	towers[cell] = t
	gold -= cost
	_emit(SimEvent.Type.BUILD, GameConfig.cell_center(cell), cost, tower_id)
	return true


## Gold for the next level of the tower on `cell`, or -1 if there's none.
func upgrade_cost(cell: Vector2i) -> int:
	var t: Entities.Tower = towers.get(cell)
	if t == null or t.level >= content.tower_max_level(t.type):
		return -1
	return int(content.tower_level(t.type, t.level + 1)["cost"])


func upgrade(cell: Vector2i) -> bool:
	var cost := upgrade_cost(cell)
	if cost < 0 or gold < cost or state == State.WON or state == State.LOST:
		return false
	var t := towers[cell]
	t.level += 1
	t.spent += cost
	gold -= cost
	_emit(SimEvent.Type.UPGRADE, GameConfig.cell_center(cell), cost, t.type)
	return true


func sell_value(cell: Vector2i) -> int:
	var t: Entities.Tower = towers.get(cell)
	return 0 if t == null else floori(t.spent * config.sell_refund)


## Sells the tower on `cell`; returns the gold paid back (0 if none).
func sell(cell: Vector2i) -> int:
	if not towers.has(cell) or state == State.WON or state == State.LOST:
		return 0
	var value := sell_value(cell)
	var t := towers[cell]
	towers.erase(cell)
	gold += value
	_emit(SimEvent.Type.SELL, GameConfig.cell_center(cell), value, t.type)
	return value


func set_target_mode(cell: Vector2i, mode: String) -> void:
	if towers.has(cell) and mode in TARGET_MODES:
		towers[cell].target_mode = mode


# --- Main loop --------------------------------------------------------------

## Advances one tick (1/30 s). Nothing moves before the first wave is called.
func step() -> Array[SimEvent]:
	var out := _events
	_events = []
	if state != State.RUNNING:
		return out
	tick += 1
	_spawn_due()
	_move_enemies()
	_fire_towers()
	_move_shots()
	enemies = enemies.filter(func(e: Entities.Enemy) -> bool: return e.hp > 0.0)
	shots = shots.filter(func(s: Entities.Shot) -> bool: return not s.done)
	_wave_flow()
	out.append_array(_events)
	_events = []
	return out


func _start_wave(tag: String) -> void:
	wave += 1
	_next_wave_tick = -1
	for s: Array in level.wave_spawns(wave - 1):
		_pending.append([tick + int(s[0]), s[1]])
	_emit(SimEvent.Type.WAVE_START, GameConfig.cell_center(map.spawn), wave, tag)


func _spawn_due() -> void:
	while not _pending.is_empty() and int(_pending[0][0]) <= tick:
		_spawn(str(_pending.pop_front()[1]), 0.0)


func _spawn(type: String, progress: float) -> void:
	var d := content.get_entry(type)
	var e := Entities.Enemy.new()
	e.id = _next_enemy_id
	_next_enemy_id += 1
	e.type = type
	e.max_hp = float(d["hp"]) * level.hp_mult
	e.hp = e.max_hp
	e.speed = float(d["speed"])
	e.armor = float(d.get("armor", 0.0))
	e.bounty = int(d["bounty"])
	e.lives = int(d.get("lives", 1))
	e.flying = bool(d.get("flying", false))
	e.boss = bool(d.get("boss", false))
	e.progress = progress
	e.pos = _position(e)
	enemies.append(e)
	_emit(SimEvent.Type.SPAWN, e.pos, 0.0, type)


func _position(e: Entities.Enemy) -> Vector2:
	return map.flight_position_at(e.progress) if e.flying else map.position_at(e.progress)


## Pixels an enemy still has to go.
func remaining(e: Entities.Enemy) -> float:
	return (map.flight_length if e.flying else map.path_length) - e.progress


func _move_enemies() -> void:
	for e: Entities.Enemy in enemies:
		e.flash = maxi(0, e.flash - 1)
		if e.slow_ticks > 0:
			e.slow_ticks -= 1
			if e.slow_ticks == 0:
				e.slow = 1.0
		e.progress += e.speed * e.slow * GameConfig.DT
		e.pos = _position(e)
		if remaining(e) <= 0.0 and e.hp > 0.0:
			e.hp = 0.0
			lives = maxi(0, lives - e.lives)
			_emit(SimEvent.Type.LEAK, e.pos, e.lives, e.type)
			if lives == 0 and state == State.RUNNING:
				state = State.LOST
				_emit(SimEvent.Type.LOSE, e.pos)


# --- Towers and shots ---------------------------------------------------------

func _fire_towers() -> void:
	for cell: Vector2i in towers:
		var t := towers[cell]
		t.cooldown = maxi(0, t.cooldown - 1)
		if t.cooldown > 0:
			continue
		var d := content.get_entry(t.type)
		var s := content.tower_level(t.type, t.level)
		var from := GameConfig.cell_center(cell)
		var target := _pick_target(t, from, float(s["range"]), d.get("targets", ["ground", "air"]))
		if target == null:
			continue
		t.cooldown = maxi(1, GameConfig.ticks(1.0 / float(s["rate"])))
		t.aim = target.pos
		_emit(SimEvent.Type.FIRE, from, 0.0, t.type, target.pos)
		var kind := str(d["kind"])
		if kind == "ray":
			_damage(target, float(s["damage"]), t.type, true)
			continue
		var shot := Entities.Shot.new()
		shot.id = _next_shot_id
		_next_shot_id += 1
		shot.tower = t.type
		shot.pos = from
		shot.target_id = target.id
		shot.target_pos = target.pos
		shot.speed = float(s["speed"])
		shot.damage = float(s["damage"])
		if kind == "splash":
			shot.splash = float(s["splash"])
		elif kind == "slow":
			shot.slow = float(s["slow"])
			shot.slow_ticks = GameConfig.ticks(float(s["slow_time"]))
		shots.append(shot)


func _pick_target(t: Entities.Tower, from: Vector2, reach: float, targets: Array) -> Entities.Enemy:
	var best: Entities.Enemy = null
	var best_score := INF
	for e: Entities.Enemy in enemies:
		if e.hp <= 0.0 or from.distance_to(e.pos) > reach:
			continue
		if ("air" if e.flying else "ground") not in targets:
			continue
		var score: float
		match t.target_mode:
			"last": score = -remaining(e)
			"strong": score = -e.hp
			"close": score = from.distance_to(e.pos)
			_: score = remaining(e) # "first": closest to the goal
		if score < best_score:
			best_score = score
			best = e
	return best


func _find(id: int) -> Entities.Enemy:
	for e: Entities.Enemy in enemies:
		if e.id == id and e.hp > 0.0:
			return e
	return null


func _move_shots() -> void:
	for s: Entities.Shot in shots:
		var target := _find(s.target_id)
		if target != null:
			s.target_pos = target.pos
		var step := s.speed * GameConfig.DT
		if s.pos.distance_to(s.target_pos) > step:
			s.pos = s.pos.move_toward(s.target_pos, step)
			continue
		s.pos = s.target_pos
		s.done = true
		if s.splash > 0.0:
			var targets: Array = content.get_entry(s.tower).get("targets", ["ground"])
			for e: Entities.Enemy in enemies.duplicate(): # kills can add splitter children
				if e.hp > 0.0 and e.pos.distance_to(s.pos) <= s.splash and ("air" if e.flying else "ground") in targets:
					_damage(e, s.damage, s.tower, false)
			_emit(SimEvent.Type.SPLASH, s.pos, s.splash, s.tower)
		elif target != null:
			_damage(target, s.damage, s.tower, false)
			if s.slow_ticks > 0 and target.hp > 0.0:
				if s.slow <= target.slow:
					target.slow = s.slow
				target.slow_ticks = maxi(target.slow_ticks, s.slow_ticks)
				_emit(SimEvent.Type.SLOW, target.pos, s.slow, s.tower)


## Armor takes a flat amount off each hit (never below 1) unless the tower
## ignores armor (ray towers do).
func _damage(e: Entities.Enemy, amount: float, tower: String, ignores_armor: bool) -> void:
	if e.hp <= 0.0:
		return
	var dmg := amount if ignores_armor else maxf(1.0, amount - e.armor)
	e.hp -= dmg
	e.flash = 3
	_emit(SimEvent.Type.HIT, e.pos, dmg, tower)
	if e.hp <= 0.0:
		kills += 1
		gold += e.bounty
		_emit(SimEvent.Type.KILL, e.pos, e.bounty, e.type)
		var d := content.get_entry(e.type)
		var into := str(d.get("splits_into", ""))
		for i: int in int(d.get("split_count", 0)) if not into.is_empty() else 0:
			_spawn(into, maxf(0.0, e.progress - rng.randf_range(0.0, 12.0)))


# --- Waves and the end ----------------------------------------------------------

func _wave_flow() -> void:
	if state != State.RUNNING:
		return
	if not _pending.is_empty():
		return
	if wave < total_waves():
		if _next_wave_tick < 0:
			_next_wave_tick = tick + GameConfig.ticks(config.wave_gap)
		elif tick >= _next_wave_tick:
			_start_wave("")
			return
	if enemies.is_empty() and _cleared_wave < wave:
		_cleared_wave = wave
		if wave >= total_waves():
			state = State.WON
			_emit(SimEvent.Type.WIN, GameConfig.cell_center(map.goal), lives)
		else:
			_emit(SimEvent.Type.WAVE_CLEAR, GameConfig.cell_center(map.goal), wave)


func _emit(type: SimEvent.Type, pos: Vector2, value: float = 0.0, tag: String = "", target: Vector2 = Vector2.ZERO) -> void:
	_events.append(SimEvent.make(type, pos, value, tag, target))


## A compact picture of the battle, for determinism checks.
func snapshot() -> Dictionary:
	var t: Array = []
	for cell: Vector2i in towers:
		t.append([cell, towers[cell].type, towers[cell].level])
	return {"tick": tick, "gold": gold, "lives": lives, "wave": wave, "kills": kills, "state": state,
		"enemies": enemies.map(func(e: Entities.Enemy) -> Array: return [e.type, snappedf(e.progress, 0.001), e.hp]),
		"towers": t}
