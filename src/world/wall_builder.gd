class_name WallBuilder
## Collision for a floor's walls: one rectangle per horizontal run of wall cells (few shapes).


static func build(map: DungeonMap, body: StaticBody2D) -> void:
	var ts := float(map.tile_size)
	for y in map.height:
		var x := 0
		while x < map.width:
			if not map.is_wall_edge(Vector2i(x, y)):
				x += 1
				continue
			var run_start := x
			while x < map.width and map.is_wall_edge(Vector2i(x, y)):
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - run_start) * ts, ts)
			var collision := CollisionShape2D.new()
			collision.shape = shape
			collision.position = Vector2((run_start + x) * 0.5 * ts, (y + 0.5) * ts)
			body.add_child(collision)
