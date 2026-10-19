class_name DebugPanel
extends Control
## Dev tools, only in debug builds (running from the editor, debug exports): jump to any floor,
## force a curse or a floor event, god mode, gold, levels, items, monsters, temperature...
## Opened from the HUD's DBG button (or F1). Built in code: nothing to maintain in a scene.

signal closed

const BUTTON_SIZE := Vector2(170, 54)

var _game: Game
var _depth := 1
var _monster_index := 0
var _monsters: Array[MonsterDef] = []

var _depth_label: Label
var _monster_label: Label
var _god_button: Button
var _status: Label
var _sections: VBoxContainer


## Debug builds only: everywhere else there is no debug panel at all.
static func is_available() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 24
	panel.offset_right = -40
	panel.offset_bottom = -24
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Debug"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Palette.GOLD)
	_status.add_theme_font_size_override("font_size", 18)
	header.add_child(_status)
	header.add_child(_button("Close", close))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_sections = VBoxContainer.new()
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override("separation", 6)
	scroll.add_child(_sections)


func open(game: Game) -> void:
	_game = game
	if _sections.get_child_count() == 0:
		# Built on first use: the curses, events and monsters come from the game's content.
		_build_floor(_sections)
		_build_hero(_sections)
		_build_monsters(_sections)
	_depth = game.depth
	_god_button.text = _god_text()
	_status.text = ""
	_refresh_labels()
	show()


func close() -> void:
	hide()
	closed.emit()


# --- Sections --------------------------------------------------------------------

func _build_floor(parent: Control) -> void:
	var row := _section(parent, "Floor")
	row.add_child(_button("-", func() -> void: _set_depth(_depth - 1)))
	_depth_label = _label("")
	row.add_child(_depth_label)
	row.add_child(_button("+", func() -> void: _set_depth(_depth + 1)))
	row.add_child(_button("Go there", func() -> void: _go(_depth)))
	row.add_child(_button("Next floor", func() -> void: _go(_game.depth + 1)))
	row.add_child(_button("Rebuild floor", func() -> void: _go(_game.depth)))
	row.add_child(_button("Next boss", func() -> void: _go(_next_boss_depth())))
	row.add_child(_button("Stairs", func() -> void: _act(func() -> void:
		var world := _game.world
		if not world.stairs_cells.is_empty():
			_game.player.global_position = world.map.cell_to_world(world.stairs_cells[0]) + Vector2(0, 40)
		, "To the stairs")))
	row.add_child(_button("Break seal", func() -> void: _act(func() -> void: _game.world.seal.break_now(), "Stairs open")))
	row.add_child(_button("Reveal map", func() -> void: _act(func() -> void: _game.world.reveal_all(), "Map revealed")))

	var curses := _section(parent, "Curse (rebuilds the floor)")
	curses.add_child(_button("None", func() -> void: _go(_game.depth, null, null, true)))
	for curse in _game_content().curses:
		curses.add_child(_button(curse.display_name, func() -> void: _go(maxi(_game.depth, 2), curse)))

	var events := _section(parent, "Floor event (rebuilds the floor)")
	for event in _game_content().floor_events:
		events.add_child(_button(event.display_name, func() -> void: _go(maxi(_game.depth, 2), null, event)))

	var biomes := _section(parent, "Biome (goes to its act)")
	var dungeon := _game_content().dungeon
	for i in dungeon.acts.size():
		for biome in dungeon.acts[i].biomes:
			var depth := dungeon.first_depth(i)
			biomes.add_child(_button("%s: %s" % [dungeon.acts[i].subtitle.trim_prefix("Act "), biome.display_name], func() -> void:
				_game.world.forced_biome = biome
				_go(depth)))


func _build_hero(parent: Control) -> void:
	var row := _section(parent, "Hero")
	_god_button = _button("", func() -> void:
		_game.player.invincible = not _game.player.invincible
		_god_button.text = _god_text())
	row.add_child(_god_button)
	row.add_child(_button("Full heal", func() -> void: _act(func() -> void:
		_game.player.heal(_game.player.get_max_hp())
		_game.player.statuses.clear(), "Healed")))
	row.add_child(_button("+500 gold", func() -> void: _act(func() -> void: _game.player.add_gold(500), "+500 gold")))
	row.add_child(_button("Level up", func() -> void: _act(func() -> void:
		_game.player.gain_xp(_game.player.xp_to_next_level() - _game.player.xp), "Level up")))
	row.add_child(_button("Epic weapon", func() -> void: _act(_give_epic_weapon, "Epic weapon in the bag")))
	row.add_child(_button("All consumables", func() -> void: _act(func() -> void:
		for item in _game_content().items:
			if item is ConsumableDef:
				_game.player.store(item), "Consumables added")))

	var forge := _section(parent, "Forge")
	forge.add_child(_button("Forge here", func() -> void: _act(func() -> void:
		var world: World = _game.world
		var cell := world.map.world_to_cell(world.find_open_point_near(_game.player.global_position + Vector2(70, 0), 40.0))
		world.spawn_forge(_game_content().dungeon.forge, cell), "The smith is here")))
	forge.add_child(_button("Every rune", func() -> void: _act(func() -> void:
		for rune in _game_content().runes:
			_game.player.inventory.add(rune), "Runes in the bag")))

	var heat := _section(parent, "Temperature")
	heat.add_child(_button("Freezing", func() -> void: _act(func() -> void: _game.player.temperature.value = -90.0, "Cold")))
	heat.add_child(_button("Burning", func() -> void: _act(func() -> void: _game.player.temperature.value = 90.0, "Hot")))
	heat.add_child(_button("Normal", func() -> void: _act(func() -> void: _game.player.temperature.reset(), "Normal")))


