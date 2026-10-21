class_name InventoryPanel
extends Control
## Bag screen, in the game's skin (RpgWindow, ItemSlot): the hero and what they wear (weapon,
## head, body) with the belt and their stats on the left, the bag as a grid of slots in the
## middle, the picked item's card on the right (rarity, stats, rune sockets, what to do with it).
## Pauses the game while open. Built in code. "Perks" in the header opens the build (BuildWindow):
## the families and the perks taken, in words.
## Identical items stack (Inventory): one slot, "x2", one place of the bag. Gear in the bag can be
## dismantled for gold (two taps), and "Dismantle the worse" breaks down, after a confirmation,
## every piece worse than what is worn (Player.worse_gear()).

signal closed

const NO_SLOT := -1
const BAG_COLUMNS := 4
const BAG_SLOT := 66.0
const GEAR_SLOT := 74.0

## Every family of perks (for the build window).
var content: ContentDB
var _player: Player
var _selected_item: ItemDef
var _selected_slot := NO_SLOT
## Belt slot selected (-1 = none).
var _selected_belt := NO_SLOT

var _window: RpgWindow
var _slot_buttons := {}
var _belt_slots: Array[ItemSlot] = []
var _portrait: TextureRect
var _stats: GridContainer
var _bag_title: Label
var _item_grid: GridContainer
var _card_slot: ItemSlot
var _item_name: Label
var _item_type: Label
var _item_details: Label
var _sockets: HBoxContainer
var _use_button: Button
var _drop_button: Button
var _belt_button: Button
var _dismantle_button: Button
## The card's "Dismantle value: 12 gold" line.
var _dismantle_note: Label
## The item the Dismantle button was tapped once for (a second tap breaks it).
var _dismantle_armed: ItemDef
var _worse_button: Button
## "Dismantle the worse": the list, the gold, Dismantle / Keep them.
var _confirm: RpgDialog
var _confirm_text: Label
var _confirm_items: HFlowContainer
var _confirm_yes: Button
var _gold: Label
var _named: Array[Node] = []
var _build_window: BuildWindow
var _perks_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(player: Player) -> void:
	if _player != player:
		if _player:
			_player.dismantled.disconnect(_on_dismantled)
		player.dismantled.connect(_on_dismantled)
	_player = player
	_confirm.hide()
	_clear_selection()
	_refresh()
	show()
	Sfx.play_ui(Sfx.bank.ui_open)


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	_build_window.hide()
	_confirm.hide()
	hide()
	closed.emit()


## The build: families and perks, over the bag (Close comes back to it).
func open_build() -> void:
	var families: Array[SynergyDef] = content.synergies if content else ([] as Array[SynergyDef])
	_build_window.show_build(_player.perks, families)
	Sfx.play_ui(Sfx.bank.ui_open)


func is_build_open() -> bool:
	return _build_window.visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _confirm.visible and event.is_action_pressed("ui_cancel"):
			_confirm.hide()
		elif _build_window.visible and event.is_action_pressed("ui_cancel"):
			_build_window.hide()
		else:
			close()


# --- Display -----------------------------------------------------------------

func _refresh() -> void:
	_perks_button.text = tr("Perks (%d)") % _player.perks.entries.size()
	for slot: EquipmentDef.Slot in _slot_buttons:
		var button: ItemSlot = _slot_buttons[slot]
		button.item = _player.equipment.get_item(slot)
		button.selected = _selected_slot == slot
	for i in _belt_slots.size():
		var button := _belt_slots[i]
		button.item = _player.belt.item_at(i)
		button.count = _player.belt.count_at(i)
		button.selected = _selected_belt == i
	_gold.text = tr("Gold %d") % _player.gold
	_portrait.texture = _hero_picture()
	_fill_stats()

	var inventory := _player.inventory
	# Places, not items: a stack takes one.
	_bag_title.text = tr("Bag  %d / %d") % [inventory.places_used(), inventory.capacity]
	for child in _item_grid.get_children():
		_item_grid.remove_child(child)
		child.queue_free()
	var shown := 0
	for entry in inventory.grouped():
		var item: ItemDef = entry.item
		var button := ItemSlot.new(BAG_SLOT)
		button.item = item
		button.count = entry.count
		button.selected = _selected_item == item and _selected_slot == NO_SLOT and _selected_belt == NO_SLOT
		button.pressed.connect(_select_item.bind(item))
		_item_grid.add_child(button)
		shown += 1
	# The empty places left in the bag.
	for i in range(shown, inventory.capacity):
		var empty := ItemSlot.new(BAG_SLOT)
		empty.disabled = true
		_item_grid.add_child(empty)
	var worse := _player.worse_gear()
	_worse_button.text = tr("Dismantle the worse (%d)") % worse.size()
	_worse_button.disabled = worse.is_empty()
	_refresh_details()


