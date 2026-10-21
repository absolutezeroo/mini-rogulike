class_name ChainLightningPassive
extends Passive
## Every few hits, lightning jumps from the target to the nearest enemies around it.

## Direct hits needed for one strike.
@export_range(1, 20) var every_hits: int = 4
@export_range(1, 8) var jumps: int = 3
@export var reach: float = 170.0
## Damage of each jump = the owner's power x this.
@export var damage_multiplier: float = 0.6
## The bolt's color when it has no element.
@export var color: Color = Color("a8e6ff")
## What jumps (storm): the bolt and the sparks take its ramp.
@export var element: VfxElementDef


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if hit.is_secondary:
		return
	var count: int = perk.memory.get("hits", 0) + 1
	perk.memory["hits"] = count % every_hits
	if count < every_hits:
		return
	var world := owner.world
	var amount := maxi(1, roundi(owner.get_power() * damage_multiplier))
	var from := target.global_position
	var struck: Array[Actor] = [target]
	for i in jumps:
		var next := _nearest(world, owner, from, struck)
		if next == null:
			break
		var bolt := element.color() if element else color
		world.spawn_vfx(BeamVfx.create(from + Vector2(0, -8), next.global_position + Vector2(0, -8), bolt, element))
		Vfx.hit(world, next.global_position, from.direction_to(next.global_position), bolt, false, element)
		next.take_hit(Combat.make_secondary_hit(owner, amount))
		struck.append(next)
		from = next.global_position


func _nearest(world: World, owner: Actor, from: Vector2, skip: Array[Actor]) -> Actor:
	var best: Actor = null
	var best_distance := reach
	for actor in world.get_hostiles(owner.faction):
		if actor.is_dead or skip.has(actor):
			continue
		var distance := from.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best
