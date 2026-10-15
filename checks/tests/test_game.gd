extends CheckCase
## The real scenes and the Game autoload: title, level select and unlocking,
## tapping to build, the tower menu, the HUD buttons, pause, winning (stars
## saved) and losing.

const TITLE := "res://ui/title.tscn"
const LEVELS := "res://ui/level_select.tscn"
const BATTLE := "res://game/battle_screen.tscn"


func _sandbox() -> void:
	Game.save_path = "user://check_progress.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.load_progress()
	Game.next_seed = 5
	Game.level_index = 0


func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.save_path = "user://progress.json"
	Game.next_seed = 0
	Game.load_progress()
	tree.paused = false


func _open_battle(index: int = 0) -> BattleScreen:
	Game.level_index = index
	var s: BattleScreen = load(BATTLE).instantiate()
	tree.root.add_child(s)
	await frames(2)
	return s


## Plays the battle with the bot's choices, through the screen's own event handling.
func _autoplay(s: BattleScreen, max_seconds: float) -> void:
	var cov := {}
	var order := Bot._think(s.battle, cov, 0)
	s.next_wave()
	for i: int in GameConfig.ticks(max_seconds):
		if s.battle.state != Battle.State.RUNNING:
			break
		for e: SimEvent in s.battle.step():
			s._on_event(e)
		if s.battle.tick % Bot.THINK_EVERY == 0:
			order = Bot._think(s.battle, cov, order)


func test_title_builds() -> void:
	_sandbox()
	var t: Control = load(TITLE).instantiate()
	tree.root.add_child(t)
	await frames(2)
	var play := t.find_child("PlayButton", true, false) as Button
	expect(play != null and play.is_visible_in_tree(), "a visible Play button")
	t.queue_free()
	_restore()


func test_only_the_first_level_starts_unlocked() -> void:
	_sandbox()
	var l: Control = load(LEVELS).instantiate()
	tree.root.add_child(l)
	await frames(2)
	var cards: Array[Button] = l.call("cards")
	expect_eq(cards.size(), Game.content.levels.size(), "a card per level")
	expect(not cards[0].disabled and cards.slice(1).all(func(b: Button) -> bool: return b.disabled), "only level 1 open")
	l.queue_free()
	Game.record_win(Game.content.levels[0].id, 2)
	expect(Game.is_unlocked(1), "winning level 1 opens level 2")
	Game.load_progress()
	expect_eq(Game.stars.get(Game.content.levels[0].id, 0), 2, "stars are saved")
	_restore()


func test_tapping_a_tile_and_a_tower_button_builds() -> void:
	_sandbox()
	var s := await _open_battle()
	var cell := Bot.best_cell(s.battle, str(Game.content.towers[0]["id"]), {})
	var at := BattleScreen.cell_to_screen(cell)
	mouse_button(at, true)
	mouse_button(at, false)
	await frames(2)
	expect(s.menu.is_open() and s.menu.cell == cell, "the build menu opened on that cell")
	var gold := s.battle.gold
	var first: Button = s.menu.buttons()[0]
	var center := first.get_global_rect().get_center()
	mouse_button(center, true)
	mouse_button(center, false)
	await frames(2)
	expect(s.battle.towers.has(cell), "the tower was built")
	expect(s.battle.gold < gold, "and paid for")
	expect(not s.menu.is_open(), "the menu closed")
	s.queue_free()
	_restore()


func test_number_keys_build_every_tower() -> void:
	_sandbox()
	var s := await _open_battle()
	s.battle.gold = 100000
	var n := mini(Game.TOWER_KEYS, Game.content.towers.size())
	var cell := Bot.best_cell(s.battle, str(Game.content.towers[0]["id"]), {})
	s.tap_cell(cell)
	await frames(1)
	action(StringName("tower_%d" % n), true)
	action(StringName("tower_%d" % n), false)
	await frames(2)
	expect(s.battle.towers.has(cell) and s.battle.towers[cell].type == str(Game.content.towers[n - 1]["id"]),
		"key %d built the %s" % [n, Game.content.towers[n - 1]["id"]])
	s.queue_free()
	_restore()


