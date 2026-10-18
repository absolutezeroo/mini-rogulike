class_name SummonEffect
extends Effect
## Calls monsters next to the user. They join the user's fight right away.

@export var monsters: Array[MonsterDef] = []
@export var count: int = 2
## Distance from the user where they appear.
@export var radius: float = 70.0
## Nothing is summoned once the floor holds this many monsters.
@export var max_alive: int = 8


func apply(user: Actor, _aim: Vector2) -> void:
	if monsters.is_empty():
		return
	var world := user.world
	for i in count:
		if world.monster_count() >= max_alive:
			return
		var at := world.find_open_point_near(user.global_position, radius)
		var minion := world.spawn_monster(monsters.pick_random(), at)
		if user is Monster:
			minion.target = (user as Monster).target
		Vfx.puff(world, at)