func _fill_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	var stats := _player.get_stats()
	var lines := [
		[tr("Level"), str(_player.level)],
		[tr("Health"), "%d / %d" % [_player.hp, _player.get_max_hp()]],
		[tr("Damage"), str(_player.get_power())],
		[tr("Armor"), str(stats.defense)],
		[tr("Move speed"), str(roundi(stats.move_speed))],
		[tr("Critical hits"), tr("%d%%") % roundi(stats.crit_chance * 100.0)],
		[tr("Attack speed"), tr("%+d%%") % roundi(stats.attack_speed * 100.0)],
		[tr("Skill damage"), tr("%+d%%") % roundi(stats.skill_power * 100.0)],
		[tr("Skill recharge"), tr("%+d%%") % roundi(minf(stats.cooldown_reduction, SkillSet.MAX_COOLDOWN_REDUCTION) * 100.0)],
	]
	for line: Array in lines:
		_stats.add_child(UiSkin.label(line[0], 15, UiSkin.DIM))
		var value := UiSkin.label(line[1], 15, UiSkin.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(value)


## The hero as they stand (first frame of their idle animation).
func _hero_picture() -> Texture2D:
	var frames: SpriteFrames = _player.def.frames if _player.def else null
	if frames == null:
		return null
	for anim: StringName in [&"idle_down", &"idle", &"walk_down"]:
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			return _cropped(frames.get_frame_texture(anim, 0))
	return null


## Just the drawn pixels of a frame (sheets leave room around the body).
static func _cropped(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	var used := image.get_used_rect()
	if used.size.x <= 0:
		return texture
	return ImageTexture.create_from_image(image.get_region(used))


func _refresh_details() -> void:
	var item: ItemDef = _selected_item
	if _selected_slot != NO_SLOT:
		item = _player.equipment.get_item(_selected_slot)
	if _selected_belt != NO_SLOT:
		item = _player.belt.item_at(_selected_belt)
	_use_button.visible = item != null and not item is RuneDef and not item is KeyItemDef  # runes go in at a forge; keys wait
	_drop_button.visible = item != null and _selected_slot == NO_SLOT and _selected_belt == NO_SLOT
	# Consumables move between the belt and the bag.
	_belt_button.visible = item is ConsumableDef and (_selected_belt != NO_SLOT or _player.belt.can_add(item))
	_belt_button.text = tr("To bag") if _selected_belt != NO_SLOT else tr("To belt")
	# Gear in the bag breaks down for gold (never what is worn).
	var gold := Player.DISMANTLE.gold_for(item) if _selected_slot == NO_SLOT and _selected_belt == NO_SLOT and DismantleRules.can_dismantle(item) else 0
	_dismantle_button.visible = gold > 0
	_dismantle_note.visible = gold > 0
	if _dismantle_armed != item:
		_dismantle_armed = null
	_dismantle_button.text = tr("Sure? +%d gold") % gold if _dismantle_armed else tr("Dismantle")
	_dismantle_button.add_theme_color_override("font_color", UiSkin.GOLD if _dismantle_armed else UiSkin.TEXT)
	_dismantle_note.text = tr("Dismantle value: %d gold") % gold
	if gold > 0 and not (item as EquipmentDef).runes.is_empty():
		_dismantle_note.text += "\n" + tr("The runes set in it break with it (counted in the gold).")
	_card_slot.item = item
	_card_slot.count = _player.belt.count_at(_selected_belt) if _selected_belt != NO_SLOT else 1
	for child in _sockets.get_children():
		_sockets.remove_child(child)
		child.queue_free()
	if item == null:
		_item_name.text = tr("Pick an item")
		_item_name.add_theme_color_override("font_color", UiSkin.GOLD)
		_item_type.text = tr("Tap a slot to see what it does.")
		_item_details.text = ""
		return
	_item_name.text = tr(item.display_name)
	_item_name.add_theme_color_override("font_color", item.rarity_color())
	_item_type.text = item.get_type_label()
	_item_details.text = item.get_details() + _compare_text(item)
	_fill_sockets(item as EquipmentDef)
	if _selected_slot != NO_SLOT:
		_use_button.text = tr("Unequip")
	elif item is EquipmentDef:
		_use_button.text = tr("Equip")
	elif item is SkillTomeDef:
		_use_button.text = tr("Learn")
	else:
		_use_button.text = tr("Use")


## Equipment in the bag: what wearing it would change ("Compared with your Katana: +3 item
## levels, +5 damage..."). Empty for what is worn and for anything else.
func _compare_text(item: ItemDef) -> String:
	var equipment := item as EquipmentDef
	if equipment == null or _selected_slot != NO_SLOT:
		return ""
	var worn := _player.equipment.get_item(equipment.slot)
	if worn == equipment:
		return ""
	var changes := ItemCompare.lines(equipment, worn).map(func(change: Dictionary) -> String: return change.text)
	return "\n\n%s %s" % [ItemCompare.heading(equipment, worn), ", ".join(changes) if not changes.is_empty() else tr("the same stats")]


## A weapon's rune sockets, as slots (set at a forge).
func _fill_sockets(equipment: EquipmentDef) -> void:
	if equipment == null or equipment.socket_count() <= 0:
		return
	_sockets.add_child(UiSkin.label(tr("Runes"), 15, UiSkin.DIM))
	for i in equipment.socket_count():
		var socket := ItemSlot.new(46.0)
		socket.item = equipment.runes[i] if i < equipment.runes.size() else null
		socket.caption = "-"
		socket.tooltip_text = tr(socket.item.description) if socket.item else tr("An empty socket: a forge sets runes in it.")
		socket.mouse_filter = Control.MOUSE_FILTER_PASS
		_sockets.add_child(socket)


# --- Selection & actions -----------------------------------------------------

func _select_item(item: ItemDef) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = item
	_selected_slot = NO_SLOT
	_selected_belt = NO_SLOT
	_refresh()


func _select_slot(slot: EquipmentDef.Slot) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = null
	_selected_belt = NO_SLOT
	_selected_slot = slot
	_refresh()


func _select_belt(index: int) -> void:
	if _player.belt.item_at(index) == null:
		return
	Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = null
	_selected_slot = NO_SLOT
	_selected_belt = index
	_refresh()


func _clear_selection() -> void:
	_selected_item = null
	_selected_slot = NO_SLOT
	_selected_belt = NO_SLOT


func _on_use_pressed() -> void:
	if _selected_belt != NO_SLOT:
		_player.use_belt(_selected_belt)
		if _player.belt.item_at(_selected_belt) == null:
			_clear_selection()
	elif _selected_slot != NO_SLOT:
		_player.unequip(_selected_slot)
		_clear_selection()
	elif _selected_item:
		_player.use_item(_selected_item)
		_keep_stack_selected()
	_refresh()


func _on_belt_pressed() -> void:
	if _selected_belt != NO_SLOT:
		_player.move_to_bag(_selected_belt)
	elif _selected_item:
		_player.move_to_belt(_selected_item)
	_clear_selection()
	_refresh()


func _on_drop_pressed() -> void:
	if _selected_item:
		_player.drop_item(_selected_item)
		_keep_stack_selected()
	_refresh()


## After one of a stack is gone, the rest of it stays picked (else nothing is).
func _keep_stack_selected() -> void:
	var rest := _player.inventory.find_like(_selected_item)
	if rest:
		_selected_item = rest
	else:
		_clear_selection()


## First tap: the button asks again (with the gold); second tap: broken down.
func _on_dismantle_pressed() -> void:
	if _selected_item == null:
		return
	if _dismantle_armed != _selected_item:
		_dismantle_armed = _selected_item
		Sfx.play_ui(Sfx.bank.ui_click)
		_refresh_details()
		return
	_dismantle_armed = null
	_player.dismantle(_selected_item)
	_keep_stack_selected()
	_refresh()


## "Dismantle the worse": what would go, and the gold, before anything breaks.
func _on_worse_pressed() -> void:
	var worse := _player.worse_gear()
	if worse.is_empty():
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	var gold := 0
	var shown := Inventory.new(worse.size())
	for item in worse:
		gold += Player.DISMANTLE.gold_for(item)
		shown.add(item)
	_confirm_text.text = (tr("Dismantle 1 piece of gear worse than what you wear, for %d gold?") % gold) if worse.size() == 1 \
		else tr("Dismantle %d pieces of gear worse than what you wear, for %d gold?") % [worse.size(), gold]
	UiParts.clear(_confirm_items)
	for entry in shown.grouped():
		var slot := ItemSlot.new(58.0)
		slot.item = entry.item
		slot.count = entry.count
		slot.tooltip_text = tr(entry.item.display_name)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_confirm_items.add_child(slot)
	_confirm_yes.text = tr("Dismantle: +%d gold") % gold
	_confirm.show()


## Is the confirmation of "Dismantle the worse" up? (tests)
func is_confirm_open() -> bool:
	return _confirm.visible


func _on_worse_confirmed() -> void:
	_confirm.hide()
	_player.dismantle_all(_player.worse_gear())
	if _selected_item:
		_keep_stack_selected()
	_refresh()


## Coins fly from the bag (or the card) to the gold counter.
func _on_dismantled(_items: Array[ItemDef], gold: int) -> void:
	if not visible:
		return
	var from := _dismantle_button.get_global_rect().get_center() if _dismantle_button.is_visible_in_tree() else _item_grid.get_global_rect().get_center()
	GoldBurst.play(self, from, _gold.get_global_rect().get_center(), gold)
	var tween := create_tween()
	_gold.pivot_offset = _gold.size * 0.5
	tween.tween_property(_gold, "scale", Vector2.ONE * 1.3, 0.12).set_delay(0.6)
	tween.tween_property(_gold, "scale", Vector2.ONE, 0.2)


# --- Building ----------------------------------------------------------------

func _build() -> void:
	_window = RpgWindow.new(tr("Inventory"))
	_window.close_requested.connect(close)
	add_child(_window)
	_gold = UiSkin.label("", 22, UiSkin.GOLD)
	_window.header_right.add_child(_gold)
	_perks_button = Button.new()
	_perks_button.text = tr("Perks")
	_perks_button.focus_mode = Control.FOCUS_NONE
	_perks_button.custom_minimum_size = Vector2(140, 48)
	_perks_button.pressed.connect(open_build)
	_window.header_right.add_child(_perks_button)
	_build_window = BuildWindow.new()
	_build_window.name = "BuildWindow"
	_build_window.hide()
	_build_window.close_requested.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		_build_window.hide())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)

	# Left: the hero, what they wear, the belt, their stats.
	var hero: Dictionary = RpgWindow.section(tr("Hero"))
	(hero.box as Control).custom_minimum_size.x = 330
	columns.add_child(hero.box)
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 8)
	hero.column.add_child(gear_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(74, 74)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear_row.add_child(_portrait)
	for slot: EquipmentDef.Slot in [EquipmentDef.Slot.WEAPON, EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
		var button := ItemSlot.new(GEAR_SLOT)
		button.caption = tr(EquipmentDef.SLOT_NAMES[slot])
		button.name = "%sSlot" % EquipmentDef.SLOT_NAMES[slot]
		button.pressed.connect(_select_slot.bind(slot))
		_own(button)
		gear_row.add_child(button)
		_slot_buttons[slot] = button
	hero.column.add_child(UiSkin.label(tr("Belt"), 17, UiSkin.GOLD))
	var belt_row := HBoxContainer.new()
	belt_row.add_theme_constant_override("separation", 8)
	hero.column.add_child(belt_row)
	for i in Belt.SLOTS:
		var button := ItemSlot.new(62.0)
		button.caption = str(i + 1)
		button.name = "BeltSlot%d" % (i + 1)
		button.pressed.connect(_select_belt.bind(i))
		_own(button)
		belt_row.add_child(button)
		_belt_slots.append(button)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 16)
	_stats.add_theme_constant_override("v_separation", 0)
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.column.add_child(_stats)

	# Middle: the bag.
	var bag: Dictionary = RpgWindow.section(tr("Bag"))
	_bag_title = bag.title
	columns.add_child(bag.box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = BAG_COLUMNS * (BAG_SLOT + 6) + 4
	bag.column.add_child(scroll)
	_item_grid = GridContainer.new()
	_item_grid.columns = BAG_COLUMNS
	_item_grid.name = "ItemGrid"
	_item_grid.add_theme_constant_override("h_separation", 6)
	_item_grid.add_theme_constant_override("v_separation", 6)
	_own(_item_grid)
	scroll.add_child(_item_grid)
	_worse_button = _action(tr("Dismantle the worse (%d)") % 0, "DismantleWorseButton", _on_worse_pressed)
	_worse_button.add_theme_font_size_override("font_size", 16)
	_worse_button.custom_minimum_size = Vector2(0, 50)
	_worse_button.size_flags_horizontal = Control.SIZE_FILL
	bag.column.add_child(_worse_button)

	# Right: the picked item.
	var card: Dictionary = RpgWindow.section(tr("Item"), true)
	(card.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(card.box)
	(card.title as Label).hide()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	card.column.add_child(top)
	_card_slot = ItemSlot.new(84.0)
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_card_slot)
	var naming := VBoxContainer.new()
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(naming)
	_item_name = UiSkin.label("", 22, UiSkin.GOLD, true)
	naming.add_child(_item_name)
	_item_type = UiSkin.label("", 15, UiSkin.DIM, true)
	naming.add_child(_item_type)
	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.column.add_child(details_scroll)
	_item_details = UiSkin.label("", 16, UiSkin.TEXT, true)
	_item_details.name = "ItemDetails"
	details_scroll.add_child(_item_details)
	_sockets = HBoxContainer.new()
	_sockets.alignment = BoxContainer.ALIGNMENT_BEGIN
	_sockets.add_theme_constant_override("separation", 6)
	card.column.add_child(_sockets)
	_dismantle_note = UiSkin.label("", 15, UiSkin.GOLD, true)
	_dismantle_note.name = "DismantleNote"
	_own(_dismantle_note)
	card.column.add_child(_dismantle_note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	card.column.add_child(actions)
	_use_button = _action(tr("Use"), "UseButton", _on_use_pressed)
	actions.add_child(_use_button)
	_belt_button = _action(tr("To belt"), "BeltButton", _on_belt_pressed)
	actions.add_child(_belt_button)
	_drop_button = _action(tr("Drop"), "DropButton", _on_drop_pressed)
	actions.add_child(_drop_button)
	_dismantle_button = _action(tr("Dismantle"), "DismantleButton", _on_dismantle_pressed)
	_dismantle_button.add_theme_font_size_override("font_size", 16)
	actions.add_child(_dismantle_button)
	_build_confirm()
	for node in _named:
		node.owner = self
		node.unique_name_in_owner = true
	add_child(_build_window)  # over the bag


func _build_confirm() -> void:
	_confirm = RpgDialog.new(tr("Dismantle the worse"), 640.0)
	_confirm.name = "DismantleConfirm"
	_confirm.hide()
	add_child(_confirm)  # over the window (the build window comes over both)
	_confirm_text = UiParts.text("", 19, UiSkin.TEXT, 580.0)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.body.add_child(_confirm_text)
	_confirm_items = HFlowContainer.new()
	_confirm_items.alignment = FlowContainer.ALIGNMENT_CENTER
	_confirm_items.custom_minimum_size.x = 580.0
	_confirm_items.add_theme_constant_override("h_separation", 6)
	_confirm_items.add_theme_constant_override("v_separation", 6)
	_confirm.body.add_child(_confirm_items)
	var note := UiParts.text(tr("What you wear, potions, runes, tomes and keys are never touched."), 15, UiSkin.DIM, 580.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.body.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_confirm.body.add_child(buttons)
	_confirm_yes = UiParts.button(tr("Dismantle"), _on_worse_confirmed, Vector2(0, 56), 18)
	_confirm_yes.name = "ConfirmDismantleButton"
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own(_confirm_yes)
	buttons.add_child(_confirm_yes)
	var keep := UiParts.button(tr("Keep them"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		_confirm.hide(), Vector2(0, 56), 18)
	keep.name = "KeepButton"
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own(keep)
	buttons.add_child(keep)


func _action(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 52)  # three in a row on a 16:9 phone (Equip, Drop, Dismantle)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_own(button)
	return button


## Reachable as %Name from the panel (tests, other scripts), once built.
func _own(node: Node) -> void:
	_named.append(node)
