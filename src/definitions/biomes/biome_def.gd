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


func pick_prop(content: ContentDB, depth: int, rng: RandomNumberGenerator) -> PropDef:
	if props.is_empty():
		return content.pick_prop(depth, rng)
	return ContentDB.pick_from(props, depth, rng) as PropDef


func pick_hazard(act: ActDef, depth: int, rng: RandomNumberGenerator) -> HazardDef:
	if hazards.is_empty():
		return act.pick_hazard(depth, rng) if act else null
	return ContentDB.pick_from(hazards, depth, rng) as HazardDef
