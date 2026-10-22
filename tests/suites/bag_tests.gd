class_name BagTests
extends PcTests
## The bag's tabs and quick actions (docs/design/interface.md, "Bag"). Unit part (run by the unit
## suite): which tab each item lands in (BagCategorySet), the order inside a tab, the counts, which
## dismantles ask first. Game part (game suite): the bag screen on touch (tabs tapped, the card's
## buttons, the new marks), with a gamepad (LB / RB, A, X, Y, B) and with keys (Q / E, Enter, X,
## G), the confirmation for rare pieces, what is worn never broken. Borrows PcTests' helpers.

const CATEGORIES: BagCategorySet = preload("res://data/items/bag_categories.tres")


func _tab_of(id: StringName) -> int:
	for i in CATEGORIES.categories.size():
		if CATEGORIES.categories[i].id == id:
			return i
	return -1


func _item(path: String) -> ItemDef:
	return load(path) as ItemDef


# --- Unit ---------------------------------------------------------------------------------

func run_bag_unit() -> void:
	var gear := _tab_of(&"gear")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	var other := _tab_of(&"other")
	check(gear >= 0 and runes >= 0 and scrolls >= 0 and consumables >= 0 and other >= 0, "the bag has its five tabs (bag_categories.tres)")
	for category in CATEGORIES.categories:
		check(not category.display_name.is_empty() and category.icon != null, "the tab %s has a name and an icon" % category.id)
	var wrong: Array[String] = []
	var everything: Array[ItemDef] = []
	everything.append_array(CONTENT.items)
	everything.append_array(CONTENT.locked_items)
	for rune in CONTENT.runes:
		everything.append(rune)
	everything.append(_item("res://data/items/keys/bone_key.tres"))
	for item in everything:
		var expected := other
		if item is EquipmentDef:
			expected = gear
		elif item is RuneDef:
			expected = runes
		elif item is SkillTomeDef or item.id == &"fire_scroll":
			expected = scrolls
		elif item is ConsumableDef:
			expected = consumables
		if CATEGORIES.index_of(item) != expected:
			wrong.append("%s in %d" % [item.id, CATEGORIES.index_of(item)])
	check(wrong.is_empty(), "every item lands in its tab: gear, runes, tomes and the scroll, consumables, keys (%s)" % ", ".join(wrong))
	var katana := _item("res://data/items/weapons/katana.tres") as EquipmentDef
	var helm := _item("res://data/items/armors/iron_helm.tres") as EquipmentDef
	var mail := _item("res://data/items/armors/chain_mail.tres") as EquipmentDef
	var no_affix: Array[ItemAffixDef] = []
	var rare := LootRoller.make(katana, ItemRarity.RARE, no_affix, [], 3)
	var epic := LootRoller.make(mail, ItemRarity.EPIC, no_affix, [], 2)
	check(CATEGORIES.index_of(rare) == gear, "a rolled weapon (a WeaponDef: its parent class EquipmentDef) is gear")
	check(CATEGORIES.index_of(ItemDef.new()) == other, "an item no tab names goes to the catch-all tab")
	# Inside a tab: the rarest first, then weapons, helms, body armors, the higher level first.
	var bag := Inventory.new(16)
	for item: ItemDef in [mail, helm, katana, katana, rare, epic, _item("res://data/runes/ember.tres"), _item("res://data/runes/ember.tres")]:
		bag.add(item)
	var shown := CATEGORIES.entries_in(gear, bag.grouped())
	var order: Array = shown.map(func(entry: Dictionary) -> ItemDef: return entry.item)
	check(order == [epic, rare, katana, helm, mail], "a tab shows the rarest first, then weapon, head, body (%s)" % [order.map(func(item: ItemDef) -> String: return item.display_name)])
	check(CATEGORIES.count_in(gear, bag.grouped()) == 6 and CATEGORIES.count_in(runes, bag.grouped()) == 2, "a tab counts items, a stack all of its own")
	# Which dismantles ask first (DismantleRules.needs_confirm).
	var rules := Player.DISMANTLE
	var magic := LootRoller.make(katana, ItemRarity.MAGIC, no_affix, [], 1)
	var socketed := LootRoller.make(katana, ItemRarity.COMMON, no_affix, [_item("res://data/runes/ember.tres") as RuneDef], 1)
	check(rules.confirm_rarity == ItemRarity.RARE, "rare and better ask before they break (dismantle.tres)")
	check(not rules.needs_confirm(katana) and not rules.needs_confirm(magic), "common and magic gear breaks down at once")
	check(rules.needs_confirm(rare) and rules.needs_confirm(epic), "rare and epic gear asks a second press")
	check(rules.needs_confirm(socketed), "gear with a rune set asks too (the rune breaks with it)")
	# The actions on a selection.
	var selection := BagSelection.new(null, katana)
	check(BagDropAction.new().available(selection) and BagUseAction.new().label(selection) == "Equip", "gear in the bag: Equip, Drop")
	var worn := BagSelection.new(null, katana, EquipmentDef.Slot.WEAPON)
	check(not BagDismantleAction.new().available(worn) and not BagDropAction.new().available(worn) and BagUseAction.new().label(worn) == "Unequip", "what is worn: Unequip only, never dismantled or dropped")
	var rune := BagSelection.new(null, _item("res://data/runes/ember.tres"))
	check(not BagUseAction.new().available(rune) and not BagDismantleAction.new().available(rune), "a rune: nothing to use, never dismantled")
	# The keys of the quick actions.
	for action: StringName in [&"menu_scroll_up", &"menu_scroll_down"]:
		check(InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == JOY_AXIS_RIGHT_Y), "%s is the right stick (the keys have the mouse's wheel)" % action)
	for action: StringName in [&"item_dismantle", &"item_drop"]:
		var events := InputMap.action_get_events(action)
		check(events.any(func(e: InputEvent) -> bool: return e is InputEventKey) and events.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion), "%s works on keys and on a gamepad" % action)
	var pad_button := func(action: StringName) -> int:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				return (e as InputEventJoypadButton).button_index
		return -1
	check(pad_button.call(&"item_dismantle") == JOY_BUTTON_X and pad_button.call(&"item_drop") == JOY_BUTTON_Y, "X dismantles, Y drops on a gamepad")


