class_name Blow
extends RefCounted
## A melee blow struck in the body's four directions (docs/design/builds.md, "Blows in four
## directions"). Bodies, their armor and the weapon in hand are drawn facing down, up, left or
## right only (ActorRig.DIRECTIONS), so a blow is drawn toward `facing`, the one of the four
## nearest the aim (the pose the body strikes in: ActorRig.direction_name), and so is every
## effect on it: the arc, the thrust's streak, a smash, a claw, a charged crescent.
##
## Its zone is the blow's shape swept from `facing` to the exact `aim` (never more than 45
## degrees away): it hits what it draws, plus everything the same blow aimed straight at the
## target would have hit, so a foe standing on a diagonal is never missed (a rapier's 30-degree
## thrust drawn to the right still runs through the skeleton at 40 degrees up). A blow that does
## not follow the facing (a shot, a spin, a spell placed far off) is the same object with `facing`
## equal to `aim`: nothing is swept.

## Where it is struck from (the wielder's feet).
var origin: Vector2
## The way it is drawn (a cardinal when it follows the body's pose, else the aim).
var facing: Vector2 = Vector2.RIGHT
## The exact way it was aimed (at the closest enemy).
var aim: Vector2 = Vector2.RIGHT


## A blow from `origin` aimed along `aim`, drawn in the body's four directions when `follows`.
static func at(from: Vector2, direction: Vector2, follows: bool = true) -> Blow:
	var blow := Blow.new()
	blow.origin = from
	blow.aim = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	blow.facing = Blow.cardinal(blow.aim) if follows else blow.aim
	return blow


## The blow of `weapon`'s basic attack: a melee weapon follows the body's four directions, a
## blow all around (a body slam: `arc_degrees` 360) stays as it is, and a shot is no blow (its
## projectiles fly at the exact aim).
static func of_weapon(from: Vector2, direction: Vector2, weapon: WeaponDef) -> Blow:
	return Blow.at(from, direction, weapon != null and weapon.kind == WeaponDef.Kind.MELEE and weapon.arc_degrees < 359.0)


## The nearest of the four directions (ties go sideways, like ActorRig.direction_name, which
## uses it).
static func cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


## The direction between `facing` and `aim` nearest the way to `point`: the blow's shape turned
## there is the part of its sweep that comes closest to it (a circle's centre, a segment, an
## arc's middle).
func toward(point: Vector2) -> Vector2:
	var to := point - origin
	if to == Vector2.ZERO:
		return facing
	var span := facing.angle_to(aim)
	return facing.rotated(clampf(facing.angle_to(to), minf(span, 0.0), maxf(span, 0.0)))


## Whether the way to `point` is inside the swept arc of `half_arc` radians on each side (the
## angle only: the reach is the caller's).
func in_arc(point: Vector2, half_arc: float) -> bool:
	if half_arc >= PI:
		return true
	return absf(toward(point).angle_to(point - origin)) <= half_arc + 0.0001


## The one cone covering the swept arc of `half_arc` radians: x its middle (an angle), y its half
## angle (a monster's warning cone, TelegraphView).
func cone(half_arc: float) -> Vector2:
	var span := facing.angle_to(aim)
	return Vector2(facing.angle() + span * 0.5, minf(half_arc + absf(span) * 0.5, PI))


## Where a circle `offset` out along the blow is drawn (its centre toward `facing`).
func drawn_center(offset: float) -> Vector2:
	return origin + facing * offset
