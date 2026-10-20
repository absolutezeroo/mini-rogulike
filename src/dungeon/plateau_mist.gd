class_name PlateauMist
extends Sprite2D
## Mist over the plateau above the walls (and all around the map): instead of a flat color, a
## slow, dark mist with lighter wisps, thin at the rim (the cliff's edge stays readable) and thick
## further in. One sprite over the whole map: its texture is the mask (one pixel per cell, soft
## edges), the shader (plateau_mist.gdshader) does the rest. Colors: DungeonTheme > Mist.

const SHADER := preload("res://src/dungeon/plateau_mist.gdshader")
## How thick the mist is 1, 2 and 3+ cells away from the floor or a cliff face.
const THICKNESS: Array[float] = [0.0, 0.25, 0.65, 1.0]


func _init() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER


## `margin`: cells of plateau drawn around the map (DungeonView.OUTSIDE_MARGIN).
func setup(map: DungeonMap, theme: DungeonTheme, margin: int) -> void:
	visible = theme != null and theme.mist_density > 0.0
	if not visible:
		return
	var look := material as ShaderMaterial
	look.set_shader_parameter("deep_color", theme.mist_deep)
	look.set_shader_parameter("wisp_color", theme.mist_wisp)
	look.set_shader_parameter("density", theme.mist_density)
	texture = ImageTexture.create_from_image(mask_image(map, margin))
	position = Vector2.ONE * -margin * map.tile_size
	scale = Vector2.ONE * map.tile_size


## The mist's thickness per cell (red): 0 on the floor and the cliff faces, more with each cell
## away from them, full outside the map.
static func mask_image(map: DungeonMap, margin: int) -> Image:
	var w := map.width
	var h := map.height
	var depth := PackedInt32Array()
	depth.resize(w * h)
	depth.fill(THICKNESS.size() - 1)
	var queue := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			var low := map.tiles[i] == DungeonMap.Tile.FLOOR or (y + 1 < h and map.tiles[i + w] == DungeonMap.Tile.FLOOR)
			if low:
				depth[i] = 0
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var next_depth := depth[i] + 1
		if next_depth >= THICKNESS.size() - 1:
			continue
		var x := i % w
		var y := i / w
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n := ny * w + nx
				if depth[n] > next_depth:
					depth[n] = next_depth
					queue.append(n)
	var image := Image.create_empty(w + margin * 2, h + margin * 2, false, Image.FORMAT_L8)
	image.fill(Color(1, 1, 1))
	for y in h:
		for x in w:
			var thickness: float = THICKNESS[depth[y * w + x]]
			image.set_pixel(x + margin, y + margin, Color(thickness, thickness, thickness))
	return image
