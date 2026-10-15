extends Node
## Autoload `Game`: config, content, saved progress (stars per level),
## settings, default controls, the UI theme, and scene changes.

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
## inherit the window's theme).
func ui_root(layer: CanvasLayer) -> Control:
	var c := Control.new()
	c.theme = theme
	c.size = Vector2(480, 270)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	return c


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
