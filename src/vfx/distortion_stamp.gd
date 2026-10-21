class_name DistortionStamp
extends Node2D
## A patch of bent space, drawn by the one screen pass (screen.gdshader) rather than by a
## screen-reading node of its own: reading the screen costs a copy of it, so every distortion of
## the frame goes through one list. ScreenEffects gathers the stamps on screen each frame (at most
## MAX, the nearest to the camera; a shockwave first) and hands them to the shader.
##
## - HEAT: rows of art pixels sliding sideways above a fire (a campfire, a brazier, a ring of
##   flame), the waves climbing. The stamp sits at the fire's foot.
## - COLD: blocks of art pixels caught askew through a frost nova, thickest on its front.
## - PULL: rings of the picture drawn in toward a shadow knot or an arcane missile.
## - SHOCK: a blast's ring running out (ShockwaveVfx drives it).
##
## Every offset is whole art pixels on the world's grid, so the art stays crisp. Fewer effects:
## only shockwaves are kept. Attach one to the node it bends around; it lives as long as that
## node, or `life` seconds, fading by whole pixels.

enum Kind { HEAT, COLD, PULL, SHOCK }

const GROUP := &"distortion_stamps"
## Stamps the screen pass reads at once.
const MAX := 8

var kind := Kind.HEAT
## World units: half the width of a heat column, a disc's radius, a shockwave's reach.
var radius := 16.0
## Art pixels at the strongest.
var strength := 1.0
## Heat: how high the column rises above the foot, world units.
var height := 40.0
## Seconds it lasts (0: as long as its parent).
var life := 0.0
## Shock: the running ring's radius and width right now (ShockwaveVfx).
var ring := 0.0
var ring_width := 10.0
## 0..1: how much of it is left (the shader weakens it by whole pixels).
var left := 1.0
var seed := 0.0

var _age := 0.0


## A stamp of `of_kind` on `parent` (its origin, plus `offset`), `size` world units wide and
## `power` art pixels strong; it lasts `seconds` (0: as long as `parent`). Nothing when the
## player asked for fewer effects (except a shockwave). Returns it, or null.
static func attach(parent: Node, of_kind: Kind, size: float, power: float, seconds: float = 0.0, offset: Vector2 = Vector2.ZERO) -> DistortionStamp:
	if Settings.fewer_effects and of_kind != Kind.SHOCK:
		return null
	var stamp := DistortionStamp.new()
	stamp.kind = of_kind
	stamp.radius = size
	stamp.strength = power
	stamp.life = seconds
	stamp.position = offset
	stamp.height = size * 2.5
	stamp.seed = randf() * 20.0
	parent.add_child(stamp)
	return stamp


## The element's distortion (VfxElementDef.distortion) around `parent`, if it has one.
static func of_element(parent: Node, element: VfxElementDef, size: float, power: float = 1.0, seconds: float = 0.0, offset: Vector2 = Vector2.ZERO) -> DistortionStamp:
	if element == null or element.distortion == VfxElementDef.Distortion.NONE:
		return null
	var stamp_kind: Kind = Kind.HEAT
	match element.distortion:
		VfxElementDef.Distortion.COLD:
			stamp_kind = Kind.COLD
		VfxElementDef.Distortion.PULL:
			stamp_kind = Kind.PULL
	return attach(parent, stamp_kind, size, power, seconds, offset)


func _enter_tree() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	if life <= 0.0:
		return
	_age += delta
	if _age >= life:
		queue_free()
		return
	# The main action first, then it weakens.
	left = 1.0 - maxf(_age / life - 0.3, 0.0) / 0.7


## How far around its centre it bends anything, world units (to know if it is on screen).
func extent() -> float:
	match kind:
		Kind.HEAT:
			return maxf(radius, height)
		Kind.SHOCK:
			return ring + ring_width
	return radius


## What the shader reads: (x, y, radius, strength) and (kind, height or ring, seed or width, left).
func packed() -> Array[Vector4]:
	var at := global_position
	match kind:
		Kind.SHOCK:
			return [Vector4(at.x, at.y, ring + ring_width, strength), Vector4(kind, ring, ring_width, left)]
		Kind.HEAT:
			return [Vector4(at.x, at.y, radius, strength), Vector4(kind, height, seed, left)]
	return [Vector4(at.x, at.y, radius, strength), Vector4(kind, 0.0, seed, left)]
