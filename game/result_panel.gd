class_name ResultPanel
extends CanvasLayer
## End of a level: victory with stars, or defeat.

signal next_pressed
signal retry_pressed
signal levels_pressed

const STAR := "assets/ui/star.png"

var _box: VBoxContainer


func _ready() -> void:
	layer = 30
	visible = false
	_box = Overlays.panel(self, 220)


func open(won: bool, stars: int, lives: int, max_lives: int, has_next: bool) -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	Overlays.label(_box, "VICTORY!" if won else "THE SHRINE FELL", &"TitleLabel", 16)
	if won:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for i: int in 3:
			var s := TextureRect.new()
			s.texture = Sprites.frame(STAR, 1 if i < stars else 0)
			row.add_child(s)
		_box.add_child(row)
		Overlays.label(_box, "LIVES %d/%d" % [lives, max_lives])
	var first: Button = null
	if won and has_next:
		first = Overlays.button(_box, "NEXT LEVEL", _click.bind(next_pressed))
	var retry := Overlays.button(_box, "RETRY", _click.bind(retry_pressed))
	Overlays.button(_box, "LEVELS", _click.bind(levels_pressed))
	visible = true
	(first if first != null else retry).grab_focus.call_deferred()


func _click(sig: Signal) -> void:
	Audio.play(&"click")
	sig.emit()
