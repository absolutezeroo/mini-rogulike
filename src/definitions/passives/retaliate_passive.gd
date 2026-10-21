class_name RetaliatePassive
extends Passive
## Getting hit throws enemies around the owner back (and hurts them a little), at most once
## every `cooldown` seconds.

@export var radius: float = 80.0
@export var knockback: float = 320.0
## Damage = the owner's power x this, per stack.
@export var damage_multiplier: float = 0.3
@export var cooldown: float = 3.0
## The wave's look when it has no element.
@export var color: Color = Color("adb5bd")
## What the wave is made of (Frost Armor: frost).
@export var element: VfxElementDef
## Left on the enemies thrown back (Frost Armor chills them). Optional.
@export var status: OnHitStatus


func on_damaged(owner: Actor, _hit: HitInfo, damage: int, perk: PerkSet.Entry) -> void:
	var now := Engine.get_physics_frames()
	if damage <= 0 or owner.is_dead or now < int(perk.memory.get("_ready", 0)):
		return
	perk.memory["_ready"] = now + roundi(cooldown * Engine.physics_ticks_per_second)
	var amount := maxi(1, roundi(owner.get_power() * damage_multiplier * perk.stacks))
	Combat.damage_area(owner.world, owner, owner.global_position, radius, amount, knockback, true, status, element)
	Vfx.nova(owner.world, owner.global_position, radius, VfxElementDef.or_color(element, color))
