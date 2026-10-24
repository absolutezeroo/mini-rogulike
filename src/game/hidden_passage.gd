class_name HiddenPassage
extends Node
## The way to the hidden floor during a run (HiddenFloorDef, DungeonConfig.hidden_floor), owned
## by the Game. When the boss of one of its acts falls and the hero carries its key, a third way
## opens in the arena (HiddenWay) beside the usual stairs; stepping in is a way down like the
## others (World.stairs_reached with ROUTE): the Game spends the key and goes down. When the
## hidden boss falls: its chest, the bonus souls, the feat counted, and the run goes on to the
## next act by the arena's stairs.

## The `route` the Game gets for the hidden way (the others are 0, 1...).
const ROUTE := -1
const WAY_SCENE: PackedScene = preload("res://src/entities/stairs/hidden_way.tscn")

var game: Game
var def: HiddenFloorDef
## The way opened in this arena (null: none).
var way: HiddenWay


func _ready() -> void:
	Events.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(boss: Monster) -> void:
	way = null
	if def == null or game == null or game.run == null or boss.world != game.world:
		return
	if game.run.hidden_floor:
		_reward()
	elif can_open():
		open_way()


## The way opens here: an act of its list, its boss slain, the key in the bag, not been down yet.
func can_open() -> bool:
	var run := game.run
	return not run.hidden_done and def.opens_after(game.content.dungeon, run.depth) \
		and not game.content.dungeon.is_final_floor(run.depth) and def.carries_key(game.player)


## A run saved in a cleared arena picks up there (FloorSave "arena_cleared"): above, the way
## opens again if the key is still in the bag; below, the hoard waits again (open if it was).
func resume_cleared() -> void:
	way = null
	if def == null or game == null or game.run == null:
		return
	if game.run.hidden_floor:
		if game.run.hidden_done:
			_hoard(true)
	elif can_open():
		open_way(true)


## Tears the way open in the arena, away from the stairs. `quiet`: a resumed run's, opened before
## quitting (no shake, no sound, no line).
func open_way(quiet: bool = false) -> HiddenWay:
	var world := game.world
	var cell := _spot(world)
	if cell == DungeonMap.NO_CELL:
		return null
	way = WAY_SCENE.instantiate() as HiddenWay
	way.glow = def.color
	var route := FloorRoute.new()
	route.biome = def.biome
	way.route = route
	way.position = world.map.cell_to_world(cell)
	way.z_index = -1
	world.add_entity(way)
	way.reached.connect(func() -> void: world.stairs_reached.emit(ROUTE))
	if quiet:
		return way
	Events.screen_shake.emit(0.6)
	Sfx.play_world(Sfx.bank.gate, way.position)
	Vfx.magic(world, way.position, def.color)
	world.flash_light(way.position, def.color, 200.0)
	Events.log_message(tr("The key in your bag turns to ice. Beneath the arena, a sealed way opens."), def.color)
	return way


## A free cell of the arena a few steps from the middle and from the stairs.
func _spot(world: World) -> Vector2i:
	var middle := world.map.boss_room.get_center()
	for offset: Vector2i in [Vector2i(0, 4), Vector2i(0, -4), Vector2i(-5, 0), Vector2i(5, 0), Vector2i(4, 3), Vector2i(-4, 3), Vector2i(4, -3), Vector2i(-4, -3)]:
		var cell := middle + offset
		if world.map.boss_room.has_point(cell) and world.is_free_cell(cell) \
				and world.stairs_cells.all(func(stairs: Vector2i) -> bool: return Vector2(stairs).distance_to(Vector2(cell)) >= 3.0):
			return cell
	var near := world.map.world_to_cell(world.nearest_free_point(world.map.cell_to_world(middle + Vector2i(0, 3))))
	return near if world.map.is_floor(near) else DungeonMap.NO_CELL


## The hero steps in: the key is spent (the Game then goes down).
func spend_key() -> void:
	if game.player and def.key:
		game.player.inventory.remove(def.key)


## The hidden boss fell: once a run, its hoard and its souls.
func _reward() -> void:
	var run := game.run
	if run.hidden_done:
		return
	run.hidden_done = true
	run.bonus_souls += def.bonus_souls
	Events.stat_counted.emit("hidden_bosses", 1)
	_hoard(false)
	Events.log_message(tr("The hidden floor gives up its hoard: +%d souls.") % run.bonus_souls_worth(def.bonus_souls), def.color)
	Events.run_souls_changed.emit()


## The hidden floor's chest, by the middle of the arena. `resumed`: a run picked up after the
## hidden boss fell: opened before quitting, it stands open (FloorSave.restored_chest_cells).
func _hoard(resumed: bool) -> void:
	var world := game.world
	if def.chest == null:
		return
	var cell := world.map.world_to_cell(world.nearest_free_point(world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, -3))))
	var chest := world.spawn_chest(def.chest, cell, false)
	if resumed and world.floor_save.restored_chest_cells.has(cell):
		chest.set_spent()
		world.floor_save.opened_chests.append(cell)
