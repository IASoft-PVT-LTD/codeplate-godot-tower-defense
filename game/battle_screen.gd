class_name BattleScreen
extends Node2D
## One level. Each physics tick (30/s, more at 2x/3x speed) steps the Battle
## and turns its events into sound and effects. Taps on the map open the
## build or tower menu; keys do the same for the cell under the mouse.
##
## Layout (fit_layout(), on every resize): the HUD is a bar across the top of
## the safe area, or a column at its right when that leaves a bigger map, and
## the map is scaled to fill the rest. In a 480x270 desktop window that is the
## bar with the map at 1:1 below it. With the touch layout (Game.is_touch())
## every buildable cell also ends above the bottom strip
## (`bottom_clear_fraction`), and a tap a little off a buildable cell or a
## tower still picks it (`tap_snap`). Android Back pauses (a second Back
## leaves for the level select), and the level pauses when the app goes to
## the background.

const RANGE_ART := "assets/fx/range.png"
## Gap (view units) between the map and the HUD column.
const MARGIN := 2.0

var battle: Battle
var speed_index := 0
## View units per map cell (GameConfig.CELL at 1:1) and where the map's
## top-left corner is on screen. fit_layout() sets them.
var cell_px := float(GameConfig.CELL)
var map_origin := Vector2(0, Hud.HEIGHT)
## Sim ticks owed at the current speed. Each physics frame adds the speed
## (1.5 at 1.5x) and runs the whole ticks, so fractional speeds are exact on
## average: 1.5x runs 1, 2, 1, 2... ticks per frame.
var _tick_budget := 0.0
var _shake := 0.0
var _hover := Vector2i(-1, -1)
var _finished := false
## What the open menu previews: a tower id to build on the menu's cell,
## "upgrade", or "" (the plain range).
var _preview := ""

@onready var world: Node2D = %World
@onready var map_view: MapView = %MapView
@onready var units: UnitsView = %Units
@onready var fx: Fx = %Fx
@onready var hud: Hud = %Hud
@onready var menu: CellMenu = %CellMenu
@onready var result: ResultPanel = %Result
@onready var pause_menu: PauseMenu = %PauseMenu

var _ring: Sprite2D
var _ghost: Sprite2D
var _cursor: ColorRect


func _ready() -> void:
	var level: LevelData = Game.content.levels[Game.level_index]
	var s := Game.next_seed if Game.next_seed != 0 else randi()
	battle = Battle.new(Game.content, Game.config, level, s)
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
	menu.preview_changed.connect(func(what: String) -> void: _preview = what)
	result.next_pressed.connect(func() -> void: Game.start_level(Game.level_index + 1))
	result.retry_pressed.connect(func() -> void: Game.start_level(Game.level_index))
	result.levels_pressed.connect(Game.goto_levels)
	pause_menu.quit_pressed.connect(Game.goto_levels)
	pause_menu.set_tip(level.tip)
	_ring = Sprites.sprite(RANGE_ART) # scaled to the range in _update_ring()
	_ring.visible = false
	_ring.modulate = Color(1.0, 0.85, 0.5, 0.8)
	_ring.z_index = 5
	world.add_child(_ring)
	_ghost = Sprite2D.new()
	_ghost.visible = false
	_ghost.modulate = Color(1, 1, 1, 0.6)
	_ghost.z_index = 5
	world.add_child(_ghost)
	_cursor = ColorRect.new()
	_cursor.size = Vector2(GameConfig.CELL, GameConfig.CELL)
	_cursor.color = Color(1, 0.9, 0.6, 0.18)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	world.add_child(_cursor)
	get_viewport().size_changed.connect(fit_layout)
	fit_layout()
	hud.announce(level.name.to_upper(), level.tip)
	Audio.play_music(&"battle")


# --- Layout ----------------------------------------------------------------------

## Places the HUD and scales the map into the rest of the safe area: the
## whole map on screen and, with the touch layout, every buildable cell above
## Game.bottom_limit(). Picks the HUD shape (bar or column) that leaves the
## bigger map; the bar wins a tie.
func fit_layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	var safe := Game.safe_rect(vp)
	var limit := Game.bottom_limit(vp)
	var column := false
	var best := -1.0
	for c: bool in [false, true]:
		var px := _fit_cell(_map_area(safe, hud.measure(safe, limit, c), c), limit)
		if px > best + 0.01:
			best = px
			column = c
	var area := _map_area(safe, hud.fit(safe, limit, column), column)
	cell_px = _fit_cell(area, limit)
	var m := battle.map
	var size := Vector2(m.width, m.height) * cell_px
	var y := area.position.y + maxf(0.0, (area.size.y - size.y) * 0.5)
	y = minf(y, limit - (last_buildable_row(m) + 1) * cell_px) # buildable rows stay above the bottom strip
	map_origin = Vector2(area.position.x + maxf(0.0, (area.size.x - size.x) * 0.5), maxf(area.position.y, y)).floor()
	world.scale = Vector2.ONE * (cell_px / GameConfig.CELL)
	world.position = map_origin
	hud.fit_message(map_rect())
	if menu.is_open():
		menu.reposition(cell_rect(menu.cell), menu_area())


