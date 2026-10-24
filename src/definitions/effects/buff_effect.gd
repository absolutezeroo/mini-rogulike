class_name BuffEffect
extends Effect
## Temporarily adds stats to the user.
## Its `element` (Effect.element): what the blessing is made of (Holy Shield: holy): the sigil takes
## its ramp.

@export var bonuses: StatBlock
@export var duration: float = 6.0
@export var color: Color = Color(1.0, 0.4, 0.3)
## Played on the user instead of the sigil, following them (Holy Shield's ring of light rising
## into a halo). Drawn at its own size, behind the user's body: it rises around them and never
## covers them (docs/vfx.md 2b).
@export var sheet: VfxSheetDef
## Radius of the element's ring around the user, when it has no sheet of its own (Battle Cry:
## jets of blood out of the ground).
@export var element_radius: float = 40.0


func apply(user: Actor, _aim: Vector2) -> void:
	if bonuses == null:
		return
	user.add_timed_bonus(bonuses, duration)
	user.world.spawn_floating_text(user.head_position(), bonuses.describe(), element.color() if element else color)
	if sheet:
		VfxLayer.on_body(user, SheetVfx.play(sheet, Vector2.ZERO, Vector2.RIGHT, element), true)
		if element and element.emissive:
			user.world.flash_light(user.global_position, element.color(), 160.0)
	elif element:
		Vfx.nova(user.world, user.global_position, element_radius, element)
		Vfx.shockwave(user.world, user.global_position, element_radius * 2.0, 5.0)
	else:
		Vfx.magic(user.world, user.global_position, color)


func play_preview(preview: EffectPreview) -> void:
	preview.ring(0.0, preview.caster_radius() + 26.0, color, false)
