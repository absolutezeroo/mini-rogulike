class_name DarkRoom
extends Node2D
## Built from a DarkRoomDef: a room covered in darkness except right around the hero.
## Drawn above everything in the world (monsters, traps, damage numbers), below the HUD.

const SHADER := preload("res://src/entities/hazards/dark_room.gdshader")

var def: DarkRoomDef
var world: World
var room := Rect2i()
## Covered area, in world space (the room and its walls).
var area := Rect2()

var _material := ShaderMaterial.new()
var _entered := false


func setup(dark_def: DarkRoomDef, floor_world: World, dark_room: Rect2i) -> void:
	def = dark_def
	world = floor_world
	room = dark_room
	var ts := float(world.map.tile_size)
	area = Rect2(Vector2(room.position - Vector2i.ONE) * ts, Vector2(room.size + Vector2i(2, 2)) * ts)
	z_index = 60
	add_to_group("dark_rooms")
	_material.shader = SHADER
	_material.set_shader_parameter("shade", def.shade)
	_material.set_shader_parameter("radius", def.vision_radius)
	_material.set_shader_parameter("area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
	_material.set_shader_parameter("edge", ts * 1.5)
	material = _material


## True if `point` (world space) is inside the dark room itself.
func covers(point: Vector2) -> bool:
	return room.has_point(world.map.world_to_cell(point))


func _process(_delta: float) -> void:
	var player := world.player
	if player == null or not is_instance_valid(player):
		return
	_material.set_shader_parameter("hero", player.global_position + Vector2(0, -8))
	if not _entered and covers(player.global_position):
		_entered = true
		if not def.message.is_empty():
			Events.log_message(tr(def.message), Color("8e86a8"))


func _draw() -> void:
	draw_rect(area, Color.WHITE)
