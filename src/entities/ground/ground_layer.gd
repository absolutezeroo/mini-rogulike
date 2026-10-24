class_name GroundLayer
extends Node2D
## Draws one ground of a floor (GroundLayerDef: sand, moss...) over its cells: a shader rounds
## the patches off, roughens their edges with noise and draws the rim, in the art's chunky pixels.
## Over the floor tiles, under everything else (walls are cut out).

const SHADER := preload("res://src/entities/ground/ground_layer.gdshader")
## Texels per cell of the smoothed ground mask.
const SMOOTHING := 8

var def: GroundLayerDef

## The part of the world drawn (the whole map by default; a pool only its room).
var _area := Rect2()


## `bounds`: the cells the patches can be in (a pool's room), so the shader runs only there;
## empty: the whole map.
func setup(layer: GroundLayerDef, map: DungeonMap, cells: Dictionary, bounds: Rect2i = Rect2i()) -> void:
	def = layer
	z_index = -10  # with the floor tiles, drawn after them
	var ts := float(map.tile_size)
	_area = Rect2(Vector2.ZERO, Vector2(map.width, map.height) * ts)
	if bounds.has_area():
		_area = Rect2(Vector2(bounds.grow(1).position) * ts, Vector2(bounds.grow(1).size) * ts).intersection(_area)
	# One pixel per cell: where the ground is (it also covers the walls right next to it, so
	# that its rim never runs along a wall), then scaled up smoothly: rounded patches.
	# And where the floor is (walls are cut out).
	var ground := Image.create(map.width, map.height, false, Image.FORMAT_L8)
	var floor_mask := Image.create(map.width, map.height, false, Image.FORMAT_L8)
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var here := cells.has(cell)
			if not map.is_floor(cell):
				for dir: Vector2i in GridDirs.FOUR:
					here = here or cells.has(cell + dir)
			ground.set_pixel(x, y, Color.WHITE if here else Color.BLACK)
			floor_mask.set_pixel(x, y, Color.WHITE if map.is_floor(cell) else Color.BLACK)
	ground.resize(map.width * SMOOTHING, map.height * SMOOTHING, Image.INTERPOLATE_CUBIC)
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("ground", ImageTexture.create_from_image(ground))
	look.set_shader_parameter("floor_mask", ImageTexture.create_from_image(floor_mask))
	look.set_shader_parameter("cells", Vector2(map.width, map.height))
	look.set_shader_parameter("cell_size", ts)
	look.set_shader_parameter("tiles", layer.texture)
	look.set_shader_parameter("tiles_size", layer.texture.get_size() if layer.texture else Vector2.ONE)
	look.set_shader_parameter("fill", Vector4(layer.tile.position.x, layer.tile.position.y, layer.tile.size.x, layer.tile.size.y))
	var alt := layer.tile_alt if layer.tile_alt.size != Vector2i.ZERO else layer.tile
	look.set_shader_parameter("fill_alt", Vector4(alt.position.x, alt.position.y, alt.size.x, alt.size.y))
	look.set_shader_parameter("edge_color", layer.edge_color)
	look.set_shader_parameter("roughness", layer.roughness)
	look.set_shader_parameter("shimmer", layer.shimmer)
	material = look


func _draw() -> void:
	draw_rect(_area, Color.WHITE)
