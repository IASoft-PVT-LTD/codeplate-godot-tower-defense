extends CheckCase
## Phones and tablets in landscape, with the touch layout on: every screen
## fits views from 18:9 to 22:9 and a 4:3 tablet with a pretend camera cutout
## and gesture bar; buttons are at least min_touch_share of the height
## (48 dp), inside the safe area and never overlap; every button and every
## buildable map cell ends at least bottom_clear_fraction (15%) of the height
## above the bottom edge. Also taps beside a cell, two-tap spending, the
## tower numbers in the menu, Android's Back button, leaving the app
## mid-level, the splash hook and the Android preset.

const BATTLE := "res://game/battle_screen.tscn"
const TITLE := "res://ui/title.tscn"
const LEVELS := "res://ui/level_select.tscn"
## [name, window size in pixels, safe insets in view units (left, top, right, bottom)]
const VIEWS := [
	["18:9 phone", Vector2i(2160, 1080), Rect2(20, 0, 0, 10)],
	["20:9 phone", Vector2i(2400, 1080), Rect2(0, 0, 24, 11)],
	["22:9 phone", Vector2i(2640, 1080), Rect2(26, 0, 26, 12)],
	["4:3 tablet", Vector2i(2048, 1536), Rect2(0, 8, 0, 8)],
]

var _window_size := Vector2i.ZERO
var _touch_ui := ""


func _setup_view(window: Vector2i, inset: Rect2) -> Vector2:
	tree.root.size = window
	Game.safe_override_on = true
	Game.safe_override = inset
	await frames(2)
	return tree.root.get_visible_rect().size


func _sandbox() -> void:
	if _window_size == Vector2i.ZERO:
		_window_size = tree.root.size
	_touch_ui = Game.config.touch_ui
	Game.config.touch_ui = "always"
	Game.save_path = "user://check_phone.json"
	Game.reset_progress()
	Game.next_seed = 3


func _restore() -> void:
	Game.safe_override_on = false
	Game.config.touch_ui = _touch_ui
	if _window_size != Vector2i.ZERO:
		tree.root.size = _window_size
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.save_path = "user://progress.json"
	Game.next_seed = 0
	Game.load_progress()
	tree.paused = false
	await frames(2)


func _open(scene: String) -> Node:
	var node: Node = load(scene).instantiate()
	tree.root.add_child(node)
	await frames(4)
	return node


func _close(node: Node) -> void:
	node.queue_free()
	tree.paused = false
	await frames(1)


func _safe_rect(view: Vector2, inset: Rect2) -> Rect2:
	return Rect2(inset.position, view - inset.position - inset.size)


## Every visible button and slider under `root`: inside the safe view, big
## enough, and not overlapping another. Returns them.
func _check_controls(root: Node, safe: Rect2, view: Vector2, where: String) -> Array[Control]:
	var ctls: Array[Control] = []
	for c: Node in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if (ctl is BaseButton or ctl is Slider) and ctl.is_visible_in_tree() and not _in_scroll(ctl):
			ctls.append(ctl)
	var size := view.y * Game.config.min_touch_share
	for ctl: Control in ctls:
		var r := ctl.get_global_rect()
		expect(safe.grow(0.5).encloses(r), "%s: %s %s inside the safe view %s" % [where, ctl.name, r, safe])
		expect(r.size.x >= size - 0.5 and r.size.y >= size - 0.5, "%s: %s is %s, under %.0f units (48 dp)" % [where, ctl.name, r.size, size])
	for i: int in ctls.size():
		for j: int in range(i + 1, ctls.size()):
			if ctls[i].is_ancestor_of(ctls[j]) or ctls[j].is_ancestor_of(ctls[i]):
				continue
			var a := ctls[i].get_global_rect().grow(-1.0)
			var b := ctls[j].get_global_rect().grow(-1.0)
			expect(not a.intersects(b), "%s: %s and %s overlap" % [where, ctls[i].name, ctls[j].name])
	return ctls


