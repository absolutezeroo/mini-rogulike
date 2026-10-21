class_name World
extends Node2D
## Everything that exists on the current floor: map, walls, actors, items, projectiles, effects.
## Also the gateway other systems use to spawn things and query the level.

## The hero took a way down: `route` is its index in `next_routes` (0 when there is no choice).
signal stairs_reached(route: int)
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
## Boss floors only: the arena and its boss (null on normal floors), and its plan (ArenaDef).
var arena: BossArena
var arena_plan: ArenaDef
## Debug: the next arena is this one. Used once.
var forced_arena: ArenaDef
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
## The ways down from this floor (FloorRoute), set by the Game before the floor is built.
## Two or more: each stairs leads to one, its sign says where. Empty: one stairs, no choice.
var next_routes: Array[FloorRoute] = []
## The way the hero took to this floor (null: none to choose, or the first floor).
var route: FloorRoute
## The run's rules from the Tree of Souls and its oath (RunBoons), set by the Game.
var boons := RunBoons.new()

## Debug: the next floor built is this biome. Used once.
var forced_biome: BiomeDef
## Debug: the next boss comes at this rank. Used once.
var forced_boss_rank: MonsterRankDef
## The boss of each act for this run (an act may have several; the game draws one per run).
## Empty or null entries: the act's main boss.
var run_bosses: Array[BossDef] = []
## The floor's ambush room, if it has one.
var ambush: AmbushRoom
## Merchant stock the hero locked and didn't buy: { item, price, locked } entries waiting for the
## next merchant (see Merchant). Lives as long as the run.
var kept_stock: Array[Dictionary] = []
## Floors in a row without the smith's forge (each makes the next more likely).
var floors_without_forge := 0
## The same, when this floor began (what a save keeps: a resumed run makes the floor again).
var forge_drought_at_start := 0
## What the hero already took from this floor (a resumed run rebuilds the same floor from its
## seed: these stay taken). Cells of opened chests, items bought from the merchant (saved form).
var opened_chests: Array[Vector2i] = []
var bought: Array = []
## Set before rebuilding a saved floor (restore_spent), used once by build_floor.
var _to_restore := {}
## Where the stairs are (boss floors get theirs when the boss dies).
var stairs_cells: Array[Vector2i] = []
## Normal floors: the stairs open once enough of the floor's monsters are slain.
var seal := StairsSeal.new()
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
## When the hero was last told the stairs are sealed (seconds).
var _blocked_note_at := -10.0
## The monsters thinking this moment (the others sleep: off screen and far from the hero).
## Refreshed a few times a second (see _update_activity()).
var awake_monsters: Array = []  # (untyped: one may be freed before the next refresh)
var _activity_timer := 0.0
## Seconds between two looks at who sleeps and who wakes.
const ACTIVITY_INTERVAL := 0.2
## Monsters this far past the screen's edge still think (they may walk in any moment).
const WAKE_MARGIN := 256.0

@onready var _view: DungeonView = $DungeonView
@onready var _pits: PitLayer = $Pits
@onready var _walls: StaticBody2D = $Walls
@onready var _entities: Node2D = $Entities
@onready var _projectiles: Node2D = $Projectiles
@onready var _effects: Node2D = $Effects
## The floor's light, in steps (lamps, torch, glowing shots, flashes).
@onready var lights: LightField = $Lights


# --- Floor lifecycle ---------------------------------------------------------

func _ready() -> void:
	Events.monster_killed.connect(_on_monster_killed)
	seal.broken.connect(_on_seal_broken)


