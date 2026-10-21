class_name BuffEffect
extends Effect
## Temporarily adds stats to the user.

@export var bonuses: StatBlock
@export var duration: float = 6.0
@export var color: Color = Color(1.0, 0.4, 0.3)
## What it is made of (data/vfx/elements/): a ring of its pieces bursts around the user (Battle
## Cry: jets of blood out of the ground) and a ripple runs out. Empty: a magic circle.
@export var element: VfxElementDef
## Radius of the element's ring around the user.
@export var element_radius: float = 40.0


func apply(user: Actor, _aim: Vector2) -> void:
	if bonuses == null:
		return
	user.add_timed_bonus(bonuses, duration)
	user.world.spawn_floating_text(user.head_position(), bonuses.describe(), element.color() if element else color)
	if element:
		Vfx.nova(user.world, user.global_position, element_radius, element)
		Vfx.shockwave(user.world, user.global_position, element_radius * 2.0, 5.0)
	else:
		Vfx.magic(user.world, user.global_position, color)
