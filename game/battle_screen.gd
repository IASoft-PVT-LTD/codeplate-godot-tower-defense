class_name BattleScreen
extends Node2D
## One level. Each physics tick (30/s, more at 2x/3x speed) steps the Battle
## and turns its events into sound and effects. Taps on the map open the
## build or tower menu; keys do the same for the cell under the mouse.

## The map sits below the HUD bar.
const MAP_ORIGIN := Vector2(0, 30)
const RANGE_ART := "assets/fx/range.png"

var battle: Battle
var speed_index := 0
## Sim ticks owed at the current speed. Each physics frame adds the speed
## (1.5 at 1.5x) and runs the whole ticks, so fractional speeds are exact on
## average: 1.5x runs 1, 2, 1, 2... ticks per frame.
var _tick_budget := 0.0
var _shake := 0.0
var _hover := Vector2i(-1, -1)
var _finished := false

@onready var world: Node2D = %World
@onready var map_view: MapView = %MapView
@onready var units: UnitsView = %Units
@onready var fx: Fx = %Fx
@onready var hud: Hud = %Hud
@onready var menu: CellMenu = %CellMenu
@onready var result: ResultPanel = %Result
@onready var pause_menu: PauseMenu = %PauseMenu

var _ring: Sprite2D
var _cursor: ColorRect


func _ready() -> void:
	var level: LevelData = Game.content.levels[Game.level_index]
	var s := Game.next_seed if Game.next_seed != 0 else randi()
	battle = Battle.new(Game.content, Game.config, level, s)
	world.position = MAP_ORIGIN
	map_view.setup(level.map)
	units.setup(battle)
	hud.setup(battle)
	hud.set_speed(Game.config.speeds[0])
	hud.next_wave_pressed.connect(next_wave)
	hud.speed_pressed.connect(cycle_speed)
	hud.pause_pressed.connect(_open_pause)
	menu.build_chosen.connect(func(id: String) -> void: build(id, menu.cell))
	menu.upgrade_pressed.connect(func() -> void: upgrade(menu.cell))
	menu.sell_pressed.connect(func() -> void: sell(menu.cell))
	menu.target_pressed.connect(_cycle_target)
	result.next_pressed.connect(func() -> void: Game.start_level(Game.level_index + 1))
	result.retry_pressed.connect(func() -> void: Game.start_level(Game.level_index))
	result.levels_pressed.connect(Game.goto_levels)
	pause_menu.quit_pressed.connect(Game.goto_levels)
	_ring = Sprite2D.new()
	_ring.texture = Sprites.texture(RANGE_ART)
	_ring.visible = false
	_ring.modulate = Color(1.0, 0.85, 0.5, 0.8)
	_ring.z_index = 5
	world.add_child(_ring)
	_cursor = ColorRect.new()
	_cursor.size = Vector2(GameConfig.CELL, GameConfig.CELL)
	_cursor.color = Color(1, 0.9, 0.6, 0.18)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	world.add_child(_cursor)
	hud.announce(level.name.to_upper())
	Audio.play_music(&"battle")


func _physics_process(_delta: float) -> void:
	for i: int in take_ticks(Game.config.speeds[speed_index]):
		units.remember()
		for e: SimEvent in battle.step():
			_on_event(e)


func _process(delta: float) -> void:
	units.sync(Engine.get_physics_interpolation_fraction())
	_shake = maxf(0.0, _shake - delta * 20.0)
	world.position = MAP_ORIGIN + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake).round()
	_update_ring()


## How many sim ticks to run this frame at `speed` (see _tick_budget).
func take_ticks(speed: float) -> int:
	_tick_budget += speed
	var n := floori(_tick_budget)
	_tick_budget -= n
	return n


# --- Commands (buttons, keys and checks all come through here) ---------------

func next_wave() -> void:
	if battle.call_wave():
		menu.close()


func cycle_speed() -> void:
	speed_index = (speed_index + 1) % Game.config.speeds.size()
	hud.set_speed(Game.config.speeds[speed_index])


func build(tower_id: String, cell: Vector2i) -> bool:
	var ok := battle.build(tower_id, cell)
	if ok:
		menu.close()
	elif menu.is_open():
		Audio.play(&"click", 0.6)
	return ok


func upgrade(cell: Vector2i) -> bool:
	var ok := battle.upgrade(cell)
	if ok:
		menu.open_tower(cell, cell_to_screen(cell), battle)
	return ok


func sell(cell: Vector2i) -> int:
	var gold := battle.sell(cell)
	menu.close()
	return gold


## Taps a map cell: opens the build menu on empty ground, the tower menu on
## a tower, or closes the menu.
func tap_cell(cell: Vector2i) -> void:
	if battle.state == Battle.State.WON or battle.state == Battle.State.LOST:
		return
	if battle.towers.has(cell):
		Audio.play(&"click")
		menu.open_tower(cell, cell_to_screen(cell), battle)
	elif battle.map.kind(cell) == Map.Kind.BUILD:
		Audio.play(&"click")
		menu.open_build(cell, cell_to_screen(cell), battle)
	else:
		menu.close()


static func cell_to_screen(cell: Vector2i) -> Vector2:
	return GameConfig.cell_center(cell) + MAP_ORIGIN


