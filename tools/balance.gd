extends SceneTree
## Balance report: a simple bot plays every level (and a run where nobody
## builds) and prints the result, lives left and stars. Use it after changing
## towers, enemies, waves or gold.
##
##   godot --headless --path . --script res://tools/balance.gd
##   godot --headless --path . --script res://tools/balance.gd -- level=level_03
##   godot --headless --path . --script res://tools/balance.gd -- level=level_03 waves=1
##   godot --headless --path . --script res://tools/balance.gd -- level=level_02 gold=200 hp=1.2
##   godot --headless --path . --script res://tools/balance.gd -- margin=1
##   godot --headless --path . --script res://tools/balance.gd -- level=level_03 tune=1
##
## `waves=1` prints the bot's gold, lives and towers as each wave starts.
##
## What-ifs, without editing any file: `gold=N` plays with another starting
## gold, `hp=X` with another health multiplier (the level's "hp_mult").
## `margin=1` also finds the least starting gold the bot needs to reach the
## lives target (25 gold steps, three wins in a row, since the bot's result
## wobbles a little with gold). "slack" is the level's gold divided by that:
## higher is more forgiving, and a steady climb has slack falling level by level.
##
## `tune=1` sweeps the level's health multiplier (hp_mult) from 0.6 to 1.6 in
## 0.05 steps and prints the bot's lives at each. The bot's result can jump
## from "untouched" to "lost" over a few percent of health; set hp_mult in a
## steady stretch, with a few steps of room before the losses start (the
## fairness check also wants a win with `bot_hp_margin` more health).
##
## The bot builds in towers.json's "bot_order" on the cells that cover the most path.
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
		if args.has("gold") or args.has("hp"):
			level = level.with_changes(int(args.get("gold", level.start_gold)), float(args.get("hp", level.hp_mult)))
			print("%-12s      what-if: start_gold %d, hp_mult %.2f" % [level.id, level.start_gold, level.hp_mult])
		if args.get("tune", "0") == "1":
			tune(content, config, level)
		if args.get("margin", "0") == "1":
			var need := least_gold(content, config, level)
			print("%-12s      the bot needs %d gold (the level gives %d): slack %.2f" % [level.id, need, level.start_gold,
				float(level.start_gold) / maxf(1.0, need)])
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


## Prints the bot's lives at health multipliers 0.6 to 1.6, marking the level's own.
static func tune(content: Content, config: GameConfig, level: LevelData) -> void:
	print("%-12s      hp_mult sweep (the level has %.2f; target %d+ lives):" % [level.id, level.hp_mult, ceili(level.lives * config.bot_min_lives)])
	for step: int in range(12, 33):
		var hp := step * 0.05
		var o := Bot.play(content, config, level.with_changes(level.start_gold, hp), 1)
		var bar := "#".repeat(o.lives) if o.won else "lost"
		print("    %.2f %s %3d/%-3d %s" % [hp, "<" if is_equal_approx(hp, level.hp_mult) else " ", o.lives if o.won else 0, level.lives, bar])


## The least starting gold at which the bot wins `level` with at least
## bot_min_lives of its lives, three 25-gold steps in a row.
static func least_gold(content: Content, config: GameConfig, level: LevelData) -> int:
	var wins := 0
	var gold := 0
	while gold < level.start_gold * 4:
		gold += 25
		var o := Bot.play(content, config, level.with_changes(gold, level.hp_mult), 1)
		wins = wins + 1 if o.won and o.lives >= ceili(level.lives * config.bot_min_lives) else 0
		if wins == 3:
			return gold - 50
	return gold