## The part of the safe area the map may use, beside (column) or below (bar)
## the HUD's space `used`.
func _map_area(safe: Rect2, used: Rect2, column: bool) -> Rect2:
	if column:
		return Rect2(safe.position, Vector2(used.position.x - MARGIN - safe.position.x, safe.size.y))
	return Rect2(safe.position.x, used.end.y, safe.size.x, safe.end.y - used.end.y)


## The biggest cell size (view units) that fits the whole map into `area`
## with every buildable row above `limit`.
func _fit_cell(area: Rect2, limit: float) -> float:
	var m := battle.map
	var build_rows := last_buildable_row(m) + 1
	var px := minf(area.size.x / m.width, minf(area.size.y / m.height, (limit - area.position.y) / build_rows))
	return maxf(px, 1.0)


## Where the cell menu may go: the safe area outside the HUD, above the bottom limit.
func menu_area() -> Rect2:
	var vp := get_viewport()
	var safe := Game.safe_rect(vp)
	var used := hud.rect()
	var top := safe.position.y + 2.0
	var right := safe.end.x - 2.0
	if hud.is_column():
		right = used.position.x - MARGIN
	else:
		top = used.end.y + 2.0
	var left := safe.position.x + 2.0
	return Rect2(left, top, right - left, Game.bottom_limit(vp) - 2.0 - top)


## The lowest map row that has a buildable cell.
static func last_buildable_row(m: Map) -> int:
	for y: int in range(m.height - 1, -1, -1):
		for x: int in m.width:
			if m.kind(Vector2i(x, y)) == Map.Kind.BUILD:
				return y
	return 0


## The map on screen.
func map_rect() -> Rect2:
	return Rect2(map_origin, Vector2(battle.map.width, battle.map.height) * cell_px)


## A cell on screen.
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(map_origin + Vector2(cell) * cell_px, Vector2.ONE * cell_px)


## The center of a cell on screen.
func cell_to_screen(cell: Vector2i) -> Vector2:
	return map_origin + GameConfig.cell_center(cell) * (cell_px / GameConfig.CELL)


## The cell under a screen point (it may be off the map).
func screen_to_cell(pos: Vector2) -> Vector2i:
	return GameConfig.pixel_to_cell((pos - map_origin) / (cell_px / GameConfig.CELL))


## The cell a tap at `pos` means: the cell under it if it is buildable or
## has a tower; with the touch layout, else the nearest such cell whose edge
## is within `tap_snap` cells of the tap; else the cell under it.
func tap_target(pos: Vector2) -> Vector2i:
	var under := screen_to_cell(pos)
	if _pickable(under) or not Game.is_touch():
		return under
	var best := under
	var best_d := Game.config.tap_snap * cell_px
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var c := under + Vector2i(dx, dy)
			if _pickable(c):
				var r := cell_rect(c)
				var d := pos.distance_to(pos.clamp(r.position, r.end))
				if d < best_d:
					best_d = d
					best = c
	return best


func _pickable(cell: Vector2i) -> bool:
	return battle.towers.has(cell) or battle.map.kind(cell) == Map.Kind.BUILD


# --- Loop --------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	for i: int in take_ticks(Game.config.speeds[speed_index]):
		units.remember()
		for e: SimEvent in battle.step():
			_on_event(e)


func _process(delta: float) -> void:
	units.sync(Engine.get_physics_interpolation_fraction())
	_shake = maxf(0.0, _shake - delta * 20.0)
	world.position = map_origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * (cell_px / GameConfig.CELL)
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
	var problem := battle.build_problem(tower_id, cell)
	var ok := battle.build(tower_id, cell)
	if ok:
		menu.close()
	elif menu.is_open():
		Audio.play(&"click", 0.6)
		menu.say(problem)
	return ok


func upgrade(cell: Vector2i) -> bool:
	var ok := battle.upgrade(cell)
	if ok:
		_open_menu(cell)
	elif menu.is_open() and battle.towers.has(cell):
		Audio.play(&"click", 0.6)
		menu.say("not enough gold" if battle.upgrade_cost(cell) > battle.gold else "max level")
	return ok


func sell(cell: Vector2i) -> int:
	var gold := battle.sell(cell)
	menu.close()
	return gold


