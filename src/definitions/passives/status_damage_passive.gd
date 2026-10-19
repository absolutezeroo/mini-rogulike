class_name StatusDamagePassive
extends Passive
## More damage to enemies already suffering something (burning, poisoned, slowed): fire feeds
## on fire, frost shatters what it slowed. Can also freeze them solid on a critical hit.

enum Condition { BURNING, POISONED, SLOWED }

@export var condition: Condition = Condition.BURNING
## Extra damage per stack (0.15 = +15%).
@export var bonus_per_stack: float = 0.15
## Critical hits on such an enemy slow it this much for `crit_slow_duration` (0 = no).
@export_range(0.0, 0.9) var crit_slow: float = 0.0
@export var crit_slow_duration: float = 1.0
@export var crit_color: Color = Palette.FROST


static func matches(target: Actor, wanted: Condition) -> bool:
	match wanted:
		Condition.BURNING:
			return target.statuses.has(&"burn")
		Condition.POISONED:
			return target.statuses.has(&"poison")
		Condition.SLOWED:
			return target.statuses.is_slowed()
	return false


func modify_outgoing_hit(_owner: Actor, target: Actor, hit: HitInfo, perk: PerkSet.Entry) -> void:
	if matches(target, condition):
		hit.amount = maxi(1, roundi(hit.amount * (1.0 + bonus_per_stack * perk.stacks)))


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, _perk: PerkSet.Entry) -> void:
	if crit_slow <= 0.0 or not hit.is_crit or target.is_dead or not matches(target, condition):
		return
	target.statuses.apply_slow(crit_slow, crit_slow_duration, &"freeze")
	owner.world.spawn_vfx(RingVfx.create(target.global_position, target.radius + 14.0, crit_color))
