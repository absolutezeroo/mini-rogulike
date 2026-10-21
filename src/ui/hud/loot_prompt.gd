class_name LootPrompt
extends PanelContainer
## Standing on an item that auto loot leaves on the ground (Settings.auto_loot), or that the bag
## has no room for: a small board low on the screen, above the buttons, shows it (its slot, name
## in its rarity, how it compares with what is worn) with a Take button. With no room, the button
## opens the bag instead (dismantle or drop something, then take it). Gone when the hero walks off.
## Also says, in a toast, when the bag is full (Events.bag_full), at most every few seconds.
## Built by the HUD; listens to Events.

const WIDTH := 600.0
## Seconds between two "bag full" toasts (walking over loot again and again).
const FULL_TOAST_GAP := 4.0
const REFRESH := 0.25

## Toasts, and the bag button's signal.
var hud: Hud
var player: Player

## Pickups the hero stands on, the last one shown.
var _offers: Array[ItemPickup] = []
var _shown: ItemPickup
var _slot: ItemSlot
var _name: Label
var _type: Label
var _compare: RichTextLabel
var _take: Button
var _last_full_toast := -100.0
var _refresh_in := 0.0


func _ready() -> void:
	name = "LootPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the joystick's thumb may slide under it
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	# Above the belt and skill buttons (even at the biggest controls size), under the hero.
	offset_bottom = -140.0
	offset_top = -246.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_stylebox_override("panel", _panel())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_slot = ItemSlot.new(68.0)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slot)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	_name = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_name)
	_type = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_type.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_type)
	_compare = RichTextLabel.new()
	_compare.name = "LootCompare"
	_compare.bbcode_enabled = true
	_compare.fit_content = true
	_compare.scroll_active = false
	_compare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compare.add_theme_font_size_override("normal_font_size", Fonts.BODY)
	_compare.add_theme_constant_override("outline_size", Fonts.outline_size(Fonts.BODY))
	_compare.add_theme_color_override("font_outline_color", Fonts.OUTLINE)
	_compare.add_theme_color_override("default_color", UiSkin.TEXT)
	words.add_child(_compare)
	_take = UiParts.button(tr("Take"), _on_take, Vector2(130, 60))
	_take.name = "TakeButton"
	_take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_take)
	hide()
	Events.loot_offered.connect(_on_offered)
	Events.loot_left.connect(_on_left)
	Events.bag_full.connect(_on_bag_full)
	Events.depth_changed.connect(func(_depth: int) -> void:
		_offers.clear()
		_show_last())


## The item shown (tests), null when hidden.
func shown_item() -> ItemDef:
	return _shown.item if visible and is_instance_valid(_shown) else null


## The Take button (or "Open the bag" when there is no room), as if tapped (tests).
func press_take() -> void:
	_on_take()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_show_last()  # the bag may have room now, gear may have changed


func _on_offered(pickup: ItemPickup) -> void:
	_offers.erase(pickup)
	_offers.append(pickup)
	_show_last()


func _on_left(pickup: ItemPickup) -> void:
	_offers.erase(pickup)
	_show_last()


func _on_bag_full(item: ItemDef) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if hud == null or now - _last_full_toast < FULL_TOAST_GAP:
		return
	_last_full_toast = now
	hud.toast(tr("Your bag is full: %s stays on the ground. Dismantle or drop something in the bag.") % tr(item.display_name) if item \
		else tr("Your bag is full. Dismantle or drop something in the bag."))


func _on_take() -> void:
	if not is_instance_valid(_shown) or player == null:
		return
	if not player.can_store(_shown.item) and not _fits_by_equipping(_shown.item):
		if hud:
			hud.inventory_requested.emit()
		return
	Sfx.play_ui(Sfx.bank.ui_click)
	_shown.take(player)


## Gear for an empty slot is put on at once, needing no room in the bag.
func _fits_by_equipping(item: ItemDef) -> bool:
	return item is EquipmentDef and player.equipment.get_item((item as EquipmentDef).slot) == null


func _show_last() -> void:
	_refresh_in = REFRESH
	while not _offers.is_empty() and (not is_instance_valid(_offers[-1]) or _offers[-1].is_taken()):
		_offers.pop_back()
	_shown = _offers[-1] if not _offers.is_empty() else null
	visible = _shown != null and player != null and not player.is_dead
	if not visible:
		return
	var item := _shown.item
	_slot.item = item
	_name.text = tr(item.display_name)
	_name.add_theme_color_override("font_color", item.rarity_color())
	_type.text = item.get_type_label()
	var room := player.can_store(item) or _fits_by_equipping(item)
	_take.text = tr("Take") if room else tr("Open the bag")
	_compare.text = _compare_line(item) if room else "[color=#%s]%s[/color]" % [UiParts.BAD.to_html(false), tr("Your bag is full.")]


## "+3 damage, -1 armor": the first changes against what is worn, green or red.
func _compare_line(item: ItemDef) -> String:
	var gear := item as EquipmentDef
	if gear == null:
		return ""
	var worn := player.equipment.get_item(gear.slot)
	if worn == null:
		return "[color=#%s]%s[/color]" % [UiParts.GOOD.to_html(false), tr("Nothing worn there yet.")]
	var parts := PackedStringArray()
	for change in ItemCompare.lines(gear, worn).slice(0, 3):
		parts.append("[color=#%s]%s[/color]" % [(UiParts.GOOD if change.good else UiParts.BAD).to_html(false), change.text])
	return ", ".join(parts) if not parts.is_empty() else tr("The same as what you wear.")


static func _panel() -> StyleBoxTexture:
	var box := UiSkin.panel()
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
