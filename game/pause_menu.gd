class_name PauseMenu
extends CanvasLayer
## Pause overlay; pauses the tree while open. Opened by the pause button,
## Esc, Android's Back button, or the app going to the background. Back
## again (or Quit level) leaves for the level select. Shows the level's tip.

signal quit_pressed

var _box: VBoxContainer
var _resume: Button
var _sound: Button
var _tip: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_box = Overlays.panel(self, 160)
	Overlays.label(_box, "PAUSED", &"TitleLabel", 16)
	_tip = Overlays.label(_box, "", &"SmallLabel")
	_tip.name = "TipLabel"
	_tip.visible = false
	_resume = Overlays.button(_box, "RESUME", close)
	_sound = Overlays.button(_box, "", func() -> void:
		Game.set_sound(not Game.sound_on)
		Audio.apply_sound_setting()
		_sound.text = "SOUND: ON" if Game.sound_on else "SOUND: OFF")
	Overlays.button(_box, "QUIT LEVEL", _quit)
	Touch.enlarge(_box)


## The level's tip ("" hides it).
func set_tip(text: String) -> void:
	_tip.text = text.to_upper()
	_tip.visible = not text.is_empty()


func open() -> void:
	if visible:
		return
	_sound.text = "SOUND: ON" if Game.sound_on else "SOUND: OFF"
	visible = true
	get_tree().paused = true
	Touch.focus_later(_resume)


func close() -> void:
	Audio.play(&"click")
	visible = false
	get_tree().paused = false


## Android Back on the pause menu: leave for the level select.
func go_back() -> void:
	_quit()


func _quit() -> void:
	Audio.play(&"click")
	visible = false
	get_tree().paused = false
	quit_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
