class_name CodePlateSettings
extends Control
## A settings + credits overlay every CodePlate game opens from its title
## screen: music and sound-effect volume, fullscreen, reset progress (with a
## confirmation), and a credits page built from res://CREDITS.md.
##
##   CodePlateSettings.open(self)                  # from the title screen
##   CodePlateSettings.open(self, true)            # all-caps text (pixel UIs)
##
## It talks to the project's `Game` autoload by name only, so it works in any
## project. Every member is optional; a missing one hides its control:
##
##   var music_volume: float     0..1     func set_music_volume(v: float) -> void
##   var sfx_volume: float       0..1     func set_sfx_volume(v: float) -> void
##   var fullscreen: bool                 func set_fullscreen(on: bool) -> void
##   func save_settings() -> void         writes the save file (called on change)
##   func reset_progress() -> void        erases progress, keeps the settings
##
## Credits: every line of res://CREDITS.md, except HTML comments (<!-- ... -->),
## which hold notes for the developer. Markdown links show as "text (url)".
## Exported games must include CREDITS.md: add it to the export preset's
## include_filter (the export recipe says how).
##
## Uses the theme it inherits. Part of the CodePlate add-on: don't edit it in a
## project; style it through the theme instead.

signal closed

const CREDITS_PATH := "res://CREDITS.md"
const LICENSE_PATH := "res://LICENSE.md"
## The credit the CodePlate Free License asks games to show.
const CODEPLATE_CREDIT := "Built with CodePlate (codeplate.io)"
## Volume slider step.
const VOLUME_STEP := 0.05

var uppercase := false

var _game: Node
var _fs := 16
var _settings_page: Control
var _credits_page: Control
var _reset_row: Control
var _confirm_row: Control
var _reset_note: Label
var _back: Button
var _credits_scroll: ScrollContainer
var _credits_max_height := 0.0


## Adds the overlay on top of `parent` (usually the title screen) and returns it.
static func open(parent: Node, all_caps: bool = false) -> CodePlateSettings:
	var s := CodePlateSettings.new()
	s.uppercase = all_caps
	s.name = "CodePlateSettings"
	parent.add_child(s)
	return s


## True when res://LICENSE.md is the CodePlate Free License, which asks for
## the credit to be visible.
static func is_free_license() -> bool:
	return FileAccess.file_exists(LICENSE_PATH) \
		and FileAccess.get_file_as_string(LICENSE_PATH).begins_with("# CodePlate Free License")


## The credits as display lines: [kind, text], kind is "heading", "item" or "text".
static func credit_lines(markdown: String) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var md := RegEx.create_from_string("(?s)<!--.*?-->").sub(markdown, "", true)
	var link := RegEx.create_from_string("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	var para := ""
	var first_heading := true
	for raw: String in md.split("\n"):
		var line := raw.strip_edges()
		var kind := ""
		if line.begins_with("#"):
			kind = "heading"
			line = line.lstrip("#").strip_edges()
		elif line.begins_with("- ") or line.begins_with("* "):
			kind = "item"
			line = "- " + line.substr(2).strip_edges()
		if line.is_empty() or kind != "":
			if para != "":
				out.append(PackedStringArray(["text", para]))
				para = ""
		line = _inline(line, link)
		if kind == "heading":
			if first_heading:
				first_heading = false # the page has its own "Credits" title
				continue
			out.append(PackedStringArray([kind, line]))
		elif kind == "item":
			out.append(PackedStringArray([kind, line]))
		elif line != "":
			para = line if para == "" else para + " " + line
	if para != "":
		out.append(PackedStringArray(["text", para]))
	return out


static func _inline(line: String, link: RegEx) -> String:
	var out := line
	for m: RegExMatch in link.search_all(line):
		var text := m.get_string(1)
		var url := m.get_string(2)
		out = out.replace(m.get_string(), text if text == url else "%s (%s)" % [text, url])
	return out.replace("**", "").replace("`", "")


## Every piece of text on the credits page, for checks.
func credits_text() -> String:
	var parts: PackedStringArray = []
	for label: Label in _credits_page.find_children("*", "Label", true, false):
		parts.append(label.text)
	return "\n".join(parts)


func show_settings() -> void:
	_credits_page.visible = false
	_settings_page.visible = true
	_cancel_reset()
	_back.grab_focus.call_deferred()


func show_credits() -> void:
	_settings_page.visible = false
	_credits_page.visible = true
	_back.grab_focus.call_deferred()
	_fit_credits.call_deferred()


func close() -> void:
	_save()
	closed.emit()
	queue_free()


func _ready() -> void:
	_game = get_node_or_null(^"/root/Game")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fs = get_theme_font_size(&"font_size", &"Label")
	var view := size if size.x > 0 else get_viewport_rect().size
	var gap := maxi(2, _fs / 2)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var width := minf(view.x - _fs * 2, _fs * 30)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", gap)
	panel.add_child(col)

	_settings_page = _build_settings(gap)
	_credits_page = _build_credits(gap, view.y - _fs * 9)
	col.add_child(_settings_page)
	col.add_child(_credits_page) # only one page is visible at a time

	_back = _button("Back")
	_back.name = "BackButton"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void:
		_click()
		if _credits_page.visible:
			show_settings()
		else:
			close())
	col.add_child(_back)
	show_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back.pressed.emit()