func _in_scroll(ctl: Control) -> bool:
	var n := ctl.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _above_bottom(r: Rect2, view: Vector2, inset: Rect2, what: String) -> void:
	var limit := view.y * (1.0 - Game.config.bottom_clear_fraction)
	expect(r.end.y <= limit + 0.5, "%s: bottom %.0f is at least %d%% of the height above the bottom (limit %.0f)" % [what, r.end.y, roundi(Game.config.bottom_clear_fraction * 100), limit])
	expect(r.end.y <= view.y - inset.size.y + 0.5, "%s: clear of the gesture bar" % what)


func _all_above_bottom(ctls: Array[Control], view: Vector2, inset: Rect2, where: String) -> void:
	for b: Control in ctls:
		_above_bottom(b.get_global_rect(), view, inset, "%s %s" % [where, b.name])


func test_battles_fit_phones_and_tablets() -> void:
	_sandbox()
	for v: Array in VIEWS:
		var inset: Rect2 = v[2]
		var view := await _setup_view(v[1], inset)
		var safe := _safe_rect(view, inset)
		for index: int in [0, Game.content.levels.size() - 1]:
			Game.level_index = index
			var s := await _open(BATTLE) as BattleScreen
			var where := "%s level %d" % [v[0], index + 1]
			var hud := s.hud.rect()
			expect(safe.grow(0.5).encloses(hud), "%s: the HUD %s is inside the safe view" % [where, hud])
			s.hud.set_process(false)
			# The longest it gets (early bonus over a whole wave gap): the text fits its button.
			var longest := "NEXT +%d" % ceili(Game.config.early_bonus_per_second * Game.config.wave_gap)
			var nb := s.hud.next_button()
			nb.text = longest
			nb.visible = true
			await frames(2)
			var text_w := nb.get_theme_font(&"font").get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, nb.get_theme_font_size(&"font_size")).x
			expect(text_w <= nb.size.x - 8.0, "%s: \"%s\" fits its button (%d of %d)" % [where, longest, int(text_w), int(nb.size.x)])
			_all_above_bottom(_check_controls(s.hud, safe, view, where + " HUD"), view, inset, where)
			s.hud.set_process(true)
			var map := s.map_rect()
			expect(safe.grow(0.5).encloses(map), "%s: the map %s is inside the safe view" % [where, map])
			expect(not map.grow(-0.5).intersects(hud.grow(-0.5)), "%s: the map and the HUD don't overlap" % where)
			var m := s.battle.map
			for y: int in m.height:
				for x: int in m.width:
					if m.kind(Vector2i(x, y)) == Map.Kind.BUILD:
						_above_bottom(s.cell_rect(Vector2i(x, y)), view, inset, "%s buildable cell %d,%d" % [where, x, y])
			# A cell is at least 28 dp (taps snap to the nearest one; the buttons are 48 dp).
			# dp per view unit: a phone is at least 360 dp tall in landscape, a tablet 600.
			var dp := s.cell_px * (360.0 if view.x / view.y > 1.6 else 600.0) / view.y
			expect(dp >= 28.0, "%s: map cells are %.1f units (%.0f dp), at least 28 dp" % [where, s.cell_px, dp])
			# The build menu and the tower menu, on the cell the bot likes best.
			var id := _first_offered(s.battle)
			var cell := Bot.best_cell(s.battle, id, {})
			s.tap_cell(cell)
			await frames(2)
			_all_above_bottom(_check_controls(s.menu, safe, view, where + " build menu"), view, inset, where + " build menu")
			expect(not s.menu.panel().get_global_rect().intersects(hud), "%s: the build menu stays clear of the HUD" % where)
			s.battle.gold = 10000
			s.build(id, cell)
			s.tap_cell(cell)
			await frames(2)
			_all_above_bottom(_check_controls(s.menu, safe, view, where + " tower menu"), view, inset, where + " tower menu")
			expect(not s.menu.panel().get_global_rect().intersects(hud), "%s: the tower menu stays clear of the HUD" % where)
			s.menu.close()
			if index == 0:
				s.pause_menu.open()
				await frames(3)
				_all_above_bottom(_check_controls(s.pause_menu, safe, view, where + " pause menu"), view, inset, where + " pause")
				s.pause_menu.close()
				await frames(1)
				s.result.open(true, 3, 20, 20, true)
				await frames(3)
				_all_above_bottom(_check_controls(s.result, safe, view, where + " results"), view, inset, where + " results")
			await _close(s)
	await _restore()


