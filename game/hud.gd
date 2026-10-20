class_name Hud
extends CanvasLayer
## The HUD: gold, lives, wave, the start / next-wave button (with the
## early-call bonus), game speed and pause. Built in code; the battle screen
## places it with fit() on every resize, as one of two shapes:
##   bar     a strip across the top of the safe area (the desktop layout)
##   column  a strip down the right of the safe area, buttons above the
##           bottom strip (wide phones, where it leaves a bigger map)
## Buttons are at least Game.min_touch_size() (48 dp with the touch layout).

signal next_wave_pressed
signal speed_pressed
signal pause_pressed

const ICONS := "assets/ui/icons.png" # coin, heart, flag, play, fast, pause
## The bar's height without the touch layout (view units).
const HEIGHT := 30.0
## The column's inner width (view units): fits "NEXT +21" in the pixel font.
const COLUMN_WIDTH := 72.0
const PAD := 4.0
## The button's text before the first wave (checks read it from here).
const START_TEXT := "START"

var battle: Battle
var _root: Control
var _back: ColorRect
var _gold: Label
var _lives: Label
var _wave: Label
var _stats: Array[Control] = []
var _next: Button
var _speed: Button
var _pause: Button
var _msg: Label
var _tip: Label
var _msg_tween: Tween
var _tip_tween: Tween
var _rect := Rect2()
var _column := false


func setup(p_battle: Battle) -> void:
	battle = p_battle
	layer = 10
	_root = Game.ui_root(self)
	_back = ColorRect.new()
	_back.color = Color(0.04, 0.04, 0.1, 0.92)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_back)
	_gold = _stat(0)
	_lives = _stat(1)
	_wave = _stat(2)
	_next = _button("NextWaveButton", "", next_wave_pressed.emit)
	_next.icon = Sprites.frame(ICONS, 3)
	_speed = _button("SpeedButton", "1X", speed_pressed.emit)
	_pause = _button("PauseButton", "", pause_pressed.emit)
	_pause.icon = Sprites.frame(ICONS, 5)
	_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.tooltip_text = "Pause"
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.theme_type_variation = &"TitleLabel"
	_msg.add_theme_font_size_override(&"font_size", 16)
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_msg)
	_tip = Label.new()
	_tip.name = "TipLabel"
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.theme_type_variation = &"SmallLabel"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.modulate.a = 0.0
	_root.add_child(_tip)
	fit(Rect2(Vector2.ZERO, _root.size), _root.size.y, false)


## The space the HUD takes as a bar (`column` false) or a column, inside
## `safe`, without placing anything (the battle screen compares the two).
func measure(safe: Rect2, bottom: float, column: bool) -> Rect2:
	var t := _button_size()
	if column:
		var w := maxf(COLUMN_WIDTH, t) + PAD * 2.0
		return Rect2(safe.end.x - w, safe.position.y, w, bottom - safe.position.y)
	return Rect2(safe.position.x, safe.position.y, safe.size.x, maxf(HEIGHT, t + PAD * 2.0))


## Places the HUD as a bar or a column inside `safe`, its buttons above
## `bottom` (Game.bottom_limit()). Returns the space it takes.
func fit(safe: Rect2, bottom: float, column: bool) -> Rect2:
	_column = column
	_rect = measure(safe, bottom, column)
	var t := _button_size()
	var view := _root.size
	if column:
		_back.position = Vector2(_rect.position.x, 0.0)
		_back.size = Vector2(view.x - _rect.position.x, view.y)
		var x := _rect.position.x + PAD
		var w := _rect.size.x - PAD * 2.0
		var y := _rect.position.y + PAD
		_place(_pause, Vector2(x, y), Vector2(w, t))
		y += t + PAD * 2.0
		for row: Control in _stats:
			row.position = Vector2(x + 2.0, y)
			y += 14.0
		var low := maxf(y + PAD, bottom - PAD)
		_place(_next, Vector2(x, low - t), Vector2(w, t))
		_place(_speed, Vector2(x, low - t * 2.0 - PAD), Vector2(w, t))
	else:
		_back.position = Vector2.ZERO
		_back.size = Vector2(view.x, _rect.end.y)
		var y := _rect.position.y + (_rect.size.y - t) * 0.5
		var right := _rect.end.x - PAD - 2.0
		_place(_pause, Vector2(right - maxf(30.0, t), y), Vector2(maxf(30.0, t), t))
		right = _pause.position.x - PAD
		_place(_speed, Vector2(right - maxf(48.0, t), y), Vector2(maxf(48.0, t), t))
		right = _speed.position.x - PAD
		_place(_next, Vector2(right - 112.0, y), Vector2(112.0, t))
		var sy := _rect.position.y + (_rect.size.y - 12.0) * 0.5
		var lefts := [6.0, 76.0, 136.0]
		for i: int in _stats.size():
			_stats[i].position = Vector2(_rect.position.x + lefts[i], sy)
	_next.icon = null if column else Sprites.frame(ICONS, 3)
	return _rect


## The space the HUD takes on screen (fit()'s last result).
func rect() -> Rect2:
	return _rect


## True when the HUD is a column at the right.
func is_column() -> bool:
	return _column


## Puts the big message over the middle of the map.
func fit_message(map: Rect2) -> void:
	_msg.position = Vector2(map.position.x, map.get_center().y - 25.0)
	_msg.size = Vector2(map.size.x, 20)
	var w := minf(map.size.x - 40.0, 300.0)
	_tip.position = Vector2(map.get_center().x - w * 0.5, map.get_center().y - 2.0)
	_tip.size = Vector2(w, 0)


func set_speed(multiplier: float) -> void:
	# "2X", or "1.5X" for fractional speeds.
	_speed.text = ("%dX" % roundi(multiplier)) if is_equal_approx(multiplier, roundf(multiplier)) else ("%.1fX" % multiplier)


## A big message in the middle that fades ("WAVE 3", "BOSS!"), with an
## optional tip under it that stays longer (the level's "tip").
func announce(text: String, tip: String = "") -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	if _msg_tween != null:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.2 if tip.is_empty() else 2.5)
	_msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.5)
	if not tip.is_empty():
		_tip.text = tip.to_upper()
		_tip.modulate.a = 1.0
		if _tip_tween != null:
			_tip_tween.kill()
		_tip_tween = create_tween()
		_tip_tween.tween_interval(5.0)
		_tip_tween.tween_property(_tip, "modulate:a", 0.0, 0.8)


## The tip on screen now ("" when none). Checks read it.
func tip_text() -> String:
	return _tip.text if _tip.modulate.a > 0.0 else ""


func _process(_delta: float) -> void:
	if battle == null:
		return
	_gold.text = str(battle.gold)
	_lives.text = str(battle.lives)
	_wave.text = ("W %d/%d" if _column else "WAVE %d/%d") % [battle.wave, battle.total_waves()]
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


func pause_button() -> Button:
	return _pause


func _button_size() -> float:
	return maxf(22.0, Game.min_touch_size(get_viewport()))


func _place(c: Control, at: Vector2, size: Vector2) -> void:
	c.custom_minimum_size = size
	c.position = at.floor()
	c.size = size


func _stat(icon: int) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)
	var t := TextureRect.new()
	t.texture = Sprites.frame(ICONS, icon)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(t)
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	_stats.append(row)
	return l


func _button(n: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.pressed.connect(func() -> void:
		Audio.play(&"click")
		action.call())
	_root.add_child(b)
	return b
