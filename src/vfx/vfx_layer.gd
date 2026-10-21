class_name VfxLayer
## Where an effect is drawn among the actors (docs/vfx.md, "Layers"). Three layers:
##
## - GROUND: flat on the floor (a sigil, a ring, a telegraph, crackles, mist at the feet, marks):
##   under every actor, over the floor's own marks (splats, footprints). It sits under the
##   floor's light (LightField.Z), so it darkens with the room like the floor; one that glows
##   lights itself with a light (World.flash_light, a LightSource), like a lamp would.
## - STANDING: upright on the floor (an ice crystal growing, a column of light, a bolt striking,
##   rock spikes, smoke rising from the ground): sorted with the actors by its base (the bottom of
##   what it draws), in the world's Entities, so it hides a monster standing behind it and is
##   hidden by the hero standing in front. Lit with the room, like the actors.
## - AIR: in the air or on a body (a shot, a hit's flash and sparks, a blade's arc, a burst, a
##   halo, damage numbers): over every actor and over the floor's light (it shines on its own).
##
## A sheet says its layer (VfxSheetDef.layer, AIR when it doesn't: an impact, a shot); code
## that draws an effect sets it with `apply` and World.spawn_vfx puts it in its place.

enum Layer {
	## In the air or on a body: over every actor (the default of a sheet).
	AIR,
	## Flat on the floor: under every actor.
	GROUND,
	## Upright on the floor: sorted with the actors by its base.
	STANDING,
}

## Over the floor's marks (splats -8, footprints -5), under the actors (0) and the floor's light.
const GROUND_Z := -1
## Sorted with the actors (their own z in the world's Entities).
const STANDING_Z := 0
## Over the actors and the floor's light (LightField.Z).
const AIR_Z := 5

const _META := &"vfx_layer"
## An effect leaving a body toward a direction with less than this y goes north, away from the
## camera: it starts behind that body (`goes_behind`).
const NORTH := -0.2


## Puts `node` on `layer`: its z (absolute, whatever its parent), and a mark World.spawn_vfx
## reads to add a standing one to the y-sorted Entities. Returns `node`.
static func apply(node: Node2D, layer: Layer) -> Node2D:
	node.set_meta(_META, layer)
	node.z_as_relative = false
	match layer:
		Layer.GROUND:
			node.z_index = GROUND_Z
		Layer.STANDING:
			node.z_index = STANDING_Z
			node.y_sort_enabled = true
		_:
			node.z_index = maxi(node.z_index, AIR_Z)
	return node


## A glowing (emissive) effect on the GROUND or STANDING lies under the floor's light: it lights
## itself (a light in its element's core, `reach` world units around, for as long as it lives)
## so its colors stay its own in a dim room. Nothing for matter (blood, earth, steel) or AIR.
static func light_up(node: Node2D, element: VfxElementDef, reach: float) -> void:
	if element == null or not element.emissive or of(node) == Layer.AIR:
		return
	var light := LightSource.new()
	light.color = element.core()
	light.relative = true
	light.moves = true
	light.level = clampi(roundi(reach / 32.0) + 6, 6, LightField.MAX_LEVEL)
	node.add_child(light)


## The layer `node` was put on (AIR when it never was).
static func of(node: Node) -> Layer:
	return node.get_meta(_META, Layer.AIR) as Layer


## The hero's own effects never hide him (docs/vfx.md 2b): one leaving his body toward
## `direction` (a shot, a blow, the charge in his hand) starts behind it when it goes north
## (we see his back), in front of it otherwise.
static func goes_behind(direction: Vector2) -> bool:
	return direction.y < NORTH * direction.length()


## Puts `node` on `body` (an actor): a child of it, sorted with it among the actors, drawn
## behind its sprite (`behind`: a halo rising around the hero, a column of light, his weapon's
## glow when he faces north) or over it (the glow when he faces us). Lit with the room like
## the body. Returns `node`.
##
## Behind is the body's children's order, not `show_behind_parent`: an actor draws nothing of
## its own, its sprites are its Rig, a sibling drawn in tree order. A node behind is moved
## before every other child (the Rig first), one in front after them.
static func on_body(body: Node2D, node: Node2D, behind: bool = true) -> Node2D:
	node.set_meta(_META, Layer.STANDING)
	node.z_as_relative = true
	node.z_index = 0
	if node.get_parent() != body:
		if node.get_parent():
			node.reparent(body, false)
		else:
			body.add_child(node)
	set_behind(node, behind)
	return node


## Moves `node` (a child of a body, `on_body`) behind the body's sprites or in front of them:
## the hero's glow in hand goes behind him when he turns to face north.
static func set_behind(node: Node2D, behind: bool) -> void:
	var body := node.get_parent()
	if body == null:
		return
	var last := body.get_child_count() - 1
	if behind and node.get_index() != 0:
		body.move_child(node, 0)
	elif not behind and node.get_index() != last:
		body.move_child(node, last)


## Whether `node` is drawn behind the sprites of the body it is on (`on_body`): before its rig.
static func is_behind_body(node: Node2D) -> bool:
	var body := node.get_parent()
	if body == null:
		return false
	for child in body.get_children():
		if child == node:
			return true
		if child is ActorRig:
			return false
	return false
