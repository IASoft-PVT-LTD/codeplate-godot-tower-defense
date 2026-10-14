class_name Sprites
extends RefCounted
## Builds animations from the horizontal sprite strips listed in assets.json.
## Frame size and count come from assets.json, so to reskin you replace the
## PNG and update its width/height/frames there; no code changes needed.

static var _manifest: Dictionary = {}
static var _textures: Dictionary[String, Texture2D] = {}


## {width, height, frames} for an asset path like "assets/enemies/grunt.png".
static func info(path: String) -> Dictionary:
	if _manifest.is_empty():
		var json := JSON.new()
		var data: Variant = json.data if json.parse(FileAccess.get_file_as_string("res://assets.json")) == OK else null
		if data is Dictionary:
			for a: Dictionary in data.get("assets", []):
				_manifest[str(a["path"])] = a
	var a: Dictionary = _manifest.get(path, {})
	if a.is_empty():
		push_error("Sprites: %s is not listed in assets.json" % path)
		return {"width": 16, "height": 16, "frames": 1}
	return {"width": int(a.get("width", 16)), "height": int(a.get("height", 16)), "frames": int(a.get("frames", 1))}


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load("res://" + path)
	return _textures[path]


## One frame of a strip as its own texture.
static func frame(path: String, index: int) -> Texture2D:
	var i := info(path)
	var at := AtlasTexture.new()
	at.atlas = texture(path)
	at.region = Rect2(i["width"] * clampi(index, 0, i["frames"] - 1), 0, i["width"], i["height"])
	return at


## Adds an animation named `anim` made from a whole strip.
static func add_strip(frames: SpriteFrames, anim: StringName, path: String, fps: float, loop: bool = true) -> void:
	var i := info(path)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for f: int in i["frames"]:
		frames.add_frame(anim, frame(path, f))
