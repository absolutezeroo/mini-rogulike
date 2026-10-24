class_name ForcedFloorKind
extends FloorKind
## Any kind of floor with the debug panel's twist instead of its own (FloorOverrides: a curse, an
## event, or a plain floor), a warden's included. Everything else is the wrapped kind's.

var inner: FloorKind
var forced: FloorRoute


func _init(wrapped: FloorKind, twist_forced: FloorRoute) -> void:
	inner = wrapped
	forced = twist_forced


func boss() -> BossDef:
	return inner.boss()


func twist(_world: World, _content: ContentDB) -> FloorRoute:
	return forced


func pick_biome(world: World, content: ContentDB) -> BiomeDef:
	return inner.pick_biome(world, content)


func pick_arena(world: World, content: ContentDB) -> ArenaDef:
	return inner.pick_arena(world, content)


func generate(world: World, content: ContentDB) -> DungeonMap:
	return inner.generate(world, content)


func lay(world: World, content: ContentDB) -> void:
	inner.lay(world, content)