func test_menus_fit_phones_and_tablets() -> void:
	_sandbox()
	for v: Array in VIEWS:
		var inset: Rect2 = v[2]
		var view := await _setup_view(v[1], inset)
		var safe := _safe_rect(view, inset)
		var title := await _open(TITLE) as Control
		_all_above_bottom(_check_controls(title, safe, view, "%s title" % v[0]), view, inset, "%s title" % v[0])
		expect(safe.grow(0.5).encloses((title.get_node("%Logo") as Control).get_global_rect()), "%s title: the name fits" % v[0])
		title.call("open_quit")
		await frames(2)
		_all_above_bottom(_check_controls(title.get_node("QuitPanel"), safe, view, "%s quit question" % v[0]), view, inset, "%s quit" % v[0])
		title.call("close_quit")
		var s: CodePlateSettings = title.call("open_settings")
		await frames(4)
		_check_controls(s, safe, view, "%s settings" % v[0])
		s.close()
		await _close(title)
		for n: int in Game.content.levels.size():
			Game.record_win(Game.content.levels[n].id, 2)
		var select := await _open(LEVELS) as Control
		_all_above_bottom(_check_controls(select, safe, view, "%s level select" % v[0]), view, inset, "%s level select" % v[0])
		var scroll := select.get_node("%Scroll") as Control
		expect(safe.grow(0.5).encloses(scroll.get_global_rect()), "%s level select: the cards stay in the safe view" % v[0])
		_above_bottom(scroll.get_global_rect(), view, inset, "%s level select cards" % v[0])
		for card: Button in select.call("cards"):
			expect(card.size.y >= view.y * Game.config.min_touch_share - 0.5, "%s level select: cards are at least 48 dp tall" % v[0])
		await _close(select)
		Game.reset_progress()
	await _restore()


func test_the_desktop_layout_is_unchanged() -> void:
	# Without the touch layout a 480x270 view keeps the bar and the map at 1:1 below it.
	if _window_size == Vector2i.ZERO:
		_window_size = tree.root.size
	var saved := Game.config.touch_ui
	Game.config.touch_ui = "off"
	tree.root.size = Vector2i(1440, 810)
	await frames(2)
	Game.level_index = 0
	var s := await _open(BATTLE) as BattleScreen
	expect(not s.hud.is_column(), "a bar across the top")
	expect_eq(s.cell_px, float(GameConfig.CELL), "the map is drawn 1:1")
	expect_eq(s.map_origin, Vector2(0, Hud.HEIGHT), "right below the bar")
	await _close(s)
	Game.config.touch_ui = saved
	tree.root.size = _window_size
	await frames(2)


func test_a_tap_beside_a_cell_still_picks_it() -> void:
	_sandbox()
	await _setup_view(Vector2i(2400, 1080), Rect2())
	Game.level_index = 0
	var s := await _open(BATTLE) as BattleScreen
	var cell := Bot.best_cell(s.battle, _first_offered(s.battle), {})
	var r := s.cell_rect(cell)
	expect_eq(s.tap_target(r.get_center()), cell, "a tap in the middle of a cell picks it")
	var tried := 0
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var near := r.get_center() + d * r.size.x * 0.8 # 0.3 of a cell over the edge
		var under := s.screen_to_cell(near)
		if not s._pickable(under):
			tried += 1
			expect_eq(s.tap_target(near), cell, "a tap just off the cell (%s, on a path or decoration) still picks it" % d)
	var far := r.get_center() + Vector2.LEFT * r.size.x * 3.0
	if not s._pickable(s.screen_to_cell(far)) and not s._pickable(s.screen_to_cell(far) + Vector2i.RIGHT):
		expect(s.tap_target(far) != cell, "a tap two cells away doesn't")
	await _close(s)
	await _restore()


