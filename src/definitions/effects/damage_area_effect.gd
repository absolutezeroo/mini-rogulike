class_name DamageAreaEffect
extends Effect
## Hits every enemy inside a circle, centred on the user or pushed forward along the aim.

@export var radius: float = 80.0
## Damage = flat_damage + user's power (weapon damage + attack) x multiplier.
@export var damage_multiplier: float = 1.5
@export var flat_damage: int = 0
## Distance of the circle centre along the aim direction. 0 = around the user.
@export var offset: float = 0.0
@export var knockback: float = 220.0
@export var color: Color = Color(1.0, 0.8, 0.3)
## Fire, smoke and screen shake instead of a simple ring.
@export var explosive: bool = false
## Effect sheet (frames in a row) played on the area, e.g. a circular slash.
@export var fx: Texture2D


func apply(user: Actor, aim: Vector2) -> void:
	var center := user.global_position + aim * offset
	var base := flat_damage + roundi(user.get_power() * damage_multiplier)
	Combat.damage_area(user.world, user, center, radius, base, knockback)
	if explosive:
		Vfx.explosion(user.world, center, radius)
	elif fx:
		user.world.spawn_vfx(SheetVfx.create(fx, center, 0.0, radius * 2.0 / fx.get_height()))
	else:
		user.world.spawn_vfx(RingVfx.create(center, radius, color))
