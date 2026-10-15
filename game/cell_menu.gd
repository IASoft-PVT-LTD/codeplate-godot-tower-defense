class_name CellMenu
extends CanvasLayer
## The small popup next to a tapped cell: tower buttons on an empty cell,
## or upgrade / sell / targeting on a tower. Emits what was chosen; the
## battle screen applies it.

signal build_chosen(tower_id: String)
signal upgrade_pressed
signal sell_pressed
signal target_pressed

const ICONS := "assets/ui/tower_icons.png"

## The cell the menu is open for, or (-1, -1).
var cell := Vector2i(-1, -1)
var _root: Control
var _panel: PanelContainer
var _box: Container


func _ready() -> void:
	layer = 15
	_root = Game.ui_root(self)
	visible = false


func is_open() -> bool:
	return visible


func close() -> void:
	visible = false
	cell = Vector2i(-1, -1)


## Tower buttons for an empty cell. `screen_pos` is the cell's center on screen.
func open_build(p_cell: Vector2i, screen_pos: Vector2, battle: Battle) -> void:
	_reset(p_cell, HBoxContainer.new())
	for i: int in battle.content.towers.size():
		var t: Dictionary = battle.content.towers[i]
		var cost := int(battle.content.tower_level(str(t["id"]), 1)["cost"])
		var b := Button.new()
		b.icon = Sprites.frame(ICONS, int(t.get("icon", i)))
		b.text = str(cost)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(36, 40)
		b.tooltip_text = "%s [%d]\n%s" % [t["name"], i + 1, t.get("description", "")]
		b.disabled = battle.gold < cost
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(build_chosen.emit.bind(str(t["id"])))
		_box.add_child(b)
	_place(screen_pos)


## Upgrade, sell and targeting for the tower on `p_cell`.
func open_tower(p_cell: Vector2i, screen_pos: Vector2, battle: Battle) -> void:
	_reset(p_cell, VBoxContainer.new())
	var t := battle.towers[p_cell]
	var d := battle.content.get_entry(t.type)
	var title := Label.new()
	title.text = "%s  LV %d" % [str(d["name"]).to_upper(), t.level]
	title.theme_type_variation = &"SmallLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var cost := battle.upgrade_cost(p_cell)
	var up := _row("UPGRADE %d" % cost if cost >= 0 else "MAX LEVEL", upgrade_pressed.emit)
	up.disabled = cost < 0 or battle.gold < cost
	_row("SELL +%d" % battle.sell_value(p_cell), sell_pressed.emit)
	_row("TARGET: %s" % t.target_mode.to_upper(), target_pressed.emit)
	_place(screen_pos)


## The menu's buttons (checks press them).
func buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _box != null:
		for c: Node in _box.get_children():
			if c is Button and not c.is_queued_for_deletion():
				out.append(c)
	return out


func _reset(p_cell: Vector2i, box: Container) -> void:
	if _panel != null:
		_panel.queue_free()
	cell = p_cell
	_panel = PanelContainer.new()
	_root.add_child(_panel)
	_box = box
	_box.add_theme_constant_override(&"separation", 2)
	_panel.add_child(_box)
	visible = true


func _row(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	_box.add_child(b)
	return b


## Puts the panel beside the cell, kept inside the view and below the HUD.
func _place(screen_pos: Vector2) -> void:
	_panel.reset_size()
	var size := _panel.get_combined_minimum_size()
	var at := screen_pos + Vector2(16, -size.y * 0.5)
	if at.x + size.x > 476.0:
		at.x = screen_pos.x - 16.0 - size.x
	at.y = clampf(at.y, Hud.HEIGHT + 2.0, 268.0 - size.y)
	_panel.position = at.round()


## True if a screen point is on the menu (taps there aren't map taps).
func covers(screen_pos: Vector2) -> bool:
	return visible and _panel != null and _panel.get_global_rect().has_point(screen_pos)
