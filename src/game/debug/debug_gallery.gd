class_name DebugGallery
extends RefCounted
## The debug panel's gallery (DebugPanel, Gallery tab): seeing the game's content without playing
## to it. Two things, both built by the World's own floor builder, never by a builder of their own:
##
## - **A biome's floor**: any biome (the acts', the hidden floor's, the Deeps' dressing, the bottom
##   of the Well) as a plain floor of its act, its map revealed. Optionally every room (but the
##   first, where the hero arrives) in one of its room shapes, or its signature room for sure, and
##   another biome's ceiling (or none). This works on a copy of the BiomeDef (`variant()`): the
##   generator and the dresser read it as they read any biome, nothing in them knows the gallery.
## - **A monster gallery**: a hall (one big room, `hall()`) handed to the World as its next map
##   (World.forced_map), in the chosen biome's look, every monster of a scope (an act with its
##   bosses, the hidden floor, the Deeps, the bottom of the Well, or all of them) standing in rows,
##   its name under its feet. No AI and the hero invisible are turned on with it.
##
## Both make the run a debug run (DebugCheats.mark_run()): nothing of it is kept.

## Pixels between two bodies in a row, and between two rows (over their own sizes).
const GAP := 40.0
const ROW_GAP := 70.0
## A row is never wider than this many pixels (the hall then gets another row).
const ROW_WIDTH := 1700.0
## Pixels more over a boss's row.
const BOSS_HEADROOM := 110.0
## Cells of floor around the rows (the hero walks round them).
const HALL_MARGIN := 4

## One scope of the monster gallery: its name, its monsters (bosses last), the depth they are
## set up for.
class Scope:
	var name := ""
	var monsters: Array[MonsterDef] = []
	var depth := 1

	func _init(scope_name: String, depth_value: int) -> void:
		name = scope_name
		depth = depth_value

	func add(def: MonsterDef) -> void:
		# A boss's other forms (BossDef.next_boss) stand beside it.
		while def != null and not monsters.has(def):
			monsters.append(def)
			def = (def as BossDef).next_boss if def is BossDef else null


# --- Biomes --------------------------------------------------------------------------------

## Every biome of the game: the acts' (their floors' and their bosses'), the hidden floor's, the
## Deeps' dressing, the bottom of the Well's.
static func biomes(content: ContentDB) -> Array[BiomeDef]:
	var found: Array[BiomeDef] = []
	var dungeon := content.dungeon
	var all: Array = []
	for act in dungeon.acts:
		all.append_array(act.biomes)
		all.append(act.boss_biome)
	if dungeon.hidden_floor:
		all.append(dungeon.hidden_floor.biome)
	if dungeon.abyss:
		all.append(dungeon.abyss.dressing)
	if dungeon.finale:
		all.append(dungeon.finale.biome)
	for biome: BiomeDef in all:
		if biome and not found.has(biome):
			found.append(biome)
	return found


## The depth a floor of `biome` is built at: the first floor of the act it belongs to (no boss
## there); the last act's for a biome no act uses.
static func depth_for(content: ContentDB, biome: BiomeDef) -> int:
	var dungeon := content.dungeon
	for i in dungeon.acts.size():
		if dungeon.acts[i].biomes.has(biome) or dungeon.acts[i].boss_biome == biome:
			return dungeon.first_depth(i)
	return dungeon.first_depth(maxi(dungeon.acts.size() - 1, 0))


## `biome`'s room shapes and signature rooms, the shapes the gallery can force.
static func shapes_of(biome: BiomeDef) -> Array[RoomShapeDef]:
	var found: Array[RoomShapeDef] = []
	for shape in biome.room_shapes + biome.set_pieces:
		if shape and not found.has(shape):
			found.append(shape)
	return found


## Every ceiling a biome has (the gallery can hang any of them over any biome).
static func ceilings(content: ContentDB) -> Array[CeilingDef]:
	var found: Array[CeilingDef] = []
	for biome in biomes(content):
		if biome.ceiling and not found.has(biome.ceiling):
			found.append(biome.ceiling)
	return found


