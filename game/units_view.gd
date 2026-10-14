class_name UnitsView
extends Node2D
## Draws a Battle's towers, enemies (with health bars) and shots, matched to
## the simulation every frame and interpolated between ticks. Art comes from
## content/ (`sprite`, `shot`). Never changes the battle.

const BASE := "assets/towers/base.png"

var battle: Battle
var _towers: Dictionary[Vector2i, Sprite2D] = {}
var _enemies: Dictionary[int, AnimatedSprite2D] = {}
var _shots: Dictionary[int, Sprite2D] = {}
var _spare_shots: Array[Sprite2D] = []
var _prev: Dictionary[int, Vector2] = {}
var _prev_shots: Dictionary[int, Vector2] = {}
var _frames: Dictionary[String, SpriteFrames] = {}
var _actors: Node2D
var _bars: Node2D


func setup(p_battle: Battle) -> void:
	battle = p_battle
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_bars = Node2D.new()
	_bars.z_index = 4
	_bars.draw.connect(_draw_bars)
	add_child(_bars)


## Call before each simulation tick so drawing can interpolate.
func remember() -> void:
	_prev.clear()
	for e: Entities.Enemy in battle.enemies:
		_prev[e.id] = e.pos
	_prev_shots.clear()
	for s: Entities.Shot in battle.shots:
		_prev_shots[s.id] = s.pos


## Matches sprites to the battle. `t` is the fraction between ticks (0..1).
func sync(t: float) -> void:
	_sync_towers()
	var seen: Dictionary[int, bool] = {}
	for e: Entities.Enemy in battle.enemies:
		seen[e.id] = true
		var s: AnimatedSprite2D = _enemies.get(e.id)
		if s == null:
			s = _make_enemy(e)
			_enemies[e.id] = s
		var p: Vector2 = _prev.get(e.id, e.pos)
		s.position = p.lerp(e.pos, t).round()
		if absf(e.pos.x - p.x) > 0.01:
			s.flip_h = e.pos.x < p.x
		s.modulate = Color(3, 3, 3) if e.flash > 0 else (Color(0.6, 0.85, 1.4) if e.slow < 1.0 else Color.WHITE)
	for id: int in _enemies.keys():
		if not seen.has(id):
			_enemies[id].queue_free()
			_enemies.erase(id)
	var live: Dictionary[int, bool] = {}
	for shot: Entities.Shot in battle.shots:
		live[shot.id] = true
		var s: Sprite2D = _shots.get(shot.id)
		if s == null:
			s = _spare_shots.pop_back() if not _spare_shots.is_empty() else null
			if s == null:
				s = Sprite2D.new()
				s.z_index = 3
				add_child(s)
			s.visible = true
			_shots[shot.id] = s
		var from: Vector2 = _prev_shots.get(shot.id, shot.pos)
		s.position = from.lerp(shot.pos, t).round()
		s.rotation = (shot.target_pos - shot.pos).angle()
		var art := str(battle.content.get_entry(shot.tower).get("shot", ""))
		if s.get_meta(&"art", "") != art:
			s.set_meta(&"art", art)
			s.texture = Sprites.texture(art)
	for id: int in _shots.keys():
		if not live.has(id):
			_shots[id].visible = false
			_spare_shots.append(_shots[id])
			_shots.erase(id)
	_bars.queue_redraw()


## How many enemy sprites are drawn (checks use this).
func visible_enemies() -> int:
	return _enemies.size()


func _sync_towers() -> void:
	for cell: Vector2i in _towers.keys():
		if not battle.towers.has(cell):
			_towers[cell].get_parent().queue_free()
			_towers.erase(cell)
	for cell: Vector2i in battle.towers:
		var t := battle.towers[cell]
		var art := str(battle.content.get_entry(t.type)["sprite"])
		var s: Sprite2D = _towers.get(cell)
		if s == null:
			var holder := Node2D.new()
			holder.position = GameConfig.cell_center(cell) + Vector2(0, GameConfig.CELL * 0.5)
			var base := Sprite2D.new()
			base.texture = Sprites.texture(BASE)
			base.offset = Vector2(0, -GameConfig.CELL * 0.5)
			holder.add_child(base)
			s = Sprite2D.new()
			holder.add_child(s)
			_actors.add_child(holder)
			_towers[cell] = s
		var key := "%s:%d" % [art, t.level]
		if s.get_meta(&"key", "") != key:
			s.set_meta(&"key", key)
			s.texture = Sprites.frame(art, t.level - 1)
			s.offset = Vector2(0, -s.texture.get_height() * 0.5)
		s.flip_h = t.aim.x < GameConfig.cell_center(cell).x


func _make_enemy(e: Entities.Enemy) -> AnimatedSprite2D:
	var path := str(battle.content.get_entry(e.type)["sprite"])
	if not _frames.has(path):
		var f := SpriteFrames.new()
		f.remove_animation(&"default")
		Sprites.add_strip(f, &"walk", path, 8.0)
		_frames[path] = f
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _frames[path]
	s.play(&"walk")
	s.offset = Vector2(0, -Sprites.info(path)["height"] * 0.3)
	if e.flying:
		s.z_index = 2
		s.offset.y -= 6.0
	_actors.add_child(s)
	return s


func _draw_bars() -> void:
	for e: Entities.Enemy in battle.enemies:
		if e.hp >= e.max_hp or not _enemies.has(e.id):
			continue
		var s := _enemies[e.id]
		var h := float(Sprites.info(str(battle.content.get_entry(e.type)["sprite"]))["height"])
		var w := 12.0 if not e.boss else 28.0
		var at := s.position + Vector2(-w * 0.5, s.offset.y - h * 0.5 - 4.0)
		_bars.draw_rect(Rect2(at, Vector2(w, 2)), Color(0, 0, 0, 0.7))
		_bars.draw_rect(Rect2(at, Vector2(w * clampf(e.hp / e.max_hp, 0.0, 1.0), 2)), Color(0.95, 0.35, 0.3))
