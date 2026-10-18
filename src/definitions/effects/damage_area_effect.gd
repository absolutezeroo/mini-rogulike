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
## Statuses left on the enemies hit (burn, slow...).
@export var status: OnHitStatus
## Fire, smoke and screen shake instead of a simple ring.
@export var explosive: bool = false

@export_group("Effect sheet")
## Played on the area, e.g. a circular slash or rock spikes. Without one, a ring is drawn.
@export var fx: Texture2D
## Frames in the sheet. 0 = square frames.
@export var fx_frames: int = 0
## Turn the sheet toward the aim (slashes in front of the user).
@export var fx_follow_aim: bool = false
@export var fx_tint: Color = Color.WHITE


func apply(user: Actor, aim: Vector2) -> void:
	var center := user.global_position + aim * offset
	var base := flat_damage + roundi(user.get_skill_power() * damage_multiplier)
	Combat.damage_area(user.world, user, center, radius, base, knockback, false, status)
	if explosive:
		Vfx.explosion(user.world, center, radius)
	elif fx:
		var frame_width := fx.get_width() / fx_frames if fx_frames > 0 else fx.get_height()
		var size := radius * 2.0 / maxi(frame_width, fx.get_height())
		var sheet := SheetVfx.create(fx, center, aim.angle() if fx_follow_aim else 0.0, size, SheetVfx.DEFAULT_FPS, frame_width)
		user.world.spawn_vfx(sheet.with_color(fx_tint))
	else:
		user.world.spawn_vfx(RingVfx.create(center, radius, color))