func _build_settings(gap: int) -> Control:
	var page := VBoxContainer.new()
	page.name = "SettingsPage"
	page.add_theme_constant_override(&"separation", gap)
	page.add_child(_heading("Settings"))
	if _has(&"music_volume", &"set_music_volume"):
		page.add_child(_volume_row("Music", &"music_volume", &"set_music_volume", "MusicSlider"))
	if _has(&"sfx_volume", &"set_sfx_volume"):
		page.add_child(_volume_row("Sound effects", &"sfx_volume", &"set_sfx_volume", "SfxSlider"))
	if _has(&"fullscreen", &"set_fullscreen") and not OS.has_feature("mobile"):
		var full := _button("")
		full.name = "FullscreenButton"
		full.toggle_mode = true
		full.button_pressed = bool(_game.get(&"fullscreen"))
		full.text = _fullscreen_text(full.button_pressed)
		full.toggled.connect(func(on: bool) -> void:
			_game.call(&"set_fullscreen", on)
			full.text = _fullscreen_text(on)
			_click()
			_save())
		page.add_child(full)

	var credits := _button("Credits")
	credits.name = "CreditsButton"
	credits.pressed.connect(func() -> void:
		_click()
		show_credits())
	page.add_child(credits)

	if _game != null and _game.has_method(&"reset_progress"):
		_reset_row = _button("Reset progress")
		_reset_row.name = "ResetButton"
		(_reset_row as Button).pressed.connect(func() -> void:
			_click()
			_reset_note.visible = true
			_reset_note.text = _t("Erase all progress? This can't be undone.")
			_reset_row.visible = false
			_confirm_row.visible = true
			(_confirm_row.get_node(^"CancelResetButton") as Button).grab_focus())
		page.add_child(_reset_row)
		var row := HBoxContainer.new()
		row.name = "ConfirmRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", gap)
		var yes := _button("Yes, erase")
		yes.name = "ConfirmResetButton"
		yes.pressed.connect(func() -> void:
			_game.call(&"reset_progress")
			_save()
			_click()
			_cancel_reset()
			_reset_note.visible = true
			_reset_note.text = _t("Progress erased."))
		var no := _button("Cancel")
		no.name = "CancelResetButton"
		no.pressed.connect(func() -> void:
			_click()
			_cancel_reset())
		row.add_child(yes)
		row.add_child(no)
		_confirm_row = row
		page.add_child(row)
		_reset_note = _label("", &"SmallLabel")
		_reset_note.name = "ResetNote"
		_reset_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(_reset_note)
	return page