# --- Game ---------------------------------------------------------------------------------

func run_bag_game(game: Game) -> void:
	var player := game.player
	var saved_bag := player.inventory.items.duplicate()
	var saved_weapon := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	var saved_body := player.equipment.get_item(EquipmentDef.Slot.BODY)
	var saved_gold := player.gold
	var saved_belt := player.belt.to_data()
	var saved_spell := player.learned_skill
	await _test_touch(game)
	await _test_gamepad(game)
	await _test_keys(game)
	await _test_french_fit(game)
	InputDevice.use(InputDevice.Kind.TOUCH)
	player.inventory.items.assign(saved_bag)
	player.equipment.equip(saved_weapon)
	if saved_body:
		player.equipment.equip(saved_body)
	player.gold = saved_gold
	player.belt.load_data(saved_belt)
	if player.learned_skill != saved_spell:
		player.learned_skill = saved_spell
		player._rebuild_skills(0.0)
	for left in get_tree().get_nodes_in_group("pickups"):
		left.queue_free()
	get_tree().paused = false
	await _frames(2)


## A bag of everything: gear of each rarity (a stack of two commons), runes, a tome, the scroll,
## a potion.
func _fill(player: Player) -> Dictionary:
	var katana := _item("res://data/items/weapons/katana.tres") as EquipmentDef
	var mail := _item("res://data/items/armors/chain_mail.tres") as EquipmentDef
	var no_affix: Array[ItemAffixDef] = []
	var items := {
		"common": LootRoller.make(katana, ItemRarity.COMMON, no_affix, [], 1),
		"common2": LootRoller.make(katana, ItemRarity.COMMON, no_affix, [], 1),
		"rare": LootRoller.make(katana, ItemRarity.RARE, no_affix, [], 2),
		"epic": LootRoller.make(mail, ItemRarity.EPIC, no_affix, [], 2),
		"rune": _item("res://data/runes/ember.tres"),
		"rune2": _item("res://data/runes/spark.tres"),
		"tome": _item("res://data/items/tomes/tome_fire.tres"),
		"scroll": _item("res://data/items/consumables/fire_scroll.tres"),
		"potion": _item("res://data/items/consumables/haste_draught.tres"),
	}
	player.inventory.items.clear()
	for key: String in items:
		player.inventory.add(items[key])
	return items


