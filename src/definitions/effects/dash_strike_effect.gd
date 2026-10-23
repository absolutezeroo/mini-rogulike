class_name DashStrikeEffect
extends Effect
## Dashes along the aim and cuts every enemy on the way (stops at walls). Without `moves`, the
## user stays put and the cut runs out along the aim (a lance's long thrust).

@export var distance: float = 160.0
@export var duration: float = 0.14
## Width of the cut along the path.
@export var width: float = 28.0
## Damage = flat_damage + user's skill power x multiplier.
@export var damage_multiplier: float = 1.4
@export var flat_damage: int = 0
@export var knockback: float = 160.0
@export var status: OnHitStatus
## The cut drawn along the path (a thrust's streak: data/vfx/slashes/), instead of a sheet.
@export var slash: SlashDef
## Slash sheet drawn along the path.
@export var fx: Texture2D
@export var fx_tint: Color = Color.WHITE
## What it is made of (data/vfx/elements/): the element's pieces are left along the path
## (Glacial Dive: ice crystals that grow behind it and shatter), a sheet takes its ramp.
@export var element: VfxElementDef
## The user dashes along the cut (off: a thrust that reaches out, the user standing still).
@export var moves: bool = true

## A second element its blow sheds a few bits of (not saved, never in data: a charged attack
## dressed in what the hero's weapon carries sets it, ChargedAttackDef).
var second_element: VfxElementDef
## Not saved, never in data: a weapon's skill dressed in what its runes and affixes carry
## (SkillDef.effects_for, docs/vfx.md "Elemental attacks") is drawn in this element, its hits
## staying in `element` (the rune's own rules decide when a hit lands in it). A blade's blow or a
## plain area is drawn in it; one of its own element keeps it, and this one rides it.
var look_element: VfxElementDef


## A copy dressed in the elements the hero's weapon carries (`carried`, the strongest first): a
## plain cut (Dash Strike, Piercing Thrust) is drawn in the first, the second adding its bits;
## one of its own element stays itself, the first other shedding its bits. Only the look.
func dressed_in(carried: Array[VfxElementDef]) -> DashStrikeEffect:
	var copy := duplicate() as DashStrikeEffect
	var others: Array[VfxElementDef] = []
	for other in carried:
		if other and other != element:
			others.append(other)
	if others.is_empty():
		return copy
	copy.look_element = others[0]
	copy.second_element = (others[1] if others.size() > 1 else null) if element == null else others[0]
	return copy


func apply(user: Actor, aim: Vector2) -> void:
	var world := user.world
	var start := user.global_position
	var length := distance
	# Stop short of walls.
	var query := PhysicsRayQueryParameters2D.create(start, start + aim * distance, Layers.WORLD)
	var wall := world.get_world_2d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		length = maxf(start.distance_to(wall.position) - user.radius - 2.0, 0.0)
	var end := start + aim * length
	var amount := flat_damage + roundi(user.get_skill_power() * damage_multiplier)
	Combat.damage_segment(world, user, start, end, width, amount, knockback, status, element)
	if moves and length > 1.0:
		user.start_dash(aim * length / duration, duration, true, element)
	if element:
		Vfx.trail(world, start, end, element, duration)
	elif slash == null and fx == null and moves:
		Vfx.dust_trail(world, start, end, duration)  # a plain rush kicks up dust on its way
	# What the cut is drawn in (look_element: the weapon's runes and affixes on a plain cut).
	var drawn := element if element else look_element
	if slash:
		SwingVfx.slash(world, slash, start + Vector2(0, -6), aim, maxf(length, 40.0), drawn, user.faction != Actor.Faction.PLAYER, second_element)
	elif fx:
		# At the nearest whole size of the art's pixel along the path (SheetVfx snaps it).
		var size := maxf(length, 40.0) / fx.get_height()
		world.spawn_vfx(SheetVfx.create(fx, (start + end) * 0.5, aim.angle(), size, 20.0).with_color(fx_tint).in_element(drawn))