## `taken`: the way down the hero chose to get here (its world, curse or event), or null.
func build_floor(new_depth: int, content: ContentDB, taken: FloorRoute = null) -> void:
	clear_floor()
	route = taken
	floor_id += 1
	depth = new_depth
	opened_chests.clear()
	bought.clear()
	forge_drought_at_start = floors_without_forge
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
	elif taken != null and boss == null:
		curse = taken.curse
		floor_event = taken.floor_event
	elif boss == null and depth > 1:
		var curse_chance := difficulty.curse_chance if difficulty else 0.0
		if rng.randf() < curse_chance:
			curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
		if curse == null and rng.randf() < content.dungeon.floor_event_chance:
			floor_event = ContentDB.pick_from(content.floor_events, depth, rng) as FloorEventDef
	arena_plan = null
	if boss:
		arena_plan = _pick_arena(boss, content.dungeon)
		map = DungeonGenerator.generate_arena(content.dungeon, rng, arena_plan)
	else:
		map = DungeonGenerator.generate(content.dungeon, rng, difficulty.floor_size if difficulty else 1.0, difficulty.rooms if difficulty else 1.0)
	biome = _pick_biome(content, boss != null)
	theme = biome.theme if biome else null
	rules = FloorRules.make(content.dungeon, difficulty, floor_event, depth, curse)
	var light_tint := rules.light()
	if floor_event:
		light_tint *= floor_event.ambient_tint
	_view.show_map(map, theme)
	lights.setup(map, theme.lighting if theme else null, light_tint)
	_view.mist.bind_light(lights)
	_pits.setup(map.tile_size)
	fog.reset(map)
	stairs_cells.clear()
	WallBuilder.build(map, _walls)
	nav.build(map)
	if boss:
		# No stairs until the boss is dead: the arena spawns them.
		arena = ARENA_SCENE.instantiate() as BossArena
		_entities.add_child(arena)
		arena.setup(self, boss, arena_plan)
		for room in map.rooms:
			FloorPopulator.place_lights(self, content.dungeon, room, {})
		FloorDresser.dress(self, {}, false)  # the arena keeps clear: grounds and decor only
		seal.clear()
	else:
		var exits := spawn_exits()
		FloorPopulator.populate(self, content, depth)
		seal.reset(monster_count(), content.dungeon.seal_share, content.dungeon.seal_reveal_left, content.dungeon.seal_max)
		for stairs in exits:
			stairs.bind_seal(seal)
			stairs.blocked.connect(_on_stairs_blocked)
		_apply_restore()
		if boons.cartographer:
			reveal_landmarks()
	map_reset.emit()


## Removes everything from the floor except the player.
func clear_floor() -> void:
	for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.world_of() == self:
			kept_stock.append_array(merchant.locked_entries())
			merchant.remove_from_group("merchants")  # counted once
	arena = null
	ambush = null
	awake_monsters.clear()
	_activity_timer = 0.0
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
	player.perks.on_floor_started(player)
	player.camera.reset_smoothing()


# --- Spawning ----------------------------------------------------------------

## The bestiary's rules (mastered kinds take more damage), or null.
func bestiary_rules() -> BestiaryRules:
	return _content.bestiary if _content else null


## (Awake until the next look at who sleeps: see _update_activity().)
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
	return spawn_item(roll_item(item, quality * rules.loot_quality() * boons.loot_quality_scale), at)


## `item`, or a better rolled copy of it if it is equipment.
func roll_item(item: ItemDef, quality: float = 1.0) -> ItemDef:
	return LootRoller.roll(item, depth, quality, config(), _content.item_affixes, rng)


## Coins on the floor, split in a few piles that fly to the hero when close.
func spawn_gold(at: Vector2, amount: int) -> void:
	amount = roundi(rules.gold(amount) * boons.gold_scale)
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


func spawn_forge(def: ForgeDef, cell: Vector2i) -> Forge:
	var forge := Forge.new()
	forge.setup(def, self)
	_place_on_cell(forge, cell)
	return forge


## A rune for this floor (null if none).
func pick_rune() -> RuneDef:
	return _content.pick_rune(depth, rng) if _content else null


## Drops a rune at `at` (`chance`: 1 = always).
func drop_rune(at: Vector2, chance: float = 1.0) -> void:
	if chance < 1.0 and rng.randf() >= chance:
		return
	var rune := pick_rune()
	if rune:
		spawn_item(rune, at)


func spawn_merchant(def: ShopDef, cell: Vector2i) -> Merchant:
	var merchant := Merchant.new()
	merchant.setup(def, self)
	_place_on_cell(merchant, cell)
	return merchant


