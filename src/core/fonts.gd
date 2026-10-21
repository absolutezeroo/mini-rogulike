class_name Fonts
## The game's font, its sizes, and drawing text by hand (damage numbers, labels in the world,
## buttons drawn in code) with whole font pixels.
##
## normal_font.ttf is pixel art on a 9-pixel em: each of its pixels is 1/9 of the font size. Drawn
## without smoothing, a letter stays whole only when one font pixel covers a whole number of
## screen pixels; otherwise rows and columns of it double or vanish ("cut" letters). The UI is
## laid out for 720 lines and stretched x1 (720 lines), x1.5 (1080, most phones), x2 (1440): the
## sizes that are whole at all of them are the multiples of 18 (2, 4, 6 UI pixels a font pixel).
## See docs/design/interface.md, Text.

const MAIN: Font = preload("res://assets/fonts/normal_font.ttf")

## Font pixels in an em (the font's grid).
const GRID := 9
## Little counters inside a slot or a button (a level, a stack, a badge) where BODY doesn't fit:
## whole on phones (x1.5: 2 screen pixels a font pixel), a little uneven on a 720-line screen.
const SMALL := 12
## Everything read: sentences, notes, buttons, names, headings in a panel.
const BODY := 18
## Titles, big numbers.
const TITLE := 36
## The game's name, act and curse cards.
const HUGE := 54
## Every size the game uses (a check in the unit tests holds every scene and theme to it).
const SIZES: Array[int] = [SMALL, BODY, TITLE, HUGE]

## The dark edge around text on wood and over the game.
const OUTLINE := Color(0.12, 0.07, 0.05)


## The outline_size that draws a one-font-pixel edge at `font_size` (Godot's outline grows a
## quarter of a pixel per unit): thick enough to read on anything, never fattening a letter
## unevenly.
static func outline_size(font_size: int) -> int:
	return roundi(font_size * 4.0 / GRID)


## Draws `text` on `item` (in its _draw()), its baseline at `at` (the item's own coordinates),
## `align` 0 = starting at `at`, 0.5 = centred on it, 1 = ending there. `font_size` is in the UI's
## units whatever the item's scale (a zoomed camera), and the text lands on a whole screen pixel,
## so its letters keep whole font pixels anywhere. A one-font-pixel `outline` (none if
## transparent). Resets the item's draw transform.
static func draw(item: CanvasItem, at: Vector2, text: String, font_size: int, color: Color, align := 0.0, outline := OUTLINE) -> void:
	var to_canvas := item.get_global_transform_with_canvas()
	var stretch := item.get_viewport().get_final_transform()
	var to_screen := stretch * to_canvas
	var width := MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spot := to_screen * at
	spot.x -= width * align * stretch.get_scale().x
	var origin := to_screen.affine_inverse() * spot.round()
	var zoom := to_canvas.get_scale()
	item.draw_set_transform(origin, 0.0, Vector2(1.0 / zoom.x, 1.0 / zoom.y))
	if outline.a > 0.0:
		item.draw_string_outline(MAIN, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size(font_size), outline)
	item.draw_string(MAIN, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	item.draw_set_transform(Vector2.ZERO)


## How wide `text` is at `font_size`, in the UI's units.
static func width(text: String, font_size: int) -> float:
	return MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## How wide `text` drawn by draw() on `item` is in the item's own units (smaller under a zoomed
## camera).
static func local_width(item: CanvasItem, text: String, font_size: int) -> float:
	return width(text, font_size) / item.get_global_transform_with_canvas().get_scale().x