## A copy of `biome` for one floor: every room but the first in `shape` (a signature room: that one
## for sure, the others as usual), under `ceiling`. `shape` null: its rooms as usual.
## `keep_ceiling`: its own ceiling (`ceiling` is then ignored; null with it off: none).
static func variant(biome: BiomeDef, shape: RoomShapeDef, ceiling: CeilingDef, keep_ceiling: bool) -> BiomeDef:
	var copy := biome.duplicate() as BiomeDef
	if not keep_ceiling:
		copy.ceiling = ceiling
	if shape == null:
		return copy
	var forced := shape.duplicate() as RoomShapeDef
	forced.min_depth = 1  # whatever the depth it is built at
	if biome.set_pieces.has(shape):
		copy.set_pieces = [forced] as Array[RoomShapeDef]
		copy.set_piece_chance = 1.0
	else:
		forced.spawn_weight = 100
		forced.max_per_floor = 0
		copy.room_shapes = [forced] as Array[RoomShapeDef]
		copy.plain_weight = 0
		copy.set_pieces = [] as Array[RoomShapeDef]
	return copy


# --- Monsters ------------------------------------------------------------------------------

## The monster gallery's scopes: each act (its monsters, then its bosses), the hidden floor, the
## Deeps, the bottom of the Well, then everything.
static func scopes(content: ContentDB) -> Array[Scope]:
	var result: Array[Scope] = []
	var dungeon := content.dungeon
	var everything := Scope.new("Everything", 1)
	for i in dungeon.acts.size():
		var act := dungeon.acts[i]
		var scope := Scope.new("%s: %s" % [act.subtitle, act.title], dungeon.first_depth(i))
		for monster in act.monsters:
			scope.add(monster)
		for boss in act.all_bosses():
			scope.add(boss)
		result.append(scope)
	var hidden := dungeon.hidden_floor
	if hidden:
		var after := hidden.key_acts[0] + 1 if not hidden.key_acts.is_empty() else 1  # the act its way leads to
		var scope := Scope.new(hidden.title, dungeon.first_depth(mini(after, dungeon.acts.size() - 1)))
		for monster in hidden.monsters:
			scope.add(monster)
		scope.add(hidden.boss)
		result.append(scope)
	if dungeon.abyss:
		var scope := Scope.new("The Deeps", 1)
		for monster in content.abyss_monsters():
			scope.add(monster)
		result.append(scope)
	if dungeon.finale:
		var scope := Scope.new(dungeon.finale.title, dungeon.first_depth(maxi(dungeon.acts.size() - 1, 0)))
		scope.add(dungeon.finale.boss)
		result.append(scope)
	for scope in result:
		for monster in scope.monsters:
			if not monster is BossDef:
				everything.add(monster)
	for scope in result:
		for monster in scope.monsters:
			if monster is BossDef:
				everything.add(monster)
	result.append(everything)
	return result


