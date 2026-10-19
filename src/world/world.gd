class_name World
extends Node2D
## Everything that exists on the current floor: map, walls, actors, items, projectiles, effects.
## Also the gateway other systems use to spawn things and query the level.

signal stairs_reached
## A new floor was built (the explored map starts over).
signal map_reset
## Cells the hero discovered, or whose look changed (a floor that gave way...). For the minimap.
signal cells_changed(cells: Array[Vector2i])

const MONSTER_SCENE := preload("res://src/entities/monster/monster.tscn")
const PICKUP_SCENE := preload("res://src/entities/pickup/item_pickup.tscn")
const PROJECTILE_SCENE := preload("res://src/entities/projectile/projectile.tscn")
const STAIRS_SCENE := preload("res://src/entities/stairs/stairs.tscn")
const ARENA_SCENE := preload("res://src/world/boss_arena.tscn")
const PROP_SCENE := preload("res://src/entities/prop/prop.tscn")
const TRAP_SCENE := preload("res://src/entities/trap/trap.tscn")
const FLASH_SCENE := preload("res://src/vfx/light_flash.tscn")
## Pixels of a hole's edge you can stand on without falling.
const PIT_EDGE := 6.0

## Goes up with every floor built: delayed effects started on an old floor are dropped.
var floor_id := 0
var map: DungeonMap
var theme: DungeonTheme
var player: Player
var depth := 1
var rng := RandomNumberGenerator.new()
## Difficulty of the run (set by the game before building floors).
var difficulty: DifficultyDef:
	set(value):
		difficulty = value
		if rules:
			rules = FloorRules.make(rules.config, value, floor_event, depth, curse)
## Boss floors only: the arena and its boss (null on normal floors).
var arena: BossArena
## What makes this floor special (null on most floors).
var floor_event: FloorEventDef
## The Well's curse on this whole floor (null on most floors).
var curse: CurseDef
## The world this floor belongs to (a mossy cave, a crypt, desert ruins...): its look, its
## grounds, scenes and decor (FloorDresser). `theme` is its theme.
var biome: BiomeDef
## The grounds laid on this floor (sand, moss...): GroundLayerDef -> cells (Dictionary).
var grounds := {}
## Difficulty, event and depth combined: ask it how hard and rewarding this floor is.
var rules: FloorRules
## Debug (DebugPanel): the next floor built gets this curse or event instead of rolling one
## (and neither if `forced_plain`). Used once.
var forced_curse: CurseDef
var forced_event: FloorEventDef
var forced_plain := false
## Debug: the next floor built is this biome. Used once.
var forced_biome: BiomeDef
## The boss of each act for this run (an act may have several; the game draws one per run).
## Empty or null entries: the act's main boss.
var run_bosses: Array[BossDef] = []
## The floor's ambush room, if it has one.
var ambush: AmbushRoom
## Where the stairs are (boss floors get theirs when the boss dies).
var stairs_cells: Array[Vector2i] = []
## Where walking monsters can go (pathfinding, blocked cells).
var nav := NavGrid.new()
## What the hero has seen (the minimap).
var fog := FogOfWar.new()

var _content: ContentDB
## What lies on the floor's cells, by cell or by kind (asked every frame: no group scans).
var _cracks := {}
var _heat_sources: Array[HeatSource] = []
var _splats: SplatLayer
var _dark_rooms: Array[DarkRoom] = []

@onready var _view: DungeonView = $DungeonView
@onready var _pits: PitLayer = $Pits
@onready var _walls: StaticBody2D = $Walls
@onready var _entities: Node2D = $Entities
@onready var _projectiles: Node2D = $Projectiles
@onready var _effects: Node2D = $Effects
@onready var _ambient: CanvasModulate = $Ambient


# --- Floor lifecycle ---------------------------------------------------------

