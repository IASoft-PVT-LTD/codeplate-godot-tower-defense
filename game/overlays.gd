class_name Overlays
extends RefCounted
## Shared helpers for the overlay panels (result, pause).


## A dimmed full-view panel with a centered box; returns the box (VBox).
static func panel(layer: CanvasLayer, width: float) -> VBoxContainer:
	var root := Game.ui_root(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.04, 0.65)
	dim.size = Vector2(480, 270)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.size = Vector2(480, 270)
	root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	p.add_child(box)
	return box


static func label(box: Container, text: String, variation: StringName = &"", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation:
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	box.add_child(l)
	return l


static func button(box: Container, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	box.add_child(b)
	return b
