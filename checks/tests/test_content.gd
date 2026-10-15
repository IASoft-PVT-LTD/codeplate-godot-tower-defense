extends CheckCase
## The real content is valid, validation catches common mistakes, and every
## level is fair: the bot wins it, and doing nothing loses it.

## The made-up map letters of test_battle.gd, so validation checks don't
## depend on the game's own legend.
const LEGEND: Dictionary = preload("res://checks/tests/test_battle.gd").LEGEND


func test_content_files_are_valid() -> void:
	var errors: PackedStringArray = []
	var c := Content.load_dir(Content.DIR, errors)
	expect(c != null and errors.is_empty(), "content errors:\n       " + "\n       ".join(errors))
	expect(c != null and c.levels.size() > 0, "there are levels")


func test_map_validation_catches_mistakes() -> void:
	var legend := LEGEND
	var cases := {
		"S..\n...\n..G": "path stops",
		"SPPG\n.P..": "branches",
		"SPG\n..": "same width",
		"SPP\n...": "no goal",
		"SPGz": "isn't in content/legend.json",
		"SPG\n...\nPP.": "aren't on the route",
		"SPG\nS..": "more than one spawn",
		"SPPG\nRQQQ\n.Q..": "route 1: the path branches",
		"SPG\n.Q.": "aren't on the route",
		"SPG\n...\n.QR": "route 1: the path stops",
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
			{"id": "v", "kind": "bullet", "sprite": "x", "base": "", "muzzle": [4, 5], "levels": [{"cost": 1, "damage": 1, "range": 9, "rate": 1, "speed": 9}]},
			{"id": "u", "kind": "splash", "sprite": "x", "targets": ["sea"], "levels": [{"cost": 1, "damage": 1, "range": 9, "rate": 1, "speed": 9}]},
		]},
		"enemies": {"enemies": [{"id": "t", "hp": 1}, {"id": "q", "hp": 1, "view": "sideways"}, {"id": "e", "hp": 1, "speed": 1, "bounty": 1, "sprite": "x", "splits_into": "ghost"}]},
		"legend": {"tiles": LEGEND.merged({"r": {"kind": "spawn", "route": -1}})},
		"levels": [{"id": "l", "map": "SPG", "waves": [{"groups": [{"enemy": "dragon", "count": 0, "route": 3}]}]}],
	}, errors)
	expect(c == null, "invalid content returns null")
	for needle: String in ["kind must be one of", "level 1 is missing \"splash\"", "\"targets\" must list", "used twice",
			"missing \"speed\"", "\"view\" must be", "\"base\" must be an art path", "\"muzzle\" must list one barrel length per level",
			"\"route\" must be a whole number", "route 3 isn't on the map", "splits_into \"ghost\"", "\"dragon\" isn't in enemies.json", "\"count\" must be at least 1"]:
		expect(Array(errors).any(func(e: String) -> bool: return e.contains(needle)), "reports: %s" % needle)


func test_every_sprite_and_icon_exists() -> void:
	var c := Game.content
	for e: Dictionary in c.enemies:
		expect(ResourceLoader.exists("res://" + str(e["sprite"])), "%s sprite %s exists" % [e["id"], e["sprite"]])
	var icons := int(Sprites.info("assets/ui/tower_icons.png")["frames"])
	for t: Dictionary in c.towers:
		for key: String in ["sprite", "shot", "base"]:
			if key == "base" and not t.has("base"):
				continue
			expect(ResourceLoader.exists("res://" + str(t.get(key, ""))), "%s %s %s exists" % [t["id"], key, t.get(key)])
		expect(int(Sprites.info(str(t["sprite"]))["frames"]) >= c.tower_max_level(str(t["id"])),
			"%s sprite has a frame per level" % t["id"])
		expect(int(t.get("icon", -1)) in range(icons), "%s icon is a frame of tower_icons.png" % t["id"])
		var sound := str(t.get("sound", ""))
		expect(sound.is_empty() or Audio.SOUNDS.has(StringName(sound)), "%s sound \"%s\" is in autoload/audio.gd SOUNDS" % [t["id"], sound])
	var decor_frames := int(Sprites.info(MapView.DECOR)["frames"])
	for ch: String in c.legend:
		var tile := "assets/tiles/%s.png" % c.legend[ch].get("tile", Map.DEFAULT_TILE)
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


