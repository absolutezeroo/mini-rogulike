class_name RoomFeatures
## Lays what the shaped rooms' plans hold (RoomShapeDef, DungeonMap.features and .pillars) on a
## freshly built floor, before anything else is placed: chasms (holes in the biome's look of
## holes: a fall sends the hero into the Deeps, as any hole), pools (deep water, WaterPool) and pillars
## (props: the shape's own, or one of the biome's for the whole hall). A biome or a dungeon
## without a look for chasms or pools leaves plain floor there.


static func lay(world: World) -> void:
	var map := world.map
	if map.features.is_empty() and map.pillars.is_empty():
		return
	var config := world.config()
	var biome := world.biome
	var chasm: PitDef = biome.chasm if biome and biome.chasm else (config.chasm if config else null)
	var water: GroundLayerDef = biome.pool if biome and biome.pool else (config.pool if config else null)
	var holes: Array[Vector2i] = []
	var pools := {}  # room index -> {cell: true}
	for cell: Vector2i in map.features.keys():
		match map.features[cell]:
			DungeonMap.Feature.CHASM:
				if chasm:
					holes.append(cell)
				else:
					map.features.erase(cell)
			DungeonMap.Feature.POOL:
				if water:
					var room := map.room_at(cell)
					if not pools.has(room):
						pools[room] = {}
					pools[room][cell] = true
				else:
					map.features.erase(cell)
	if not holes.is_empty():
		world.add_pits(holes, chasm)
	for room: int in pools:
		var bounds := map.rooms[room] if room >= 0 else Rect2i()
		world.spawn_pool(pools[room], water, bounds)
	var kinds := {}  # room index -> the PropDef of its pillars
	for cell: Vector2i in map.pillars.keys():
		var room: int = map.pillars[cell]
		if not kinds.has(room):
			kinds[room] = _pillar_for(map.plan(room).shape, biome, config, world.rng)
		var prop: PropDef = kinds[room]
		if prop:
			world.spawn_prop(prop, cell)
		else:
			map.pillars.erase(cell)


## What stands in a hall of `shape`: its own pillar, else one of the biome's, else the dungeon's.
static func _pillar_for(shape: RoomShapeDef, biome: BiomeDef, config: DungeonConfig, rng: RandomNumberGenerator) -> PropDef:
	if shape and shape.pillar:
		return shape.pillar
	if biome and not biome.pillars.is_empty():
		return biome.pillars[rng.randi() % biome.pillars.size()]
	return config.pillar if config else null
