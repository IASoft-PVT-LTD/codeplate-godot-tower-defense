extends Control
## Title screen: the backdrop, the game name, stars earned, Play and Settings
## (the shared CodePlate settings + credits screen). It fills the visible view
## at any aspect ratio and keeps its rows inside the safe area, buttons above
## the bottom strip with the touch layout. Android Back closes Settings; on
## the bare title it asks before leaving the game.

const LOGO_MAX_WIDTH := 440.0
## The gap between the tagline and the buttons (view units); it shrinks when
## a short view needs the room.
const SPACER := 54.0

## The hint under the buttons: keys on a computer, touch wording with the
## touch layout (Game.is_touch(), `touch_ui` in config/game_config.tres).
const HINT_KEYS := "TAP A TILE TO BUILD  -  NUMBER KEYS BUILD  -  SPACE NEXT WAVE  -  F SPEED"
const HINT_TOUCH := "TAP A TILE, THEN A TOWER TWICE TO BUILD  -  TAP START FOR THE NEXT WAVE"

@onready var _logo: Label = %Logo
@onready var _stars: Label = %Stars
@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _hint: Label = $Rows/Hint
@onready var _rows: VBoxContainer = $Rows
@onready var _spacer: Control = $Rows/Spacer
@onready var _background: TextureRect = $Background
var _quit_panel: Control


func _ready() -> void:
	_logo.text = str(ProjectSettings.get_setting("application/config/name", "TOWER DEFENSE")).to_upper()
	_fit_logo()
	var total := Game.total_stars()
	_stars.text = "%d / %d STARS" % [total, Game.content.levels.size() * 3] if total > 0 else "%d LEVELS" % Game.content.levels.size()
	_play.pressed.connect(func() -> void:
		Audio.play(&"click")
		Game.goto_levels())
	_settings.pressed.connect(open_settings)
	_quit_panel = _build_quit_panel()
	set_hint(is_touch())
	Touch.enlarge(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	Audio.play_music(&"title")
	Touch.focus_later(_play)


## True with the touch layout (touch screens and mobile exports, unless
## config `touch_ui` says otherwise).
static func is_touch() -> bool:
	return Game.is_touch()


## Shows the touch wording or the keyboard wording (checks call this with both).
func set_hint(touch: bool) -> void:
	_hint.text = HINT_TOUCH if touch else HINT_KEYS


## Covers the visible view; the rows stay inside its safe area and the
## buttons above Game.bottom_limit().
func _fit() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var safe := Game.safe_rect(vp)
	_rows.position = Vector2(safe.position.x, safe.position.y + 30.0 * minf(1.0, safe.size.y / 270.0))
	_rows.size = Vector2(safe.size.x, safe.end.y - _rows.position.y)
	# Shrink the gap until Settings ends above the bottom limit.
	_spacer.custom_minimum_size.y = SPACER
	var over := _rows.position.y + _rows.get_combined_minimum_size().y - _hint.get_combined_minimum_size().y - _rows.get_theme_constant(&"separation") - Game.bottom_limit(vp)
	if over > 0.0:
		_spacer.custom_minimum_size.y = maxf(0.0, SPACER - over)


## Android Back: closes Settings (the credits page goes back to the settings
## page first) or the quit question; on the bare title it asks before leaving.
func go_back() -> void:
	var settings := get_node_or_null(^"CodePlateSettings") as CodePlateSettings
	if settings != null and not settings.is_queued_for_deletion():
		(settings.find_child("BackButton", true, false) as Button).pressed.emit()
	elif _quit_panel.visible:
		close_quit()
	else:
		open_quit()


func open_quit() -> void:
	Audio.play(&"click")
	_quit_panel.visible = true
	Touch.focus_later(_quit_panel.find_child("StayButton", true, false) as Button)


func close_quit() -> void:
	Audio.play(&"click")
	_quit_panel.visible = false
	Touch.focus_later(_play)


## True while the "leave the game?" question shows.
func is_asking_to_quit() -> bool:
	return _quit_panel.visible


## Shrinks the logo until the game name fits on one line.
func _fit_logo() -> void:
	var font := _logo.get_theme_font(&"font")
	var font_size := _logo.get_theme_font_size(&"font_size")
	while font_size > 8 and font.get_string_size(_logo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > LOGO_MAX_WIDTH:
		font_size -= 8
	_logo.add_theme_font_size_override(&"font_size", font_size)


## Opens the shared settings screen (volumes, fullscreen, reset, credits) on
## top. Fullscreen is hidden where the game can't change it (phones, web).
func open_settings() -> CodePlateSettings:
	Audio.play(&"click")
	var s := CodePlateSettings.open(self, true)
	var full := s.find_child("FullscreenButton", true, false) as Control
	if full != null and (OS.has_feature("mobile") or OS.has_feature("web")):
		full.visible = false
	Touch.enlarge(s)
	s.closed.connect(func() -> void: Touch.focus_later(_settings))
	return s


## The "leave the game?" question (hidden until Back on the bare title).
func _build_quit_panel() -> Control:
	var root := Control.new()
	root.name = "QuitPanel"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	var q := Label.new()
	q.text = "LEAVE %s?" % _logo.text
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	var stay := Button.new()
	stay.name = "StayButton"
	stay.text = "STAY"
	stay.custom_minimum_size = Vector2(70, 0)
	stay.pressed.connect(close_quit)
	row.add_child(stay)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "LEAVE"
	leave.custom_minimum_size = Vector2(70, 0)
	leave.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(leave)
	return root
