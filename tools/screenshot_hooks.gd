extends RefCounted
## Screens and setup for the CodePlate screenshot tool:
##
##   godot --path . --script res://addons/codeplate/tools/screenshot.gd -- screen=battle level=2 wave=4 wait=1
##
## Screens: title, settings, credits (the shared settings screen over the
## title), levels, battle.
## Extra arguments:
##   level=N        battle: which level (1-based, default 1)
##   wave=N         battle: the bot builds and plays until wave N starts (0 = before the first wave)
##   menu=build     battle: open the build menu on the best free cell
##   menu=tower     battle: open the tower menu on the first tower
##   stars=N        levels: pretend every level has N stars (shows unlocked cards)
##   seed=N         battle seed (default 7)
##
## Uses a throwaway progress file, so real progress is never touched.
## A --script file compiles before autoloads exist, so this file must not name
## classes whose code uses them (like BattleScreen). It uses get() and call().

const SCREENS := {
	"title": "res://ui/title.tscn",
	"settings": "res://ui/title.tscn",
	"credits": "res://ui/title.tscn",
	"levels": "res://ui/level_select.tscn",
	"battle": "res://game/battle_screen.tscn",
}


func before_add(_node: Node, args: Dictionary, tree: SceneTree) -> void:
	var game: Node = tree.root.get_node("Game")
	game.set("save_path", "user://screenshot_progress.json")
	game.call("load_progress")
	game.set("next_seed", int(args.get("seed", "7")))
	game.set("level_index", int(args.get("level", "1")) - 1)
	if args.has("stars"):
		var content: Content = game.get("content")
		for l: LevelData in content.levels:
			game.call("record_win", l.id, int(args["stars"]))


func after_add(node: Node, args: Dictionary, tree: SceneTree) -> void:
	var screen := str(args.get("screen", ""))
	if screen == "settings" or screen == "credits":
		var settings: Node = node.call("open_settings")
		if screen == "credits":
			settings.call("show_credits")
		return
	var battle: Variant = node.get("battle")
	if battle == null:
		await tree.create_timer(0.3).timeout
		return
	var b: Battle = battle
	var units: Node = node.get("units")
	var target_wave := int(args.get("wave", "0"))
	var coverage := {}
	var order := 0
	if target_wave > 0:
		# The bot mustn't lose on the way to the shot: lend it lives, give back what's left.
		var real_lives := b.lives
		const LOAN := 1000000
		b.lives += LOAN
		order = Bot._think(b, coverage, order)
		b.call_wave()
		while b.wave < target_wave and b.state == Battle.State.RUNNING:
			units.call("remember")
			b.step()
			if b.tick % Bot.THINK_EVERY == 0:
				order = Bot._think(b, coverage, order)
		# let the new wave walk in a little
		for i: int in GameConfig.ticks(float(args.get("walk", "6"))):
			units.call("remember")
			b.step()
		b.lives = maxi(1, real_lives - (real_lives + LOAN - b.lives))
	elif args.has("menu"):
		Bot._think(b, coverage, order)
	if target_wave > 0 or args.has("menu"):
		node.get("hud").call("announce", "") # hide the level-name banner
	match args.get("menu", ""):
		"build":
			node.call("tap_cell", Bot.best_cell(b, str(b.content.towers[0]["id"]), coverage))
		"tower":
			if not b.towers.is_empty():
				node.call("tap_cell", b.towers.keys()[0])
	await tree.create_timer(0.3).timeout
