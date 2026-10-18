class_name FloorPopulator
## Fills a freshly generated floor with monsters and items.
## The first room is where the player starts, so it stays empty.


static func populate(world: World, content: ContentDB, depth: int) -> void:
	var map := world.map
	var rng := world.rng
	var config := content.dungeon
	if map.rooms.size() < 2:
		return

	var extra := floori(config.extra_monsters_per_depth * (depth - 1))
	for i in range(1, map.rooms.size()):
		var room := map.rooms[i]
		var count := mini(rng.randi_range(config.monsters_per_room_min, config.monsters_per_room_max) + extra, config.max_monsters_per_room)
		for n in count:
			var def := content.pick_monster(depth, rng)
			if def:
				world.spawn_monster(def, _random_point_in(map, room, rng))

	for n in config.items_per_floor:
		var room := map.rooms[rng.randi_range(1, map.rooms.size() - 1)]
		var item := content.pick_item(depth, rng)
		if item:
			world.spawn_item(item, _random_point_in(map, room, rng))


static func _random_point_in(map: DungeonMap, room: Rect2i, rng: RandomNumberGenerator) -> Vector2:
	var jitter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
	return map.cell_to_world(map.random_cell_in(room, rng)) + jitter
