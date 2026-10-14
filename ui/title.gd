extends Control
## Title screen: the backdrop, the game name, stars earned, Play and Settings
## (the shared CodePlate settings + credits screen).

const LOGO_MAX_WIDTH := 440.0

@onready var _logo: Label = %Logo
@onready var _stars: Label = %Stars
@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton


func _ready() -> void:
	_logo.text = str(ProjectSettings.get_setting("application/config/name", "TOWER DEFENSE")).to_upper()
	_fit_logo()
	var total := Game.total_stars()
	_stars.text = "%d / %d STARS" % [total, Game.content.levels.size() * 3] if total > 0 else "%d LEVELS" % Game.content.levels.size()
	_play.pressed.connect(func() -> void:
		Audio.play(&"click")
		Game.goto_levels())
	_settings.pressed.connect(open_settings)
	Audio.play_music(&"title")
	_play.grab_focus.call_deferred()


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
