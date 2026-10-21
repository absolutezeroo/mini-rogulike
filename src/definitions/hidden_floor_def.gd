class_name HiddenFloorDef
extends Resource
## The hidden floor between two acts (DungeonConfig.hidden_floor). Its key lies in a secret room
## of one of `key_acts` (SecretRoom, `key_chance`); slaying that act's boss with the key in the
## bag opens a third, sealed way in the arena (HiddenPassage). Down it: one floor of its own look
## (`biome`), its own monsters, its own boss in an arena, then the next act as usual. Once a run.
## The floor keeps the depth of the boss before it (RunState.hidden_floor): its monsters and its
## boss scale like that floor's, and the run's numbering, splits and records stay the same.

@export var id: StringName
## Its name: the card, the banner, the sign over the way down.
@export var title: String
## Over the title on its card (an act says "Act II").
@export var subtitle: String = "Between the Acts"
## Its card's line of story.
@export_multiline var lore: String
## What opens the way (a KeyItemDef, carried in the bag).
@export var key: ItemDef
## Acts (indexes in DungeonConfig.acts: 0 is Act I) whose secret rooms may hold the key and
## whose boss opens the way. Looping in endless mode, the same acts count again.
@export var key_acts: Array[int] = [1]
## Chance for a secret room of those acts to hold the key (while the run has none and has not
## been down yet), instead of its own reward.
@export_range(0.0, 1.0) var key_chance: float = 0.5

@export_group("The floor")
## Its look, grounds and decor (a biome no act uses).
@export var biome: BiomeDef
## Its monsters, by spawn weight (min_depth is not asked: the list is its own).
@export var monsters: Array[MonsterDef] = []
## Rooms before the arena (a start room comes first).
@export_range(1, 6) var rooms: int = 3
@export var monsters_per_room: Vector2i = Vector2i(2, 4)
## Its boss (its BossDef.arenas, or the dungeon's).
@export var boss: BossDef

@export_group("Rewards")
## Appears in the arena when its boss falls, beside the usual relic choice.
@export var chest: ChestDef
## Souls added to the run when its boss falls (times the difficulty's souls, like the rest).
@export_range(0, 500) var bonus_souls: int = 60

@export_group("Look")
## The light of the sealed way and of its key.
@export var color: Color = Color(0.62, 0.86, 1.0)


## The key, if a secret room of `world`'s floor may hold it now (its act, the run not down yet,
## the hero without one). Null otherwise.
func key_for(world: World) -> ItemDef:
	if key == null or world.hidden_floor_done or world.hidden_floor != null:
		return null
	if not key_acts.has(world.config().act_index(world.depth)):
		return null
	var hero := world.player
	if hero and is_instance_valid(hero) and not hero.is_queued_for_deletion() and carries_key(hero):
		return null
	return key


## The boss of the floor at `depth` opens the way (when the hero carries the key).
func opens_after(config: DungeonConfig, depth: int) -> bool:
	return config.boss_for_depth(depth) != null and key_acts.has(config.act_index(depth))


func carries_key(player: Player) -> bool:
	return key != null and player.inventory.count_of(key) > 0


## Its title card, as an act's (ActCard shows acts).
func as_act() -> ActDef:
	var act := ActDef.new()
	act.title = title
	act.subtitle = subtitle
	act.lore = lore
	if biome:
		act.biomes = [biome]
	act.floors = 1
	return act


## Fills the rooms before the arena with its monsters (not the start room, not the arena).
func populate(world: World) -> void:
	var map := world.map
	var rng := world.rng
	for i in range(1, map.rooms.size() - 1):
		var room := map.rooms[i]
		for n in rng.randi_range(monsters_per_room.x, monsters_per_room.y):
			var def := pick_monster(rng)
			if def == null:
				return
			var cell := map.random_cell_in(room, rng)
			var at := world.nearest_free_point(map.cell_to_world(cell))
			world.roll_elite(world.spawn_monster(def, at))


## One of its monsters, by spawn weight.
func pick_monster(rng: RandomNumberGenerator) -> MonsterDef:
	var weights := PackedInt32Array()
	for monster in monsters:
		weights.append(monster.spawn_weight if monster else 0)
	return RandomUtils.pick_weighted(monsters, weights, rng) as MonsterDef
