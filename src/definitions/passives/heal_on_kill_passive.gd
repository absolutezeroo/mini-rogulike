class_name HealOnKillPassive
extends Passive
## Heals the owner every time they kill an enemy (not summoned monsters nor a boss's adds: see
## Actor.can_heal_killer). Limited for the hero like every heal from hits and kills (SustainRules).

@export var heal_per_stack: int = 2


func on_kill(owner: Actor, victim: Actor, perk: PerkSet.Entry) -> void:
	if not victim.can_heal_killer():
		return
	var healed := owner.sustain_heal(heal_per_stack * perk.stacks)
	if healed > 0:
		owner.world.spawn_vfx(BloodDrainVfx.create(victim.global_position + Vector2(0, -victim.radius), owner, 3))
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Palette.HEAL)
