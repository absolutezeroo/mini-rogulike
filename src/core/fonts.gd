class_name Fonts
## The game's font, its sizes, and drawing text by hand (damage numbers, labels in the world,
## buttons drawn in code) with whole font pixels.
##
## Pixel Operator 8 (Jayvee Enaguas, CC0) is pixel art on an 8-pixel em: each of its pixels is 1/8
## of the font size, capitals 7 pixels high, a descender 1 pixel. Drawn without smoothing, a letter
## stays whole only when one font pixel covers a whole number of screen pixels; otherwise rows and
## columns of it double or vanish ("cut" letters). The UI is laid out for 720 lines and stretched
## x1 (720 lines), x1.5 (1080, most phones), x2 (1440) (PixelGrid): the sizes that are whole at all
## of them are the multiples of 16 (2, 4, 6 UI pixels a font pixel). SMALL alone is off that grid
## (nothing smaller than 16 is whole on a phone). Only the Regular: the pack's Bold is a pixel wider
## a letter and closes its accented capitals at HUGE. See docs/design/interface.md, Text.

## The font as the game uses it (assets/fonts/pixel_operator.tres): Pixel Operator 8 with room
## over and under its lines. Its em holds the capitals with no room above them (ascent 7 = a
## capital), so labels stacked without it touch; 4 UI pixels over a line and 2 under it give back
## the air the old font had (a whole font pixel at BODY each, the baseline unmoved).
const MAIN: Font = preload("res://assets/fonts/pixel_operator.tres")

## Font pixels in an em (the font's grid).
const GRID := 8
## Font pixels a capital stands (an accented one too: its accent is drawn inside them).
const CAPS := 7
## Little counters inside a slot or a button (a level, a stack, a badge) and fine print where BODY
## doesn't fit: 1.5 UI pixels a font pixel. No size under 16 is whole on a phone; this one is the
## least uneven there (2.25 screen pixels: one row or column in four a pixel thicker, where 8
## would make every other one double) and whole at x2, a little uneven on a 720-line screen.
const SMALL := 12
## Everything read: sentences, notes, buttons, names, headings in a panel.
const BODY := 16
## Titles, big numbers.
const TITLE := 32
## The game's name, act and curse cards.
const HUGE := 48
## Every size the game uses (a check in the unit tests holds every scene and theme to it).
const SIZES: Array[int] = [SMALL, BODY, TITLE, HUGE]
## The sizes on the grid (whole font pixels at x1, x1.5 and x2): all but SMALL.
const WHOLE_SIZES: Array[int] = [BODY, TITLE, HUGE]

## The dark edge around text on wood and over the game.
const OUTLINE := Color(0.12, 0.07, 0.05)


## The outline_size that draws a one-font-pixel edge at `font_size` (Godot's outline grows a
## quarter of a pixel per unit): thick enough to read on anything, never fattening a letter
## unevenly.
static func outline_size(font_size: int) -> int:
	return roundi(font_size * 4.0 / GRID)


## How tall a capital stands at `font_size` (UI units).
static func cap_height(font_size: int) -> float:
	return font_size * float(CAPS) / GRID


## How far under a line's middle its baseline goes for its capitals to sit centred on it (half a
## capital): text drawn by hand in a disc, a slot, a bar.
static func half_cap(font_size: int) -> float:
	return cap_height(font_size) * 0.5


## Draws `text` on `item` (in its _draw()), its baseline at `at` (the item's own coordinates),
## `align` 0 = starting at `at`, 0.5 = centred on it, 1 = ending there. `font_size` is in the UI's
## units whatever the item's scale (a zoomed camera), and the text lands on a whole screen pixel,
## so its letters keep whole font pixels anywhere. A one-font-pixel `outline` (none if
## transparent). Resets the item's draw transform.
static func draw(item: CanvasItem, at: Vector2, text: String, font_size: int, color: Color, align := 0.0, outline := OUTLINE) -> void:
	var to_canvas := item.get_global_transform_with_canvas()
	var stretch := item.get_viewport().get_final_transform()
	var to_screen := stretch * to_canvas
	var text_width := MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spot := to_screen * at
	spot.x -= text_width * align * stretch.get_scale().x
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