func build_floor(new_depth: int, content: ContentDB) -> void:
	clear_floor()
	floor_id += 1
	depth = new_depth
	_content = content
	var boss := content.dungeon.boss_for_depth(depth)
	var act_index := content.dungeon.act_index(depth)
	if boss and act_index < run_bosses.size() and run_bosses[act_index] != null:
		boss = run_bosses[act_index]
	floor_event = null
	curse = null
	if forced_curse or forced_event or forced_plain:
		curse = forced_curse
		floor_event = forced_event
		forced_curse = null
		forced_event = null
		forced_plain = false
	elif boss == null and depth > 1:
		var curse_chance := difficulty.curse_chance if difficulty else 0.0
		if rng.randf() < curse_chance:
			curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
		if curse == null and rng.randf() < content.dungeon.floor_event_chance:
			floor_event = ContentDB.pick_from(content.floor_events, depth, rng) as FloorEventDef
	if boss:
		map = DungeonGenerator.generate_arena(content.dungeon, rng)
	else:
		map = DungeonGenerator.generate(content.dungeon, rng)
	biome = _pick_biome(content, boss != null)
	theme = biome.theme if biome else null
	rules = FloorRules.make(content.dungeon, difficulty, floor_event, depth, curse)
	_ambient.color = Color((theme.ambient if theme else Color.WHITE) * rules.light(), 1.0)
	_view.show_map(map, theme)
	_pits.setup(map.tile_size)
	fog.reset(map)
	stairs_cells.clear()
	WallBuilder.build(map, _walls)
	nav.build(map)
	if boss:
		# No stairs until the boss is dead: the arena spawns them.
		arena = ARENA_SCENE.instantiate() as BossArena
		_entities.add_child(arena)
		arena.setup(self, boss)
		for room in map.rooms:
			FloorPopulator.place_lights(self, content.dungeon, room, {})
		FloorDresser.dress(self, {}, false)  # the arena keeps clear: grounds and decor only
	else:
		spawn_stairs(map.stairs_cell)
		FloorPopulator.populate(self, content, depth)
	map_reset.emit()


## Removes everything from the floor except the player.
func clear_floor() -> void:
	arena = null
	ambush = null
	_cracks.clear()
	grounds.clear()
	_heat_sources.clear()
	_dark_rooms.clear()
	if _pits:
		_pits.clear()
	for layer: Node in [_entities, _projectiles, _effects, _walls]:
		for child in layer.get_children():
			if child != player:
				layer.remove_child(child)
				child.queue_free()


func place_player(new_player: Player) -> void:
	player = new_player
	player.world = self
	if player.get_parent() == null:
		_entities.add_child(player)
	player.global_position = map.cell_to_world(map.start_cell)
	player.temperature.reset()
	player.reset_safe_position()
	player.camera.reset_smoothing()


# --- Spawning ----------------------------------------------------------------

func spawn_monster(def: MonsterDef, at: Vector2) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.world = self
	monster.setup(def, depth, _content.dungeon)
	monster.position = at
	_entities.add_child(monster)
	return monster


## Found loot: equipment may come out Magic, Rare or Epic (see LootRoller). `quality` above 1
## for better sources (elites, chests, bosses).
## A consumable the hero already carries plenty of comes as gold instead
## (DungeonConfig.consumable_carry_cap): then this returns null.
func spawn_loot(item: ItemDef, at: Vector2, quality: float = 1.0) -> ItemPickup:
	if item is ConsumableDef and player and player.carried_count(item) >= config().consumable_carry_cap:
		spawn_gold(at, maxi(2, roundi(item.value * 0.3)))
		return null
	return spawn_item(roll_item(item, quality * rules.loot_quality()), at)


## `item`, or a better rolled copy of it if it is equipment.
func roll_item(item: ItemDef, quality: float = 1.0) -> ItemDef:
	return LootRoller.roll(item, depth, quality, config(), _content.item_affixes, rng)


## Coins on the floor, split in a few piles that fly to the hero when close.
func spawn_gold(at: Vector2, amount: int) -> void:
	amount = rules.gold(amount)
	if amount <= 0:
		return
	var piles := clampi(ceili(amount / 4.0), 1, 6)
	for i in piles:
		var share := floori(float(amount) / piles) + (1 if i < amount % piles else 0)
		if share <= 0:
			continue
		var coin := GoldPickup.create(at, share, self)
		_entities.add_child.call_deferred(coin)


func spawn_encounter(def: EncounterDef, cell: Vector2i) -> Encounter:
	var encounter := Encounter.new()
	encounter.setup(def, self)
	_place_on_cell(encounter, cell)
	return encounter


