class_name DeathBurstTrait
extends MonsterTrait
## Bursts a moment after dying, hurting everyone around (stay away!). Not down a hole.

@export var radius: float = 60.0
## Grows with depth and the difficulty (FloorRules.dungeon_damage).
@export var damage: int = 6
## Statuses left by the burst (frost...).
@export var status: OnHitStatus
## Sheet played for the burst (square frames). Empty = an explosion.
@export var fx: Texture2D
## Seconds between the death and the burst.
@export var fuse: float = 0.35


func on_died(monster: Monster, _killer: Actor, fell: bool, _rewards: bool) -> void:
	if fell:
		return
	var world := monster.world
	Combat.delayed_blast(world, monster.global_position, radius, world.rules.dungeon_damage(damage), fuse, fx, status)


func describe() -> String:
	return tr("Bursts when it dies.")
