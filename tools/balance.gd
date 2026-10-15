extends SceneTree
## Balance report: a simple bot plays every level (and a run where nobody
## builds) and prints the result, lives left and stars. Use it after changing
## towers, enemies, waves or gold.
##
##   godot --headless --path . --script res://tools/balance.gd
##   godot --headless --path . --script res://tools/balance.gd -- level=level_03
##   godot --headless --path . --script res://tools/balance.gd -- level=level_03 waves=1
##
## `waves=1` prints the bot's gold, lives and towers as each wave starts.
##
## The bot builds from a fixed order on the cells that cover the most path.
## A thoughtful person does better, so if the bot wins with lives to spare,
## the level is fair; if it wins untouched, it's probably too easy.


func _initialize() -> void:
	preload("res://addons/codeplate/checks/run.gd").watchdog(self, 600.0)
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var config: GameConfig = load("res://config/game_config.tres")
	var errors: PackedStringArray = []
	var content := Content.load_dir(Content.DIR, errors)
	if content == null:
		print("content errors:\n  " + "\n  ".join(errors))
		quit(1)
		return
	print("level        bot: result  lives  stars  towers   time   | idle: result  waves")
	for level: LevelData in content.levels:
		if args.has("level") and level.id != args["level"]:
			continue
		var t := Time.get_ticks_msec()
		var on_wave := Callable()
		if args.get("waves", "0") == "1":
			on_wave = func(b: Battle) -> void:
				var kinds := {}
				for cell: Vector2i in b.towers:
					var tw: Entities.Tower = b.towers[cell]
					kinds["%s%d" % [tw.type, tw.level]] = kinds.get("%s%d" % [tw.type, tw.level], 0) + 1
				print("    wave %2d  %5s  gold %4d  lives %2d  towers %s" % [b.wave, "%d:%02d" % [int(b.seconds()) / 60, int(b.seconds()) % 60], b.gold, b.lives, kinds])
		var o := Bot.play(content, config, level, 1, true, on_wave)
		var idle := Bot.play(content, config, level, 1, false)
		print("%-12s      %-6s %3d/%-3d  %d     %3d    %5s   |       %-6s %d/%d   (%d ms)" % [level.id,
			"WON" if o.won else "lost", o.lives, o.max_lives, o.stars, o.towers,
			"%d:%02d" % [int(o.seconds) / 60, int(o.seconds) % 60],
			"WON" if idle.won else "lost", idle.waves_cleared, level.waves.size(), Time.get_ticks_msec() - t])
	quit(0)
