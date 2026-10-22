class_name AtmosphereLayer
extends Node2D
## The air of a floor (see atmosphere.gdshader): leaf shadows, mist, water light, shafts of
## light, set by its AmbienceDef. Covers what the camera sees, in world space.

const SHADER := preload("res://src/world/atmosphere/atmosphere.gdshader")
const MARGIN := 64.0

var _look: ShaderMaterial


## Nothing to draw: returns null.
static func create(def: AmbienceDef, map: DungeonMap) -> AtmosphereLayer:
	if def == null or (def.canopy <= 0.0 and def.mist_color.a <= 0.0 and def.caustics_color.a <= 0.0 and def.rays_color.a <= 0.0):
		return null
	var layer := AtmosphereLayer.new()
	layer.z_index = 8  # over the floor and whoever walks on it, under the HUD
	var mask := Image.create(map.width, map.height, false, Image.FORMAT_L8)
	for y in map.height:
		for x in map.width:
			if map.is_floor(Vector2i(x, y)):
				mask.set_pixel(x, y, Color.WHITE)
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("floor_mask", ImageTexture.create_from_image(mask))
	look.set_shader_parameter("cells", Vector2(map.width, map.height))
	look.set_shader_parameter("cell_size", float(map.tile_size))
	look.set_shader_parameter("canopy", def.canopy)
	look.set_shader_parameter("mist_color", def.mist_color)
	look.set_shader_parameter("mist_speed", def.mist_speed)
	look.set_shader_parameter("caustics_color", def.caustics_color)
	look.set_shader_parameter("rays_color", def.rays_color)
	look.set_shader_parameter("rays_angle", deg_to_rad(def.rays_angle))
	look.set_shader_parameter("rays_density", def.rays_density)
	layer._look = look
	layer.material = look
	return layer


func _process(_delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var half := get_viewport_rect().size / camera.zoom * 0.5 + Vector2.ONE * MARGIN
	var center := camera.get_screen_center_position() - global_position
	draw_rect(Rect2(center - half, half * 2.0), Color.WHITE)