func spawn_merchant(def: ShopDef, cell: Vector2i) -> Merchant:
	var merchant := Merchant.new()
	merchant.setup(def, self)
	_place_on_cell(merchant, cell)
	return merchant


## Puts `node` on `cell` among the entities; it blocks the cell for pathfinding unless told not to.
func _place_on_cell(node: Node2D, cell: Vector2i, blocks: bool = true) -> void:
	node.position = map.cell_to_world(cell)
	_entities.add_child(node)
	if blocks:
		set_cell_blocked(cell, true)


func spawn_item(item: ItemDef, at: Vector2, armed: bool = true) -> ItemPickup:
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.setup(item, armed)
	pickup.position = at
	_entities.add_child.call_deferred(pickup)  # may be called from physics callbacks
	return pickup


## Fires a volley. Spread is spread evenly; 360 degrees makes a full ring.
## The shooter's perks can change the volley first (extra projectiles...).
func fire_projectiles(shooter: Actor, direction: Vector2, spec: ProjectileSpec) -> void:
	shooter.perks.modify_projectiles(shooter, spec)
	for i in spec.count:
		var angle := 0.0
		if spec.spread_degrees >= 360.0:
			angle = 360.0 * i / spec.count
		elif spec.count > 1:
			angle = lerpf(-spec.spread_degrees * 0.5, spec.spread_degrees * 0.5, float(i) / (spec.count - 1))
		var shot_direction := direction.rotated(deg_to_rad(angle))
		var projectile := PROJECTILE_SCENE.instantiate() as Projectile
		projectile.setup(shooter, shot_direction, spec)
		projectile.position = shooter.global_position + shot_direction * (shooter.radius * 0.5)
		_projectiles.add_child.call_deferred(projectile)


## This floor's biome: one of its act's (the debug one if forced).
func _pick_biome(content: ContentDB, boss: bool) -> BiomeDef:
	var forced := forced_biome
	forced_biome = null
	if forced:
		return forced
	var act := content.dungeon.act_for_depth(depth)
	return act.pick_biome(depth, boss, rng) if act else null


## Props stand on a cell (the top-left one of a bigger footprint) and block it until they break.
func spawn_prop(def: PropDef, cell: Vector2i) -> Prop:
	var prop := PROP_SCENE.instantiate() as Prop
	prop.world = self
	prop.setup(def)
	_place_on_cell(prop, cell)
	if def.footprint != Vector2i.ONE:
		prop.position += (Vector2(def.footprint) - Vector2.ONE) * map.tile_size * 0.5
		for y in def.footprint.y:
			for x in def.footprint.x:
				set_cell_blocked(cell + Vector2i(x, y), true)
	return prop


## A framed floor (3x3 tiles in `region` of `tiles`) over `cells`: a carpet, a mosaic...
func spawn_floor_patch(tiles: Texture2D, region: Rect2i, cells: Rect2i) -> FloorPatch:
	var patch := FloorPatch.new()
	patch.setup(tiles, region, self, cells)
	_effects.add_child(patch)
	return patch


func spawn_trap(def: TrapDef, cell: Vector2i, cycle_offset: float = 0.0) -> Trap:
	var trap := TRAP_SCENE.instantiate() as Trap
	trap.world = self
	trap.setup(def, cycle_offset)
	_place_on_cell(trap, cell, false)
	return trap


## Monsters roll to be elites with the floor's chance (DungeonConfig > Elites, the difficulty).
func roll_elite(monster: Monster) -> void:
	if rng.randf() < rules.elite_chance():
		make_elite(monster)


func make_elite(monster: Monster) -> void:
	var affix := _content.pick_affix(depth, rng)
	if affix:
		monster.make_elite(affix, config())


func spawn_chest(def: ChestDef, cell: Vector2i, trapped: bool) -> Chest:
	var chest := Chest.new()
	chest.setup(def, self, trapped)
	_place_on_cell(chest, cell)
	return chest


func spawn_ambush(room: Rect2i) -> AmbushRoom:
	ambush = AmbushRoom.new()
	_entities.add_child(ambush)
	ambush.setup(self, room)
	return ambush


