extends CheckCase
## The shared settings screen (addons/codeplate/ui/settings_screen.gd) with a
## stand-in Game, so these run the same in every project and with its theme:
## add_row(), the language row, and the layout on a short view.
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


func test_settings_fit_a_short_wide_view() -> void:
	var game := FakeGame.new()
	game.languages = {"en": "English", "es": "Español"}
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var s := await _open(game, view.size)
	var extra := Button.new()
	extra.text = "Extra"
	s.add_row(extra)
	await frames(2)
	for b: Button in s.find_children("*", "Button", true, false):
		if b.is_visible_in_tree():
			var r := b.get_global_rect()
			expect(view.encloses(r), "%s fits inside a 1280x720 view (at %s)" % [b.name, r])
	expect(s.find_child("ButtonsRow", true, false) != null, "Fullscreen, Credits and Reset share a row on a short view")
	await _close(s)
