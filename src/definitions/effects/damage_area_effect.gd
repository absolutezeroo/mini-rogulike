class_name DamageAreaEffect
extends Effect
## Hits every enemy inside a circle, centred on the user or pushed forward along the aim.

@export var radius: float = 80.0
## Damage = flat_damage + user's skill power (power boosted by skill power) x multiplier.
@export var damage_multiplier: float = 1.5
@export var flat_damage: int = 0
## Distance of the circle centre along the aim direction. 0 = around the user.
@export var offset: float = 0.0
@export var knockback: float = 220.0
@export var color: Color = Color(1.0, 0.8, 0.3)
## What it is made of (data/vfx/elements/): without a sheet, the element's nova (Frost Nova's
## ring of crystals); a sheet is painted in the element's ramp; an explosion takes its colors
## (Quake: earth, not fire). Its hits flash in its language.
@export var element: VfxElementDef
## Statuses left on the enemies hit (burn, slow...).
@export var status: OnHitStatus
## A blast (its element's burst, a ripple, screen shake) instead of a simple ring.
@export var explosive: bool = false
## A sheet of its own played on the area's middle at the art's size, never stretched to the
## radius (Thunder's bolt from the sky, Smite's column of light), over the element's nova.
@export var strike: VfxSheetDef

@export_group("Effect sheet")
## Drawn as a blade's blow (Cleave's crescent, Whirlwind's spin: data/vfx/slashes/) from the
## user toward the aim, its edge at the area's far side, instead of a sheet or a nova.
@export var slash: SlashDef
## Played on the area, e.g. a circular slash or rock spikes. Without one, a ring is drawn.
@export var fx: Texture2D
## Frames in the sheet. 0 = square frames.
@export var fx_frames: int = 0
## Turn the sheet toward the aim (slashes in front of the user). Without a sheet, the element's
## pieces sweep across the front of the area instead of ringing it (Flame Arc).
@export var fx_follow_aim: bool = false
@export var fx_tint: Color = Color.WHITE


func apply(user: Actor, aim: Vector2) -> void:
	var center := user.global_position + aim * offset
	var base := flat_damage + roundi(user.get_skill_power() * damage_multiplier)
	Combat.damage_area(user.world, user, center, radius, base, knockback, false, status, element)
	if explosive:
		Vfx.explosion(user.world, center, radius, element)
	elif slash:
		var reach := offset + radius if slash.shape != SlashDef.Shape.SPIN else radius
		SwingVfx.slash(user.world, slash, user.global_position + Vector2(0, -6), aim, reach, element, user.faction != Actor.Faction.PLAYER)
	elif fx:
		# The sheet at the nearest whole size of the art's pixel (SheetVfx snaps it), not
		# stretched to the radius: a 32-pixel sheet over a 110 radius is drawn 6x, never 6.9x.
		var frame := VfxSheetDef.cell_size(fx, fx_frames)
		var size := radius * 2.0 / maxi(frame.x, frame.y)
		var sheet := SheetVfx.create(fx, center, aim.angle() if fx_follow_aim else 0.0, size, SheetVfx.DEFAULT_FPS, frame.x)
		user.world.spawn_vfx(sheet.with_color(fx_tint).in_element(element))
	elif element and fx_follow_aim:
		Vfx.arc(user.world, center, radius, aim, element)
	elif element:
		Vfx.nova(user.world, center, radius, element)
	else:
		user.world.spawn_vfx(RingVfx.create(center, radius, color))
	if strike:
		user.world.spawn_vfx(SheetVfx.play(strike, center, aim, element))
