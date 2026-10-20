class_name BuildWindow
extends RpgWindow
## "Your perks", opened from the bag: every family with how many of its perks you hold and what
## its bonus does (awake or not yet), and every perk you took with its level and what it does.
## So the little icons under the health bar always have their words somewhere.

const ICON := Vector2(40, 40)

var _families: VBoxContainer
var _perks: VBoxContainer


func _init() -> void:
	super._init("Your perks")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	var left := RpgWindow.section("Families  -  hold 3 perks of one to awaken its bonus")
	left.box.custom_minimum_size.x = 470
	left.box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(left.box)
	_families = VBoxContainer.new()
	_families.add_theme_constant_override("separation", 6)
	left.column.add_child(_scrolling(_families))
	var right := RpgWindow.section("Perks taken this run")
	right.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right.box)
	_perks = VBoxContainer.new()
	_perks.add_theme_constant_override("separation", 8)
	right.column.add_child(_scrolling(_perks))


func show_build(owned: PerkSet, families: Array[SynergyDef]) -> void:
	for list: Container in [_families, _perks]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	# The families you started first (awake, then the closest), then the others.
	var sorted := families.duplicate()
	sorted.sort_custom(func(a: SynergyDef, b: SynergyDef) -> bool:
		return _rank(owned, a) > _rank(owned, b))
	for synergy: SynergyDef in sorted:
		_families.add_child(PerkCard.family_box(synergy, owned, null))
	if owned.entries.is_empty():
		_perks.add_child(UiSkin.label("No perk yet: you pick one at every level up.", 16, UiSkin.DIM, true))
	for entry in owned.entries:
		_perks.add_child(_perk_row(entry))
	show()


static func _rank(owned: PerkSet, synergy: SynergyDef) -> float:
	return (100.0 if owned.is_awake(synergy) else 0.0) + owned.pieces_of(synergy)


func _perk_row(entry: PerkSet.Entry) -> Control:
	var perk := entry.perk
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = perk.icon
	icon.custom_minimum_size = ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	var families := ", ".join(perk.synergies.filter(func(s: SynergyDef) -> bool: return s != null).map(func(s: SynergyDef) -> String: return s.display_name))
	var head := "%s   Level %d / %d" % [perk.display_name, entry.stacks, perk.max_stacks]
	column.add_child(UiSkin.label(head, 18, perk.color.lerp(Color.WHITE, 0.4)))
	column.add_child(UiSkin.label(perk.describe(), 14, UiSkin.TEXT, true))
	if not families.is_empty():
		column.add_child(UiSkin.label("Family: %s" % families, 13, UiSkin.DIM))
	return row


func _scrolling(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	TouchScroll.attach(scroll)
	return scroll
