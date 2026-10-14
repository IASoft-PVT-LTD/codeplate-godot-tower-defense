extends CheckCase
## The shared settings + credits screen (addons/codeplate/ui/settings_screen.gd):
## it opens from the title screen, its controls change Game's settings, reset
## asks first, and the credits show the line the free license asks for.


func _title() -> Control:
	var title: Control = load("res://ui/title.tscn").instantiate()
	tree.root.add_child(title)
	await frames(2)
	return title


func _use_throwaway_save() -> String:
	var saved := Game.save_path
	Game.save_path = "user://check_settings.json"
	Game.load_progress()
	return saved


func _restore(saved: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.save_path = saved
	Game.load_progress()
	Audio.apply_sound_setting()


func test_settings_open_from_title() -> void:
	var saved := _use_throwaway_save()
	var title := await _title()
	var button := title.get_node_or_null("%SettingsButton") as Button
	if not expect(button != null and button.is_visible_in_tree(), "title has a visible Settings button"):
		return
	button.pressed.emit()
	await frames(2)
	var s := title.get_node_or_null("CodePlateSettings") as CodePlateSettings
	if not expect(s != null, "Settings opens the settings screen"):
		return
	var music := s.find_child("MusicSlider", true, false) as HSlider
	var sfx := s.find_child("SfxSlider", true, false) as HSlider
	expect(music != null and music.is_visible_in_tree(), "music volume slider shown")
	expect(sfx != null and sfx.is_visible_in_tree(), "sound effects volume slider shown")
	expect(s.find_child("FullscreenButton", true, false) != null, "fullscreen toggle shown")
	music.value = 0.25
	sfx.value = 0.5
	expect_eq(Game.music_volume, 0.25, "music slider sets Game.music_volume")
	expect_eq(Game.sfx_volume, 0.5, "sfx slider sets Game.sfx_volume")
	s.close()
	Game.load_progress()
	expect_eq(Game.music_volume, 0.25, "music volume saved")
	expect_eq(Game.sfx_volume, 0.5, "sfx volume saved")
	_restore(saved)


func test_reset_progress_asks_first() -> void:
	var saved := _use_throwaway_save()
	_make_progress()
	var title := await _title()
	var s: CodePlateSettings = title.call("open_settings")
	await frames(1)
	var reset := s.find_child("ResetButton", true, false) as Button
	var confirm := s.find_child("ConfirmResetButton", true, false) as Button
	reset.pressed.emit()
	await frames(1)
	expect(confirm.is_visible_in_tree(), "reset shows a confirmation")
	expect(_has_progress(), "nothing erased before confirming")
	(s.find_child("CancelResetButton", true, false) as Button).pressed.emit()
	expect(_has_progress(), "cancel keeps progress")
	reset.pressed.emit()
	confirm.pressed.emit()
	expect(not _has_progress(), "confirming erases progress")
	_restore(saved)


func test_credits_show_codeplate_credit() -> void:
	var title := await _title()
	var s: CodePlateSettings = title.call("open_settings")
	await frames(1)
	(s.find_child("CreditsButton", true, false) as Button).pressed.emit()
	await frames(1)
	expect(s.find_child("CreditsPage", true, false).is_visible_in_tree(), "Credits opens the credits page")
	var text := s.credits_text()
	expect(text.contains("Godot Engine"), "credits come from CREDITS.md")
	if CodePlateSettings.is_free_license():
		expect(text.contains(CodePlateSettings.CODEPLATE_CREDIT),
			"free license: the credits show \"%s\" (keep it in CREDITS.md)" % CodePlateSettings.CODEPLATE_CREDIT)


func _make_progress() -> void:
	Game.record_win(Game.content.levels[0].id, 3)


func _has_progress() -> bool:
	return Game.total_stars() > 0
