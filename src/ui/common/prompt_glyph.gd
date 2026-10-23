class_name PromptGlyph
extends Control
## The key or button that does `action`, drawn as a small cap in pixel art (Prompts.glyph()): a
## keyboard key, a gamepad's round face button in its color (✕ ○ □ △ on a PlayStation pad), a
## shoulder or trigger, a stick, a mouse with the button lit. It follows the device in use
## (InputDevice) and hides on touch, where the on-screen buttons speak for themselves.
## Drawn on the 2-unit grid of a BODY letter's pixels, the word at Fonts.BODY.

## The cap's height (UI units), its key's lower edge included.
const HEIGHT := 28.0
## One pixel of the cap's art (a BODY letter's pixel).
const PIXEL := 2.0
## The rim of keys and buttons without a color of their own.
const RIM := Color(0.93, 0.86, 0.72)
const FACE := Color(0.13, 0.09, 0.1, 0.94)
const KEY_EDGE := Color(0.5, 0.4, 0.3)
const WORDS := Color(1.0, 0.95, 0.85)
const MOUSE_LIT := Color(1.0, 0.82, 0.4)

## The input action (or a prompt of input_prompts.tres: "move", "menu_tabs").
@export var action: StringName:
	set(value):
		action = value
		_refresh()
## Shown on touch too (never by default).
@export var on_touch := false
## A cap to draw instead of the device's own (the Controls page lists every binding).
var fixed: Dictionary = {}:
	set(value):
		fixed = value
		_refresh()

var _cap: Dictionary = {}


static func make(for_action: StringName) -> PromptGlyph:
	var glyph := PromptGlyph.new()
	glyph.action = for_action
	return glyph


## Where badge() puts a cap on its control.
enum Place { TOP, CORNER, INSIDE }


## `action`'s cap on `control`, the key of a button that does the same: over the middle of its top
## edge (TOP: the HUD's bag), over its top left corner (CORNER: the map), or inside it on the left,
## its words still centred (INSIDE: a dialog's Leave, Later, Resume).
static func badge(control: Control, for_action: StringName, where := Place.TOP) -> PromptGlyph:
	var glyph := make(for_action)
	glyph.name = "%sKey" % String(for_action).to_pascal_case()
	control.add_child(glyph)
	var place := func() -> void:
		match where:
			Place.INSIDE:
				glyph.position = Vector2(10.0, roundf((control.size.y - glyph.size.y) * 0.5))
			Place.CORNER:
				glyph.position = Vector2(-10.0, -12.0)
			_:
				glyph.position = Vector2(roundf((control.size.x - glyph.size.x) * 0.5), -12.0)
	glyph.resized.connect(place)
	control.resized.connect(place)
	place.call()
	if where == Place.INSIDE and control is Button:
		# The button's words move right of the cap while it shows (never on touch: the phone's
		# layout stays as it was).
		var make_room := func() -> void:
			for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				control.remove_theme_stylebox_override(state)
				if glyph.visible:
					var style := control.get_theme_stylebox(state).duplicate() as StyleBox
					style.content_margin_left = maxf(style.content_margin_left, 0.0) + glyph.size.x + 12.0
					control.add_theme_stylebox_override(state, style)
		glyph.visibility_changed.connect(make_room)
		glyph.resized.connect(make_room)
		make_room.call()
	return glyph


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	InputDevice.changed.connect(_refresh)
	_refresh()


## The cap shown (empty: none, hidden).
func cap() -> Dictionary:
	return _cap


func _refresh() -> void:
	if not is_inside_tree():
		return
	_cap = fixed if not fixed.is_empty() else ({} if action == &"" else Prompts.glyph(action))
	visible = not _cap.is_empty() and (on_touch or not fixed.is_empty() or InputDevice.uses_buttons())
	custom_minimum_size = cap_size(_cap)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if not _cap.is_empty():
		draw_cap(self, Vector2.ZERO, _cap)


## How big `cap` draws (UI units).
static func cap_size(cap: Dictionary) -> Vector2:
	if cap.is_empty():
		return Vector2.ZERO
	if cap.shape == Prompts.Shape.MOUSE:
		return Vector2(20, HEIGHT)
	var words := Fonts.width(cap.text, Fonts.BODY)
	var round_shape: bool = cap.shape == Prompts.Shape.ROUND or cap.shape == Prompts.Shape.STICK
	var width := maxf(HEIGHT, _snap(words + (12.0 if round_shape else 14.0)))
	return Vector2(width, HEIGHT)


