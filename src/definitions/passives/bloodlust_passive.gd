class_name BloodlustPassive
extends Passive
## Wounded, the owner hits harder; and every kill heals a share of the max HP.

## Below this share of max HP, hits deal `low_health_bonus` more.
@export_range(0.0, 1.0) var low_health: float = 0.5
@export var low_health_bonus: float = 0.4
## Healed per kill, as a share of max HP.
@export_range(0.0, 0.5) var heal_per_kill: float = 0.04


func modify_outgoing_hit(owner: Actor, _target: Actor, hit: HitInfo, _perk: PerkSet.Entry) -> void:
	if owner.hp <= owner.get_max_hp() * low_health:
		hit.amount = maxi(1, roundi(hit.amount * (1.0 + low_health_bonus)))


func on_kill(owner: Actor, _victim: Actor, _perk: PerkSet.Entry) -> void:
	var healed := owner.heal(maxi(1, roundi(owner.get_max_hp() * heal_per_kill)))
	if healed > 0:
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Palette.BLOOD)
