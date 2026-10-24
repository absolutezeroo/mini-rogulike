class_name ItemSlot
extends Button
## A square item slot (bag, equipment, belt, rune sockets): a wooden slot, the item's icon,
## a frame in its rarity (or its rune family's) color, how many there are, the rune sockets of
## a weapon. Empty, it shows what goes there, faint: a pictogram (`placeholder`, not an item of
## the game) or else a word (`caption`). Tap it like a button.

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
## Drawn faint in the middle of an empty slot (assets/ui/placeholders/: a sword, a helmet...);
## the caption then only names it (tooltip).
var placeholder: Texture2D:
	set(value):
		placeholder = value
		tooltip_text = caption if value else ""
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
## New in the bag since the player last looked (a small gold gem in the top right corner).
var fresh := false:
	set(value):
		fresh = value
		queue_redraw()

var _time := 0.0


func _init(side: float = 60.0) -> void:
	custom_minimum_size = Vector2(side, side)
	toggle_mode = false
	clip_contents = false
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)


func _process(delta: float) -> void:
	if selected:
		_time += delta
		queue_redraw()
	elif _has_sheen():
		# The sheen moves at 20 frames a second: redrawn only when it steps.
		var before := floori(_time * 20.0)
		_time += delta
		if floori(_time * 20.0) != before:
			queue_redraw()


## Epic gear (RarityLookDef.sheen) has a band of light sweeping over its icon now and then.
func _has_sheen() -> bool:
	if item == null or item.icon == null or disabled:
		return false
	var look := ItemLook.rarity_look(item)
	return look != null and look.sheen and ItemRarity.of(item) > ItemRarity.COMMON


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_style_box(slot_box(), area)
	if is_hovered() and not disabled:
		draw_rect(area.grow(-9), Color(1, 0.9, 0.6, 0.08))
	if item:
		var frame_color := _frame_color()
		if frame_color.a > 0.0:
			draw_rect(area.grow(-9), Color(frame_color, 0.16))  # a glow of its rarity inside
		var inner := area.grow(-9)
		if item.icon:
			var icon_rect := fit(item.icon, inner)
			draw_texture_rect(item.icon, icon_rect, false, item.icon_tint if not disabled else Color(item.icon_tint, 0.4))
			if _has_sheen():
				_draw_sheen(icon_rect)
		if frame_color.a > 0.0:
			draw_style_box(frame_box(frame_color), area.grow(-3))
		_draw_sockets(area)
		_draw_level()
		if count > 1:
			_text("x%d" % count, Vector2(size.x - 6, size.y - 6), HORIZONTAL_ALIGNMENT_RIGHT, Fonts.BODY, Color.WHITE)
	elif placeholder:
		draw_texture_rect(placeholder, centered_icon(placeholder, area.grow(-9), 0.6), false, Color(EMPTY_TEXT, 0.3))
	elif not caption.is_empty():
		_text(caption, Vector2(size.x * 0.5, size.y * 0.5 + Fonts.half_cap(Fonts.SMALL)), HORIZONTAL_ALIGNMENT_CENTER, Fonts.SMALL, EMPTY_TEXT)
	if fresh and item:
		draw_fresh(self, Vector2(size.x - 5, 5))
	if selected:
		var pulse := 0.75 + 0.25 * sin(_time * 5.0)
		draw_style_box(frame_box(Color(1.0, 0.85, 0.35, pulse)), area.grow(2))