static func screen_to_cell(pos: Vector2) -> Vector2i:
	return GameConfig.pixel_to_cell(pos - MAP_ORIGIN)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = screen_to_cell(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y >= MAP_ORIGIN.y and not menu.covers(event.position):
			get_viewport().set_input_as_handled()
			tap_cell(screen_to_cell(event.position))
		return
	if event.is_action_pressed(&"cancel") and menu.is_open():
		get_viewport().set_input_as_handled()
		menu.close()
	elif event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed(&"next_wave"):
		next_wave()
	elif event.is_action_pressed(&"speed"):
		cycle_speed()
	elif event.is_action_pressed(&"upgrade") and battle.towers.has(_key_cell()):
		upgrade(_key_cell())
	elif event.is_action_pressed(&"sell") and battle.towers.has(_key_cell()):
		sell(_key_cell())
	else:
		for i: int in mini(Game.TOWER_KEYS, Game.content.towers.size()):
			if event.is_action_pressed(StringName("tower_%d" % (i + 1))):
				build(str(Game.content.towers[i]["id"]), _key_cell())


## The cell keys act on: the open menu's cell, else the one under the mouse.
func _key_cell() -> Vector2i:
	return menu.cell if menu.is_open() else _hover


func _open_pause() -> void:
	if not _finished and not pause_menu.visible:
		menu.close()
		pause_menu.open()


func _cycle_target() -> void:
	var t: Entities.Tower = battle.towers.get(menu.cell)
	if t == null:
		return
	var i := Battle.TARGET_MODES.find(t.target_mode)
	battle.set_target_mode(menu.cell, Battle.TARGET_MODES[(i + 1) % Battle.TARGET_MODES.size()])
	menu.open_tower(menu.cell, cell_to_screen(menu.cell), battle)


## Shows the range of the selected tower, or of the cheapest tower on the
## selected empty cell, and highlights the hovered cell.
func _update_ring() -> void:
	var cell := menu.cell if menu.is_open() else Vector2i(-1, -1)
	_ring.visible = cell.x >= 0
	if _ring.visible:
		var t: Entities.Tower = battle.towers.get(cell)
		var id := t.type if t != null else str(Game.content.towers[0]["id"])
		var r := float(Game.content.tower_level(id, t.level if t != null else 1)["range"])
		_ring.position = GameConfig.cell_center(cell)
		_ring.scale = Vector2.ONE * (r * 2.0 / _ring.texture.get_width())
	var c := _hover
	_cursor.visible = battle.map.kind(c) == Map.Kind.BUILD and not battle.towers.has(c)
	_cursor.position = Vector2(c * GameConfig.CELL)


# --- Events ----------------------------------------------------------------------

func _on_event(e: SimEvent) -> void:
	match e.type:
		SimEvent.Type.FIRE:
			var d := Game.content.get_entry(e.tag)
			var sound := str(d.get("sound", ""))
			if not sound.is_empty():
				Audio.play(StringName(sound), randf_range(0.95, 1.05), -6.0, 6)
			if str(d.get("kind", "")) == "ray":
				fx.ray(str(d.get("shot", "")), e.pos - Vector2(0, 10), e.target)
		SimEvent.Type.HIT:
			Audio.play(&"hit", randf_range(0.9, 1.1), -12.0, 10)
			fx.burst(Fx.HIT, e.pos + Vector2(0, -4), 24.0)
		SimEvent.Type.SPLASH:
			fx.burst(Fx.BOOM, e.pos, 18.0, e.value / 16.0)
		SimEvent.Type.SLOW:
			fx.burst(Fx.FROST, e.pos)
		SimEvent.Type.KILL:
			Audio.play(&"enemy_die", randf_range(0.9, 1.1), -6.0, 8)
			fx.burst(Fx.DEATH, e.pos + Vector2(0, -4))
			fx.text(e.pos + Vector2(0, -12), "+%d" % e.value, Color(1, 0.85, 0.35))
		SimEvent.Type.LEAK:
			Audio.play(&"leak")
			_shake = maxf(_shake, Game.config.shake_leak)
		SimEvent.Type.BUILD, SimEvent.Type.UPGRADE:
			Audio.play(&"build" if e.type == SimEvent.Type.BUILD else &"upgrade")
			fx.burst(Fx.SPARKLE, e.pos)
		SimEvent.Type.SELL:
			Audio.play(&"sell")
			fx.text(e.pos, "+%d" % e.value, Color(1, 0.85, 0.35))
		SimEvent.Type.WAVE_START:
			Audio.play(&"wave_start")
			if e.tag == "early":
				Audio.play(&"coin", 1.0, -4.0) # the early-call gold bonus
			var boss := false
			for g: Dictionary in battle.level.waves[int(e.value) - 1].get("groups", []):
				boss = boss or bool(Game.content.get_entry(str(g["enemy"])).get("boss", false))
			hud.announce("BOSS WAVE!" if boss else "WAVE %d" % e.value)
		SimEvent.Type.WAVE_CLEAR:
			Audio.play(&"wave_clear")
		SimEvent.Type.WIN:
			_finish(true)
		SimEvent.Type.LOSE:
			_finish(false)


func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	menu.close()
	Audio.play(&"win" if won else &"lose")
	if won:
		Game.record_win(battle.level.id, battle.stars())
	await get_tree().create_timer(1.0).timeout
	result.open(won, battle.stars(), battle.lives, battle.level.lives, Game.level_index + 1 < Game.content.levels.size())