func _test_touch(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	InputDevice.use(InputDevice.Kind.TOUCH)
	var items := _fill(player)
	var gear := _tab_of(&"gear")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	game.open_inventory()
	await _frames(2)
	panel.show_category(gear)
	await _frames(1)
	var grid: GridContainer = panel.get_node("%ItemGrid")
	var free := player.inventory.capacity - player.inventory.places_used()
	var gear_slots: Array = grid.get_children().filter(func(slot: ItemSlot) -> bool: return slot.item != null)
	check(gear_slots.size() == 3 and grid.get_child_count() == 3 + free, "the gear tab shows its 3 stacks, then the bag's %d free places (%d slots)" % [free, grid.get_child_count()])
	check(gear_slots.all(func(slot: ItemSlot) -> bool: return slot.item is EquipmentDef), "only gear in the gear tab")
	check((gear_slots[0] as ItemSlot).item == items.epic and (gear_slots[1] as ItemSlot).item == items.rare and (gear_slots[2] as ItemSlot).count == 2, "the rarest first, the commons' stack last with its count")
	check(panel.tab(gear).count == 4 and panel.tab(runes).count == 2 and panel.tab(scrolls).count == 2 and panel.tab(consumables).count == 1, "each tab counts its items (4, 2, 2, 1)")
	check(not panel.tab(_tab_of(&"other")).visible, "the keys' tab hides while it holds nothing")
	check((panel.get_node("%CategoryName") as Label).text == "Weapons & Armor", "the tab's name under the tabs")
	check(panel.tab(runes).fresh and (gear_slots[0] as ItemSlot).fresh, "new things are marked, and their tab")
	# A tap on a tab.
	panel.tab(runes).pressed.emit()
	await _frames(1)
	var rune_items: Array = grid.get_children().filter(func(slot: ItemSlot) -> bool: return slot.item != null).map(func(slot: ItemSlot) -> ItemDef: return slot.item)
	check(panel.category_index() == runes and rune_items.size() == 2 and rune_items.all(func(item: ItemDef) -> bool: return item is RuneDef), "tapping the Runes tab shows the runes only")
	check(panel.tab(runes).button_pressed and not panel.tab(gear).button_pressed, "the tab shown stays pressed")
	panel.tab(scrolls).pressed.emit()
	await _frames(1)
	var scroll_items: Array = grid.get_children().filter(func(slot: ItemSlot) -> bool: return slot.item != null).map(func(slot: ItemSlot) -> ItemDef: return slot.item)
	check(scroll_items.has(items.tome) and scroll_items.has(items.scroll) and scroll_items.size() == 2, "tomes and the scroll share a tab")
	panel.close()
	await _frames(2)
	game.open_inventory()
	await _frames(2)
	check(panel.category_index() == scrolls, "the bag opens again on the tab picked last")
	check(not panel.tab(runes).fresh, "what was shown is no longer new")
	panel.show_category(gear)
	await _frames(1)
	# The card's buttons, as before: a common goes at once, a rare asks again.
	var dismantle: Button = panel.get_node("%DismantleButton")
	panel.slot_for(items.common).pressed.emit()
	var gold := player.gold
	var gain := Player.DISMANTLE.gold_for(items.common)
	dismantle.pressed.emit()
	check(player.gold == gold + gain and player.inventory.count_of(items.common) == 1, "tapping Dismantle on a common breaks one of its stack at once (+%d gold)" % gain)
	check(panel._selected_item != null and panel._selected_item.stack_key() == items.common.stack_key(), "the rest of the stack stays picked")
	panel.slot_for(items.rare).pressed.emit()
	gold = player.gold
	dismantle.pressed.emit()
	var note := panel.get_node("%DismantleNote") as Label
	check(player.gold == gold and player.inventory.count_of(items.rare) == 1 and dismantle.text == "Sure?", "on a rare piece a first tap asks again (%s)" % dismantle.text)
	check(note.text == "Tap again to break it: +%d gold" % Player.DISMANTLE.gold_for(items.rare), "the card says what a second tap does, in touch words: %s" % note.text)
	panel.slot_for(items.epic).pressed.emit()
	check(dismantle.text == "Dismantle", "picking another item takes the question back")
	panel.slot_for(items.rare).pressed.emit()
	dismantle.pressed.emit()
	dismantle.pressed.emit()
	check(player.gold > gold and player.inventory.count_of(items.rare) == 0, "a second tap breaks the rare piece")
	(panel.get_node("%WeaponSlot") as ItemSlot).pressed.emit()
	check(not dismantle.visible and not (panel.get_node("%DropButton") as Button).visible, "what is worn shows no Dismantle and no Drop")
	panel.slot_for(items.common).pressed.emit()
	(panel.get_node("%DropButton") as Button).pressed.emit()
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "Drop leaves it on the ground")
	# A right click equips.
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	panel.slot_for(items.epic).gui_input.emit(right)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic, "a right click on an item equips it")
	panel.close()
	await _frames(2)


