extends Control
## A card per level with its stars. A level opens once the one before it is
## won. Built in code so new levels in content/levels/ show up on their own.
## The grid takes as many columns as fit the safe area (up to MAX_COLUMNS)
## and scrolls when the levels don't fit; Back stays above the bottom strip.
## Android Back goes to the title.

const STAR := "assets/ui/star.png"
const LOCK := "assets/ui/lock.png"
const MAX_COLUMNS := 5
const CARD := Vector2(140, 52)

@onready var _grid: GridContainer = %Grid
@onready var _stars: Label = %StarsTotal
@onready var _back: Button = %BackButton
@onready var _rows: VBoxContainer = $Rows
@onready var _background: TextureRect = $Background


func _ready() -> void:
	_back.pressed.connect(func() -> void:
		Audio.play(&"click")
		Game.goto_title())
	_stars.text = "%d / %d" % [Game.total_stars(), Game.content.levels.size() * 3]
	var first: Button = null
	for i: int in Game.content.levels.size():
		var card := _card(i)
		_grid.add_child(card)
		if first == null and not card.disabled:
			first = card
	Touch.enlarge(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	if first != null:
		Touch.focus_later(first)
	Audio.play_music(&"title")


## Covers the visible view; the rows stay inside the safe area, Back above
## Game.bottom_limit(), and the grid takes as many columns as fit.
func _fit() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var safe := Game.safe_rect(vp)
	var top := safe.position.y + 14.0 * minf(1.0, safe.size.y / 270.0)
	_rows.position = Vector2(safe.position.x, top)
	_rows.size = Vector2(safe.size.x, minf(safe.end.y - 8.0, Game.bottom_limit(vp)) - top)
	var gap := float(_grid.get_theme_constant(&"h_separation"))
	var card_w := CARD.x
	if not _grid.get_children().is_empty():
		card_w = (_grid.get_child(0) as Control).get_combined_minimum_size().x
	var fit := floori((safe.size.x - 16.0 + gap) / (card_w + gap))
	_grid.columns = clampi(fit, 1, mini(MAX_COLUMNS, maxi(1, _grid.get_child_count())))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		Game.goto_title()


## Android Back: the title.
func go_back() -> void:
	Game.goto_title()


## The level cards (checks press them).
func cards() -> Array[Button]:
	var out: Array[Button] = []
	for c: Node in _grid.get_children():
		out.append(c as Button)
	return out


func _card(index: int) -> Button:
	var level := Game.content.levels[index]
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.disabled = not Game.is_unlocked(index)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 4
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var name := Label.new()
	name.text = "%d. %s" % [index + 1, level.name.to_upper()]
	name.theme_type_variation = &"SmallLabel"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	if b.disabled:
		var lock := TextureRect.new()
		lock.texture = Sprites.texture(LOCK)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)
	else:
		var got: int = Game.stars.get(level.id, 0)
		for s: int in 3:
			var star := TextureRect.new()
			star.texture = Sprites.frame(STAR, 1 if s < got else 0)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(star)
	b.pressed.connect(func() -> void:
		Audio.play(&"click")
		Game.start_level(index))
	return b