func test_art_scale_and_smoothing_come_from_assets_json() -> void:
	# assets.json "scale" (default 1) and "smooth" (default false) reach every
	# sprite through Sprites.style(); a made-up 48 px asset drawn at half size.
	Sprites.info(str(Game.content.enemies[0]["sprite"])) # loads the manifest
	const FAKE := "assets/check/half_size.png"
	Sprites._manifest[FAKE] = {"path": FAKE, "width": 48, "height": 48, "frames": 2, "scale": 0.5, "smooth": true}
	expect_eq(Sprites.view_size(FAKE), Vector2(24, 24), "48 px art with scale 0.5 is drawn 24 view pixels wide")
	var half := Sprite2D.new()
	Sprites.style(half, FAKE)
	expect_eq(half.scale, Vector2(0.5, 0.5), "style() applies the scale")
	expect_eq(half.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "and linear filtering for smooth art")
	half.free()
	Sprites._manifest.erase(FAKE)
	# Every listed asset gets exactly what assets.json says (1 and crisp when it says nothing).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets.json"))
	for a: Dictionary in data.get("assets", []):
		if str(a.get("kind", "")) != "image":
			continue
		var s := Sprite2D.new()
		Sprites.style(s, str(a["path"]))
		var want := float(a.get("scale", 1.0))
		expect(want > 0.0 and s.scale == Vector2.ONE * want, "%s: scale %s" % [a["path"], want])
		expect_eq(s.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR if bool(a.get("smooth", false)) else CanvasItem.TEXTURE_FILTER_PARENT_NODE,
			"%s: smooth %s" % [a["path"], a.get("smooth", false)])
		s.free()


func test_atlas_import_cuts_strips_from_texturepacker_json() -> void:
	# tools/import_atlas.gd on a tiny made-up atlas: frame N of the strip must
	# be the JSON rectangle, in both TexturePacker formats.
	var tool: GDScript = load("res://tools/import_atlas.gd")
	var atlas := Image.create_empty(16, 8, false, Image.FORMAT_RGBA8)
	for y: int in 8:
		for x: int in 16:
			atlas.set_pixel(x, y, Color8(x * 16, y * 32, 7, 255))
	var hash := {"frames": {
		"walk_0": {"frame": {"x": 0, "y": 0, "w": 4, "h": 4}, "rotated": false},
		"walk_1": {"frame": {"x": 8, "y": 4, "w": 4, "h": 4}, "rotated": false},
		"slim": {"frame": {"x": 4, "y": 0, "w": 2, "h": 4}, "rotated": false, "trimmed": true,
			"spriteSourceSize": {"x": 1, "y": 0, "w": 2, "h": 4}, "sourceSize": {"w": 4, "h": 4}},
		"turned": {"frame": {"x": 12, "y": 0, "w": 4, "h": 4}, "rotated": true},
		"big": {"frame": {"x": 0, "y": 0, "w": 8, "h": 8}, "rotated": false},
	}, "meta": {"image": "atlas.png"}}
	var array := {"frames": [
		{"filename": "walk_0", "frame": {"x": 0, "y": 0, "w": 4, "h": 4}},
		{"filename": "walk_1", "frame": {"x": 8, "y": 4, "w": 4, "h": 4}},
	]}
	for json: Dictionary in [hash, array]:
		var r: Dictionary = tool.cut(json, atlas, ["walk_0", "walk_1"])
		if not expect_eq(str(r["error"]), "", "the strip is cut"):
			continue
		var strip: Image = r["image"]
		expect(r["width"] == 4 and r["height"] == 4 and r["frames"] == 2 and strip.get_size() == Vector2i(8, 4), "two 4x4 frames side by side")
		expect_eq(strip.get_pixel(1, 2), atlas.get_pixel(1, 2), "frame 0 is the first rectangle")
		expect_eq(strip.get_pixel(4 + 3, 1), atlas.get_pixel(8 + 3, 4 + 1), "frame 1 is the second rectangle")
	var trimmed: Dictionary = tool.cut(hash, atlas, ["walk_0", "slim"])
	expect(str(trimmed["error"]).is_empty() and (trimmed["image"] as Image).get_pixel(4 + 1, 0) == atlas.get_pixel(4, 0)
		and (trimmed["image"] as Image).get_pixel(4, 0).a == 0.0, "a trimmed frame goes back to its place in the full frame")
	expect(str(tool.cut(hash, atlas, ["walk_0", "big"])["error"]).contains("must match"), "frames of different sizes are refused")
	expect(str(tool.cut(hash, atlas, ["turned"])["error"]).contains("rotated"), "rotated frames are refused")
	expect(str(tool.cut(hash, atlas, ["ghost"])["error"]).contains("isn't in the atlas"), "a missing frame is reported")