func _test_gamepad(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var items := _fill(player)
	var gear := _tab_of(&"gear")
	var runes := _tab_of(&"runes")
	panel.show_category(gear)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	InputDevice.navigating = true
	game.open_inventory()
	await _frames(3)
	var first := panel.slot_for(items.epic)
	check(_focus() == first and panel._selected_item == items.epic, "a gamepad starts on the tab's first slot, its card shown")
	var dismantle_key := (panel.get_node("%DismantleButton") as Button).find_child("*Key", false, false) as PromptGlyph
	check(dismantle_key != null and dismantle_key.visible and dismantle_key.cap().get("text", "") == "X", "the Dismantle button shows its button (X)")
	# LB / RB switch tabs, the focus on the new tab's first slot.
	await _tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(1)
	check(panel.category_index() == runes, "RB shows the next tab")
	check(_focus() is ItemSlot and (_focus() as ItemSlot).item is RuneDef and panel._selected_item == (_focus() as ItemSlot).item, "...its first slot focused and picked")
	await _tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(1)
	check(panel.category_index() == gear, "LB the previous one")
	# Moving the focus picks.
	await _tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await _frames(1)
	check(panel._selected_item == items.rare, "moving onto a slot shows its card")
	# X on a rare: asks; B takes it back; X X breaks it.
	var gold := player.gold
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold and player.inventory.count_of(items.rare) == 1 and (panel.get_node("%DismantleButton") as Button).text == "Sure?", "X on a rare piece asks first")
	check((panel.get_node("%DismantleNote") as Label).text.begins_with("Press [X] again"), "...and the card names the button: %s" % (panel.get_node("%DismantleNote") as Label).text)
	await _tap_pad(JOY_BUTTON_B)
	check(panel.visible and (panel.get_node("%DismantleButton") as Button).text == "Dismantle", "B takes the question back (the bag stays open)")
	await _tap_pad(JOY_BUTTON_X)
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold + Player.DISMANTLE.gold_for(items.rare) and player.inventory.count_of(items.rare) == 0, "X twice breaks the rare piece")
	check(_focus() is ItemSlot and (_focus() as ItemSlot).item == items.common and panel._selected_item == items.common, "the focus goes on to the next item")
	# X on a common: at once, one of the stack.
	gold = player.gold
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold + Player.DISMANTLE.gold_for(items.common) and player.inventory.count_of(items.common) == 1, "X breaks a common at once, one of its stack")
	check(_focus() == panel.slot_for(items.common), "the focus stays on the rest of the stack")
	# Y drops.
	await _tap_pad(JOY_BUTTON_Y)
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "Y drops it")
	# A equips.
	panel.slot_for(items.epic).grab_focus()
	await _frames(1)
	await _tap_pad(JOY_BUTTON_A)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic, "A equips the focused gear")
	# What is worn is never broken down.
	(panel.get_node("%BodySlot") as ItemSlot).grab_focus()
	await _frames(1)
	gold = player.gold
	await _tap_pad(JOY_BUTTON_X)
	await _tap_pad(JOY_BUTTON_X)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic and player.gold == gold, "X on what is worn breaks nothing")
	await _tap_pad(JOY_BUTTON_B)
	check(not panel.visible, "B closes the bag")
	await _frames(2)