func spawn_crumbling_floor(def: PitDef, cell: Vector2i) -> CrumblingFloor:
	var tile := CrumblingFloor.new()
	tile.setup(def, self, cell)
	_effects.add_child(tile)
	_cracks[cell] = tile
	return tile


## Cracked floor gives way under whoever walks on it: one lookup per actor, not one scan per crack.
func _step_on_cracks() -> void:
	if _cracks.is_empty():
		return
	for actor in get_actors():
		if actor.is_grounded():
			var crack: CrumblingFloor = _cracks.get(map.world_to_cell(actor.global_position))
			if crack and is_instance_valid(crack):
				crack.step_on()


func forget_crack(cell: Vector2i) -> void:
	_cracks.erase(cell)


func spawn_heat_source(def: HeatSourceDef, rect: Rect2i) -> HeatSource:
	var source := HeatSource.new()
	source.setup(def, self, rect)
	_effects.add_child(source)
	_heat_sources.append(source)
	return source


## The floor's campfires, springs and hot or frozen ground (see BodyTemperature).
func get_heat_sources() -> Array[HeatSource]:
	_heat_sources = _heat_sources.filter(func(source: Variant) -> bool:
		return is_instance_valid(source) and not (source as Node).is_queued_for_deletion())
	return _heat_sources


func has_heat_source_in(def: HeatSourceDef, room: Rect2i) -> bool:
	return get_heat_sources().any(func(source: HeatSource) -> bool: return source.def == def and source.rect == room)


func spawn_dark_room(def: DarkRoomDef, room: Rect2i) -> DarkRoom:
	var dark := DarkRoom.new()
	dark.setup(def, self, room)
	_effects.add_child(dark)
	_dark_rooms.append(dark)
	return dark


func is_dark_room(room: Rect2i) -> bool:
	_dark_rooms = _dark_rooms.filter(func(dark: Variant) -> bool:
		return is_instance_valid(dark) and not (dark as Node).is_queued_for_deletion())
	return _dark_rooms.any(func(dark: DarkRoom) -> bool: return dark.room == room)


func spawn_quicksand(def: QuicksandDef, rect: Rect2i) -> Quicksand:
	var pool := Quicksand.new()
	pool.setup(def, self, rect)
	_effects.add_child(pool)
	return pool


## A shot from the dungeon itself (arrow traps): it hurts players and monsters alike.
func fire_trap_projectile(from: Vector2, direction: Vector2, spec: ProjectileSpec) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.setup_trap(self, direction, spec)
	projectile.position = from
	_projectiles.add_child.call_deferred(projectile)


## A short burst of light (explosions...).
func flash_light(at: Vector2, color: Color, size: float) -> void:
	var flash := FLASH_SCENE.instantiate() as LightFlash
	flash.position = at
	flash.setup(color, size)
	_effects.add_child(flash)


func spawn_stairs(cell: Vector2i) -> Stairs:
	var stairs := STAIRS_SCENE.instantiate() as Stairs
	if theme:
		stairs.texture = theme.stairs_texture()
	stairs.position = map.cell_to_world(cell)
	stairs.reached.connect(func() -> void: stairs_reached.emit())
	stairs_cells.append(cell)
	stairs.z_index = -1
	_entities.add_child(stairs)
	return stairs


func spawn_vfx(node: Node2D) -> void:
	_effects.add_child(node)


