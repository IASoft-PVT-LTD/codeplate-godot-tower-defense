extends CheckCase
## The real content is valid, validation catches common mistakes, and every
## level is fair: the bot wins it, and doing nothing loses it.


func test_content_files_are_valid() -> void:
	var errors: PackedStringArray = []
	var c := Content.load_dir(Content.DIR, errors)
	expect(c != null and errors.is_empty(), "content errors:\n       " + "\n       ".join(errors))
	expect(c != null and c.levels.size() > 0, "there are levels")


func test_map_validation_catches_mistakes() -> void:
	var legend: Dictionary = Game.content.legend
	var cases := {
		"S..\n...\n..G": "path stops",
		"SPPG\n.P..": "branches",
		"SPG\n..": "same width",
		"SPP\n...": "no goal",
		"SPGz": "isn't in content/legend.json",
		"SPG\n...\nPP.": "aren't on the route",
	}
	for text: String in cases:
		var errors: PackedStringArray = []
		var m := Map.parse(text, legend, errors, "test")
		expect(m == null and Array(errors).any(func(e: String) -> bool: return e.contains(cases[text])),
			"map %s reports \"%s\" (got %s)" % [text.c_escape(), cases[text], errors])


func test_content_validation_catches_mistakes() -> void:
	var errors: PackedStringArray = []
	var c := Content.from_data({
		"towers": {"towers": [
			{"id": "t", "kind": "laser", "levels": [{}]},
			{"id": "u", "kind": "splash", "sprite": "x", "targets": ["sea"], "levels": [{"cost": 1, "damage": 1, "range": 9, "rate": 1, "speed": 9}]},
		]},
		"enemies": {"enemies": [{"id": "t", "hp": 1}, {"id": "q", "hp": 1}, {"id": "e", "hp": 1, "speed": 1, "bounty": 1, "sprite": "x", "splits_into": "ghost"}]},
		"legend": {"tiles": Game.content.legend},
		"levels": [{"id": "l", "map": "SPG", "waves": [{"groups": [{"enemy": "dragon", "count": 0}]}]}],
	}, errors)
	expect(c == null, "invalid content returns null")
	for needle: String in ["kind must be one of", "level 1 is missing \"splash\"", "\"targets\" must list", "used twice",
			"missing \"speed\"", "splits_into \"ghost\"", "\"dragon\" isn't in enemies.json", "\"count\" must be at least 1"]:
		expect(Array(errors).any(func(e: String) -> bool: return e.contains(needle)), "reports: %s" % needle)


func test_every_sprite_and_icon_exists() -> void:
	var c := Game.content
	for e: Dictionary in c.enemies:
		expect(ResourceLoader.exists("res://" + str(e["sprite"])), "%s sprite %s exists" % [e["id"], e["sprite"]])
	var icons := int(Sprites.info("assets/ui/tower_icons.png")["frames"])
	for t: Dictionary in c.towers:
		for key: String in ["sprite", "shot"]:
			expect(ResourceLoader.exists("res://" + str(t.get(key, ""))), "%s %s %s exists" % [t["id"], key, t.get(key)])
		expect(int(Sprites.info(str(t["sprite"]))["frames"]) >= c.tower_max_level(str(t["id"])),
			"%s sprite has a frame per level" % t["id"])
		expect(int(t.get("icon", -1)) in range(icons), "%s icon is a frame of tower_icons.png" % t["id"])
	var decor_frames := int(Sprites.info(MapView.DECOR)["frames"])
	for ch: String in c.legend:
		var tile := "assets/tiles/%s.png" % c.legend[ch].get("tile", "grass")
		expect(ResourceLoader.exists("res://" + tile), "legend '%s' tile %s exists" % [ch, tile])
		if c.legend[ch].has("decor"):
			expect(int(c.legend[ch]["decor"]) in range(decor_frames), "legend '%s' decor %s is a frame of %s (%d frames)" % [ch, c.legend[ch]["decor"], MapView.DECOR, decor_frames])


func test_every_level_is_fair() -> void:
	# If this fails after you change towers, enemies, waves or gold, run
	# tools/balance.gd (add waves=1 to see the bot's gold and lives per wave),
	# then adjust the level or the targets in the config (and tell the user).
	var cfg := Game.config
	for level: LevelData in Game.content.levels:
		var o := Bot.play(Game.content, cfg, level, 1)
		expect(o.won and o.lives >= ceili(level.lives * cfg.bot_min_lives),
			"%s: the bot %s with %d/%d lives; target %d%% (tools/balance.gd)" % [level.id, "won" if o.won else "lost",
			o.lives, level.lives, roundi(cfg.bot_min_lives * 100.0)])
		if cfg.idle_must_lose:
			var idle := Bot.play(Game.content, cfg, level, 1, false)
			expect(not idle.won, "%s: winnable without building anything" % level.id)
