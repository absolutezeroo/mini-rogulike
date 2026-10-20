class_name ItemSlot
extends Button
## A square item slot (bag, equipment, belt, rune sockets): a wooden slot, the item's icon,
## a frame in its rarity (or its rune family's) color, how many there are, the rune sockets of
## a weapon. Empty, it shows what goes there (`caption`, faint). Tap it like a button.

const EMPTY_TEXT := Color(1, 0.92, 0.8, 0.45)

var item: ItemDef:
	set(value):
		item = value
		queue_redraw()
var count := 1:
	set(value):
		count = value
		queue_redraw()
## Shown faint in an empty slot ("Head", "Rune"...).
var caption := "":
	set(value):
		caption = value
		queue_redraw()
## Equipment shows its item level in the corner ("Lv 7"); off where it means nothing (a pick of
## plain weapons).
var show_level := true:
	set(value):
		show_level = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _time := 0.0


func _init(side: float = 60.0) -> void:
	custom_minimum_size = Vector2(side, side)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	clip_contents = false
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)


func _process(delta: float) -> void:
	if selected:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_style_box(_slot_box(), area)
	if is_hovered() and not disabled:
		draw_rect(area.grow(-9), Color(1, 0.9, 0.6, 0.08))
	if item:
		var frame_color := _frame_color()
		if frame_color.a > 0.0:
			draw_rect(area.grow(-9), Color(frame_color, 0.16))  # a glow of its rarity inside
		var inner := area.grow(-9)
		if item.icon:
			draw_texture_rect(item.icon, _fit(item.icon, inner), false, item.icon_tint if not disabled else Color(item.icon_tint, 0.4))
		if frame_color.a > 0.0:
			draw_style_box(_frame_box(frame_color), area.grow(-3))
		_draw_sockets(area)
		_draw_level()
		if count > 1:
			_text("x%d" % count, Vector2(size.x - 6, size.y - 6), HORIZONTAL_ALIGNMENT_RIGHT, 15, Color.WHITE)
	elif not caption.is_empty():
		_text(caption, Vector2(size.x * 0.5, size.y * 0.5 + 6), HORIZONTAL_ALIGNMENT_CENTER, 14, EMPTY_TEXT)
	if selected:
		var pulse := 0.75 + 0.25 * sin(_time * 5.0)
		draw_style_box(_frame_box(Color(1.0, 0.85, 0.35, pulse)), area.grow(2))


## Its rarity's color (Magic and better), a rune's family color; clear for plain things.
func _frame_color() -> Color:
	if item is RuneDef:
		return item.rarity_color()
	var equipment := item as EquipmentDef
	if equipment and equipment.rarity > ItemRarity.COMMON:
		return ItemRarity.COLORS[equipment.rarity]
	return Color(0, 0, 0, 0)


## Equipment's item level in the top-left corner ("Lv 7"): deeper finds are stronger.
func _draw_level() -> void:
	var equipment := item as EquipmentDef
	if equipment == null or size.x < 44.0 or not show_level:
		return
	_text("Lv %d" % equipment.item_level, Vector2(7, 19), HORIZONTAL_ALIGNMENT_LEFT, 13, Color(1, 0.92, 0.7))


## A weapon's rune sockets: little stones along the bottom, lit in their rune's color.
func _draw_sockets(area: Rect2) -> void:
	var equipment := item as EquipmentDef
	if equipment == null or equipment.socket_count() <= 0:
		return
	var dot := 6.0
	var x := area.position.x + 7.0
	var y := area.end.y - 7.0 - dot
	for i in equipment.socket_count():
		var rect := Rect2(x + i * (dot + 3.0), y, dot, dot)
		draw_rect(rect.grow(1.5), Color(0.12, 0.07, 0.05))
		var rune := equipment.runes[i] if i < equipment.runes.size() else null
		draw_rect(rect, rune.rarity_color() if rune else Color(0.3, 0.24, 0.2))


func _text(text: String, at: Vector2, align: HorizontalAlignment, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x - (width if align == HORIZONTAL_ALIGNMENT_RIGHT else (width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.12, 0.07, 0.05))
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## The biggest whole-pixel scale of `texture` that fits in `box`, centred.
static func _fit(texture: Texture2D, box: Rect2) -> Rect2:
	var source := texture.get_size()
	var scale := floorf(minf(box.size.x / source.x, box.size.y / source.y))
	if scale < 1.0:
		scale = minf(box.size.x / source.x, box.size.y / source.y)
	var drawn := source * scale
	return Rect2((box.position + (box.size - drawn) * 0.5).round(), drawn)


static var _slot: StyleBoxTexture
static var _frames := {}


static func _slot_box() -> StyleBoxTexture:
	if _slot == null:
		_slot = StyleBoxTexture.new()
		_slot.texture = UiSkin.SLOT
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_slot.set_texture_margin(side, 15)
	return _slot


static func _frame_box(color: Color) -> StyleBoxTexture:
	var key := color.to_html()
	if not _frames.has(key):
		var box := StyleBoxTexture.new()
		box.texture = UiSkin.FRAME
		box.modulate_color = color
		box.draw_center = false
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, 9)
		_frames[key] = box
	return _frames[key]
