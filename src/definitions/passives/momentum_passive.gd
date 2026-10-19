class_name MomentumPassive
extends Passive
## For a moment after a roll, the owner's hits deal more damage.

@export var duration: float = 1.5
## Extra damage per stack (0.25 = +25%).
@export var bonus_per_stack: float = 0.25


func on_dash(_owner: Actor, perk: PerkSet.Entry) -> void:
	perk.memory["until"] = Engine.get_physics_frames() + roundi(duration * Engine.physics_ticks_per_second)


func modify_outgoing_hit(_owner: Actor, _target: Actor, hit: HitInfo, perk: PerkSet.Entry) -> void:
	if Engine.get_physics_frames() <= int(perk.memory.get("until", -1)):
		hit.amount = maxi(1, roundi(hit.amount * (1.0 + bonus_per_stack * perk.stacks)))
