class_name DashStrikeEffect
extends Effect
## Dashes along the aim and cuts every enemy on the way (stops at walls).

@export var distance: float = 160.0
@export var duration: float = 0.14
## Width of the cut along the path.
@export var width: float = 28.0
## Damage = flat_damage + user's skill power x multiplier.
@export var damage_multiplier: float = 1.4
@export var flat_damage: int = 0
@export var knockback: float = 160.0
@export var status: OnHitStatus
## Slash sheet drawn along the path.
@export var fx: Texture2D
@export var fx_tint: Color = Color.WHITE
## What it is made of (data/vfx/elements/): the element's pieces are left along the path
## (Glacial Dive: ice crystals that grow behind it and shatter), a sheet takes its ramp.
@export var element: VfxElementDef


func apply(user: Actor, aim: Vector2) -> void:
	var world := user.world
	var start := user.global_position
	var length := distance
	# Stop short of walls.
	var query := PhysicsRayQueryParameters2D.create(start, start + aim * distance, Layers.WORLD)
	var wall := world.get_world_2d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		length = maxf(start.distance_to(wall.position) - user.radius - 2.0, 0.0)
	var end := start + aim * length
	var amount := flat_damage + roundi(user.get_skill_power() * damage_multiplier)
	Combat.damage_segment(world, user, start, end, width, amount, knockback, status, element)
	if length > 1.0:
		user.start_dash(aim * length / duration, duration, true)
	if element:
		Vfx.trail(world, start, end, element, duration)
	if fx:
		# At the nearest whole size of the art's pixel along the path (SheetVfx snaps it).
		var size := maxf(length, 40.0) / fx.get_height()
		world.spawn_vfx(SheetVfx.create(fx, (start + end) * 0.5, aim.angle(), size, 20.0).with_color(fx_tint).in_element(element))
