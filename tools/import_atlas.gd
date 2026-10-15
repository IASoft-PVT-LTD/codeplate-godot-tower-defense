extends SceneTree
## Cuts sprite strips out of a texture atlas (TexturePacker JSON, "hash" or
## "array" format) into the horizontal strips this project uses.
##
##   godot --headless --path . --script res://tools/import_atlas.gd -- atlas=art/pack.json map=art/mapping.json
##
## `atlas` is the atlas JSON; its image is "meta.image", next to the JSON.
## `map` names the strips to write and their frames, in order:
##   {"assets/enemies/scout.png": ["scout_0", "scout_1", "scout_2", "scout_3"],
##    "assets/towers/base.png": ["turret_base"]}
## Every frame of one strip must be the same size (trimmed frames are put back
## at their source size). Rotated frames aren't supported: export the atlas
## with rotation off. Paths are relative to this folder, or absolute.
##
## Then, for each strip, set "width", "height" and "frames" in assets.json to
## the numbers printed here (and "scale" if the art was made for another cell
## size; see docs/recipes/retheme.md), and run the import command.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not args.has("atlas") or not args.has("map"):
		print("usage: --script res://tools/import_atlas.gd -- atlas=<atlas.json> map=<mapping.json>")
		quit(1)
		return
	var atlas_path := _abs(str(args["atlas"]))
	var atlas: Variant = JSON.parse_string(FileAccess.get_file_as_string(atlas_path))
	var mapping: Variant = JSON.parse_string(FileAccess.get_file_as_string(_abs(str(args["map"]))))
	if not atlas is Dictionary or not mapping is Dictionary:
		print("can't read %s or %s as JSON" % [args["atlas"], args["map"]])
		quit(1)
		return
	var image_name := str((atlas as Dictionary).get("meta", {}).get("image", ""))
	var image := Image.load_from_file(atlas_path.get_base_dir().path_join(image_name))
	if image == null or image.is_empty():
		print("can't load the atlas image \"%s\" (meta.image)" % image_name)
		quit(1)
		return
	var failed := false
	for out: String in mapping:
		var result := cut(atlas, image, mapping[out])
		if not str(result["error"]).is_empty():
			print("%s: %s" % [out, result["error"]])
			failed = true
			continue
		var target := _abs(out)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		(result["image"] as Image).save_png(target)
		print("%s  width %d  height %d  frames %d" % [out, result["width"], result["height"], result["frames"]])
	quit(1 if failed else 0)


## {name: {x, y, w, h, ox, oy, sw, sh, rotated}} from either JSON format.
## (ox, oy) is where the trimmed rectangle sits in the frame of size (sw, sh).
static func frames_of(atlas: Dictionary) -> Dictionary:
	var out := {}
	var raw: Variant = atlas.get("frames", {})
	var entries: Array = []
	if raw is Dictionary:
		for key: String in raw:
			var e: Dictionary = (raw[key] as Dictionary).duplicate()
			e["filename"] = key
			entries.append(e)
	elif raw is Array:
		entries = raw
	for e: Dictionary in entries:
		var f: Dictionary = e.get("frame", {})
		var src: Dictionary = e.get("spriteSourceSize", {"x": 0, "y": 0})
		var size: Dictionary = e.get("sourceSize", {"w": f.get("w", 0), "h": f.get("h", 0)})
		out[str(e.get("filename", ""))] = {
			"x": int(f.get("x", 0)), "y": int(f.get("y", 0)), "w": int(f.get("w", 0)), "h": int(f.get("h", 0)),
			"ox": int(src.get("x", 0)), "oy": int(src.get("y", 0)), "sw": int(size.get("w", 0)), "sh": int(size.get("h", 0)),
			"rotated": bool(e.get("rotated", false)),
		}
	return out


## Builds one horizontal strip from the named frames.
## Returns {image, width, height, frames, error} ("" error when it worked).
static func cut(atlas: Dictionary, image: Image, names: Array) -> Dictionary:
	var frames := frames_of(atlas)
	var result := {"image": null, "width": 0, "height": 0, "frames": names.size(), "error": ""}
	if names.is_empty():
		result["error"] = "lists no frames"
		return result
	var w := -1
	var h := -1
	for n: Variant in names:
		if not frames.has(str(n)):
			result["error"] = "frame \"%s\" isn't in the atlas" % n
			return result
		var f: Dictionary = frames[str(n)]
		if f["rotated"]:
			result["error"] = "frame \"%s\" is rotated in the atlas; export it with rotation off" % n
			return result
		if w < 0:
			w = f["sw"]
			h = f["sh"]
		elif f["sw"] != w or f["sh"] != h:
			result["error"] = "frame \"%s\" is %dx%d but the strip's first frame is %dx%d (a strip's frames must match)" % [n, f["sw"], f["sh"], w, h]
			return result
	var strip := Image.create_empty(w * names.size(), h, false, Image.FORMAT_RGBA8)
	var src := image.duplicate() as Image
	src.convert(Image.FORMAT_RGBA8)
	for i: int in names.size():
		var f: Dictionary = frames[str(names[i])]
		strip.blit_rect(src, Rect2i(f["x"], f["y"], f["w"], f["h"]), Vector2i(i * w + int(f["ox"]), int(f["oy"])))
	result["image"] = strip
	result["width"] = w
	result["height"] = h
	return result


static func _abs(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)
