extends Node
## Moves everything drawn a quarter of a screen pixel right and down, so pixel art and text that
## land halfway between two screen pixels still draw whole.
##
## On a phone the UI is stretched x1.5 (1080 lines for the 720 the layouts use): an odd position
## in the UI's units falls on a half screen pixel. There, every screen pixel samples a texture
## exactly on the edge between two of its pixels and picks one or the other by rounding luck:
## letters get a column or a row doubled, or lost. A quarter-pixel shift takes both whole and half
## positions off those edges (docs/design/interface.md, Text).

## How far, in screen pixels.
const SHIFT := 0.25


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var root := get_tree().root
	var scale := root.get_stretch_transform().get_scale().x
	if scale <= 0.0:
		return
	root.global_canvas_transform = Transform2D(0.0, Vector2.ONE * SHIFT / scale)
