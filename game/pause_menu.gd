class_name PauseMenu
extends CanvasLayer
## Pause overlay; pauses the tree while open.

signal quit_pressed

var _resume: Button
var _sound: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var box := Overlays.panel(self, 140)
	Overlays.label(box, "PAUSED", &"TitleLabel", 16)
	_resume = Overlays.button(box, "RESUME", close)
	_sound = Overlays.button(box, "", func() -> void:
		Game.set_sound(not Game.sound_on)
		Audio.apply_sound_setting()
		_sound.text = "SOUND: ON" if Game.sound_on else "SOUND: OFF")
	Overlays.button(box, "QUIT LEVEL", func() -> void:
		get_tree().paused = false
		quit_pressed.emit())


func open() -> void:
	_sound.text = "SOUND: ON" if Game.sound_on else "SOUND: OFF"
	visible = true
	get_tree().paused = true
	_resume.grab_focus.call_deferred()


func close() -> void:
	Audio.play(&"click")
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
