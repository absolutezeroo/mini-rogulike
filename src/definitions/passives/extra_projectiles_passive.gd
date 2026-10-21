class_name ExtraProjectilesPassive
extends Passive
## Everything the owner shoots (weapons and skills) fires extra projectiles in a fan.
## Every source (Multishot, Prism runes) adds to the same volley, up to `max_extra` extra
## projectiles in all, and the volley's damage is spread: each extra projectile adds
## `extra_damage` of a shot (the shots of a volley share one damage). Without that, Multishot 2
## and two Prism runes made a Spark Wand fire 5 full shots (x5.2 damage at close range).

@export var count_per_stack: int = 1
## Degrees between projectiles when the volley had no spread.
@export var spread_per_projectile: float = 12.0
## Most extra projectiles a volley gets from every source together.
@export var max_extra: int = 2
## What each extra projectile adds, in shots of the volley (1 = a full shot).
@export_range(0.1, 1.0, 0.05) var extra_damage: float = 0.65

## Spec meta: the volley before any extra projectile ({ count, damage }).
const BASE := &"extra_projectiles_base"


func modify_projectiles(_owner: Actor, spec: ProjectileSpec, perk: PerkSet.Entry) -> void:
	if not spec.has_meta(BASE):
		spec.set_meta(BASE, { "count": spec.count, "damage": spec.damage })
	var base: Dictionary = spec.get_meta(BASE)
	var room := max_extra - (spec.count - int(base.count))
	var added := mini(count_per_stack * perk.stacks, room)
	if added <= 0:
		return
	spec.count += added
	var extra := spec.count - int(base.count)
	var share := (float(base.count) + extra_damage * extra) / float(spec.count)
	spec.damage = maxi(1, roundi(int(base.damage) * share))
	if spec.spread_degrees < 360.0:
		spec.spread_degrees = maxf(spec.spread_degrees, spread_per_projectile * (spec.count - 1))


## Arcane on the weapon that carries it (ItemLook).
func look_element() -> VfxElementDef:
	return VfxElementDef.named(&"arcane")
