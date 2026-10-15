class_name Hud
extends CanvasLayer
## The top bar: gold, lives, wave, the start / next-wave button (with the
## early-call bonus), game speed and pause. Built in code for the 480x270 view.

signal next_wave_pressed
signal speed_pressed
signal pause_pressed

const ICONS := "assets/ui/icons.png" # coin, heart, flag, play, fast, pause
const HEIGHT := 30.0
## The button's text before the first wave (checks read it from here).
const START_TEXT := "START"

var battle: Battle
var _gold: Label
var _lives: Label
var _wave: Label
var _next: Button
var _speed: Button
var _msg: Label


func setup(p_battle: Battle) -> void:
	battle = p_battle
	layer = 10
	var root := Game.ui_root(self)
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.04, 0.1, 0.92)
	bar.size = Vector2(480, HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	_gold = _stat(root, 6, 0)
	_lives = _stat(root, 76, 1)
	_wave = _stat(root, 136, 2)
	_next = _button(root, Rect2(276, 4, 112, 22), "", next_wave_pressed.emit)
	_next.icon = Sprites.frame(ICONS, 3)
	_speed = _button(root, Rect2(392, 4, 48, 22), "1X", speed_pressed.emit)
	var pause := _button(root, Rect2(444, 4, 30, 22), "", pause_pressed.emit)
	pause.icon = Sprites.frame(ICONS, 5)
	_msg = Label.new()
	_msg.position = Vector2(0, 110)
	_msg.size = Vector2(480, 20)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.theme_type_variation = &"TitleLabel"
	_msg.add_theme_font_size_override(&"font_size", 16)
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_msg)


func set_speed(multiplier: float) -> void:
	# "2X", or "1.5X" for fractional speeds.
	_speed.text = ("%dX" % roundi(multiplier)) if is_equal_approx(multiplier, roundf(multiplier)) else ("%.1fX" % multiplier)


## A big message in the middle that fades ("WAVE 3", "BOSS!").
func announce(text: String) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	if battle == null:
		return
	_gold.text = str(battle.gold)
	_lives.text = str(battle.lives)
	_wave.text = "WAVE %d/%d" % [battle.wave, battle.total_waves()]
	if battle.state == Battle.State.BUILDING:
		_next.visible = true
		_next.text = START_TEXT
	elif battle.seconds_to_next_wave() >= 0.0:
		_next.visible = true
		_next.text = "NEXT +%d" % battle.early_bonus()
	else:
		_next.visible = false


## The next-wave button (checks press it).
func next_button() -> Button:
	return _next


func speed_button() -> Button:
	return _speed


func _stat(root: Control, x: float, icon: int) -> Label:
	var t := TextureRect.new()
	t.texture = Sprites.frame(ICONS, icon)
	t.position = Vector2(x, 9)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(t)
	var l := Label.new()
	l.position = Vector2(x + 15, 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _button(root: Control, r: Rect2, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.custom_minimum_size = r.size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Audio.play(&"click")
		action.call())
	root.add_child(b)
	return b