func _build_credits(gap: int, max_height: float) -> Control:
	var page := VBoxContainer.new()
	page.name = "CreditsPage"
	page.add_theme_constant_override(&"separation", gap)
	page.add_child(_heading("Credits"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_max_height = maxf(_fs * 6, max_height)
	scroll.custom_minimum_size = Vector2(0, _fs * 6)
	_credits_scroll = scroll
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", gap)
	scroll.add_child(list)
	var md := FileAccess.get_file_as_string(CREDITS_PATH) if FileAccess.file_exists(CREDITS_PATH) else ""
	var lines := credit_lines(md)
	if lines.is_empty() or (is_free_license() and not md.contains(CODEPLATE_CREDIT)):
		# CREDITS.md is missing (an export without it in include_filter) or lost
		# the line the free license asks for: show the credit anyway.
		lines.push_front(PackedStringArray(["text", CODEPLATE_CREDIT]))
	for line: PackedStringArray in lines:
		var label := _label(line[1], &"" if line[0] == "text" else &"SmallLabel")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.uppercase = uppercase
		if line[0] == "heading":
			label.add_theme_color_override(&"font_color", _accent())
		elif line[1].contains(CODEPLATE_CREDIT):
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(label)
	return page


## Grows the credits list to its content, up to the space the screen has;
## longer credits scroll.
func _fit_credits() -> void:
	await get_tree().process_frame
	var list := _credits_scroll.get_child(0) as Control
	_credits_scroll.custom_minimum_size.y = clampf(list.get_combined_minimum_size().y, _fs * 6, _credits_max_height)


func _volume_row(title: String, prop: StringName, setter: StringName, slider_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", maxi(2, _fs / 2))
	var label := _label(_t(title), &"")
	label.custom_minimum_size = Vector2(_fs * 11, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = VOLUME_STEP
	slider.value = float(_game.get(prop))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_FILL
	slider.custom_minimum_size = Vector2(_fs * 6, _fs * 1.5) # a comfortable touch target
	row.add_child(slider)
	var pct := _label("", &"SmallLabel")
	pct.custom_minimum_size = Vector2(_fs * 3, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % roundi(slider.value * 100)
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		_game.call(setter, v)
		pct.text = "%d%%" % roundi(v * 100))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_click()
		_save())
	return row


func _cancel_reset() -> void:
	if _reset_row == null:
		return
	_reset_row.visible = true
	_confirm_row.visible = false
	_reset_note.visible = false


func _has(prop: StringName, setter: StringName) -> bool:
	return _game != null and _game.get(prop) != null and _game.has_method(setter)


func _save() -> void:
	if _game != null and _game.has_method(&"save_settings"):
		_game.call(&"save_settings")


func _click() -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null or not audio.has_method(&"play") or audio.get_script() == null:
		return
	var sounds: Variant = (audio.get_script() as Script).get_script_constant_map().get("SOUNDS")
	if sounds is Dictionary and (sounds as Dictionary).has(&"click"):
		audio.call(&"play", &"click")


func _fullscreen_text(on: bool) -> String:
	return _t("Fullscreen: on" if on else "Fullscreen: off")


func _t(s: String) -> String:
	return s.to_upper() if uppercase else s


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = _t(text)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(_fs * 12, 0)
	return b


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"" and _theme_has(variation):
		l.theme_type_variation = variation
	return l


func _heading(text: String) -> Label:
	var variation := &"HeaderLabel" if _theme_has(&"HeaderLabel") else &"TitleLabel"
	var l := _label(_t(text), variation)
	l.add_theme_font_size_override(&"font_size", _fs * 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## The heading color from the theme, for credit section headings.
func _accent() -> Color:
	for t: Theme in [_inherited_theme(), ThemeDB.get_project_theme()]:
		for variation: StringName in [&"HeaderLabel", &"TitleLabel"]:
			if t != null and t.has_color(&"font_color", variation):
				return t.get_color(&"font_color", variation)
	return Color(1, 0.8, 0.35)


func _theme_has(variation: StringName) -> bool:
	for t: Theme in [_inherited_theme(), ThemeDB.get_project_theme()]:
		if t != null and t.get_type_variation_base(variation) != &"":
			return true
	return false


func _inherited_theme() -> Theme:
	var n: Node = self
	while n != null:
		if n is Control and (n as Control).theme != null:
			return (n as Control).theme
		if n is Window and (n as Window).theme != null:
			return (n as Window).theme
		n = n.get_parent()
	return null
