class_name OpenerPassive
extends Passive
## The first blow on an unhurt enemy is always a critical hit.


func modify_outgoing_hit(_owner: Actor, target: Actor, hit: HitInfo, _perk: PerkSet.Entry) -> void:
	if hit.is_crit or target.hp < target.get_max_hp():
		return
	hit.is_crit = true
	hit.amount = maxi(1, roundi(hit.amount * Combat.CRIT_MULTIPLIER))
