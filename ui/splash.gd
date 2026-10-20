extends Control
## The first scene: an optional logo before the title (your studio's, or a
## publisher's). Set `splash_image` (and optionally `splash_text`) in
## config/game_config.tres; with both empty the game goes straight to the
## title on the first frame. The logo shows for `splash_seconds` with a quick
## fade in and out; a tap, click, key or Android Back skips it. The engine's
## own boot image is off (project.godot boot_splash/show_image=false) and its
## colour matches `splash_color`, so the hand-over is seamless. The title
## loads in the background meanwhile.

const FADE := 0.25
## Longest wait for smooth frames before the splash starts counting anyway.
const MAX_WAIT := 0.4

signal finished

## Checks set this to false: the splash then only emits `finished`.
var go_to_title := true
## Seconds since the splash started counting (-1 until frames come smoothly).
var elapsed := -1.0

@onready var _ink: ColorRect = %Ink
@onready var _content: Control = %Content
@onready var _logo: TextureRect = %Logo
@onready var _text: Label = %Text

var _done := false
var _waited := 0.0


func _ready() -> void:
	var c := Game.config
	_ink.color = c.splash_color
	_content.modulate.a = 0.0
	_logo.visible = not c.splash_image.is_empty()
	if _logo.visible:
		_logo.texture = load(c.splash_image) as Texture2D
	_text.text = c.splash_text
	_text.visible = not c.splash_text.is_empty()
	if not has_splash():
		finish.call_deferred()
		return
	ResourceLoader.load_threaded_request(Game.SCENE_TITLE)


## True when the config sets a logo or a line to show.
static func has_splash() -> bool:
	return not Game.config.splash_image.is_empty() or not Game.config.splash_text.is_empty()


func _process(delta: float) -> void:
	if _done:
		return
	# A phone's first frames after launch can be slow and partly hidden by the
	# system's launch screen: start counting at the first smooth frame, or after
	# MAX_WAIT seconds at most.
	if elapsed < 0.0:
		_waited += delta
		if delta > 0.1 and _waited < MAX_WAIT:
			return
		elapsed = 0.0
		delta = 0.0
	elapsed += delta
	var seconds := Game.config.splash_seconds
	_content.modulate.a = clampf(minf(elapsed / FADE, (seconds - elapsed) / FADE), 0.0, 1.0)
	if elapsed >= seconds:
		finish()


func _input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed()
	if tap and not _done:
		get_viewport().set_input_as_handled()
		finish()


## Android Back skips the splash too.
func go_back() -> void:
	finish()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if not go_to_title:
		return
	if has_splash() and ResourceLoader.load_threaded_get_status(Game.SCENE_TITLE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var scene := ResourceLoader.load_threaded_get(Game.SCENE_TITLE) as PackedScene
		if scene != null:
			get_tree().change_scene_to_packed(scene)
			return
	Game.goto_title()
