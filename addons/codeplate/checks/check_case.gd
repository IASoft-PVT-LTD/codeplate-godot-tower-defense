class_name CheckCase
extends RefCounted
## Base class for checks. Put files named test_*.gd in res://checks/tests/,
## extend CheckCase, and add methods named test_*. Methods may `await`.
## Part of the CodePlate add-on.

## The running SceneTree, for checks that need scenes or frames.
var tree: SceneTree
var failures: PackedStringArray = []


func expect(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func expect_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%sexpected %s, got %s" % [message + ": " if message else "", var_to_str(expected), var_to_str(actual)])
		return false
	return true


## Waits `n` frames.
func frames(n: int = 1) -> void:
	for i: int in n:
		await tree.process_frame


## Waits until `cond` returns true, up to `seconds`. Returns whether it did.
func until(cond: Callable, seconds: float = 10.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await tree.process_frame
	return true


## Simulates a left mouse button press or release at a viewport position.
## Touch input is emulated from the mouse by default, so this covers taps too.
func mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	tree.root.push_input(e, true)


## Simulates the mouse moving to a viewport position with the left button held.
func mouse_drag_to(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(e, true)


## Simulates pressing or releasing an input action (from the project's Input Map).
func action(name: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	Input.parse_input_event(e)
