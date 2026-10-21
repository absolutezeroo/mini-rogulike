class_name OathPanel
extends Control
## "At the Well's Edge", between the difficulty and the run, once the Tree of Souls opened an oath
## or the Armory: swear an oath (OathDef, "X, but Y") or none, and pick the weapon to start with.
## The choice is remembered for the next runs (Profile.oath, Profile.starting_weapon).
## Built in code; %OathCards, %WeaponRow and %StartRunButton are reachable from the title screen.

signal started

const CARD_SIZE := Vector2(250, 296)

var _content: ContentDB
var _window: MenuWindow
var _cards: HBoxContainer
var _weapons_box: Control
var _weapons: HBoxContainer
var _weapon_text: Label
var _start: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## Something to choose: an open oath, or the Armory bought.
static func has_choices(content: ContentDB) -> bool:
	return content.soul_tree != null and (not content.soul_tree.open_oaths().is_empty() or has_armory(content))


static func has_armory(content: ContentDB) -> bool:
	return content.upgrades.any(func(u: UpgradeDef) -> bool: return u.kind == UpgradeDef.Kind.RULES and u.armory and Profile.level_of(u) > 0)


## The weapons the hero may start with: those the dungeon holds (unlocked ones included).
static func weapons(content: ContentDB) -> Array[WeaponDef]:
	var unlocked := ShrineUpgrades.unlocked_items(content)
	var result: Array[WeaponDef] = []
	for item in content.items + content.locked_items:
		if item is WeaponDef and not result.has(item) and (not content.locked_items.has(item) or unlocked.has(item)):
			result.append(item)
	return result


func open(content: ContentDB) -> void:
	_content = content
	var open_oaths := content.soul_tree.open_oaths()
	if Profile.oath != &"" and not open_oaths.any(func(o: OathDef) -> bool: return o.id == Profile.oath):
		Profile.oath = &""
	_fill_cards()
	_fill_weapons()
	show()


func choose_oath(oath: OathDef) -> void:
	Profile.oath = oath.id if oath else &""
	Profile.save_profile()
	_fill_cards()
	_fill_weapons()


func choose_weapon(weapon: WeaponDef) -> void:
	Profile.starting_weapon = weapon.id if weapon else &""
	Profile.save_profile()
	_fill_weapons()


func start() -> void:
	hide()
	started.emit()


func _fill_cards() -> void:
	UiParts.clear(_cards)
	_cards.add_child(_card(null, true))
	for oath in _content.soul_tree.oaths():
		var open := _content.soul_tree.open_oaths().has(oath)
		_cards.add_child(_card(oath, open))


func _card(oath: OathDef, open: bool) -> Control:
	var chosen := (oath == null and Profile.oath == &"") or (oath != null and Profile.oath == oath.id)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not open
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.8, 0.35, 0.16) if chosen else Color(0, 0, 0, 0.22)
	style.border_color = UiSkin.GOLD if chosen else Color(0, 0, 0, 0.4)
	style.set_border_width_all(3 if chosen else 1)
	style.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		choose_oath(oath))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = oath.icon if oath else _content.player.starting_equipment[0].icon if not _content.player.starting_equipment.is_empty() else null
	icon.modulate = Color.WHITE if open else Color(0.4, 0.38, 0.36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var name := UiSkin.label(tr(oath.display_name) if oath else tr("Unsworn"), 19, (oath.color.lerp(Color.WHITE, 0.3) if oath else UiSkin.TEXT) if open else UiSkin.DIM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name)
	# What it changes: gains in green, costs in red (faded while it is locked).
	var lines: Array = oath.effects() if oath else [[tr("The usual start: the Katana, no rule changed."), 0]]
	for line: Array in lines:
		var color: Color = UiSkin.TEXT
		if line[1] > 0:
			color = MenuWindow.GOOD
		elif line[1] < 0:
			color = MenuWindow.BAD
		var words := UiSkin.label(line[0], 13, color if open else Color(color, 0.55), true)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(words)
	if not open:
		var branch := ""
		for node in _content.soul_tree.nodes:
			if node.oath == oath and node.branch < _content.soul_tree.branches.size():
				branch = tr(_content.soul_tree.branches[node.branch])
		var lock := UiSkin.label(tr("Opens at the end of the %s branch of the Tree of Souls, at the shrine.") % branch, 13, UiSkin.DIM, true)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(lock)
	if chosen:
		var mark := UiSkin.label(tr("Sworn"), 15, UiSkin.GOLD)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(mark)
	for child in column.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _fill_weapons() -> void:
	UiParts.clear(_weapons)
	_weapons_box.visible = has_armory(_content)
	if not _weapons_box.visible:
		return
	var oath := Game.sworn_oath(_content)
	var picked := Game.picked_weapon(_content)
	if oath and oath.starting_weapon:
		_weapon_text.text = tr("Your starting weapon (Armory): your oath brings its own, the %s. Without the oath, pick one below.") % tr(oath.starting_weapon.display_name)
	else:
		_weapon_text.text = tr("Your starting weapon (Armory): %s.") % (tr(picked.display_name) if picked else tr("the usual one"))
	for weapon in weapons(_content):
		var slot := ItemSlot.new(56.0)
		slot.item = weapon
		slot.tooltip_text = tr(weapon.display_name)
		slot.selected = weapon == picked
		slot.show_level = false
		slot.pressed.connect(func() -> void:
			Sfx.play_ui(Sfx.bank.ui_click)
			choose_weapon(null if weapon == picked else weapon))
		_weapons.add_child(slot)


func _build() -> void:
	_window = MenuWindow.new(tr("At the Well's Edge"))
	add_child(_window)
	var scene_owner: Node = owner if owner != null else self
	_window.close_button.text = tr("Back")
	_window.close_button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	var intro := UiSkin.label(tr("Swear an oath for this run, or go down unsworn. It changes how you start: pick one, then Begin the descent."), 16, UiSkin.TEXT, true)
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.header_left.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = CARD_SIZE.y + 8
	_window.body.add_child(scroll)
	TouchScroll.attach(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	scroll.add_child(_cards)
	MenuWindow.expose(_cards, "OathCards", scene_owner)
	_weapons_box = MenuWindow.strip()
	_window.body.add_child(_weapons_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_weapons_box.add_child(column)
	_weapon_text = UiSkin.label("", 16, UiSkin.GOLD, true)
	column.add_child(_weapon_text)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.custom_minimum_size.y = 64
	column.add_child(weapon_scroll)
	TouchScroll.attach(weapon_scroll)
	_weapons = HBoxContainer.new()
	_weapons.add_theme_constant_override("separation", 6)
	weapon_scroll.add_child(_weapons)
	MenuWindow.expose(_weapons, "WeaponRow", scene_owner)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.body.add_child(spacer)
	_start = MenuWindow.button(tr("Begin the descent"), 22, 60)
	_start.pressed.connect(start)
	_window.body.add_child(_start)
	MenuWindow.expose(_start, "StartRunButton", scene_owner)