## Blood, slime, ink... on the floor (SplatLayer). Nothing over walls or holes.
func add_splat(at: Vector2, color: Color, size: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if color.a <= 0.0 or not is_solid_ground(at):
		return
	if _splats == null or not is_instance_valid(_splats) or _splats.is_queued_for_deletion():
		_splats = SplatLayer.new()
		_effects.add_child(_splats)
	_splats.add(at, color, size, direction, rng)


func splat_count() -> int:
	return _splats.count() if _splats and is_instance_valid(_splats) and not _splats.is_queued_for_deletion() else 0


func spawn_floating_text(at: Vector2, text: String, color: Color) -> void:
	spawn_vfx(FloatingText.create(at, text, color))


# --- Holes ------------------------------------------------------------------

## Makes `cell` a hole: anyone standing on it falls, monsters path around it.
func add_pit(cell: Vector2i, def: PitDef) -> void:
	_pits.add(cell, def)
	set_cell_blocked(cell, true)
	cells_changed.emit([cell] as Array[Vector2i])


func has_pit(cell: Vector2i) -> bool:
	return _pits.has(cell)


## The hole under `point`, if it is well inside one (a few pixels of edge are forgiven).
func pit_under(point: Vector2) -> PitDef:
	var def := _pits.get_def(map.world_to_cell(point))
	if def == null:
		return null
	for offset: Vector2 in [Vector2(PIT_EDGE, 0), Vector2(-PIT_EDGE, 0), Vector2(0, PIT_EDGE), Vector2(0, -PIT_EDGE)]:
		if not _pits.has(map.world_to_cell(point + offset)):
			return null
	return def


## Floor that can't give way: no hole, no cracked floor (where the hero climbs out after a fall).
## Solid ground nothing stands on (no wall, hole, crack, chest, encounter, prop...).
func is_free_cell(cell: Vector2i) -> bool:
	return is_solid_ground(map.cell_to_world(cell)) and not nav.is_blocked(cell)


func is_solid_ground(point: Vector2) -> bool:
	var cell := map.world_to_cell(point)
	if not map.is_floor(cell) or _pits.has(cell):
		return false
	var crack: CrumblingFloor = _cracks.get(cell)
	if crack and is_instance_valid(crack) and not crack.is_queued_for_deletion():
		return false
	return true


# --- Exploration -------------------------------------------------------------

func is_explored(cell: Vector2i) -> bool:
	return fog.is_explored(cell)


## The whole floor on the map (debug).
func reveal_all() -> void:
	cells_changed.emit(fog.reveal_all())


## Reveals the room the hero stands in (all of it) and a few cells around them.
func reveal_around(point: Vector2) -> void:
	var revealed := fog.reveal_around(point)
	if not revealed.is_empty():
		cells_changed.emit(revealed)


func _physics_process(_delta: float) -> void:
	if player and map and not player.is_dead:
		reveal_around(player.global_position)
	_step_on_cracks()


# --- Queries -----------------------------------------------------------------

func config() -> DungeonConfig:
	return _content.dungeon


## A monster of the current act (ambushes, trapped chests).
func pick_monster() -> MonsterDef:
	return _content.pick_monster(depth, rng)


## A random item that can be found on this floor (chests, elite drops).
func pick_random_item() -> ItemDef:
	return _content.pick_item(depth, rng)


## Living actors that are enemies of `faction`.
func get_hostiles(faction: Actor.Faction) -> Array[Actor]:
	var result: Array[Actor] = []
	if faction == Actor.Faction.PLAYER:
		for node in get_tree().get_nodes_in_group("monsters"):
			var monster := node as Actor
			if monster and not monster.is_dead and monster.is_inside_tree():
				result.append(monster)
	elif player and not player.is_dead:
		result.append(player)
	return result


## Every living actor, whatever its side (traps and explosions hurt everyone).
func get_actors() -> Array[Actor]:
	var result: Array[Actor] = get_hostiles(Actor.Faction.PLAYER)
	if player and not player.is_dead:
		result.append(player)
	return result


## Props that can still be broken.
func get_breakable_props() -> Array[Prop]:
	var result: Array[Prop] = []
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop and not prop.is_broken and prop.def.is_breakable() and prop.is_inside_tree():
			result.append(prop)
	return result


## Marks a cell as an obstacle (or free again) for monster pathfinding.
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	nav.set_blocked(cell, blocked)


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Path between two world positions, as a list of cell centres (empty if unreachable).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return nav.find_path(from, to)


## A walkable point about `distance` away from `center`, in sight of it (or `center` itself).
## Never over a hole or cracked floor.
func find_open_point_near(center: Vector2, distance: float) -> Vector2:
	for attempt in 10:
		var point := center + Vector2.from_angle(rng.randf() * TAU) * distance
		if is_solid_ground(point) and has_line_of_sight(center, point):
			return point
	return center


func monster_count() -> int:
	return get_hostiles(Actor.Faction.PLAYER).size()
