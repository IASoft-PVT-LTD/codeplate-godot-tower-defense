extends SceneTree
## CodePlate check runner. From the project folder:
##
##   godot --headless --path . --import
##   godot --headless --path . --script res://addons/codeplate/checks/run.gd
##
## The import builds Godot's cache (needed after a fresh copy, and after adding
## assets or class_name scripts). To run only some checks, pass a filter after
## `--`, matched against "file:method": ... run.gd -- resolver
##
## Runs every test_* method of every test_*.gd in res://checks/tests/ (the
## project's own checks) and in this add-on's builtin/ folder (project-wide
## checks such as assets.json and res:// paths). Methods may `await`.
## Any engine or script error printed while a check runs fails that check.
##
## Part of the CodePlate add-on: don't edit it in a project. Put project checks
## in res://checks/tests/ instead.

const TEST_DIRS := ["res://addons/codeplate/checks/builtin", "res://checks/tests"]
## A script error in a --script file stops the function before quit(), and
## Godot would then run forever. The watchdog ends the process instead.
const WATCHDOG_SECONDS := 900.0

var _keep: Array[Node] = []


class ErrorCatcher:
	extends Logger
	var mutex := Mutex.new()
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])
		mutex.unlock()

	func take() -> PackedStringArray:
		mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		mutex.unlock()
		return out


func _initialize() -> void:
	watchdog(self, WATCHDOG_SECONDS)
	_run.call_deferred()


## Quits with status 1 after `seconds` if the script hasn't finished by then.
## Call it first in any --script tool.
static func watchdog(tree: SceneTree, seconds: float) -> void:
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		print("CODEPLATE CHECKS: FAIL (stopped after %d s: a script error or a hang; see the errors above)" % int(seconds))
		tree.quit(1))


func _run() -> void:
	_keep = root.get_children()
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var filter := " ".join(OS.get_cmdline_user_args())
	var passed := 0
	var failed := 0

	for dir: String in TEST_DIRS:
		var files := Array(DirAccess.get_files_at(dir)).filter(
			func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
		files.sort()
		for f: String in files:
			var script: GDScript = load(dir.path_join(f))
			if script == null or not script.can_instantiate():
				print("FAIL %s: does not load (see the error above)" % f)
				failed += 1
				continue
			for m: Dictionary in script.get_script_method_list():
				var method: String = m["name"]
				if not method.begins_with("test_"):
					continue
				var name := "%s:%s" % [f.get_basename(), method]
				if filter and not name.contains(filter):
					continue
				var case: Object = script.new()
				case.set("tree", self)
				catcher.take()
				await case.call(method)
				await process_frame
				var problems: PackedStringArray = case.get("failures")
				problems.append_array(catcher.take())
				if problems.is_empty():
					passed += 1
					print("ok   %s" % name)
				else:
					failed += 1
					print("FAIL %s" % name)
					for p: String in problems:
						print("     %s" % p)
				_clean_root()
				await process_frame # let queue_free() finish before the next check

	OS.remove_logger(catcher)
	await quiet_exit(self)
	print("")
	print("%d passed, %d failed" % [passed, failed])
	if passed + failed == 0:
		print("CODEPLATE CHECKS: FAIL (no checks ran)")
		quit(1)
	elif failed == 0:
		print("CODEPLATE CHECKS: PASS")
		quit(0)
	else:
		print("CODEPLATE CHECKS: FAIL (%d failed)" % failed)
		quit(1)


## Stops every sound so nothing outlives the process, then waits long enough
## for the audio thread to release playbacks. Without this, Godot may print
## "ObjectDB instances leaked" or "resources still in use" at exit.
static func quiet_exit(tree: SceneTree) -> void:
	tree.paused = false
	for node: Node in tree.root.get_children():
		if node.has_method(&"stop_all"):
			node.call(&"stop_all")
	for player: Node in tree.root.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	for player: Node in tree.root.find_children("*", "AudioStreamPlayer2D", true, false):
		(player as AudioStreamPlayer2D).stop()
	await tree.create_timer(0.1).timeout


## Frees scenes a check added under root, keeping autoloads.
func _clean_root() -> void:
	for child: Node in root.get_children():
		if child not in _keep:
			child.queue_free()
