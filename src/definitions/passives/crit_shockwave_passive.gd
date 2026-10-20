class_name CritShockwavePassive
extends Passive
## Critical hits release a shockwave that damages enemies around the target.
## The enemy struck is not caught by its own shockwave (`hits_target`): the wave is crowd
## damage, not a second crit on the same body (crit chance x crit damage x the wave would
## multiply on a boss: the crit build killed act II bosses in 7-10 s standing still).

@export var radius: float = 70.0
@export var radius_per_stack: float = 10.0
## Damage = owner's power x this, per stack.
@export var damage_multiplier: float = 0.5
@export var color: Color = Palette.FROST
## Left on the enemies caught (the Shatter rune chills them). Optional.
@export var status: OnHitStatus
## Whether the enemy that took the critical hit is caught too.
@export var hits_target: bool = false
## Knockback of the wave.
@export var knockback: float = 120.0


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if not hit.is_crit:
		return
	var size := radius + radius_per_stack * (perk.stacks - 1)
	var amount := roundi(owner.get_power() * damage_multiplier * perk.stacks)
	var center := target.global_position
	if hits_target:
		Combat.damage_area(owner.world, owner, center, size, amount, knockback, true, status)
	else:
		for other in owner.world.get_hostiles(owner.faction):
			if other == target:
				continue
			var offset := other.global_position - center
			if offset.length() > size + other.radius:
				continue
			var wave := Combat.make_hit_from(owner, amount)
			wave.knockback = offset.normalized() * knockback
			wave.origin = owner.global_position
			wave.is_secondary = true
			wave.status = status
			other.take_hit(wave)
		Combat.hit_props(owner.world, owner, center, size)
	owner.world.spawn_vfx(RingVfx.create(center, size, color))