## The locked stock waiting for the next merchant, plus what is locked at this floor's
## merchant (for save files: a saved run rebuilds its floor).
func locked_stock() -> Array[Dictionary]:
	var result := kept_stock.duplicate()
	for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.world_of() == self:
			result.append_array(merchant.locked_entries())
	return result


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
## `from`: where it starts (the shooter by default; shards bursting out of a body...).
func fire_projectiles(shooter: Actor, direction: Vector2, spec: ProjectileSpec, from: Vector2 = Vector2.INF) -> void:
	if not spec.secondary:  # shards and rings fired by passives get no extra projectiles
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
		if from == Vector2.INF:
			projectile.position = shooter.global_position + shot_direction * (shooter.radius * 0.5)
		else:
			projectile.position = from + shot_direction * 6.0
		_projectiles.add_child.call_deferred(projectile)


## The boss' own arenas, else the dungeon's; null for a plain room.
func _pick_arena(boss: BossDef, config: DungeonConfig) -> ArenaDef:
	var forced := forced_arena
	forced_arena = null
	if forced:
		return forced
	var pool: Array[ArenaDef] = boss.arenas if not boss.arenas.is_empty() else config.arenas
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## This floor's biome: one of its act's (the debug one if forced).
func _pick_biome(content: ContentDB, boss: bool) -> BiomeDef:
	var forced := forced_biome
	forced_biome = null
	if forced:
		return forced
	if route and route.biome and not boss:
		return route.biome
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
## Maybe raises a freshly spawned monster's rank: the rare ranks first (Shiny, Legendary,
## Epic: DungeonConfig.rare_ranks), then the plain elite.
func roll_elite(monster: Monster) -> void:
	for rank in config().rare_ranks:
		if rank and rng.randf() < rules.rank_chance(rank):
			make_ranked(monster, rank)
			return
	if rng.randf() < rules.elite_chance():
		make_elite(monster)


## A boss may come at a rare rank too (a Legendary Vampiric King Slime...). `forced_boss_rank`
## (debug) wins once.
func roll_boss_rank(boss: Monster) -> void:
	var forced := forced_boss_rank
	forced_boss_rank = null
	if forced:
		make_ranked(boss, forced)
		return
	for rank in config().rare_ranks:
		if rank and rng.randf() < rank.boss_chance * rules.difficulty.elite_chance:
			make_ranked(boss, rank)
			return


func make_elite(monster: Monster) -> void:
	make_ranked(monster, config().elite_rank)


## `rank` with as many different affixes as it asks for.
func make_ranked(monster: Monster, rank: MonsterRankDef) -> void:
	var picked: Array[EliteAffixDef] = []
	for attempt in rank.affixes * 6:
		if picked.size() >= rank.affixes:
			break
		var affix := _content.pick_affix(depth, rng)
		if affix and not picked.has(affix):
			picked.append(affix)
	monster.make_ranked(rank, picked)


func spawn_chest(def: ChestDef, cell: Vector2i, trapped: bool) -> Chest:
	var chest := Chest.new()
	chest.setup(def, self, trapped)
	_place_on_cell(chest, cell)
	chest.opened.connect(func(_chest: Chest) -> void: opened_chests.append(cell))
	return chest


## What was taken from this floor, for a save file.
func spent_data() -> Dictionary:
	return {
		"chests": opened_chests.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]),
		"bought": bought.duplicate(),
	}


## The next floor built is the saved one again: what was taken from it stays taken.
func restore_spent(data: Dictionary) -> void:
	_to_restore = data


func _apply_restore() -> void:
	if _to_restore.is_empty():
		return
	var data := _to_restore
	_to_restore = {}
	var cells: Array[Vector2i] = []
	for pair: Array in data.get("chests", []):
		if pair.size() == 2:
			cells.append(Vector2i(int(pair[0]), int(pair[1])))
	for node in _entities.get_children():
		var chest := node as Chest
		if chest and cells.has(map.world_to_cell(chest.global_position)):
			chest.set_spent()
			opened_chests.append(map.world_to_cell(chest.global_position))
	for saved_item: Variant in data.get("bought", []):
		for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
			if merchant.world_of() == self and merchant.forget_sold(saved_item):
				bought.append(saved_item)
				break


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


