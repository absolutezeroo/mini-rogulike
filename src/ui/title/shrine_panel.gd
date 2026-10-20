class_name ShrinePanel
extends Control
## The shrine, in the game's skin (MenuWindow): spend souls on upgrades that last for every run.
## Left, what souls are (brought back from every run, kept forever) and how many you have;
## right, the upgrades by kind (stronger hero, head start, perk choices, new items), each with
## its level, what the next level adds and its price (UpgradeRow).
## Built in code; %Souls, %Rows and %ShrineText are reachable from the title screen.

const ROW_SCENE: PackedScene = preload("res://src/ui/title/upgrade_row.tscn")
const LEFT_WIDTH := 330.0

## The groups of the list, in order: kinds, heading, what they are.
const GROUPS := [
	[[UpgradeDef.Kind.STATS], "Stronger in every run",
		"Your hero's starting stats, for good."],
	[[UpgradeDef.Kind.STARTING_ITEMS, UpgradeDef.Kind.STARTING_PERK], "Head start",
		"What you carry from the first floor of every run."],
	[[UpgradeDef.Kind.REROLLS, UpgradeDef.Kind.BANISHES], "Perk choices",
		"At each level up you pick one of three perk cards. A reroll deals new cards; a banish removes a perk for the rest of the run."],
	[[UpgradeDef.Kind.UNLOCK], "New items in the dungeon",
		"Buy once: these weapons and armor can then drop in every run."],
]

var _upgrades: Array[UpgradeDef] = []

var _window: MenuWindow
var _souls: Label
var _souls_big: Label
var _bought: Label
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	Profile.changed.connect(_refresh)


func open(upgrades: Array[UpgradeDef]) -> void:
	_upgrades = upgrades
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var shown: Array[UpgradeDef] = []
	for group: Array in GROUPS:
		var members := upgrades.filter(func(u: UpgradeDef) -> bool: return (group[0] as Array).has(u.kind))
		_add_group(group[1], group[2], members)
		shown.append_array(members)
	# Any other kind (added later), at the end.
	_add_group("More", "", upgrades.filter(func(u: UpgradeDef) -> bool: return not shown.has(u)))
	_refresh()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()


## The upgrade rows (the headings between them left out).
func rows() -> Array[UpgradeRow]:
	var result: Array[UpgradeRow] = []
	for child in _rows.get_children():
		if child is UpgradeRow:
			result.append(child)
	return result


func _add_group(heading: String, text: String, members: Array) -> void:
	if members.is_empty():
		return
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	if _rows.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 6
		head.add_child(gap)
	head.add_child(UiSkin.label(heading, 19, UiSkin.GOLD))
	if not text.is_empty():
		head.add_child(UiSkin.label(text, 14, UiSkin.DIM, true))
	_rows.add_child(head)
	for upgrade: UpgradeDef in members:
		var row := ROW_SCENE.instantiate() as UpgradeRow
		_rows.add_child(row)
		row.setup(upgrade)
		row.buy_requested.connect(_buy)


func _buy(upgrade: UpgradeDef) -> void:
	if Profile.buy(upgrade):
		Sfx.play_ui(Sfx.bank.perk_chosen)


func _refresh() -> void:
	_souls.text = "Souls %d" % Profile.souls
	_souls_big.text = str(Profile.souls)
	var levels := 0
	var bought := 0
	for upgrade in _upgrades:
		levels += upgrade.max_level
		bought += mini(Profile.level_of(upgrade), upgrade.max_level)
	_bought.text = "Upgrade levels bought: %d / %d" % [bought, levels]
	for row in rows():
		row.refresh()


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = MenuWindow.new("The Shrine")
	_window.close_requested.connect(close)
	add_child(_window)
	var scene_owner: Node = owner if owner != null else self
	var flavor := UiSkin.label("", 16, UiSkin.DIM, true)
	flavor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.header_left.add_child(flavor)
	MenuWindow.expose(flavor, "ShrineText", scene_owner)
	_souls = UiSkin.label("", 22, MenuWindow.SOULS)
	_window.header_right.add_child(_souls)
	MenuWindow.expose(_souls, "Souls", scene_owner)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)

	# Left: what souls are.
	var left: Dictionary = RpgWindow.section("Your souls")
	(left.box as Control).custom_minimum_size.x = LEFT_WIDTH
	columns.add_child(left.box)
	var column: VBoxContainer = left.column
	var count := HBoxContainer.new()
	count.add_theme_constant_override("separation", 10)
	column.add_child(count)
	_souls_big = UiSkin.label("0", 40, MenuWindow.SOULS)
	count.add_child(_souls_big)
	var unit := UiSkin.label("souls to spend", 17, MenuWindow.SOULS)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.add_child(unit)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 8)
	scroll.add_child(words)
	for line in [
		"Every run brings souls back, even if you die: about 1 per monster, 5 per floor, 20 per boss, 100 for a win.",
		"Harder difficulties, quests and achievements give more.",
		"Souls are kept forever: what you buy here lasts for every run.",
	]:
		words.add_child(UiSkin.label(line, 15, UiSkin.TEXT, true))
	words.add_child(UiSkin.label("Gold is different: it only lasts for the run you are in.", 15, UiSkin.GOLD, true))
	_bought = UiSkin.label("", 15, UiSkin.GOLD, true)
	column.add_child(_bought)

	# Right: the upgrades.
	var right: Dictionary = RpgWindow.section("Upgrades: they last for every run")
	(right.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right.box)
	var list := ScrollContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.column.add_child(list)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	list.add_child(_rows)
	MenuWindow.expose(_rows, "Rows", scene_owner)
