class_name ExecutePassive
extends Passive
## More damage against badly wounded enemies.

## Applies when the target is at or below this fraction of its HP.
@export_range(0.0, 1.0) var hp_threshold: float = 0.35
## 0.6 = +60% damage, per stack.
@export var bonus_per_stack: float = 0.6


func modify_outgoing_hit(_owner: Actor, target: Actor, hit: HitInfo, perk: PerkSet.Entry) -> void:
	if float(target.hp) / target.get_max_hp() <= hp_threshold:
		hit.amount = roundi(hit.amount * (1.0 + bonus_per_stack * perk.stacks))
		if hit.element == null:
			hit.element = VfxElementDef.named(&"blood")  # a finishing blow lands in blood