## A hall for `monsters` (bosses on rows of their own): one big room, the hero's start under the
## last row, the stairs in its bottom-right corner. `spots`: where each one stands (world pixels),
## in the same order. Returns { map, spots }.
static func hall(config: DungeonConfig, monsters: Array[MonsterDef]) -> Dictionary:
	var tile := config.tile_size
	var rows: Array[Array] = []  # each: indexes into monsters
	var row: Array = []
	var row_width := 0.0
	var boss_rows := false
	for i in monsters.size():
		var def := monsters[i]
		var width := _footprint(def)
		if not row.is_empty() and (row_width + width > ROW_WIDTH or (def is BossDef and not boss_rows)):
			rows.append(row)
			row = []
			row_width = 0.0
		boss_rows = boss_rows or def is BossDef
		row.append(i)
		row_width += width
	if not row.is_empty():
		rows.append(row)
	# Sizes, in pixels: the widest row, the rows' heights.
	var widest := 0.0
	var height := 0.0
	var heights: Array[float] = []
	for indexes: Array in rows:
		var width := 0.0
		var tallest := 0.0
		for i: int in indexes:
			width += _footprint(monsters[i])
			tallest = maxf(tallest, _height(monsters[i]))
		widest = maxf(widest, width)
		heights.append(tallest)
		height += tallest + ROW_GAP
	var cells := Vector2i(ceili(widest / tile) + HALL_MARGIN * 2, ceili(height / tile) + HALL_MARGIN * 2 + 4)
	cells = Vector2i(clampi(cells.x, 16, config.width - 6), clampi(cells.y, 14, config.height - 6))
	var map := DungeonMap.new(config.width, config.height, tile)
	var room := Rect2i(Vector2i((config.width - cells.x) / 2, (config.height - cells.y) / 2), cells)
	for y in room.size.y:
		for x in room.size.x:
			map.set_floor(room.position + Vector2i(x, y))
	map.rooms.append(room)
	map.boss_room = room  # (no ceiling over the rows: CeilingLayer leaves the boss room clear)
	map.start_cell = Vector2i(room.get_center().x, room.end.y - 2)
	map.stairs_cell = room.end - Vector2i(2, 2)
	# The rows, centred, from the top.
	var spots: Array[Vector2] = []
	spots.resize(monsters.size())
	var top := float((room.position.y + HALL_MARGIN) * tile)
	for r in rows.size():
		var indexes: Array = rows[r]
		var width := 0.0
		for i: int in indexes:
			width += _footprint(monsters[i])
		var x := room.get_center().x * tile + tile * 0.5 - width * 0.5
		var feet := top + heights[r]
		for i: int in indexes:
			var footprint := _footprint(monsters[i])
			spots[i] = Vector2(x + footprint * 0.5, feet - _label_room())
			x += footprint
		top += heights[r] + ROW_GAP
	# The hero just under the last row (the bosses), in sight of them.
	map.start_cell = Vector2i(room.get_center().x, clampi(map.world_to_cell(Vector2(0, top)).y + 1, room.position.y + 1, room.end.y - 2))
	return { "map": map, "spots": spots }


## Puts `monsters` at `spots` on `world` (its floor built from hall()), each with its name under
## its feet. Returns them.
static func fill(world: World, monsters: Array[MonsterDef], spots: Array[Vector2]) -> Array[Monster]:
	var placed: Array[Monster] = []
	for i in mini(monsters.size(), spots.size()):
		var monster := world.spawn_monster(monsters[i], spots[i])
		monster.add_child(NameTag.new(monster))
		placed.append(monster)
	return placed


## Width a body takes in a row.
static func _footprint(def: MonsterDef) -> float:
	return maxf(World.room_for(def) * 2.0, def.radius * 2.0) + GAP + 40.0


## Height a body takes in a row (its sprite over its feet, its name under them). A boss gets more
## (a wyrm's body trails behind its head, wings spread over the row above).
static func _height(def: MonsterDef) -> float:
	return def.head_height + def.radius + _label_room() + (BOSS_HEADROOM if def is BossDef else 0.0)


static func _label_room() -> float:
	return 26.0


## A monster's name under its feet, in the gallery. Drawn again every frame (its letters stay on
## whole screen pixels as the camera moves: Fonts.draw()); none with the camera zoomed far out
## (DebugCheats.zoom()), where the names would run into one another.
class NameTag:
	extends Node2D

	## Below this zoom factor the names are left out.
	const MIN_ZOOM := 0.7

	var _monster: Monster

	func _init(monster: Monster) -> void:
		_monster = monster
		z_index = 50
		position = Vector2(0, monster.radius + 16.0)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if is_instance_valid(_monster) and DebugCheats.zoom() >= MIN_ZOOM:
			var color := Palette.DANGER if _monster.is_boss() else Color(1, 0.94, 0.82)
			Fonts.draw(self, Vector2.ZERO, _monster.display_name, Fonts.SMALL, color, 0.5)
