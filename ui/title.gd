extends Control
## Title screen: the backdrop, the game name, stars earned, Play and Settings
## (the shared CodePlate settings + credits screen).

const LOGO_MAX_WIDTH := 440.0

## The hint under the buttons: keys on a computer, touch wording on a phone or tablet
## (`config/game_config.tres` touch_controls decides in the platformer).
const HINT_KEYS := "TAP A TILE TO BUILD  -  NUMBER KEYS BUILD  -  SPACE NEXT WAVE  -  F SPEED"
const HINT_TOUCH := "TAP A TILE TO BUILD  -  TAP START FOR THE NEXT WAVE  -  TAP SPEED"

@onready var _logo: Label = %Logo
@onready var _stars: Label = %Stars
@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _hint: Label = $Rows/Hint


func _ready() -> void:
	_logo.text = str(ProjectSettings.get_setting("application/config/name", "TOWER DEFENSE")).to_upper()
	_fit_logo()
	var total := Game.total_stars()
	_stars.text = "%d / %d STARS" % [total, Game.content.levels.size() * 3] if total > 0 else "%d LEVELS" % Game.content.levels.size()
	_play.pressed.connect(func() -> void:
		Audio.play(&"click")
		Game.goto_levels())
	_settings.pressed.connect(open_settings)
	set_hint(is_touch())
	Audio.play_music(&"title")
	_play.grab_focus.call_deferred()


## True on phones and tablets: a touch screen is present or this is a mobile export.
static func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## Shows the touch wording or the keyboard wording (checks call this with both).
func set_hint(touch: bool) -> void:
	_hint.text = HINT_TOUCH if touch else HINT_KEYS


## Shrinks the logo until the game name fits on one line.
func _fit_logo() -> void:
	var font := _logo.get_theme_font(&"font")
	var font_size := _logo.get_theme_font_size(&"font_size")
	while font_size > 8 and font.get_string_size(_logo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > LOGO_MAX_WIDTH:
		font_size -= 8
	_logo.add_theme_font_size_override(&"font_size", font_size)


## Opens the shared settings screen (volumes, fullscreen, reset, credits) on top.
func open_settings() -> CodePlateSettings:
	Audio.play(&"click")
	var s := CodePlateSettings.open(self, true)
	s.closed.connect(_settings.grab_focus)
	return s
