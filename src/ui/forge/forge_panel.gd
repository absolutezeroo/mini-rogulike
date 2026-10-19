class_name ForgePanel
extends Control
## The smith's forge (Forge): pick a weapon (the worn one, or one from the bag), see its rune
## sockets, set runes from the bag into the free ones (free), or take one back out, intact,
## for gold. The game is paused while it is open.

signal closed

const ICON_SIZE := Vector2(40, 40)
const SOCKET_SIZE := Vector2(92, 92)
const DIM := Color(1, 1, 1, 0.65)

var _forge: Forge
var _player: Player
var _weapon: EquipmentDef
## The socket picked on the weapon (-1: none): its rune can be taken out.
var _socket := -1

var _portrait: TextureRect
var _name: Label
var _greeting: Label
var _gold: Label
var _weapons: HFlowContainer
var _weapon_title: Label
var _weapon_details: Label
var _sockets: HBoxContainer
var _action: Button
var _runes: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(forge: Forge, player: Player) -> void:
	_forge = forge
	_player = player
	_name.text = forge.def.display_name
	_greeting.text = forge.def.random_greeting()
	_portrait.texture = forge.def.portrait
	var weapons := Forge.weapons_of(player)
	_weapon = weapons[0] if not weapons.is_empty() else null
	_socket = -1
	_refresh()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The weapon being worked on (tests, and after a rune goes in: it may be a new copy).
func weapon() -> EquipmentDef:
	return _weapon


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()


# --- Actions ----------------------------------------------------------------------

func _select_weapon(weapon: EquipmentDef) -> void:
	_weapon = weapon
	_socket = -1
	Sfx.play_ui(Sfx.bank.ui_click)
	_refresh()


func _select_socket(index: int) -> void:
	_socket = index if _socket != index else -1
	Sfx.play_ui(Sfx.bank.ui_click)
	_refresh()


## Sets `rune` into the picked weapon's first free socket.
func set_rune(rune: RuneDef) -> bool:
	var worked := Forge.set_rune(_player, _weapon, rune)
	if worked == null:
		return false
	_weapon = worked
	_socket = -1
	_forge.strike(false)
	_refresh()
	return true


## Takes the picked socket's rune back out, for gold.
func take_rune() -> bool:
	if not Forge.take_rune(_player, _weapon, _socket, _forge.removal_cost()):
		return false
	_socket = -1
	_forge.strike(true)
	_refresh()
	return true


# --- Look -------------------------------------------------------------------------

func _refresh() -> void:
	_gold.text = "Gold %d" % _player.gold
	_clear(_weapons)
	_clear(_sockets)
	_clear(_runes)
	var weapons := Forge.weapons_of(_player)
	if not weapons.has(_weapon):
		_weapon = weapons[0] if not weapons.is_empty() else null
	var worn := _player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	for weapon in weapons:
		var button := _button(("Worn: " if weapon == worn else "") + weapon.display_name, _select_weapon.bind(weapon))
		button.toggle_mode = true
		button.set_pressed_no_signal(weapon == _weapon)
		button.add_theme_color_override("font_color", weapon.rarity_color())
		button.add_theme_color_override("font_pressed_color", weapon.rarity_color())
		_weapons.add_child(button)
	if _weapon == null:
		_weapon_title.text = "No weapon to work on."
		_weapon_details.text = ""
		_action.hide()
	else:
		_weapon_title.text = _weapon.display_name
		_weapon_title.add_theme_color_override("font_color", _weapon.rarity_color())
		var damage := "%d damage" % (_weapon as WeaponDef).damage if _weapon is WeaponDef else ""
		_weapon_details.text = "%s  -  %s  -  %d rune socket%s" % [_weapon.get_type_label(), damage, _weapon.socket_count(), "s" if _weapon.socket_count() > 1 else ""]
		for i in _weapon.socket_count():
			_sockets.add_child(_socket_button(i))
		_refresh_action()
	_fill_runes()


func _refresh_action() -> void:
	if _socket < 0 or _socket >= _weapon.runes.size():
		_action.hide()
		return
	var rune := _weapon.runes[_socket]
	var price := _forge.removal_cost()
	_action.show()
	_action.text = "Take out %s  (%d gold)" % [rune.display_name, price]
	_action.disabled = _player.gold < price or _player.inventory.is_full()
	if _player.inventory.is_full():
		_action.text = "Your bag is full"


func _fill_runes() -> void:
	var any := false
	for entry in _player.inventory.grouped():
		var rune := entry.item as RuneDef
		if rune == null:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_icon(rune.icon, ICON_SIZE))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		text.add_child(_label(rune.display_name + ("  x%d" % entry.count if entry.count > 1 else ""), 18, rune.rarity_color()))
		text.add_child(_label(rune.description, 13, DIM, true))
		row.add_child(text)
		var set_button := _button("Set", set_rune.bind(rune))
		set_button.custom_minimum_size = Vector2(96, 48)
		set_button.disabled = _weapon == null or _weapon.free_sockets() <= 0
		row.add_child(set_button)
		_runes.add_child(row)
	if not any:
		_runes.add_child(_label("No runes in your bag. Elites, bosses and chests drop them.", 15, DIM, true))


## A socket: its rune (tap to pick it, then take it out), or empty.
func _socket_button(index: int) -> Control:
	var button := Button.new()
	button.custom_minimum_size = SOCKET_SIZE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 13)
	if index < _weapon.runes.size():
		var rune := _weapon.runes[index]
		button.icon = rune.icon
		button.text = rune.display_name.trim_suffix(" Rune")
		button.tooltip_text = rune.description
		button.add_theme_color_override("font_color", rune.rarity_color())
		button.add_theme_color_override("font_pressed_color", rune.rarity_color())
		button.set_pressed_no_signal(index == _socket)
		button.pressed.connect(_select_socket.bind(index))
	else:
		button.text = "Empty"
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return button


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_top = 30
	panel.offset_right = -60
	panel.offset_bottom = -30
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	_portrait = _icon(null, Vector2(64, 64))
	header.add_child(_portrait)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(who)
	_name = _label("Smith", 26, Color(1, 0.7, 0.35))
	who.add_child(_name)
	_greeting = _label("", 16, Color.WHITE, true)
	who.add_child(_greeting)
	_gold = _label("", 22, Palette.GOLD)
	header.add_child(_gold)
	var close_button := _button("Close", close)
	close_button.custom_minimum_size = Vector2(110, 48)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	box.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_label("Weapon", 20, Palette.GOLD))
	_weapons = HFlowContainer.new()
	_weapons.add_theme_constant_override("h_separation", 8)
	_weapons.add_theme_constant_override("v_separation", 6)
	left.add_child(_weapons)
	_weapon_title = _label("", 22, Color.WHITE)
	left.add_child(_weapon_title)
	_weapon_details = _label("", 15, DIM, true)
	left.add_child(_weapon_details)
	_sockets = HBoxContainer.new()
	_sockets.add_theme_constant_override("separation", 12)
	left.add_child(_sockets)
	_action = _button("", take_rune)
	_action.custom_minimum_size = Vector2(0, 52)
	_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_action)
	left.add_child(_label("Setting a rune is free. Taking one out costs gold; you get it back.", 13, DIM, true))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	right.add_child(_label("Your runes", 20, Palette.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_runes = VBoxContainer.new()
	_runes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runes.add_theme_constant_override("separation", 8)
	scroll.add_child(_runes)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	return button


func _icon(texture: Texture2D, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
