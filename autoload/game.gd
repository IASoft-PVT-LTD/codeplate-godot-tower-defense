extends Node
## Autoload `Game`: config, content, saved progress (stars per level),
## settings, default controls, the UI theme, and scene changes. Also the phone
## plumbing: Android's Back button (go_back()), muting while the app is in the
## background, the safe area (camera cutouts, rounded corners, the gesture
## bar: safe_insets()) and the touch layout (is_touch()).

const CONFIG_PATH := "res://config/game_config.tres"
const THEME_PATH := "res://ui/theme.tres"
const SCENE_TITLE := "res://ui/title.tscn"
const SCENE_LEVELS := "res://ui/level_select.tscn"
const SCENE_BATTLE := "res://game/battle_screen.tscn"

const DEFAULT_KEYS := {
	&"pause": [KEY_ESCAPE, KEY_P],
	&"next_wave": [KEY_SPACE, KEY_N],
	&"speed": [KEY_F, KEY_TAB],
	# tower_1..tower_9 build the towers in towers.json order (added in _ensure_input_map).
	&"upgrade": [KEY_U],
	&"sell": [KEY_S, KEY_DELETE],
	&"cancel": [KEY_ESCAPE, KEY_X],
}

## Number keys 1..TOWER_KEYS build the first towers in towers.json.
const TOWER_KEYS := 9

var config: GameConfig
var content: Content
var theme: Theme
## Where progress is saved. Checks point this at a throwaway file.
var save_path := "user://progress.json"
var sound_on := true
## Settings (the shared settings screen, addons/codeplate/ui/settings_screen.gd,
## reads and sets these). Volumes are 0..1; Audio applies them.
var music_volume := 1.0
var sfx_volume := 1.0
var fullscreen := false
## level id -> best stars (1..3). A level is unlocked when the one before it has stars.
var stars: Dictionary[String, int] = {}
## The level the battle screen plays (an index into content.levels).
var level_index := 0
## Seed for the next battle; 0 = random. Checks and tools set it.
var next_seed := 0
## Checks and screenshots pretend a phone's cutout and gesture bar with this:
## insets in view units, as Rect2(left, top, right, bottom). Off while
## `safe_override_on` is false; then phones report their own (safe_insets()).
var safe_override_on := false
var safe_override := Rect2()


func _ready() -> void:
	theme = load(THEME_PATH)
	get_tree().root.theme = theme
	config = load(CONFIG_PATH)
	var errors: PackedStringArray = []
	content = Content.load_dir(Content.DIR, errors)
	for e: String in errors:
		push_error("Bad content: " + e)
	_ensure_input_map()
	load_progress()
	apply_fullscreen.call_deferred()


## A full-view Control carrying the theme, for CanvasLayers (they don't
## inherit the window's theme). It covers the whole visible view at any aspect
## ratio and follows resizes: lay children out with anchors, or in a function
## connected to its `resized` signal.
func ui_root(layer: CanvasLayer) -> Control:
	var c := Control.new()
	c.name = "UiRoot"
	c.theme = theme
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	var vp := layer.get_viewport()
	if vp != null:
		var fit := func() -> void:
			c.position = Vector2.ZERO
			c.size = vp.get_visible_rect().size
		vp.size_changed.connect(fit)
		c.tree_exiting.connect(func() -> void: vp.size_changed.disconnect(fit))
		fit.call()
	return c


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED:
			AudioServer.set_bus_mute(0, true) # nothing plays while the app is in the background
		NOTIFICATION_APPLICATION_RESUMED:
			AudioServer.set_bus_mute(0, false)


## Android's Back button (project.godot has quit_on_go_back=false, so Back
## never quits by itself): the current screen's go_back() decides. Battle:
## pause, then the level select. Level select: the title. Title: closes
## Settings, else asks before leaving the game.
func go_back() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"go_back"):
		scene.call(&"go_back")


## True when the touch layout is on (config `touch_ui`): on touch screens and
## mobile exports with "auto".
func is_touch() -> bool:
	match config.touch_ui:
		"always":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## The parts of the view a phone covers (camera cutout, rounded corners, the
