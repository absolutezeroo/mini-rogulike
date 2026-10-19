class_name UiSkin
## The look of the game's big panels (bag, forge...): warm wood, dark insets, item slots with a
## frame in the item's rarity, a red ribbon for titles. Pixel art at the UI's scale (x3), from
## Kenney's "Pixel UI Pack" and "Fantasy UI Borders" (CC0, assets/ui/rpg/).

const DIR := "res://assets/ui/rpg/"
const PANEL: Texture2D = preload("res://assets/ui/rpg/panel.png")
const INSET: Texture2D = preload("res://assets/ui/rpg/inset.png")
const INSET_STONE: Texture2D = preload("res://assets/ui/rpg/inset_stone.png")
const SLOT: Texture2D = preload("res://assets/ui/rpg/slot.png")
const FRAME: Texture2D = preload("res://assets/ui/rpg/frame.png")
const RIBBON: Texture2D = preload("res://assets/ui/rpg/ribbon.png")
const PLAQUE: Texture2D = preload("res://assets/ui/rpg/plaque.png")
const ORNATE: Texture2D = preload("res://assets/ui/rpg/ornate.png")
const SOCKET: Texture2D = preload("res://assets/ui/rpg/socket.png")

## Text on the wood: light, gold titles, dim notes.
const TEXT := Color(1.0, 0.95, 0.85)
const GOLD := Color(1.0, 0.82, 0.4)
const DIM := Color(1.0, 0.92, 0.8, 0.7)
const ORNATE_TINT := Color(1.0, 0.8, 0.45, 0.9)


## The big wood panel (an ornate gold border is drawn over it by OrnatePanel).
static func panel() -> StyleBoxTexture:
	return _box(PANEL, 15, 22)


## A dark recess in the wood (lists, details).
static func inset() -> StyleBoxTexture:
	return _box(INSET, 15, 16)


static func inset_stone() -> StyleBoxTexture:
	return _box(INSET, 15, 16)  # (the stone one tiles badly: the same dark wood)


## The red ribbon under a title.
static func ribbon() -> StyleBoxTexture:
	var box := _box(RIBBON, 0, 0)
	box.texture_margin_left = 39
	box.texture_margin_right = 39
	box.texture_margin_top = 18
	box.texture_margin_bottom = 18
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 4
	box.content_margin_bottom = 10
	return box


## A small plaque (counts, gold).
static func plaque() -> StyleBoxTexture:
	var box := _box(PLAQUE, 0, 0)
	box.texture_margin_left = 15
	box.texture_margin_right = 15
	box.texture_margin_top = 15
	box.texture_margin_bottom = 15
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## A label in the skin's text style, with a dark outline (readable on wood and in any color).
static func label(text: String, font_size: int, color: Color = TEXT, wrap := false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("outline_size", 5)
	result.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.05))
	if wrap:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


## A title on the red ribbon.
static func title(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", ribbon())
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := label(text, 26, Color(1.0, 0.95, 0.85))
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(words)
	return box


## A PanelContainer drawn as a dark inset.
static func section(stone := false) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", inset_stone() if stone else inset())
	return box


static func _box(texture: Texture2D, margin: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content
	box.content_margin_top = content
	box.content_margin_right = content
	box.content_margin_bottom = content
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box
