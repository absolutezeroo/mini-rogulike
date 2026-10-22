class_name SummonEffect
extends Effect
## Calls monsters next to the user. They join the user's fight right away.

@export var monsters: Array[MonsterDef] = []
@export var count: int = 2
## Distance from the user where they appear.
@export var radius: float = 70.0
## Nothing is summoned once the floor holds this many monsters.
@export var max_alive: int = 8
## What they rise out of (data/vfx/elements/): its impact and a small ring of its pieces where
## each appears (spirits: a hollow ring and pale flames). Empty: a puff of smoke.
@export var element: VfxElementDef


func apply(user: Actor, _aim: Vector2) -> void:
	if monsters.is_empty():
		return
	var world := user.world
	for i in count:
		if world.monster_count() >= max_alive:
			return
		var kind: MonsterDef = monsters.pick_random()
		var at := world.find_open_point_near(user.global_position, radius, World.room_for(kind))
		var minion := world.spawn_monster(kind, at)
		minion.summoned = true
		if user is Monster:
			minion.target = (user as Monster).target
		if element:
			Vfx.pop(world, at + Vector2(0, -10), element, 14.0, Vector2.UP)
			Vfx.nova(world, at, 16.0, element)
		else:
			Vfx.puff(world, at)