func _test_keys(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var items := _fill(player)
	var gear := _tab_of(&"gear")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	panel.show_category(gear)
	_keys_mode()
	game.open_inventory()
	await _frames(3)
	await _tap_key(KEY_E)
	await _frames(1)
	check(panel.category_index() == runes, "E shows the next tab")
	await _tap_key(KEY_E)
	await _tap_key(KEY_E)
	await _frames(1)
	check(panel.category_index() == consumables, "...and the next")
	await _tap_key(KEY_Q)
	await _frames(1)
	check(panel.category_index() == scrolls, "Q the previous one")
	# Enter uses: the tome is learned.
	var tome_slot := panel.slot_for(items.tome)
	tome_slot.grab_focus()
	await _frames(1)
	await _tap_key(KEY_ENTER)
	check(player.inventory.count_of(items.tome) == 0, "Enter on a tome learns it")
	panel.show_category(gear)
	await _frames(1)
	panel.slot_for(items.common).grab_focus()
	await _frames(1)
	var gold := player.gold
	await _tap_key(KEY_X)
	check(player.gold > gold and player.inventory.count_of(items.common) == 1, "X dismantles on a keyboard")
	await _tap_key(KEY_G)
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "G drops")
	panel.slot_for(items.epic).grab_focus()
	await _frames(1)
	gold = player.gold
	await _tap_key(KEY_DELETE)
	check(player.gold == gold and (panel.get_node("%DismantleButton") as Button).text == "Sure?", "Delete dismantles too, asking first on an epic piece")
	await _tap_key(KEY_ESCAPE)
	check(panel.visible, "Escape takes the question back first")
	await _tap_key(KEY_ESCAPE)
	check(not panel.visible, "then closes the bag")
	await _frames(2)


## French runs long: on a 1280x720 screen (and 1920x1080, the same layout at x1.5) the bag stays
## inside the screen on every tab, a consumable's three buttons and a rare piece's question
## included (they go to a second row rather than widening the window).
func _test_french_fit(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var before := get_tree().root.size
	await _window(Vector2i(1280, 720))
	TranslationServer.set_locale("fr")
	var items := _fill(player)
	_keys_mode()
	panel.show_category(0)
	game.open_inventory()
	await _frames(3)
	var problems: Array[String] = []
	for i in InventoryPanel.CATEGORIES.categories.size():
		panel.show_category(i)
		await _frames(2)
		problems.append_array(_panel_outside(panel))
	panel.show_category(_tab_of(&"consumables"))
	panel.slot_for(items.potion).pressed.emit()
	await _frames(2)
	problems.append_array(_panel_outside(panel))
	panel.show_category(_tab_of(&"gear"))
	panel.slot_for(items.rare).grab_focus()
	await _frames(1)
	await _tap_key(KEY_X)
	await _frames(2)
	problems.append_array(_panel_outside(panel))
	check(problems.is_empty(), "the bag fits a 1280x720 screen in French, on every tab: %s" % ", ".join(problems.slice(0, 4)))
	panel.close()
	TranslationServer.set_locale("en")
	await _restore_window(before)
