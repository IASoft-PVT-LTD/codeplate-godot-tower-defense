extends CheckCase
## The shared settings screen (addons/codeplate/ui/settings_screen.gd) with a
## stand-in Game, so these run the same in every project and with its theme:
## add_row(), the language row, go_back(), and the layout in the project's own
## view size.
## Part of the CodePlate add-on.


class FakeGame:
	extends Node
	var music_volume := 1.0
	var sfx_volume := 1.0
	var fullscreen := false
	var languages: Dictionary = {}
	var language := "en"
	var saves := 0

	func set_music_volume(v: float) -> void:
		music_volume = v

	func set_sfx_volume(v: float) -> void:
		sfx_volume = v

	func set_fullscreen(on: bool) -> void:
		fullscreen = on

	func set_language(code: String) -> void:
		language = code

	func save_settings() -> void:
		saves += 1

	func reset_progress() -> void:
		pass


## A view of `view_size` with the settings screen open in it, talking to `game`.
func _open(game: FakeGame, view_size: Vector2) -> CodePlateSettings:
	var host := Control.new()
	host.size = view_size
	tree.root.add_child(host)
	host.add_child(game)
	var s := CodePlateSettings.open_with(host, game)
	await frames(3)
	return s


func _close(s: CodePlateSettings) -> void:
	s.get_parent().queue_free()
	await frames(1)


func test_add_row_goes_above_credits() -> void:
	var s := await _open(FakeGame.new(), Vector2(720, 1280))
	var row := Button.new()
	row.name = "ProjectRow"
	row.text = "Difficulty"
	s.add_row(row)
	var page := s.find_child("SettingsPage", true, false)
	var credits := s.find_child("CreditsButton", true, false) as Node
	while credits.get_parent() != page:
		credits = credits.get_parent()
	expect_eq(row.get_index(), credits.get_index() - 1, "add_row puts the control just above Credits")
	var last := Label.new()
	s.add_row(last, &"NoSuchControl")
	expect_eq(last.get_index(), page.get_child_count() - 1, "add_row with an unknown name adds at the end")
	await _close(s)


func test_language_row_only_with_languages() -> void:
	var s := await _open(FakeGame.new(), Vector2(720, 1280))
	expect(s.find_child("LanguageRow", true, false) == null, "no language row when the game lists no languages")
	await _close(s)
	var game := FakeGame.new()
	game.languages = {"en": "English", "es": "Español"}
	s = await _open(game, Vector2(720, 1280))
	var row := s.find_child("LanguageRow", true, false)
	if not expect(row != null, "a language row when the game lists two languages"):
		await _close(s)
		return
	var en := row.find_child("Language_en", true, false) as Button
	var es := row.find_child("Language_es", true, false) as Button
	expect(en.button_pressed and not es.button_pressed, "the current language is the pressed one")
	expect(en.has_theme_color_override(&"font_pressed_color"), "the chosen language is drawn in the accent colour, not dimmed")
	es.button_pressed = true
	expect_eq(game.language, "es", "choosing a language calls set_language")
	expect(game.saves > 0, "choosing a language saves the settings")
	expect(not en.button_pressed, "only one language is pressed")
	await _close(s)


## The views the game can have: the project's viewport size, and turned on its
## side too when the phone may rotate (handheld orientation "sensor"). With
## stretch aspect "expand" a real screen only adds to one side, so these are
## the tightest.
static func project_views() -> Array[Vector2]:
	var w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var views: Array[Vector2] = [Vector2(w, h)]
	if int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == DisplayServer.SCREEN_SENSOR:
		views.append(Vector2(h, w))
	return views


func test_settings_fit_the_project_view() -> void:
	for size: Vector2 in project_views():
		var game := FakeGame.new()
		game.languages = {"en": "English", "es": "Español"}
		var view := Rect2(Vector2.ZERO, size)
		var s := await _open(game, view.size)
		var extra := Button.new()
		extra.text = "Extra"
		s.add_row(extra)
		await frames(2)
		for b: Button in s.find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				var r := b.get_global_rect()
				expect(view.encloses(r), "%s fits inside the project's %dx%d view (at %s)" % [b.name, size.x, size.y, r])
		if size.y < CodePlateSettings.COMPACT_HEIGHT:
			expect(s.find_child("ButtonsRow", true, false) != null, "Fullscreen, Credits and Reset share a row on a short view")
		await _close(s)


func test_go_back_steps_back_a_page() -> void:
	var s := await _open(FakeGame.new(), Vector2(720, 1280))
	var settings_page := s.find_child("SettingsPage", true, false) as Control
	var credits_page := s.find_child("CreditsPage", true, false) as Control
	var closed := [false]
	s.closed.connect(func() -> void: closed[0] = true)
	s.show_credits()
	s.go_back()
	expect(settings_page.visible and not credits_page.visible, "go_back on the credits page shows the settings page")
	expect(not closed[0], "go_back on the credits page doesn't close the screen")
	s.go_back()
	expect(closed[0] and s.is_queued_for_deletion(), "go_back on the settings page closes the screen")
	await _close(s)
