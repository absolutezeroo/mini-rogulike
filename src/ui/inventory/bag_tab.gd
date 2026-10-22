class_name BagTab
extends Button
## A tab of the bag (BagCategoryDef): its icon, how many items it holds in the corner, and a small
## gold gem when something new waits in it. The open tab is pressed (a ButtonGroup) and its name
## is written under the row (InventoryPanel). Tapped or clicked; Q / E and LB / RB switch tabs
## (MenuNav, group "menu_tabs"), so it never takes the focus itself.

const SIZE := Vector2(54, 46)

var category: BagCategoryDef
var count := 0:
	set(value):
		count = value
		queue_redraw()
## Something in it the player hasn't seen yet.
var fresh := false:
	set(value):
		fresh = value
		queue_redraw()


func _init(for_category: BagCategoryDef) -> void:
	category = for_category
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	# Drawn as a wooden slot like the bag's (ItemSlot), not as an orange button.
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	tooltip_text = tr(category.display_name)
	name = "%sTab" % String(category.id).to_pascal_case()
	add_to_group(MenuNav.TABS)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var dim := count == 0 and not button_pressed
	draw_style_box(ItemSlot.slot_box(), area)
	if is_hovered() and not button_pressed:
		draw_rect(area.grow(-9), Color(1, 0.9, 0.6, 0.08))
	if button_pressed:
		draw_rect(area.grow(-9), Color(UiSkin.GOLD, 0.14))
		draw_style_box(ItemSlot.frame_box(UiSkin.GOLD), area.grow(-1))
	if category.icon:
		var box := Rect2(area.position + Vector2(7, 7), Vector2(32, 32))
		var drawn := ItemSlot.fit(category.icon, box)
		draw_texture_rect(category.icon, drawn, false, Color(1, 1, 1, 0.35 if dim else 1.0))
	var color := UiSkin.GOLD if button_pressed else (UiSkin.DIM if dim else UiSkin.TEXT)
	Fonts.draw(self, Vector2(size.x - 6, size.y - 8), str(count), Fonts.BODY, color, 1.0)
	if fresh:
		ItemSlot.draw_fresh(self, Vector2(size.x - 6, 6))
