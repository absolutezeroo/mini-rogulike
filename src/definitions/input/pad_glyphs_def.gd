class_name PadGlyphsDef
extends Resource
## How one family of gamepads names its buttons (Xbox, PlayStation, Nintendo, any other): the
## words on its prompts' caps and the colors of its face buttons. InputDevice picks the family
## from the pad's name (`name_hints`); Prompts and PromptGlyph draw with it.

@export var id: StringName
## The family's name (the Controls page's heading: "Xbox").
@export var brand := ""
## Lowercase pieces of a pad's name (Input.get_joy_name()) that say it is of this family.
@export var name_hints := PackedStringArray()
## What each button is called, by JoyButton index (0: the bottom face button, 1: right, 2: left,
## 3: top, 4: back, 5: guide, 6: start, 7-8: the sticks' clicks, 9-10: the shoulders, 11-14: the
## D-pad up, down, left, right). The font has ✕ ○ □ △ for PlayStation.
@export var button_glyphs := PackedStringArray()
## What each axis is called, by JoyAxis index (0-1: the left stick, 2-3: the right one, 4-5: the
## triggers).
@export var axis_glyphs := PackedStringArray()
## The rim of the four face buttons (bottom, right, left, top) on their round caps.
@export var face_colors := PackedColorArray()


## The button's word ("A", "✕", "LB"...), or "?" for one the family doesn't name.
func button_glyph(button: int) -> String:
	return button_glyphs[button] if button >= 0 and button < button_glyphs.size() else "?"


func axis_glyph(axis: int) -> String:
	return axis_glyphs[axis] if axis >= 0 and axis < axis_glyphs.size() else "?"


## The rim of a face button (white for the others).
func face_color(button: int) -> Color:
	return face_colors[button] if button >= 0 and button < face_colors.size() else Color(0.9, 0.86, 0.8)
