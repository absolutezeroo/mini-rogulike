class_name BurnOnHitPassive
extends Passive
## Hits set enemies on fire (or poison them...): damage every `interval` seconds for `duration` seconds.

## The status applied: the same id refreshes instead of stacking (&"burn", &"poison"...).
@export var status_id: StringName = &"burn"
@export var damage_per_stack: int = 2
@export var interval: float = 0.5
@export var duration: float = 3.0
@export_range(0.0, 1.0) var chance: float = 1.0
## The ticks' color when it has no element.
@export var color: Color = Palette.FIRE
## What it is (Ignite, the Ember rune: fire): the ticks and the body's tint take its color.
@export var element: VfxElementDef


## The chance is rolled before the hit lands, so a hit that will burn flashes in its element
## (the Ember Rune: a fire flash on the hits that catch, a plain one on the others).
func modify_outgoing_hit(_owner: Actor, _target: Actor, hit: HitInfo, perk: PerkSet.Entry) -> void:
	var catches := randf() < chance
	hit.rolled[[perk, self]] = catches
	if catches and element and hit.element == null:
		hit.element = element


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	var catches: bool = hit.rolled.get([perk, self], randf() < chance)
	if target.is_dead or not catches:
		return
	target.statuses.apply_dot(status_id, damage_per_stack * perk.stacks, interval, duration, owner, element.color() if element else color)


## Shows as the element it strikes with (ItemLook).
func look_element() -> VfxElementDef:
	return element
