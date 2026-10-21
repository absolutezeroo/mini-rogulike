class_name BloodlustPassive
extends Passive
## Wounded, the owner hits harder; and every kill heals a share of the max health (not summoned
## monsters nor a boss's adds; limited for the hero like every heal from kills: SustainRules).

## Below this share of max HP, hits deal `low_health_bonus` more (per stack).
@export_range(0.0, 1.0) var low_health: float = 0.5
@export var low_health_bonus: float = 0.4
## Healed per kill, as a share of max HP (0 = none).
@export_range(0.0, 0.5) var heal_per_kill: float = 0.04


func modify_outgoing_hit(owner: Actor, _target: Actor, hit: HitInfo, perk: PerkSet.Entry) -> void:
	if low_health_bonus > 0.0 and owner.hp <= owner.get_max_hp() * low_health:
		hit.amount = maxi(1, roundi(hit.amount * (1.0 + low_health_bonus * perk.stacks)))
		if hit.element == null:
			hit.element = VfxElementDef.named(&"blood")  # its blows land in blood


func on_kill(owner: Actor, victim: Actor, _perk: PerkSet.Entry) -> void:
	if heal_per_kill <= 0.0 or not victim.can_heal_killer():
		return
	var healed := owner.sustain_heal(owner.get_max_hp() * heal_per_kill)
	if healed > 0:
		owner.world.spawn_vfx(BloodDrainVfx.create(victim.global_position + Vector2(0, -victim.radius), owner, 4))
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Palette.BLOOD)