## Draws `cap` on `item` with its top left at `at` (in the item's _draw()).
static func draw_cap(item: CanvasItem, at: Vector2, cap: Dictionary) -> void:
	at = at.round()
	var area := Rect2(at, cap_size(cap))
	var rim: Color = cap.color
	var radius := int(area.size.y / PIXEL / 2.0)  # a disc's, in pixels
	match cap.shape:
		Prompts.Shape.MOUSE:
			_draw_mouse(item, area, int(cap.button))
			return
		Prompts.Shape.KEY:
			# A key: its face over a darker lower edge, corners cut by a pixel.
			var body := Rect2(area.position, area.size - Vector2(0, PIXEL * 2))
			_fill(item, Rect2(body.position + Vector2(0, PIXEL * 2), body.size), 1, Fonts.OUTLINE)
			_fill(item, Rect2(body.position + Vector2(0, PIXEL), body.size), 1, KEY_EDGE)
			_fill(item, body, 1, rim)
			_fill(item, body.grow(-PIXEL), 1, FACE)
		Prompts.Shape.SHOULDER:
			# A shoulder or trigger: its top corners rounded off.
			_fill(item, area, 4, Fonts.OUTLINE, true)
			_fill(item, area.grow(-PIXEL), 3, rim, true)
			_fill(item, area.grow(-PIXEL * 2), 2, FACE, true)
		_:
			# A round button or a stick: a pixel disc, its rim in its color.
			_fill(item, area, radius, Fonts.OUTLINE)
			_fill(item, area.grow(-PIXEL), radius - 1, rim)
			_fill(item, area.grow(-PIXEL * 2), radius - 2, FACE)
			if cap.shape == Prompts.Shape.STICK:
				_fill(item, area.grow(-PIXEL * 4), radius - 4, Color(rim, 0.3))
				_fill(item, area.grow(-PIXEL * 5), radius - 5, FACE)
	var color := rim if cap.shape == Prompts.Shape.ROUND and rim != RIM else WORDS
	var lift := PIXEL if cap.shape == Prompts.Shape.KEY else 0.0  # (over the key's lower edge)
	var baseline := area.position.y + HEIGHT * 0.5 + Fonts.half_cap(Fonts.BODY) - lift
	Fonts.draw(item, Vector2(area.get_center().x, baseline), cap.text, Fonts.BODY, color, 0.5, Color.TRANSPARENT)


## A little mouse, `button` (1 left, 2 right, 3 middle) lit in gold.
static func _draw_mouse(item: CanvasItem, area: Rect2, button: int) -> void:
	_fill(item, area, 4, Fonts.OUTLINE)
	_fill(item, area.grow(-PIXEL), 3, RIM)
	_fill(item, area.grow(-PIXEL * 2), 2, FACE)
	var middle := area.position.x + area.size.x * 0.5
	var top := area.position.y + PIXEL * 2
	var lit := Rect2()
	match button:
		MOUSE_BUTTON_LEFT:
			lit = Rect2(area.position.x + PIXEL * 2, top, middle - PIXEL - area.position.x - PIXEL * 2, PIXEL * 5)
		MOUSE_BUTTON_RIGHT:
			lit = Rect2(middle + PIXEL, top, area.end.x - PIXEL * 2 - middle - PIXEL, PIXEL * 5)
		MOUSE_BUTTON_MIDDLE:
			lit = Rect2(middle - PIXEL, top + PIXEL, PIXEL * 2, PIXEL * 3)
	if lit.has_area():
		_fill(item, lit, 1 if button != MOUSE_BUTTON_MIDDLE else 0, MOUSE_LIT, true)
	# The line between the buttons, and under them.
	item.draw_rect(Rect2(middle - PIXEL * 0.5, area.position.y + PIXEL, PIXEL, PIXEL * 6), RIM)
	item.draw_rect(Rect2(area.position.x + PIXEL * 2, top + PIXEL * 5, area.size.x - PIXEL * 4, PIXEL), RIM)


## A rectangle with rounded corners cut in whole pixels of the art's grid: `radius` pixels (0:
## square, 1: a pixel off each corner, half the height: a disc or a pill); only its top corners
## if `top_only`.
static func _fill(item: CanvasItem, rect: Rect2, radius: int, color: Color, top_only := false) -> void:
	rect = Rect2(rect.position.round(), rect.size.round())
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	radius = maxi(radius, 0)
	var rows := int(rect.size.y / PIXEL)
	for row in rows:
		var from_edge := row if top_only else mini(row, rows - 1 - row)
		var inset := 0
		if from_edge < radius:
			var y := radius - from_edge - 0.5
			inset = roundi(radius - sqrt(radius * radius - y * y))
			if from_edge == 0:
				inset = maxi(inset, 1)
		var top := rect.position.y + row * PIXEL
		var height := PIXEL if row < rows - 1 else rect.end.y - top
		var width := rect.size.x - inset * PIXEL * 2
		if width > 0.0:
			item.draw_rect(Rect2(rect.position.x + inset * PIXEL, top, width, height), color)


static func _snap(value: float) -> float:
	return ceilf(value / PIXEL) * PIXEL
