class_name BurnOnHitPassive
extends Passive
## Hits set enemies on fire: damage every `interval` seconds for `duration` seconds.

@export var damage_per_stack: int = 2
@export var interval: float = 0.5
@export var duration: float = 3.0
@export_range(0.0, 1.0) var chance: float = 1.0
@export var color: Color = Color("ff8c42")


func on_hit_dealt(owner: Actor, target: Actor, _hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if target.is_dead or randf() >= chance:
		return
	target.statuses.apply_dot(&"burn", damage_per_stack * perk.stacks, interval, duration, owner, color)
