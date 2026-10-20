class_name SoulNodeButton
extends Button
## A node of the Tree of Souls on the shrine's screen: a wooden slot with its icon, its level in
## pips, and how it stands at a glance (gold ring: bought; bright and pulsing: you can buy it
## now; dark: not open yet; red cross: the other side of its fork was taken).

const SIDE := 60.0

var node: SoulNodeDef
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _time := 0.0


func _init(def: SoulNodeDef) -> void:
	node = def
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	tooltip_text = def.display_name()
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)


func _process(delta: float) -> void:
	_time += delta
	if Profile.can_buy_node(node) or selected:
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var slot := StyleBoxTexture.new()
	slot.texture = UiSkin.SLOT
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		slot.set_texture_margin(side, 15)
	draw_style_box(slot, area)
	var owned := node.is_owned()
	var shut := node.is_shut()
	var open := node.is_open()
	var color := node.upgrade.color if node.upgrade else Color.WHITE
	if node.oath:
		color = node.oath.color
	var tint := Color.WHITE if owned or open else Color(0.45, 0.42, 0.4)
	var icon: Texture2D = node.oath.icon if node.oath and node.oath.icon else (node.upgrade.icon if node.upgrade else null)
	if icon:
		var inner := area.grow(-12)
		var scale := floorf(minf(inner.size.x / icon.get_width(), inner.size.y / icon.get_height()))
		if scale < 1.0:
			scale = minf(inner.size.x / icon.get_width(), inner.size.y / icon.get_height())
		var drawn := icon.get_size() * scale
		draw_texture_rect(icon, Rect2((inner.position + (inner.size - drawn) * 0.5).round(), drawn), false, tint)
	if owned:
		draw_rect(area.grow(-3), Color(UiSkin.GOLD, 0.95), false, 3.0)
	elif Profile.can_buy_node(node):
		var pulse := 0.55 + 0.45 * sin(_time * 4.0)
		draw_rect(area.grow(-3), Color(color.lerp(Color.WHITE, 0.4), pulse), false, 3.0)
	elif open:
		draw_rect(area.grow(-3), Color(1, 1, 1, 0.35), false, 2.0)
	if node.oath:
		# An oath: a crown of little points over it.
		for i in 3:
			var x := size.x * (0.3 + 0.2 * i)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 4), Vector2(x, -4), Vector2(x + 5, 4)]), color if owned else Color(color, 0.5))
	if shut:
		var red := Color(0.9, 0.25, 0.2, 0.9)
		draw_line(Vector2(14, 14), size - Vector2(14, 14), red, 4.0, true)
		draw_line(Vector2(size.x - 14, 14), Vector2(14, size.y - 14), red, 4.0, true)
	if node.feat and not node.is_feat_done() and not owned:
		_text("?", Vector2(size.x - 9, 17), 15, Color(0.85, 0.6, 1.0))
	# Level pips along the bottom.
	var levels := node.max_level()
	if levels > 1:
		var dot := 6.0
		var width := levels * dot + (levels - 1) * 3.0
		var x := (size.x - width) * 0.5
		for i in levels:
			var rect := Rect2(x + i * (dot + 3.0), size.y - 13.0, dot, dot)
			draw_rect(rect.grow(1.5), Color(0.12, 0.07, 0.05))
			draw_rect(rect, UiSkin.GOLD if i < node.level() else Color(0.3, 0.24, 0.2))
	if selected:
		var pulse := 0.75 + 0.25 * sin(_time * 5.0)
		draw_rect(area.grow(3), Color(1.0, 0.85, 0.35, pulse), false, 3.0)


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, Vector2(at.x - width * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.12, 0.07, 0.05))
	draw_string(font, Vector2(at.x - width * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