## The "new" mark: a small gold gem, its top right corner at `corner` (on the 2-unit grid of the
## UI's pixels, dark rim, a light facet). Bag slots and the bag's tabs.
static func draw_fresh(canvas: CanvasItem, corner: Vector2) -> void:
	var pixel := 2.0
	var at := (corner / pixel).round() * pixel - Vector2(pixel * 5, 0)
	# A diamond 5 pixels wide: rows 1, 3, 5, 3, 1 (dark around it).
	var rows := [1, 3, 5, 3, 1]
	for row in rows.size():
		var width: int = rows[row]
		var x := at.x + (5 - width) * 0.5 * pixel
		var y := at.y + row * pixel
		canvas.draw_rect(Rect2(x - pixel, y, (width + 2) * pixel, pixel), Fonts.OUTLINE)
	canvas.draw_rect(Rect2(at.x + pixel * 2, at.y - pixel, pixel, pixel), Fonts.OUTLINE)
	canvas.draw_rect(Rect2(at.x + pixel * 2, at.y + pixel * 5, pixel, pixel), Fonts.OUTLINE)
	for row in rows.size():
		var width: int = rows[row]
		var x := at.x + (5 - width) * 0.5 * pixel
		canvas.draw_rect(Rect2(x, at.y + row * pixel, width * pixel, pixel), UiSkin.GOLD)
	canvas.draw_rect(Rect2(at.x + pixel, at.y + pixel * 2, pixel, pixel), Color(1.0, 0.97, 0.8))
	canvas.draw_rect(Rect2(at.x + pixel * 2, at.y + pixel, pixel, pixel), Color(1.0, 0.97, 0.8))


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
	_text(tr("Lv %d") % equipment.item_level, Vector2(7, 17), HORIZONTAL_ALIGNMENT_LEFT, Fonts.SMALL, Color(1, 0.92, 0.7))


## A band of light, two icon pixels wide, crossing the icon on the diagonal over its own pixels
## (in the rarity's core and next step), then a pause: Epic things look alive in the bag.
func _draw_sheen(icon_rect: Rect2) -> void:
	var look := ItemLook.rarity_look(item)
	var frame := floori(_time * 20.0) % 64
	var front := frame - 4
	if front > 36:
		return
	var texel := icon_rect.size / item.icon.get_size()
	for p in WeaponAura.pixels_of(item.icon):
		var d := int(p.x) + int(p.y)
		if d == front or d == front - 1:
			draw_rect(Rect2(icon_rect.position + p * texel, texel), look.element.shade(0.0 if d == front else 0.25))


## A weapon's rune sockets: little gems along the bottom, cut in their rune's element (its
## color, a lit facet and a dark one: the element the weapon carries, ItemLook), dark when empty.
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
		var element := ItemLook.rune_element(rune) if rune else null
		if element == null:
			draw_rect(rect, rune.rarity_color() if rune else Color(0.3, 0.24, 0.2))
			continue
		var third := dot / 3.0
		draw_rect(rect, element.color())
		draw_rect(Rect2(rect.position, Vector2(third, third)), element.core())
		draw_rect(Rect2(rect.end - Vector2(third, third), Vector2(third, third)), element.edge())


func _text(words: String, at: Vector2, align: HorizontalAlignment, font_size: int, color: Color) -> void:
	Fonts.draw(self, at, words, font_size, color, 1.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))


## `texture`'s rect in `box`: centred, at the biggest whole scale that fits (pixels stay square).
static func fit(texture: Texture2D, box: Rect2) -> Rect2:
	var source := texture.get_size()
	var factor := floorf(minf(box.size.x / source.x, box.size.y / source.y))
	if factor < 1.0:
		factor = minf(box.size.x / source.x, box.size.y / source.y)
	var drawn := source * factor
	return Rect2((box.position + (box.size - drawn) * 0.5).round(), drawn)


static var _slot: StyleBoxTexture
static var _frames := {}


## The wooden slot's style (the HUD's action bar draws its slots with it).
static func slot_box() -> StyleBoxTexture:
	if _slot == null:
		_slot = StyleBoxTexture.new()
		_slot.texture = UiSkin.SLOT
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_slot.set_texture_margin(side, 15)
	return _slot


## The rarity frame's style, in `color` (the bag's tabs frame the one shown with it).
static func frame_box(color: Color) -> StyleBoxTexture:
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


## `picture` drawn whole pixels big, centred in `box`, its larger side `share` of the box's smaller
## side (so pictograms of any size sit in the middle at one size).
static func centered_icon(picture: Texture2D, box: Rect2, share: float) -> Rect2:
	var art := picture.get_size()
	var factor := maxf(1.0, floorf(minf(box.size.x, box.size.y) * share / maxf(art.x, art.y)))
	var drawn := art * factor
	return Rect2((box.position + (box.size - drawn) * 0.5).round(), drawn)
