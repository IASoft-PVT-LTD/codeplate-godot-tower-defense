class_name CellMenu
extends CanvasLayer
## The small popup next to a tapped cell: tower buttons on an empty cell
## (the towers this level offers), or upgrade / sell / targeting on a tower,
## with a line of numbers under them (damage, range, rate...) so touch
## players, who never see a tooltip, can read what a tower does.
##
## When Game.confirms_spending() (the touch layout, by default), building,
## upgrading and selling take two taps (Touch.confirm): the first shows what
## it would do (the tower's numbers here, its range and a ghost of it on the
## map), the second does it. Emits what was chosen; the battle screen applies it.

signal build_chosen(tower_id: String)
signal upgrade_pressed
signal sell_pressed
signal target_pressed
## What the map should preview: a tower id to build, "upgrade", or "" for the plain range.
signal preview_changed(what: String)

const ICONS := "assets/ui/tower_icons.png"
const BUILD_BUTTON := Vector2(36, 40)
## Width of the numbers line (view units).
const INFO_WIDTH := 150.0

## The cell the menu is open for, or (-1, -1).
var cell := Vector2i(-1, -1)
var _root: Control
var _panel: PanelContainer
var _box: Container
var _info: Label
var _cell_rect := Rect2()
var _area := Rect2()


func _ready() -> void:
	layer = 15
	_root = Game.ui_root(self)
	visible = false


func is_open() -> bool:
	return visible


func close() -> void:
	if visible:
		preview_changed.emit("")
	visible = false
	cell = Vector2i(-1, -1)


## Tower buttons for an empty cell. `cell_rect` is the cell on screen and
## `area` where the panel may go (the safe area left of or below the HUD,
## above the bottom strip).
func open_build(p_cell: Vector2i, p_cell_rect: Rect2, area: Rect2, battle: Battle) -> void:
	var row := HBoxContainer.new()
	_reset(p_cell, row)
	var confirm := Game.confirms_spending()
	for i: int in battle.content.towers.size():
		var t: Dictionary = battle.content.towers[i]
		var id := str(t["id"])
		if not battle.level.allows(id):
			continue
		var cost := int(battle.content.tower_level(id, 1)["cost"])
		var b := Button.new()
		b.name = "Build_%s" % id
		b.icon = Sprites.frame(ICONS, int(t.get("icon", i)))
		b.text = str(cost)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = BUILD_BUTTON
		b.tooltip_text = "%s [%d]\n%s" % [t["name"], i + 1, t.get("description", "")]
		# Too dear: greyed with a mouse; with two taps it stays tappable (the
		# first tap still shows the tower) and its price turns red.
		if battle.gold < cost:
			if confirm:
				b.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
			else:
				b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		var show := func() -> void:
			_info.text = tower_text(battle, id, 1)
			preview_changed.emit(id)
		b.mouse_entered.connect(show)
		if confirm:
			Touch.confirm(b, "BUILD?", build_chosen.emit.bind(id), func() -> void:
				Audio.play(&"click")
				show.call())
		else:
			b.pressed.connect(build_chosen.emit.bind(id))
		row.add_child(b)
	if row.get_child_count() == 0:
		_info.text = "NOTHING TO BUILD HERE"
	else:
		_info.text = "TAP A TOWER TO SEE IT, AGAIN TO BUILD" if confirm else "PICK A TOWER"
	_place(p_cell_rect, area)


## Upgrade, sell and targeting for the tower on `p_cell`.
func open_tower(p_cell: Vector2i, p_cell_rect: Rect2, area: Rect2, battle: Battle) -> void:
	var col := VBoxContainer.new()
	_reset(p_cell, col)
	var t := battle.towers[p_cell]
	var d := battle.content.get_entry(t.type)
	var title := Label.new()
	title.text = "%s  LV %d" % [str(d["name"]).to_upper(), t.level]
	title.theme_type_variation = &"SmallLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.get_parent().add_child(title)
	_box.get_parent().move_child(title, 0)
	_info.text = tower_text(battle, t.type, t.level)
	var confirm := Game.confirms_spending()
	var cost := battle.upgrade_cost(p_cell)
	var up := _row("UpgradeButton", "UPGRADE %d" % cost if cost >= 0 else "MAX LEVEL")
	up.disabled = cost < 0 or battle.gold < cost
	if confirm:
		Touch.confirm(up, "UPGRADE?", upgrade_pressed.emit, func() -> void:
			Audio.play(&"click")
			_info.text = "LV %d: %s" % [t.level + 1, tower_text(battle, t.type, t.level + 1)]
			preview_changed.emit("upgrade"))
	else:
		up.pressed.connect(upgrade_pressed.emit)
	var sell := _row("SellButton", "SELL +%d" % battle.sell_value(p_cell))
	if confirm:
		Touch.confirm(sell, "SELL?", sell_pressed.emit, func() -> void:
			Audio.play(&"click")
			_info.text = "SELL FOR %d GOLD" % battle.sell_value(p_cell)
			preview_changed.emit(""))
	else:
		sell.pressed.connect(sell_pressed.emit)
	var aim := _row("TargetButton", "TARGET: %s" % t.target_mode.to_upper())
	aim.pressed.connect(target_pressed.emit)
	_place(p_cell_rect, area)


