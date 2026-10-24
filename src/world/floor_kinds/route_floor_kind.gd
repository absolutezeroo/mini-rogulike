class_name RouteFloorKind
extends NormalFloorKind
## A normal floor reached by a way the hero chose (FloorRoute, a sign over each stairs): the
## way's world and twist instead of rolling them.

## The way taken.
var way: FloorRoute


func _init(taken: FloorRoute) -> void:
	way = taken


func twist(_world: World, _content: ContentDB) -> FloorRoute:
	return way


func _own_biome() -> BiomeDef:
	return way.biome
