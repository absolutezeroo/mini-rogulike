class_name NineSlice
## Draws 3x3 tiles (corners, edges, middle) stretched over a rect of cells: framed floors, ponds.


## `region`: the 3x3 block in `texture` (48x48 for 16 px tiles). `area`: where, in the canvas'
## space, `cells` cells of `cell_size` pixels.
static func draw(canvas: CanvasItem, texture: Texture2D, region: Rect2i, area: Rect2, cells: Vector2i, cell_size: float) -> void:
	var tile := Vector2i(Vector2(region.size) / 3.0)
	for y in cells.y:
		for x in cells.x:
			var column := 0 if x == 0 else (2 if x == cells.x - 1 else 1)
			var row := 0 if y == 0 else (2 if y == cells.y - 1 else 1)
			var source := Rect2(region.position + Vector2i(column * tile.x, row * tile.y), tile)
			canvas.draw_texture_rect_region(texture, Rect2(area.position + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size)), source)
