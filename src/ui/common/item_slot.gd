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
	draw_style_box(_slot_box(), area)
	if is_hovered() and not disabled:
		draw_rect(area.grow(-9), Color(1, 0.9, 0.6, 0.08))
	if item:
		var frame_color := _frame_color()
		if frame_color.a > 0.0:
			draw_rect(area.grow(-9), Color(frame_color, 0.16))  # a glow of its rarity inside
		var inner := area.grow(-9)
		if item.icon:
			var icon_rect := _fit(item.icon, inner)
			draw_texture_rect(item.icon, icon_rect, false, item.icon_tint if not disabled else Color(item.icon_tint, 0.4))
			if _has_sheen():
				_draw_sheen(icon_rect)
		if frame_color.a > 0.0:
			draw_style_box(_frame_box(frame_color), area.grow(-3))
		_draw_sockets(area)
		_draw_level()
		if count > 1:
			_text("x%d" % count, Vector2(size.x - 6, size.y - 6), HORIZONTAL_ALIGNMENT_RIGHT, Fonts.BODY, Color.WHITE)
	elif not caption.is_empty():
		_text(caption, Vector2(size.x * 0.5, size.y * 0.5 + 4), HORIZONTAL_ALIGNMENT_CENTER, Fonts.SMALL, EMPTY_TEXT)
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


func _text(text: String, at: Vector2, align: HorizontalAlignment, font_size: int, color: Color) -> void:
	Fonts.draw(self, at, text, font_size, color, 1.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))


## The biggest whole-pixel scale of `texture` that fits in `box`, centred.
## `texture`'s rect in `box`: centred, at the biggest whole scale that fits (pixels stay square).
static func fit(texture: Texture2D, box: Rect2) -> Rect2:
	return _fit(texture, box)


static func _fit(texture: Texture2D, box: Rect2) -> Rect2:
	var source := texture.get_size()
	var scale := floorf(minf(box.size.x / source.x, box.size.y / source.y))
	if scale < 1.0:
		scale = minf(box.size.x / source.x, box.size.y / source.y)
	var drawn := source * scale
	return Rect2((box.position + (box.size - drawn) * 0.5).round(), drawn)


static var _slot: StyleBoxTexture
static var _frames := {}


## The wooden slot's style (the HUD's action bar draws its slots with it).
static func slot_box() -> StyleBoxTexture:
	return _slot_box()


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
