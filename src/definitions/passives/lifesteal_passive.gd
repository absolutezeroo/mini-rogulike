class_name LifestealPassive
extends Passive
## Heals the owner for part of the damage they deal with direct hits. Burn and poison ticks and
## secondary hits (shockwaves, chains, shards...) heal nothing, fractions add up instead of being
## rounded up on every hit, and the hero's healing is limited (Actor.sustain_heal, SustainRules).

@export_range(0.0, 2.0, 0.01) var ratio_per_stack: float = 0.5


func on_hit_dealt(owner: Actor, _target: Actor, hit: HitInfo, damage: int, perk: PerkSet.Entry) -> void:
	if hit.is_tick or hit.is_secondary or damage <= 0:
		return
	var healed := owner.sustain_heal(damage * ratio_per_stack * perk.stacks)
	if healed > 0:
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Palette.HEAL)
