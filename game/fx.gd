class_name Fx
extends Node2D
## One-shot effects: animated bursts, sun rays and floating numbers.

const HIT := "assets/fx/hit.png"
const BOOM := "assets/fx/boom.png"
const FROST := "assets/fx/frost.png"
const SPARKLE := "assets/fx/sparkle.png"
const DEATH := "assets/fx/death.png"
const MAX_NUMBERS := 30

var _frames: Dictionary[String, SpriteFrames] = {}
var _numbers := 0


## Plays a strip once at `pos`, then frees it.
func burst(path: String, pos: Vector2, fps: float = 16.0, scale_by: float = 1.0) -> void:
	if not _frames.has(path):
		var f := SpriteFrames.new()
		f.remove_animation(&"default")
		Sprites.add_strip(f, &"fx", path, fps, false)
		_frames[path] = f
	var s := Sprites.animated(_frames[path], path)
	s.position = pos
	s.scale *= scale_by
	add_child(s)
	s.play(&"fx")
	s.animation_finished.connect(s.queue_free)


## A beam from `a` to `b` that fades out (`path` is a short horizontal strip).
func ray(path: String, a: Vector2, b: Vector2) -> void:
	var s := Sprites.sprite(path) # the asset's "scale" sets the beam's thickness
	s.centered = false
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	s.position = a
	s.rotation = (b - a).angle()
	s.scale.x = a.distance_to(b) / s.texture.get_width() # stretched to span a..b
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


## Small text that rises and fades (gold gained, damage).
func text(pos: Vector2, value: String, color: Color = Color.WHITE) -> void:
	if _numbers >= MAX_NUMBERS:
		return
	_numbers += 1
	var l := Label.new()
	l.text = value
	l.theme_type_variation = &"SmallLabel"
	l.modulate = color
	l.position = pos - Vector2(12, 8)
	l.size = Vector2(24, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 5
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 12.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		_numbers -= 1
		l.queue_free())