func _build_monsters(parent: Control) -> void:
	var row := _section(parent, "Monsters")
	row.add_child(_button("<", func() -> void: _cycle_monster(-1)))
	_monster_label = _label("")
	_monster_label.custom_minimum_size.x = 220
	row.add_child(_monster_label)
	row.add_child(_button(">", func() -> void: _cycle_monster(1)))
	row.add_child(_button("Spawn", func() -> void: _act(func() -> void: _spawn(false), "Spawned")))
	row.add_child(_button("Spawn elite", func() -> void: _act(func() -> void: _spawn(true), "Elite spawned")))
	# The rare ranks: spawn one of the chosen monster, or make the next boss one.
	var ranks := _section(parent, "Ranks")
	for rank in _game_content().dungeon.rare_ranks:
		ranks.add_child(_button("Spawn %s" % rank.display_name, func() -> void: _act(func() -> void: _spawn_ranked(rank), "%s spawned" % rank.display_name)))
	for rank in _game_content().dungeon.rare_ranks:
		ranks.add_child(_button("Next boss %s" % rank.display_name, func() -> void: _act(func() -> void: _game.world.forced_boss_rank = rank, "The next boss: %s" % rank.display_name)))
	row.add_child(_button("Kill all", func() -> void: _act(func() -> void:
		for monster in _game.world.get_hostiles(Actor.Faction.PLAYER):
			monster.die(_game.player), "All dead")))
	row.add_child(_button("All asleep", func() -> void: _act(func() -> void:
		for monster in _game.world.get_hostiles(Actor.Faction.PLAYER):
			(monster as Monster).dormant = true
			(monster as Monster).target = null, "Asleep (hit them to wake them)")))


# --- Actions ---------------------------------------------------------------------

## Builds floor `depth` (with that curse or event, or a plain one), then closes the panel.
func _go(depth: int, curse: CurseDef = null, event: FloorEventDef = null, plain: bool = false) -> void:
	hide()
	closed.emit()
	_game.debug_enter_floor(maxi(depth, 1), curse, event, plain)


## Runs `action` and says it happened (the panel stays open).
func _act(action: Callable, message: String) -> void:
	action.call()
	_status.text = message


func _set_depth(depth: int) -> void:
	_depth = clampi(depth, 1, 99)
	_refresh_labels()


func _next_boss_depth() -> int:
	var config := _game_content().dungeon
	for depth in range(_game.depth, _game.depth + 50):
		if config.boss_for_depth(depth):
			return depth
	return _game.depth


func _cycle_monster(step: int) -> void:
	var all := _all_monsters()
	if not all.is_empty():
		_monster_index = posmod(_monster_index + step, all.size())
	_refresh_labels()


func _spawn(elite: bool) -> void:
	var all := _all_monsters()
	if all.is_empty():
		return
	var world := _game.world
	var at := world.find_open_point_near(_game.player.global_position, 90.0)
	var monster := world.spawn_monster(all[_monster_index], at)
	if elite:
		world.make_elite(monster)


func _spawn_ranked(rank: MonsterRankDef) -> void:
	var all := _all_monsters()
	if all.is_empty():
		return
	var world := _game.world
	var monster := world.spawn_monster(all[_monster_index], world.find_open_point_near(_game.player.global_position, 90.0))
	world.make_ranked(monster, rank)


func _give_epic_weapon() -> void:
	var weapons: Array[ItemDef] = []
	for item in _game_content().items:
		if item is WeaponDef:
			weapons.append(item)
	if weapons.is_empty():
		return
	var rolled := _game.world.roll_item(weapons.pick_random(), 50.0)
	_game.player.inventory.add(rolled)


## Every monster of every act, and the bosses.
func _all_monsters() -> Array[MonsterDef]:
	if _monsters.is_empty():
		for act in _game_content().dungeon.acts:
			for monster in act.monsters:
				if not _monsters.has(monster):
					_monsters.append(monster)
			for boss in act.all_bosses():
				if not _monsters.has(boss):
					_monsters.append(boss)
	return _monsters


func _refresh_labels() -> void:
	_depth_label.text = "Depth %d" % _depth
	var all := _all_monsters() if _game else ([] as Array[MonsterDef])
	_monster_label.text = all[_monster_index].display_name if not all.is_empty() else "-"


func _god_text() -> String:
	return "God mode: %s" % ("ON" if _game and _game.player.invincible else "off")


func _game_content() -> ContentDB:
	return _game.content


# --- Widgets ---------------------------------------------------------------------

func _section(parent: Control, title: String) -> HFlowContainer:
	var label := _label(title)
	label.add_theme_color_override("font_color", Color(1, 0.94, 0.82))
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	return row


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		action.call())
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = BUTTON_SIZE.y
	label.add_theme_font_size_override("font_size", 18)
	return label