## gesture bar), in view units: Rect2(left, top, right, bottom). Zero on
## desktop and web.
func safe_insets(vp: Viewport) -> Rect2:
	if safe_override_on:
		return safe_override
	if not OS.has_feature("mobile"):
		return Rect2()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var view := vp.get_visible_rect().size
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0:
		return Rect2()
	var k := view / win # window pixels -> view units
	return Rect2(maxf(safe.position.x, 0.0) * k.x, maxf(safe.position.y, 0.0) * k.y,
		maxf(win.x - safe.end.x, 0.0) * k.x, maxf(win.y - safe.end.y, 0.0) * k.y)


## The visible view minus the safe insets, in view units: where buttons, the
## HUD and the map may go.
func safe_rect(vp: Viewport) -> Rect2:
	var inset := safe_insets(vp)
	var view := vp.get_visible_rect().size
	return Rect2(inset.position, view - inset.position - inset.size)


## The lowest a button's bottom edge (or a buildable cell's) may be, in view
## units. With the touch layout: `bottom_clear_fraction` of the height above
## the bottom, and clear of the gesture bar. Otherwise the safe area's bottom.
func bottom_limit(vp: Viewport) -> float:
	var h := vp.get_visible_rect().size.y
	if not is_touch():
		return h - safe_insets(vp).size.y
	return h - maxf(h * config.bottom_clear_fraction, safe_insets(vp).size.y)


## The smallest touch target in view units (`min_touch_share` of the height)
## with the touch layout; 0 without it.
func min_touch_size(vp: Viewport) -> float:
	return vp.get_visible_rect().size.y * config.min_touch_share if is_touch() else 0.0


## True when building, upgrading and selling take two taps (config `confirm_spending`).
func confirms_spending() -> bool:
	match config.confirm_spending:
		"always":
			return true
		"off":
			return false
	return is_touch()


func is_unlocked(index: int) -> bool:
	return index == 0 or (index < content.levels.size() and stars.get(content.levels[index - 1].id, 0) > 0)


func record_win(level_id: String, got: int) -> void:
	stars[level_id] = maxi(stars.get(level_id, 0), got)
	save_progress()


func total_stars() -> int:
	var n := 0
	for id: String in stars:
		n += stars[id]
	return n


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	Audio.apply_sound_setting()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_fullscreen()


## Fullscreen on desktop; mobile and web builds decide this themselves.
func apply_fullscreen() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Settings live in the progress file; reset_progress() keeps them.
func save_settings() -> void:
	save_progress()


## Erases every star (the settings stay).
func reset_progress() -> void:
	stars = {}
	save_progress()


func save_progress() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "stars": stars, "sound_on": sound_on,
			"music_volume": music_volume, "sfx_volume": sfx_volume, "fullscreen": fullscreen}, "  "))


func load_progress() -> void:
	stars = {}
	sound_on = true
	music_volume = 1.0
	sfx_volume = 1.0
	fullscreen = false
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		push_warning("Ignoring unreadable progress file %s" % save_path)
		return
	var d: Dictionary = json.data
	var saved: Variant = d.get("stars", {})
	if saved is Dictionary:
		for id: Variant in saved:
			stars[str(id)] = clampi(int(saved[id]), 0, 3)
	sound_on = bool(d.get("sound_on", true))
	music_volume = clampf(float(d.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", false))


func set_sound(on: bool) -> void:
	sound_on = on
	save_progress()


func goto_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITLE)


func goto_levels() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_LEVELS)


func start_level(index: int) -> void:
	level_index = index
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_BATTLE)


func _ensure_input_map() -> void:
	for action: StringName in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in DEFAULT_KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
	for i: int in TOWER_KEYS:
		var action := StringName("tower_%d" % (i + 1))
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var e := InputEventKey.new()
			e.physical_keycode = KEY_1 + i as Key
			InputMap.action_add_event(action, e)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event(&"pause", start)