# --- The stairs' seal -------------------------------------------------------

func _on_monster_killed(monster: Monster) -> void:
	if monster.world == self:
		seal.add_kill()


## The way down opens, and a guiding light shows it.
func _on_seal_broken() -> void:
	var stairs_at := map.cell_to_world(map.stairs_cell)
	Sfx.play_at(Sfx.bank.gate, player.global_position if player else stairs_at)
	if stairs_cells.size() >= 2 and next_routes.size() >= 2:
		Events.log_message(tr("The seal breaks: two ways down. %s, or %s.") % [next_routes[0].summary(), next_routes[1].summary()], Palette.GOLD)
	else:
		Events.log_message(tr("The seal breaks: the stairs are open!"), Palette.GOLD)
	for cell in stairs_cells:
		flash_light(map.cell_to_world(cell), Palette.GOLD, 220.0)
	if player:
		for cell in stairs_cells:
			var path := find_path(player.global_position, map.cell_to_world(cell))
			if not path.is_empty():
				spawn_vfx(GuideWisp.create(player.global_position + Vector2(0, -18), path))
	reward_clear()


## The floor is won (its stairs open, or its boss fell): the Regeneration node heals the hero.
func reward_clear() -> void:
	if player == null or player.is_dead or boons.heal_on_clear <= 0.0:
		return
	var healed := player.heal(roundi(player.get_max_hp() * boons.heal_on_clear))
	if healed > 0:
		spawn_floating_text(player.head_position(), "+%d" % healed, Palette.HEAL)


## Elites and up drop a Magic (or better) piece of equipment (the Trophy Hunter node).
func drop_trophy(at: Vector2) -> void:
	for i in 20:
		var item := pick_random_item() as EquipmentDef
		if item:
			spawn_item(LootRoller.roll(item, depth, rules.loot_quality() * boons.loot_quality_scale, config(), _content.item_affixes, rng, ItemRarity.MAGIC), at)
			return


## The hero stepped on sealed stairs: say what is missing (not every frame).
func _on_stairs_blocked() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blocked_note_at < 2.0:
		return
	_blocked_note_at = now
	Sfx.play_ui(Sfx.bank.ui_close, -4.0)
	var sealed := tr("Sealed. Slay %d more monster to open the stairs.") if seal.left() == 1 else tr("Sealed. Slay %d more monsters to open the stairs.")
	Events.log_message(sealed % seal.left(), Palette.SEAL)


## The floor's way down, or two when `next_routes` offers a choice (each with its sign).
func spawn_exits() -> Array[Stairs]:
	var result: Array[Stairs] = []
	var choice := next_routes.size() >= 2 and map.second_stairs_cell != DungeonMap.NO_CELL
	result.append(spawn_stairs(map.stairs_cell, 0, next_routes[0] if choice else null))
	if choice:
		result.append(spawn_stairs(map.second_stairs_cell, 1, next_routes[1]))
	return result


## Stairs at `cell`; `index` and `way`: the route they lead to (null: no sign).
func spawn_stairs(cell: Vector2i, index: int = 0, way: FloorRoute = null) -> Stairs:
	var stairs := STAIRS_SCENE.instantiate() as Stairs
	if theme:
		stairs.texture = theme.stairs_texture()
	stairs.position = map.cell_to_world(cell)
	stairs.route = way
	stairs.reached.connect(func() -> void: stairs_reached.emit(index))
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
	_splat_layer().add(at, color, size, direction, rng)


