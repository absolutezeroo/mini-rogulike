class_name ShadeTrait
extends MonsterTrait
## A body the Well has worn down to a shade (the Nameless Keeper: the hero who took the keeper's
## place, his face forgotten): its whole body, armor and weapon included, blended for good toward
## a dark `color` (the rig's pallor, as the Threshold's spectres; ActorRig.pallor), so the face
## and the colors are gone and only the shape stays; and a lantern in its hand, lit (`lantern`,
## drawn at the art's scale on its side, a glow of `glow_element` and a light on the floor).

## How far the body goes toward `color` (0: its own colors, 1: a flat silhouette).
@export_range(0.0, 1.0, 0.05) var pallor: float = 0.7
@export var color: Color = Color(0.16, 0.13, 0.2)
## A pale rim round the shade (alpha 0: none): a dark body on a dark floor still reads, the
## boss always seen (docs/vfx.md, section 2).
@export var rim: Color = Color(0, 0, 0, 0)
## The lantern it carries (null: none), where (art pixels from its feet, on its right; mirrored
## when it faces left), its glow and the light it casts (level 0-15).
@export var lantern: Texture2D
@export var lantern_offset: Vector2 = Vector2(6, -6)
@export var glow_element: VfxElementDef
@export var glow_size: float = 6.0
@export_range(0, 15) var light_level: int = 4


func on_spawn(monster: Monster) -> void:
	if monster.rig:
		_shade(monster)
	else:
		monster.ready.connect(_shade.bind(monster), CONNECT_ONE_SHOT)


func _shade(monster: Monster) -> void:
	if monster.rig == null:
		return
	monster.rig.pallor = pallor
	monster.rig.pallor_color = color
	if rim.a > 0.0:
		monster.rig.look.outline = rim
		monster.rig.look.outline_beat = false  # (one art pixel: the shape, not a rank's aura)
	if lantern == null:
		return
	var held := Sprite2D.new()
	held.name = "Lantern"
	held.texture = lantern
	held.centered = true
	held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	held.position = lantern_offset
	monster.rig.visual.add_child(held)  # (the art's scale: its pixels on the body's grid)
	monster.trait_state(self).lantern = held
	var glow_at := monster.rig.position + lantern_offset * Actor.SPRITE_SCALE
	var halo := GlowHalo.attach(monster, glow_element, glow_size, glow_at, GlowHalo.Pulse.FLICKER, light_level)
	monster.trait_state(self).halo = halo
	if halo == null and light_level > 0:
		GlowHalo.light(monster, color.lightened(0.6), light_level)


## The lantern stays in the hand on its side: mirrored when it faces left.
func update(monster: Monster, _delta: float) -> void:
	var state := monster.trait_state(self)
	var held: Sprite2D = state.get("lantern")
	if held == null or not is_instance_valid(held):
		return
	var side := -1.0 if monster.facing.x < -0.3 else 1.0
	held.position = Vector2(lantern_offset.x * side, lantern_offset.y)
	var halo: GlowHalo = state.get("halo")
	if halo and is_instance_valid(halo):
		halo.position = monster.rig.position + held.position * Actor.SPRITE_SCALE
