class_name LootOnKillPassive
extends Passive
## Slain monsters sometimes drop an extra item from their loot table (summoned ones give nothing,
## like their own loot: a summoner must not become a loot fountain).

@export_range(0.0, 1.0) var chance_per_stack: float = 0.1


func on_kill(owner: Actor, victim: Actor, perk: PerkSet.Entry) -> void:
	var monster := victim as Monster
	if monster == null or monster.summoned or monster.def.loot == null or randf() >= chance_per_stack * perk.stacks:
		return
	var item := monster.def.loot.pick(owner.world.rng)
	if item:
		owner.world.spawn_loot(item, monster.global_position)
		Vfx.sparkles(owner.world, monster.global_position, Palette.GOLD)
