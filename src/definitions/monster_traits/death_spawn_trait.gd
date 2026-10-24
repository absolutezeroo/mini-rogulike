class_name DeathSpawnTrait
extends MonsterTrait
## Monsters come out when it dies (a giant slime splitting in two...). Not down a hole.

@export var monsters: Array[MonsterDef] = []
@export_range(1, 8) var count: int = 2


func on_died(monster: Monster, _killer: Actor, fell: bool, _rewards: bool) -> void:
	if fell or monsters.is_empty():
		return
	var world := monster.world
	var at := monster.global_position
	var hunted := monster.target
	var kinds := monsters
	var amount := count
	# Deferred: we may be inside a physics callback.
	(func() -> void:
		for i in amount:
			var kind: MonsterDef = kinds.pick_random()
			var minion := world.spawn_monster(kind, world.find_open_point_near(at, 24.0, WorldSpace.room_for(kind)))
			minion.target = hunted if is_instance_valid(hunted) else null
			Vfx.puff(world, minion.global_position)
	).call_deferred()


func describe() -> String:
	return tr("Splits when it dies.")
