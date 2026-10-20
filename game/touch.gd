class_name Touch
extends RefCounted
## Touch helpers for phones and tablets.
##
## Sizes: the smallest touch target is `min_touch_share` of the view's height
## (config/game_config.tres), 48 dp on a phone 360 dp tall in landscape. With
## the touch layout (Game.is_touch()) every screen calls Touch.enlarge(self)
## once it is built, so its buttons and sliders grow to that size; with a mouse
## and keyboard the pixel-font buttons keep their own size.
##
## Spending: confirm() makes a button that arms on its first press (it lights
## up and shows what it would do) and acts on a second press within
## `confirm_seconds`. The cell menu uses it for build, upgrade and sell when
## Game.confirms_spending() is true.

const ARMED_BG := Color(0.45, 0.22, 0.08, 1)
const ARMED_BORDER := Color(1.0, 0.6, 0.25, 1)


## Grows every Button and Slider under `root` to at least the smallest touch
## target. Does nothing without the touch layout, unless `always`.
static func enlarge(root: Node, always: bool = false) -> void:
	if not always and not Game.is_touch():
		return
	var size := Game.config.min_touch_share * root.get_viewport().get_visible_rect().size.y
	for c: Node in root.find_children("*", "BaseButton", true, false):
		var b := c as Control
		b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, size), maxf(b.custom_minimum_size.y, size))
	for c: Node in root.find_children("*", "Slider", true, false):
		var s := c as Control
		s.custom_minimum_size.y = maxf(s.custom_minimum_size.y, size)


## Controls under `root` a player can press that are smaller than `size` view
## units (checks use it). Hidden ones are skipped.
static func too_small(root: Node, size: float) -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if (ctl is BaseButton or ctl is Slider) and ctl.is_visible_in_tree():
			var r := ctl.get_global_rect()
			if r.size.x < size - 0.5 or r.size.y < size - 0.5:
				out.append(ctl)
	return out


## Gives `c` keyboard/gamepad focus at the end of the frame, if it is still
## on screen then (Back or a check can change the scene in the same frame).
static func focus_later(c: Control) -> void:
	var grab := func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()
	grab.call_deferred()


## Makes `b` a two-tap button: the first press shows `armed_text`, lights it
## up and calls `on_arm` (e.g. to preview a tower); a second press within
## confirm_seconds calls `action`. Arming a button disarms its armed siblings,
## so a stray tap never confirms the wrong thing.
static func confirm(b: Button, armed_text: String, action: Callable, on_arm: Callable = Callable()) -> void:
	b.set_meta(&"confirm_text", armed_text)
	b.pressed.connect(func() -> void:
		if is_armed(b):
			disarm(b)
			action.call()
			return
		if b.get_parent() != null:
			for other: Node in b.get_parent().get_children():
				if other != b and other is Button and is_armed(other):
					disarm(other)
		_arm(b)
		if on_arm.is_valid():
			on_arm.call())


static func is_armed(b: Button) -> bool:
	return b.has_meta(&"armed_text")


static func disarm(b: Button) -> void:
	if not is_armed(b):
		return
	b.text = str(b.get_meta(&"armed_text"))
	b.remove_meta(&"armed_text")
	for s: StringName in [&"normal", &"hover", &"focus"]:
		b.remove_theme_stylebox_override(s)
	b.remove_theme_color_override(&"font_hover_color")


static func _arm(b: Button) -> void:
	b.set_meta(&"armed_text", b.text)
	b.text = str(b.get_meta(&"confirm_text"))
	var box := b.get_theme_stylebox(&"normal").duplicate() as StyleBoxFlat
	if box != null:
		box.bg_color = ARMED_BG
		box.border_color = ARMED_BORDER
		for s: StringName in [&"normal", &"hover", &"focus"]:
			b.add_theme_stylebox_override(s, box)
		b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	var token := Time.get_ticks_usec()
	b.set_meta(&"armed_token", token)
	if b.is_inside_tree():
		var ref: WeakRef = weakref(b) # the menu may be gone by the time the timer fires
		b.get_tree().create_timer(Game.config.confirm_seconds, true).timeout.connect(func() -> void:
			var btn := ref.get_ref() as Button
			if btn != null and btn.get_meta(&"armed_token", 0) == token:
				disarm(btn))
