extends Node
## Keeps text and pixel art whole on any screen (autoload "PixelGrid"): it picks the scale of the
## canvas, and shifts it a quarter of a screen pixel.
##
## The scale. The UI is laid out at 1280x720 and stretched (canvas_items, expand): Godot alone
## would scale it by min(width / 1280, height / 720), any number (x1.07 on 1366x768, x1.25 on
## 1600x900), where a BODY letter's pixel covers an uneven number of screen pixels and letters
## look cut. Here the scale is that number rounded down to a step of 0.5 (x1 on 720 to 1079
## lines, x1.5 on 1080, x2 on 1440, x3 on 2160: whole font pixels), and the canvas grows to fill
## the screen (1366x768 lays out at 1366x768, 3440x1440 at 1720x720). A screen too small for
## x1 (1024x768: x0.8) keeps Godot's scale; nothing whole fits. Settings.ui_size takes one or two
## steps off (never under x1): more room on a big monitor. The floor's framing doesn't change:
## the camera zooms in by what the rounding took off (world_zoom(), GameCamera).
##
## The shift. On a phone the UI is stretched x1.5 (1080 lines for the 720 the layouts use): an odd
## position in the UI's units falls on a half screen pixel. There, every screen pixel samples a
## texture exactly on the edge between two of its pixels and picks one or the other by rounding
## luck: letters get a column or a row doubled, or lost. A quarter-pixel shift takes both whole
## and half positions off those edges (docs/design/interface.md, Text).

## The canvas's scale changed (a new window size, the interface size option).
signal scale_changed

## How far, in screen pixels.
const SHIFT := 0.25
## The scale goes by these steps (whole font pixels at BODY: 2 UI units a font pixel).
const STEP := 0.5

## Godot's own scale for this window (expand), and the one used.
var _fit := 1.0
var _scale := 1.0


func _ready() -> void:
	get_tree().root.size_changed.connect(_apply)
	Settings.changed.connect(_apply)
	_apply()


## The canvas's scale for a window Godot would scale by `fit`, at interface size `ui_size`
## (Settings.UI_*).
static func canvas_scale(fit: float, ui_size: int) -> float:
	if fit < 1.0:
		return fit
	var whole := floorf(fit / STEP + 0.001) * STEP
	return maxf(1.0, whole - STEP * ui_size)


## How much more the camera zooms so the floor fills the screen as it would at Godot's own scale
## (1 when nothing was rounded off).
func world_zoom() -> float:
	return maxf(1.0, _fit / _scale) if _scale > 0.0 else 1.0


## The scale in use (screen pixels per UI unit).
func ui_scale() -> float:
	return _scale


func _apply() -> void:
	var root := get_tree().root
	var base := Vector2(root.content_scale_size)
	if base.x <= 0.0 or base.y <= 0.0 or root.size.x <= 0 or root.size.y <= 0:
		return
	var fit := minf(root.size.x / base.x, root.size.y / base.y)
	var target := canvas_scale(fit, Settings.ui_size)
	var factor := target / fit
	var changed := not is_equal_approx(_fit, fit) or not is_equal_approx(_scale, target)
	_fit = fit
	_scale = target
	if not is_equal_approx(root.content_scale_factor, factor):
		root.content_scale_factor = factor
	if DisplayServer.get_name() != "headless":
		var stretch := root.get_stretch_transform().get_scale().x
		if stretch > 0.0:
			root.global_canvas_transform = Transform2D(0.0, Vector2.ONE * SHIFT / stretch)
	if changed:
		scale_changed.emit()