func test_spending_needs_a_second_tap() -> void:
	_sandbox()
	Game.level_index = 0
	var s := await _open(BATTLE) as BattleScreen
	var id := _first_offered(s.battle)
	var cell := Bot.best_cell(s.battle, id, {})
	s.tap_cell(cell)
	await frames(1)
	var gold := s.battle.gold
	var b := s.menu.buttons()[0]
	b.pressed.emit()
	expect(Touch.is_armed(b) and not s.battle.towers.has(cell) and s.battle.gold == gold, "one tap: armed, nothing spent")
	expect(s.menu.info_text().contains("RANGE"), "and the menu shows the tower's numbers (%s)" % s.menu.info_text())
	await frames(2)
	expect(s._ring.visible and s._ghost.visible, "the armed tower's range and a ghost show on the map")
	s.tap_cell(cell) # tapping the cell again closes the menu: nothing built
	expect(not s.menu.is_open() and not s.battle.towers.has(cell), "tapping the cell again cancels")
	s.tap_cell(cell)
	b = s.menu.buttons()[0]
	b.pressed.emit()
	await tree.create_timer(Game.config.confirm_seconds + 0.3).timeout
	expect(not Touch.is_armed(b), "an armed button disarms after confirm_seconds")
	b.pressed.emit()
	b.pressed.emit()
	expect(s.battle.towers.has(cell), "two taps in a row build")
	s.battle.gold = 10000
	s.tap_cell(cell)
	await frames(1)
	var up := s.menu.buttons()[0]
	up.pressed.emit()
	expect_eq(s.battle.towers[cell].level, 1, "one tap on Upgrade only arms it")
	up.pressed.emit()
	expect_eq(s.battle.towers[cell].level, 2, "the second upgrades")
	var sell := s.menu.buttons()[1]
	sell.pressed.emit()
	expect(s.battle.towers.has(cell), "one tap on Sell only arms it")
	sell.pressed.emit()
	expect(not s.battle.towers.has(cell), "the second sells")
	await _close(s)
	await _restore()


func test_tower_numbers_come_from_the_content() -> void:
	var b := Battle.new(Game.content, Game.config, Game.content.levels[0], 1)
	for t: Dictionary in Game.content.towers:
		var id := str(t["id"])
		var text := CellMenu.tower_text(b, id, 1)
		expect(text.begins_with(str(t["name"]).to_upper()), "%s: the line names the tower (%s)" % [id, text])
		var s := Game.content.tower_level(id, 1)
		if s.has("range"):
			expect(text.contains("RANGE"), "%s: the line gives its range" % id)


# --- Android Back -------------------------------------------------------------

func _as_current(scene: String) -> Node:
	var node: Node = load(scene).instantiate()
	tree.root.add_child(node)
	tree.current_scene = node
	await frames(3)
	return node


func _scene_now() -> String:
	await frames(3)
	return tree.current_scene.scene_file_path if tree.current_scene != null else ""


func _drop_current() -> void:
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	tree.current_scene = null
	await frames(1)


func test_back_never_quits_by_itself() -> void:
	expect(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "project.godot: quit_on_go_back=false")
	expect(not tree.quit_on_go_back, "the running game doesn't quit on Back")


func test_back_on_the_title_asks_before_leaving() -> void:
	var title := await _as_current(TITLE)
	Game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST) # what Android sends
	await frames(1)
	expect(title.call("is_asking_to_quit"), "Back on the title asks before leaving")
	Game.go_back()
	await frames(1)
	expect(not title.call("is_asking_to_quit"), "Back again closes the question (the game stays)")
	var s: CodePlateSettings = title.call("open_settings")
	await frames(2)
	Game.go_back()
	await frames(2)
	expect(title.get_node_or_null("CodePlateSettings") == null or s.is_queued_for_deletion(), "Back closes Settings")
	expect(not title.call("is_asking_to_quit"), "...without asking to quit")
	await _drop_current()


func test_back_from_the_level_select_goes_to_the_title() -> void:
	await _as_current(LEVELS)
	Game.go_back()
	expect_eq(await _scene_now(), Game.SCENE_TITLE, "level select -> title")
	await _drop_current()


