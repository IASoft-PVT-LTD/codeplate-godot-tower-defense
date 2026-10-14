extends Control
## A card per level with its stars. A level opens once the one before it is
## won. Built in code so new levels in content/levels/ show up on their own.

const STAR := "assets/ui/star.png"
const LOCK := "assets/ui/lock.png"
const COLUMNS := 3

@onready var _grid: GridContainer = %Grid
@onready var _stars: Label = %StarsTotal
@onready var _back: Button = %BackButton


func _ready() -> void:
	_grid.columns = COLUMNS
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
	if first != null:
		first.grab_focus.call_deferred()
	Audio.play_music(&"title")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
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
	b.custom_minimum_size = Vector2(140, 52)
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
