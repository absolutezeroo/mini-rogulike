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

@export_group("Casting")
## While it casts (a skill's warning: Monster.casting_index), the lantern is held up here
## (art pixels from its feet, over its head) and its glow swells to `cast_glow_size` in
## `cast_glow_steps` whole steps as the warning fills, the last step bright (GlowHalo.bright):
## a cast reads apart from a blow (its weapon's wind-up), on a body with no cast animation of
## its own (the hero's frames: NamelessKeeperDef.cast_pose holds it still meanwhile).
@export var cast_lantern_offset: Vector2 = Vector2(5, -20)
@export var cast_glow_size: float = 10.0
@export_range(1, 6) var cast_glow_steps: int = 3


## One shade's values (Monster.trait_state()): the lantern in its hand and its glow.
class ShadeState:
	extends RefCounted
	var lantern: Sprite2D
	var halo: GlowHalo


func make_state() -> RefCounted:
	return ShadeState.new()


func _state(monster: Monster) -> ShadeState:
	return monster.trait_state(self) as ShadeState


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
	_state(monster).lantern = held
	var glow_at := monster.rig.position + lantern_offset * Actor.SPRITE_SCALE
	var halo := GlowHalo.attach(monster, glow_element, glow_size, glow_at, GlowHalo.Pulse.FLICKER, light_level)
	_state(monster).halo = halo
	if halo == null and light_level > 0:
		GlowHalo.light(monster, color.lightened(0.6), light_level)


## The lantern stays in the hand on its side (mirrored when it faces left); raised and
## swelling while it casts.
func update(monster: Monster, _delta: float) -> void:
	var state := _state(monster)
	var held := state.lantern
	if held == null or not is_instance_valid(held):
		return
	var step := cast_step(monster.casting_index >= 0, monster.telegraph)
	var side := -1.0 if monster.facing.x < -0.3 else 1.0
	var at := cast_lantern_offset if step > 0 else lantern_offset
	held.position = Vector2(at.x * side, at.y)
	var halo := state.halo
	if halo and is_instance_valid(halo):
		halo.position = monster.rig.position + held.position * Actor.SPRITE_SCALE
		halo.size = glow_size_at(step)
		halo.bright = step >= cast_glow_steps


## The glow's step while casting: 0 not casting, then 1 to `cast_glow_steps` as the warning
## (`progress`, 0..1) fills.
func cast_step(casting: bool, progress: float) -> int:
	if not casting:
		return 0
	return clampi(ceili(clampf(progress, 0.0, 1.0) * cast_glow_steps), 1, cast_glow_steps)


## The glow's core size at `step` (cast_step()), on the art's grid.
func glow_size_at(step: int) -> float:
	if step <= 0:
		return glow_size
	return PixelDraw.snap_length(lerpf(glow_size, cast_glow_size, float(step) / cast_glow_steps))


## In the bestiary: the same shade (the body shader's pallor and rim, as ActorRig paints it) and
## its lantern in hand.
func dress_look(sprite: AnimatedSprite2D) -> void:
	var look := ShaderMaterial.new()
	look.shader = BodyLook.SHADER
	look.set_shader_parameter(&"ramps", BodyLook.ramps())
	look.set_shader_parameter(&"flash_amount", pallor)
	look.set_shader_parameter(&"flash_color", color)
	var frame := Vector2(16, 16)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite.animation) and sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
		frame = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size()
	var corner := sprite.offset - frame * 0.5
	look.set_shader_parameter(&"frame_rect", Vector4(corner.x, corner.y, frame.x, frame.y))
	if rim.a > 0.0:
		look.set_shader_parameter(&"outline_color", rim)
		look.set_shader_parameter(&"outline_beat", false)
	sprite.material = look
	if lantern:
		var held := Sprite2D.new()
		held.name = "Lantern"
		held.texture = lantern
		held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		held.position = lantern_offset
		held.use_parent_material = false
		sprite.add_child(held)