## Taps a map cell: opens the build menu on empty ground or the tower menu
## on a tower; closes the menu on anything else, or when it is already open
## on that cell.
func tap_cell(cell: Vector2i) -> void:
	if battle.state == Battle.State.WON or battle.state == Battle.State.LOST:
		return
	if menu.is_open() and menu.cell == cell:
		menu.close()
	elif _pickable(cell):
		Audio.play(&"click")
		_open_menu(cell)
	else:
		menu.close()


func _open_menu(cell: Vector2i) -> void:
	_preview = ""
	if battle.towers.has(cell):
		menu.open_tower(cell, cell_rect(cell), menu_area(), battle)
	else:
		menu.open_build(cell, cell_rect(cell), menu_area(), battle)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = screen_to_cell(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if menu.covers(event.position) or hud.rect().has_point(event.position):
			return
		get_viewport().set_input_as_handled()
		var reach := cell_px * Game.config.tap_snap if Game.is_touch() else 0.0
		if map_rect().grow(reach).has_point(event.position):
			tap_cell(tap_target(event.position))
		else:
			menu.close()
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


## Android Back: in play it pauses (closing the menu); on the pause menu or
## the results it leaves for the level select. One press never throws a
## level away.
func go_back() -> void:
	if result.visible:
		Game.goto_levels()
	elif pause_menu.visible:
		pause_menu.go_back()
	elif not _finished:
		_open_pause()


func _notification(what: int) -> void:
	# Home, the app switcher or a call: pause, so nothing is lost while away.
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if battle != null and is_inside_tree():
			_open_pause()


func _cycle_target() -> void:
	var t: Entities.Tower = battle.towers.get(menu.cell)
	if t == null:
		return
	var i := Battle.TARGET_MODES.find(t.target_mode)
	battle.set_target_mode(menu.cell, Battle.TARGET_MODES[(i + 1) % Battle.TARGET_MODES.size()])
	_open_menu(menu.cell)


## Shows the selected tower's range (its next level's while Upgrade is
## armed); on an empty cell, the range and a ghost of the tower the menu
## previews (a build button hovered or armed). Highlights the hovered cell
## when there is a mouse.
func _update_ring() -> void:
	var cell := menu.cell if menu.is_open() else Vector2i(-1, -1)
	var t: Entities.Tower = battle.towers.get(cell)
	var id := ""
	var lvl := 1
	if t != null:
		id = t.type
		lvl = t.level + (1 if _preview == "upgrade" and battle.upgrade_cost(cell) >= 0 else 0)
	elif cell.x >= 0 and _preview != "upgrade":
		id = _preview
	_ring.visible = not id.is_empty()
	_ghost.visible = _ring.visible and t == null
	if _ring.visible:
		var r := float(Game.content.tower_level(id, lvl)["range"])
		_ring.position = GameConfig.cell_center(cell)
		_ring.scale = Vector2.ONE * (r * 2.0 / _ring.texture.get_width())
	if _ghost.visible:
		var d := Game.content.get_entry(id)
		var art := str(d["sprite"])
		_ghost.texture = Sprites.frame(art, 0)
		Sprites.style(_ghost, art)
		# Where UnitsView draws it: a turning head centred on the cell, else standing on the plinth.
		var turns := d.has("base")
		_ghost.position = GameConfig.cell_center(cell) + (Vector2.ZERO if turns else Vector2(0, GameConfig.CELL * 0.5))
		_ghost.offset = Vector2.ZERO if turns else Vector2(0, -_ghost.texture.get_height() * 0.5)
	# The cell under the mouse, or with the touch layout the cell the menu is open on.
	var c := _hover if not Game.is_touch() else cell
	_cursor.visible = c.x >= 0 and (Game.is_touch() or (battle.map.kind(c) == Map.Kind.BUILD and not battle.towers.has(c)))
	_cursor.position = Vector2(c * GameConfig.CELL)


# --- Events ----------------------------------------------------------------------

func _on_event(e: SimEvent) -> void:
	match e.type:
		SimEvent.Type.FIRE:
			var d := Game.content.get_entry(e.tag)
			var sound := str(d.get("sound", ""))
			if not sound.is_empty():
				Audio.play(StringName(sound), randf_range(0.95, 1.05), -6.0, 6)
			units.snap_head(Vector2i((e.pos / GameConfig.CELL).floor()))
			if str(d.get("kind", "")) == "ray":
				var muzzle := Game.content.muzzle(e.tag, int(e.value))
				var start := e.pos + (e.target - e.pos).normalized() * muzzle if muzzle > 0.0 else e.pos - Vector2(0, 10)
				fx.ray(str(d.get("shot", "")), start, e.target)
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