func test_back_in_a_level_pauses_then_leaves() -> void:
	_sandbox()
	Game.level_index = 0
	var s := await _as_current(BATTLE) as BattleScreen
	s.next_wave()
	await frames(5)
	s.tap_cell(Bot.best_cell(s.battle, _first_offered(s.battle), {}))
	await frames(1)
	var t := s.battle.tick
	Game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	expect(s.pause_menu.visible and tree.paused, "Back mid-level pauses (one press never loses the level)")
	expect(not s.menu.is_open(), "and closes the build menu")
	expect_eq(tree.current_scene, s as Node, "still in the level")
	await frames(5)
	expect_eq(s.battle.tick, t, "the level doesn't run while paused")
	Game.go_back()
	expect_eq(await _scene_now(), Game.SCENE_LEVELS, "Back on the pause menu goes to the level select")
	expect(not tree.paused, "and unpauses")
	await _drop_current()
	s = await _as_current(BATTLE) as BattleScreen
	s.result.open(false, 0, 0, 20, true)
	Game.go_back()
	expect_eq(await _scene_now(), Game.SCENE_LEVELS, "Back on the results goes to the level select")
	await _drop_current()
	await _restore()


func test_leaving_the_app_pauses_the_level() -> void:
	_sandbox()
	Game.level_index = 0
	var s := await _open(BATTLE) as BattleScreen
	s.next_wave()
	await frames(3)
	s.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	expect(s.pause_menu.visible and tree.paused, "the level pauses when the app goes to the background")
	Game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	expect(AudioServer.is_bus_mute(0), "sound is muted while the app is away")
	Game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	expect(not AudioServer.is_bus_mute(0), "and back when it returns")
	expect(s.pause_menu.visible, "coming back shows the pause menu: the player resumes when ready")
	s.pause_menu.close()
	await _close(s)
	await _restore()


# --- the splash hook and the Android preset ------------------------------------

func test_the_splash_hook() -> void:
	expect_eq(str(ProjectSettings.get_setting("application/run/main_scene", "")), "res://ui/splash.tscn", "the game starts on ui/splash.tscn")
	expect(not bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)), "the engine's boot image is off")
	var c := Game.config
	var saved := [c.splash_image, c.splash_text]
	c.splash_image = ""
	c.splash_text = ""
	var splash: Control = load("res://ui/splash.tscn").instantiate()
	splash.set("go_to_title", false)
	var done := [false]
	splash.connect("finished", func() -> void: done[0] = true)
	tree.root.add_child(splash)
	await frames(2)
	expect(done[0], "with no logo or line set, the splash finishes at once")
	splash.queue_free()
	c.splash_text = "MADE BY A CHECK"
	c.splash_image = "res://assets/ui/icon.png"
	splash = load("res://ui/splash.tscn").instantiate()
	splash.set("go_to_title", false)
	done[0] = false
	splash.connect("finished", func() -> void: done[0] = true)
	tree.root.add_child(splash)
	await frames(3)
	expect(not done[0], "with a logo it shows for a while")
	expect((splash.get_node("%Logo") as TextureRect).texture != null, "the logo shows")
	splash.call("go_back")
	expect(done[0], "Android Back skips it")
	splash.queue_free()
	c.splash_image = saved[0]
	c.splash_text = saved[1]
	await frames(1)


func test_the_android_preset_is_phone_ready() -> void:
	var cfg := ConfigFile.new()
	if not expect_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg reads"):
		return
	for section: String in cfg.get_sections():
		if not section.ends_with(".options") and str(cfg.get_value(section, "platform", "")) == "Android":
			var opts := section + ".options"
			expect(bool(cfg.get_value(opts, "screen/edge_to_edge", false)), "%s: edge_to_edge (the game lays itself out in the safe area)" % section)
			expect(not bool(cfg.get_value(opts, "user_data_backup/allow", true)), "%s: no cloud backup of the save" % section)
			for p: String in ["internet", "access_network_state", "access_wifi_state", "vibrate"]:
				expect(not bool(cfg.get_value(opts, "permissions/" + p, false)), "%s: asks for no %s permission" % [section, p])
			var exclude := str(cfg.get_value(section, "exclude_filter", ""))
			for f: String in ["codeplate.json", "package.json"]:
				expect(exclude.contains(f), "%s: %s isn't shipped" % [section, f])


func _first_offered(b: Battle) -> String:
	for t: Dictionary in b.content.towers:
		if b.level.allows(str(t["id"])):
			return str(t["id"])
	return ""
