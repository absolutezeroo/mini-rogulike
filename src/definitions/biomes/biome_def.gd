class_name BiomeDef
extends ContentDef
## The world a whole floor belongs to: a mossy cave, an underground garden, a crypt, an abandoned
## library, desert ruins... Every floor is one biome from end to end (ActDef.biomes): its tiles,
## light and music (`theme`), the grounds spread over its floor in organic patches (`grounds`),
## its hand-made little scenes (`scenes`) and the small things lying around (`decor`).
## Nothing from another biome ever shows up. See FloorDresser for how a floor gets dressed.

@export var theme: DungeonTheme
## Sand, moss, carpets... over the floor tiles, in patches shaped by noise.
@export var grounds: Array[GroundLayerDef] = []
## Little scenes made by hand (a reading corner, a camp, a grave row...), placed in the rooms.
@export var scenes: Array[SceneDef] = []
## Small things nobody bumps into (bones, books, grass...), clustered by noise.
@export var decor: Array[DecorRuleDef] = []
## Scenes in a big room (at least `big_room_area` cells) and in a smaller one.
@export var scenes_big_room: Vector2i = Vector2i(2, 3)
@export var scenes_small_room: Vector2i = Vector2i(1, 2)
@export var big_room_area: int = 80
## Its lights (braziers, candles...); null: the dungeon's lanterns.
@export var light: PropDef
## Its pots, crates and baskets, along the walls in small groups; empty: the dungeon's
## (ContentDB.props).
@export var props: Array[PropDef] = []
## Its traps and hazards; empty: the act's.
@export var hazards: Array[HazardDef] = []

@export_group("Rooms")
## The shapes its rooms may take (round halls, pillared halls, rings, chasms...), each by its
## `spawn_weight` from its `min_depth`; a plain rectangle weighs `plain_weight`. The first room
## (where the hero arrives) is always a plain one. See RoomShapeDef, DungeonGenerator.
@export var room_shapes: Array[RoomShapeDef] = []
@export_range(0, 1000) var plain_weight: int = 40
## Its signature rooms (RoomShapeDef with `set_piece`: a drowned hall, a pyre circle...): one of
## them on `set_piece_chance` of its floors.
@export var set_pieces: Array[RoomShapeDef] = []
@export_range(0.0, 1.0) var set_piece_chance: float = 0.4
## What stands in its pillared halls (one kind per hall); empty: the shape's own pillar.
@export var pillars: Array[PropDef] = []
## The look of its chasms (a hole, PitDef) and pools (deep water, GroundLayerDef); null: the
## dungeon's (DungeonConfig.chasm, DungeonConfig.pool).
@export var chasm: PitDef
@export var pool: GroundLayerDef

@export_group("Ceiling")
## What hangs over its rooms, drawn over the actors and fading around them (CeilingDef): roots,
## chains, banners, broken arches... null: nothing overhead.
@export var ceiling: CeilingDef


func pick_prop(content: ContentDB, depth: int, rng: RandomNumberGenerator) -> PropDef:
	if props.is_empty():
		return content.pick_prop(depth, rng)
	return ContentDB.pick_from(props, depth, rng) as PropDef


func pick_hazard(act: ActDef, depth: int, rng: RandomNumberGenerator) -> HazardDef:
	if hazards.is_empty():
		return act.pick_hazard(depth, rng) if act else null
	return ContentDB.pick_from(hazards, depth, rng) as HazardDef