func test_tower_menu_upgrades_and_sells() -> void:
	_sandbox()
	var s := await _open_battle()
	var cell := Bot.best_cell(s.battle, str(Game.content.towers[0]["id"]), {})
	s.battle.gold = 1000
	s.build(str(Game.content.towers[0]["id"]), cell)
	s.tap_cell(cell)
	await frames(1)
	var buttons := s.menu.buttons()
	expect_eq(buttons.size(), 3, "upgrade, sell, target")
	buttons[0].pressed.emit()
	expect_eq(s.battle.towers[cell].level, 2, "upgraded")
	s.menu.buttons()[2].pressed.emit()
	expect_eq(s.battle.towers[cell].target_mode, Battle.TARGET_MODES[1], "target mode cycled")
	var gold := s.battle.gold
	s.menu.buttons()[1].pressed.emit()
	expect(not s.battle.towers.has(cell) and s.battle.gold > gold, "sold for gold")
	s.queue_free()
	_restore()


func test_hud_starts_waves_and_changes_speed() -> void:
	_sandbox()
	var s := await _open_battle()
	expect_eq(s.hud.next_button().text, Hud.START_TEXT, "a start button before the first wave")
	s.hud.next_button().pressed.emit()
	expect_eq(s.battle.state, Battle.State.RUNNING, "the first wave started")
	await until(func() -> bool: return s.battle.tick > 5, 3.0)
	var t0 := s.battle.tick
	s.cycle_speed()
	await frames(10)
	var t1 := s.battle.tick
	expect(t1 > t0, "time passes")
	expect_eq(s.speed_index, 1, "speed changed")
	action(&"next_wave", true)
	action(&"next_wave", false)
	s.queue_free()
	_restore()


func test_speeds_are_valid_and_fractions_are_exact() -> void:
	var speeds := Game.config.speeds
	expect(not speeds.is_empty(), "config.speeds lists at least one speed")
	for v: float in speeds:
		expect(v > 0.0 and v <= GameConfig.MAX_SPEED, "speed %s is above 0 and at most %s" % [v, GameConfig.MAX_SPEED])
	_sandbox()
	var s := await _open_battle()
	s.set_physics_process(false) # count ticks by hand
	for speed: float in [1.0, 1.5, 2.0, 2.5, 3.0]:
		var total := 0
		for f: int in 60:
			total += s.take_ticks(speed)
		expect_eq(total, roundi(60 * speed), "%sx runs %d ticks in 60 frames" % [speed, roundi(60 * speed)])
	s.hud.set_speed(1.5)
	expect(s.hud.speed_button().text.contains("1.5"), "the HUD shows 1.5 (%s)" % s.hud.speed_button().text)
	s.queue_free()
	_restore()


func test_pause_stops_the_battle() -> void:
	_sandbox()
	var s := await _open_battle()
	s.next_wave()
	await frames(3)
	action(&"pause", true)
	action(&"pause", false)
	await frames(2)
	expect(s.pause_menu.visible and tree.paused, "paused")
	var t := s.battle.tick
	await frames(10)
	expect_eq(s.battle.tick, t, "no ticks while paused")
	s.pause_menu.close()
	s.queue_free()
	_restore()


func test_winning_shows_stars_and_saves_them() -> void:
	_sandbox()
	var s := await _open_battle(0)
	_autoplay(s, 600.0)
	expect_eq(s.battle.state, Battle.State.WON, "the bot won level 1")
	await until(func() -> bool: return s.result.visible, 3.0)
	expect(s.result.visible, "the result panel opened")
	expect(Game.stars.get(Game.content.levels[0].id, 0) > 0, "stars recorded")
	expect(Game.is_unlocked(1), "level 2 unlocked")
	s.queue_free()
	_restore()


func test_losing_shows_the_result() -> void:
	_sandbox()
	var s := await _open_battle(0)
	s.battle.lives = 1
	s.next_wave()
	for i: int in GameConfig.ticks(120.0):
		if s.battle.state != Battle.State.RUNNING:
			break
		for e: SimEvent in s.battle.step():
			s._on_event(e)
	expect_eq(s.battle.state, Battle.State.LOST, "lost")
	await until(func() -> bool: return s.result.visible, 3.0)
	expect(s.result.visible, "the result panel opened")
	expect_eq(Game.stars.get(Game.content.levels[0].id, 0), 0, "no stars for a loss")
	s.queue_free()
	_restore()


func test_a_crowded_battle_renders() -> void:
	_sandbox()
	var s := await _open_battle(Game.content.levels.size() - 1)
	s.battle.lives = 9999
	s.next_wave()
	for i: int in 6:
		s.battle._spawn(str(Game.content.enemies[i % Game.content.enemies.size()]["id"]), i * 20.0)
	for i: int in 3:
		s.battle.step()
	await frames(2)
	expect(s.units.visible_enemies() >= s.battle.enemies.size(), "every enemy has a sprite")
	s.queue_free()
	_restore()