## What a tower does at a level, in numbers: "DAMAGE 4, RANGE 2.5 TILES,
## 1.2 SHOTS/S, ..." (the menus show it; it reads content/towers.json).
static func tower_text(battle: Battle, id: String, level: int) -> String:
	var d := battle.content.get_entry(id)
	var s := battle.content.tower_level(id, level)
	var bits: Array[String] = []
	if s.has("damage"):
		bits.append("DAMAGE %s" % _num(float(s["damage"])))
	if s.has("range"):
		bits.append("RANGE %s TILES" % _num(float(s["range"]) / GameConfig.CELL))
	if s.has("rate"):
		bits.append("%s SHOTS/S" % _num(float(s["rate"])))
	if s.has("splash"):
		bits.append("BLAST %s TILES" % _num(float(s["splash"]) / GameConfig.CELL))
	if s.has("slow"):
		bits.append("SLOWS TO %d%%" % roundi(float(s["slow"]) * 100.0))
	var targets: Array = d.get("targets", ["ground", "air"])
	if "air" not in targets:
		bits.append("CAN'T HIT FLYERS")
	elif "ground" not in targets:
		bits.append("FLYERS ONLY")
	return "%s: %s" % [str(d.get("name", id)).to_upper(), ", ".join(bits)]


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## A short message on the numbers line ("NOT ENOUGH GOLD").
func say(text: String) -> void:
	if visible and not text.is_empty():
		_info.text = text.to_upper()


## The numbers line (checks read it).
func info_text() -> String:
	return _info.text if _info != null else ""


## The open panel (checks measure it).
func panel() -> Control:
	return _panel


## The menu's buttons (checks press them).
func buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _box != null:
		for c: Node in _box.get_children():
			if c is Button and not c.is_queued_for_deletion():
				out.append(c)
	return out


## Moves the open panel after a resize.
func reposition(p_cell_rect: Rect2, area: Rect2) -> void:
	if visible:
		_place(p_cell_rect, area)


func _reset(p_cell: Vector2i, box: Container) -> void:
	if _panel != null:
		_panel.name = "OldPanel"
		_panel.queue_free()
	cell = p_cell
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	_panel.add_child(col)
	_box = box
	_box.add_theme_constant_override(&"separation", 2)
	col.add_child(_box)
	_info = Label.new()
	_info.theme_type_variation = &"SmallLabel"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	col.add_child(_info)
	visible = true
	preview_changed.emit("")


func _row(n: String, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(Audio.play.bind(&"click"))
	_box.add_child(b)
	return b


## Puts the panel beside the cell (right of it, else left), inside `area`.
func _place(p_cell_rect: Rect2, area: Rect2) -> void:
	_cell_rect = p_cell_rect
	_area = area
	Touch.enlarge(_panel)
	_info.custom_minimum_size.x = maxf(INFO_WIDTH, _box.get_combined_minimum_size().x)
	_panel.reset_size()
	var size := _panel.get_combined_minimum_size()
	var gap := 4.0
	var at := Vector2(p_cell_rect.end.x + gap, p_cell_rect.get_center().y - size.y * 0.5)
	if at.x + size.x > area.end.x:
		at.x = p_cell_rect.position.x - gap - size.x
	at.x = clampf(at.x, area.position.x, maxf(area.position.x, area.end.x - size.x))
	at.y = clampf(at.y, area.position.y, maxf(area.position.y, area.end.y - size.y))
	_panel.position = at.floor()


## True if a screen point is on the menu (taps there aren't map taps).
func covers(screen_pos: Vector2) -> bool:
	return visible and _panel != null and _panel.get_global_rect().has_point(screen_pos)
