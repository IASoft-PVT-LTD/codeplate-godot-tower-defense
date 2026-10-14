class_name MapView
extends Node2D
## Draws a level's map: a tile per cell (variant picked from the cell
## position, so it never flickers), decorations, the spawn cave and the goal
## shrine. Tile art for a legend "tile" name is assets/tiles/<name>.png.

const SPAWN := "assets/tiles/spawn.png"
const GOAL := "assets/tiles/goal.png"
const DECOR := "assets/tiles/decor.png"

var map: Map


func setup(p_map: Map) -> void:
	map = p_map
	for y: int in map.height:
		for x: int in map.width:
			var cell := Vector2i(x, y)
			var path := "assets/tiles/%s.png" % map.tile(cell)
			var frames := int(Sprites.info(path)["frames"])
			var s := Sprite2D.new()
			s.texture = Sprites.frame(path, _variant(cell, frames))
			s.centered = false
			s.position = Vector2(cell * GameConfig.CELL)
			add_child(s)
	for cell: Vector2i in map.decor:
		var d := Sprite2D.new()
		d.texture = Sprites.frame(DECOR, map.decor[cell])
		d.position = GameConfig.cell_center(cell)
		add_child(d)
	var spawn := Sprite2D.new()
	spawn.texture = Sprites.texture(SPAWN)
	spawn.position = GameConfig.cell_center(map.spawn)
	add_child(spawn)
	var goal := Sprite2D.new()
	goal.texture = Sprites.texture(GOAL)
	goal.position = GameConfig.cell_center(map.goal) - Vector2(0, 10)
	goal.z_index = 1
	add_child(goal)


## A fixed "random" variant per cell.
static func _variant(cell: Vector2i, frames: int) -> int:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	return absi(h) % maxi(1, frames)
