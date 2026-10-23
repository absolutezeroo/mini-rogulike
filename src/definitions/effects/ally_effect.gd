class_name AllyEffect
extends Effect
## Helps the user's allies around it (its own side, the user too if `include_self`): heals the
## hurt ones, gives stats for a while, or wraps them in a ward that soaks up damage. A beam of
## light goes from the user to each ally helped. What monster supports cast (menders, moths,
## drummers): kill them first.

enum Kind { HEAL, BUFF, WARD }

@export var kind: Kind = Kind.HEAL
@export var radius: float = 220.0
@export var include_self: bool = true
@export var color: Color = Color(0.45, 1.0, 0.55)
## What it is made of (data/vfx/elements/): each ally helped flares in its element's impact, the
## beams take its color and the caster stands in a small ring of its pieces (Soul Ward: pale
## flames, a hollow ring). Empty: sparkles and a magic circle in `color`.
@export var element: VfxElementDef
@export_group("Heal")
## Part of each ally's max HP restored (plus `amount`).
@export_range(0.0, 1.0) var heal_ratio: float = 0.25
@export var amount: int = 0
@export_group("Buff")
@export var bonuses: StatBlock
@export var duration: float = 6.0
@export_group("Ward")
## Damage the ward soaks up, as a part of each ally's max HP.
@export_range(0.0, 1.0) var ward_ratio: float = 0.3


func apply(user: Actor, _aim: Vector2) -> void:
	var world := user.world
	var helped := 0
	for ally in allies_of(user, radius, include_self):
		match kind:
			Kind.HEAL:
				var healed := ally.heal(amount + roundi(ally.get_max_hp() * heal_ratio))
				if healed <= 0:
					continue
				world.spawn_floating_text(ally.head_position(), "+%d" % healed, color)
			Kind.BUFF:
				if bonuses == null:
					return
				ally.add_timed_bonus(bonuses, duration)
			Kind.WARD:
				ally.add_ward(roundi(ally.get_max_hp() * ward_ratio), duration)
		helped += 1
		var tint := element.color() if element else color
		if ally != user:
			world.spawn_vfx(BeamVfx.create(user.global_position + Vector2(0, -12), ally.global_position + Vector2(0, -10), tint))
		if element:
			Vfx.pop(world, ally.global_position + Vector2(0, -10), element, 14.0, Vector2.UP)
		else:
			Vfx.sparkles(world, ally.global_position + Vector2(0, -10), color)
	if helped > 0:
		if element:
			Vfx.nova(world, user.global_position, 26.0, element)
		else:
			Vfx.magic(world, user.global_position, color)
		if kind == Kind.BUFF and bonuses:
			world.spawn_floating_text(user.head_position(), bonuses.describe(), element.color() if element else color)


## Alive actors of `user`'s side within `reach` of it.
static func allies_of(user: Actor, reach: float, with_self: bool) -> Array[Actor]:
	var result: Array[Actor] = []
	var enemy_side := Actor.Faction.MONSTER if user.faction == Actor.Faction.PLAYER else Actor.Faction.PLAYER
	for actor in user.world.get_hostiles(enemy_side):
		if actor.is_dead or (actor == user and not with_self):
			continue
		if actor.global_position.distance_to(user.global_position) <= reach:
			result.append(actor)
	if with_self and not result.has(user) and not user.is_dead:
		result.append(user)
	return result
