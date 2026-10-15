class_name Sprites
extends RefCounted
## Builds animations from the horizontal sprite strips listed in assets.json.
## Frame size and count come from assets.json, so to reskin you replace the
## PNG and update its width/height/frames there; no code changes needed.
##
## Two optional assets.json fields fit art made for another cell size:
##   "scale":  how big to draw it (0.5 = half size, so 48 px art fills a
##             24 px cell). Default 1.
##   "smooth": true draws it with linear filtering (smooth, painted or vector
##             art). Default false: the project's nearest filtering (crisp
##             pixel art).
## Every Sprite2D / AnimatedSprite2D built from an asset goes through style()
## (or sprite() / animated(), which call it), so both fields always apply.

static var _manifest: Dictionary = {}
static var _textures: Dictionary[String, Texture2D] = {}


## {width, height, frames, scale, smooth} for an asset path like "assets/enemies/grunt.png".
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
		return {"width": 16, "height": 16, "frames": 1, "scale": 1.0, "smooth": false}
	return {"width": int(a.get("width", 16)), "height": int(a.get("height", 16)), "frames": int(a.get("frames", 1)),
		"scale": float(a.get("scale", 1.0)), "smooth": bool(a.get("smooth", false))}


## One frame's size as drawn, in view pixels (its size in the file times "scale").
static func view_size(path: String) -> Vector2:
	var i := info(path)
	return Vector2(i["width"], i["height"]) * float(i["scale"])


## Gives a sprite the asset's "scale" and "smooth" settings.
static func style(item: Node2D, path: String) -> void:
	var i := info(path)
	item.scale = Vector2.ONE * float(i["scale"])
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if i["smooth"] else CanvasItem.TEXTURE_FILTER_PARENT_NODE


## A styled Sprite2D showing frame `index` of a strip.
static func sprite(path: String, index: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = frame(path, index)
	style(s, path)
	return s


## A styled AnimatedSprite2D playing `frames` (built with add_strip from `path`).
static func animated(frames: SpriteFrames, path: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	style(s, path)
	return s


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load("res://" + path)
	return _textures[path]


## One frame of a strip as its own texture.
static func frame(path: String, index: int) -> Texture2D:
	var i := info(path)
	if int(i["frames"]) <= 1 and index == 0:
		return texture(path)
	var at := AtlasTexture.new()
	at.atlas = texture(path)
	at.region = Rect2(i["width"] * clampi(index, 0, i["frames"] - 1), 0, i["width"], i["height"])
	at.filter_clip = true # smooth filtering must not pick up the next frame's pixels
	return at


## Adds an animation named `anim` made from a whole strip.
static func add_strip(frames: SpriteFrames, anim: StringName, path: String, fps: float, loop: bool = true) -> void:
	var i := info(path)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for f: int in i["frames"]:
		frames.add_frame(anim, frame(path, f))
