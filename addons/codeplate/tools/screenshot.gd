extends SceneTree
## Saves a screenshot of a scene so you (or your agent) can see the result of a
## change. Needs a real window, so do NOT pass --headless:
##
##   godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=title
##   godot --path . --script res://addons/codeplate/tools/screenshot.gd -- scene=res://ui/title.tscn
##
## Arguments (all optional):
##   screen=NAME      a screen named by the project's res://tools/screenshot_hooks.gd
##   scene=PATH       any scene to open instead (res://...)
##   wait=SECONDS     wait before capturing (default: 0.6)
##   size=WxH         window size (default: the project's viewport size)
##   out=PATH         output PNG (default: res://shots/<screen>.png)
##   ...              any other key=value is passed to the hooks (e.g. level=3)
##
## Prints "saved <path>". Open the PNG to look at it.
##
## Projects customise it with res://tools/screenshot_hooks.gd (optional):
##   const SCREENS := {"title": "res://ui/title.tscn", ...}
##   func before_add(node: Node, args: Dictionary, tree: SceneTree) -> void   # set up before _ready
##   func after_add(node: Node, args: Dictionary, tree: SceneTree) -> void    # may await (play moves...)
##
## Note: a --script file compiles before autoloads exist, so neither this file
## nor the hooks may *name* classes whose code uses an autoload. Reach them
## with get() / call() instead.
## Part of the CodePlate add-on.

const HOOKS_PATH := "res://tools/screenshot_hooks.gd"
const RUNNER := preload("res://addons/codeplate/checks/run.gd")


func _initialize() -> void:
	RUNNER.watchdog(self, 120.0)
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("screenshot.gd needs a window: run it without --headless")
		quit(2)
		return
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]

	var hooks: Object = null
	if ResourceLoader.exists(HOOKS_PATH):
		hooks = (load(HOOKS_PATH) as GDScript).new()
	var screens: Dictionary = hooks.get("SCREENS") if hooks != null and hooks.get("SCREENS") != null else {}

	var screen := str(args.get("screen", screens.keys()[0] if not screens.is_empty() else "scene"))
	var scene_path := str(args.get("scene", screens.get(screen, "")))
	if args.has("scene") and not args.has("screen"):
		screen = scene_path.get_file().get_basename()
	if scene_path.is_empty():
		var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if args.has("screen") or main.is_empty():
			printerr("unknown screen \"%s\". Known: %s. Or pass scene=res://..." % [screen, ", ".join(screens.keys())])
			quit(2)
			return
		scene_path = main
		screen = "main"
	var out := str(args.get("out", "res://shots/%s.png" % screen))
	if out.begins_with("res://") or out.begins_with("user://"):
		out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var shots := ProjectSettings.globalize_path("res://shots")
	if DirAccess.dir_exists_absolute(shots) and not FileAccess.file_exists(shots.path_join(".gdignore")):
		FileAccess.open(shots.path_join(".gdignore"), FileAccess.WRITE).close() # keeps screenshots out of Godot's import

	var size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	if args.has("size"):
		var wh := str(args["size"]).split("x")
		size = Vector2i(int(wh[0]), int(wh[1]))
	root.size = size

	var node: Node = load(scene_path).instantiate()
	if hooks != null and hooks.has_method(&"before_add"):
		hooks.call(&"before_add", node, args, self)
	root.add_child(node)
	current_scene = node
	await create_timer(0.2).timeout
	if hooks != null and hooks.has_method(&"after_add"):
		await hooks.call(&"after_add", node, args, self)

	await create_timer(float(args.get("wait", "0.6"))).timeout
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(out)
	if err != OK:
		printerr("could not save %s (error %d)" % [out, err])
		quit(1)
		return
	print("saved %s" % out)
	await RUNNER.quiet_exit(self)
	quit(0)