## Chips of what a monster was made of, left where it died for the whole floor.
func add_debris(at: Vector2, material: ImpactMaterialDef, size: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if not is_solid_ground(at):
		return
	_splat_layer().add_debris(at, material, size, direction, rng, is_solid_ground)


func _splat_layer() -> SplatLayer:
	if _splats == null or not is_instance_valid(_splats) or _splats.is_queued_for_deletion():
		_splats = SplatLayer.new()
		_effects.add_child(_splats)
	return _splats


## Chips flung on this floor so far.
func debris_count() -> int:
	return _splats.chip_count() if _splats and is_instance_valid(_splats) and not _splats.is_queued_for_deletion() else 0


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


## The centre of the free cell nearest to `point` (itself if free; `point` if none is found).
func nearest_free_point(point: Vector2, max_radius: int = 12) -> Vector2:
	var origin := map.world_to_cell(point)
	for radius in max_radius + 1:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != radius:
					continue  # only the ring at this radius
				var cell := Vector2i(x, y)
				var distance := map.cell_to_world(cell).distance_squared_to(point)
				if distance < best_distance and is_free_cell(cell):
					best = cell
					best_distance = distance
		if best != Vector2i(-1, -1):
			return map.cell_to_world(best)
	return point


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


## The Cartographer node: the stairs, the merchant and the forge on the minimap from the start.
func reveal_landmarks() -> void:
	var spots: Array[Vector2i] = stairs_cells.duplicate()
	for group in ["merchants", "forges"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_ancestor_of(node):
				spots.append(map.world_to_cell((node as Node2D).global_position))
	var revealed: Array[Vector2i] = []
	for spot in spots:
		revealed.append_array(fog.reveal_rect(Rect2i(spot - Vector2i(2, 2), Vector2i(5, 5))))
	if not revealed.is_empty():
		cells_changed.emit(revealed)


## Reveals the room the hero stands in (all of it) and a few cells around them.
func reveal_around(point: Vector2) -> void:
	var revealed := fog.reveal_around(point)
	if not revealed.is_empty():
		cells_changed.emit(revealed)


func _physics_process(delta: float) -> void:
	if player and map and not player.is_dead:
		reveal_around(player.global_position)
	_step_on_cracks()
	_activity_timer -= delta
	if _activity_timer <= 0.0:
		_activity_timer = ACTIVITY_INTERVAL
		_update_activity()


## What isn't seen isn't run: monsters off screen (with a margin) and out of reach of the hero
## sleep, unless they are after someone or are a boss. Their bodies stay (shots still hit them).
func _update_activity() -> void:
	awake_monsters.clear()
	var view := view_rect(WAKE_MARGIN)
	var hero := player.global_position if player and is_instance_valid(player) else Vector2.INF
	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster == null or monster.is_dead or monster.is_queued_for_deletion():
			continue
		var awake := monster.target != null or monster.is_boss() or monster.is_falling \
			or view.has_point(monster.global_position) \
			or (hero != Vector2.INF and monster.global_position.distance_to(hero) <= monster.detect_radius() * 1.6 + 64.0)
		monster.set_awake(awake)
		if awake:
			awake_monsters.append(monster)


# --- Queries -----------------------------------------------------------------

func config() -> DungeonConfig:
	return _content.dungeon


## A monster of the current act (ambushes, trapped chests).
func pick_monster() -> MonsterDef:
	return _content.pick_monster(depth, rng)


## A random item that can be found on this floor (chests, elite drops).
func pick_random_item() -> ItemDef:
	return _content.pick_item(depth, rng)


## A boss fight is on: the arena's boss is awake and alive (healing from hits and kills is
## slower, its adds feed no heals: see SustainRules, Monster.can_heal_killer()).
func is_boss_fight() -> bool:
	return is_instance_valid(arena) and arena.is_started and is_instance_valid(arena.boss) and not arena.boss.is_dead


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


var _actors_frame := -1
var _actors_cache: Array[Actor] = []
var _view_frame := -1
var _view_cache := Rect2()


## get_actors(), worked out once per frame for everyone who asks (plants, quicksand...).
## Read only: the same array is handed to everyone.
func actors_this_frame() -> Array[Actor]:
	var frame := Engine.get_process_frames()
	if frame != _actors_frame:
		_actors_frame = frame
		_actors_cache = get_actors()
	return _actors_cache


## The part of the world on screen (with a margin), once per frame: what lies outside needn't
## be redrawn.
func view_rect(margin: float = 96.0) -> Rect2:
	var frame := Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
		if camera:
			var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
			_view_cache = Rect2(camera.get_screen_center_position() - half, half * 2.0)
		else:
			_view_cache = Rect2(-1e6, -1e6, 2e6, 2e6)
	return _view_cache.grow(margin)


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
