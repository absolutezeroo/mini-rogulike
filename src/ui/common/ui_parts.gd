class_name UiParts
## Small pieces shared by the in-run panels (shop, encounters, pause, end of run, perk choice),
## on top of UiSkin: buttons, a touch-friendly scroll, emptying a container, good / bad colors.

## A gain, a loss (comparisons, encounter outcomes).
const GOOD := Color(0.45, 1.0, 0.4)
const BAD := Color(1.0, 0.4, 0.32)


## A plain button (the game's default look); keys and gamepads reach it (MenuNav).
static func button(words: String, action: Callable, min_size := Vector2(0, 52), font_size := Fonts.BODY) -> Button:
	var result := Button.new()
	result.text = words
	result.custom_minimum_size = min_size
	result.add_theme_font_size_override("font_size", font_size)
	if action.is_valid():
		result.pressed.connect(action)
	return result


## A list that scrolls one way, with drag-to-scroll for phones (TouchScroll).
static func scroll(vertical := true) -> ScrollContainer:
	var result := ScrollContainer.new()
	if vertical:
		result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		result.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(result)
	return result


## Frees everything in `container` (out of the tree at once, so counts are right).
static func clear(container: Node) -> void:
	for child in container.get_children():
		if child is TouchScroll:
			continue
		container.remove_child(child)
		child.queue_free()


## A label in the skin that wraps, at a fixed width (so it knows its height in a centred box).
static func text(words: String, font_size: int, color: Color, width: float) -> Label:
	var label := UiSkin.label(words, font_size, color, true)
	label.custom_minimum_size.x = width
	return label
