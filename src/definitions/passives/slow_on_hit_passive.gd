class_name SlowOnHitPassive
extends Passive
## Hits chill: the target moves slower for a moment (more per stack, up to `max_slow`).

@export_range(0.0, 0.9) var slow_per_stack: float = 0.15
@export_range(0.0, 0.9) var max_slow: float = 0.6
@export var duration: float = 2.0


func on_hit_dealt(_owner: Actor, target: Actor, _hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if not target.is_dead:
		target.statuses.apply_slow(minf(slow_per_stack * perk.stacks, max_slow), duration)
