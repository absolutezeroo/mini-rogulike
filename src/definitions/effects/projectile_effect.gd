class_name ProjectileEffect
extends Effect
## Fires one or more projectiles along the aim direction.

## Damage = flat_damage + user's skill power (power boosted by skill power) x multiplier.
@export var damage_multiplier: float = 1.0
@export var flat_damage: int = 0
@export var speed: float = 380.0
@export var radius: float = 8.0
@export var max_distance: float = 520.0
@export var count: int = 1
## Fan width in degrees (360 = full ring).
@export var spread_degrees: float = 0.0
@export var pierce: int = 0
@export var knockback: float = 160.0
## Greater than 0: the projectile explodes on impact and hits everything around.
@export var explosion_radius: float = 0.0
@export var color: Color = Color(1.0, 0.5, 0.2)
## Sprite (or frames in a row) of the projectile. Without one, a glowing dot is drawn.
@export var texture: Texture2D
## Statuses left on the enemies hit (burn, slow...).
@export var status: OnHitStatus
## Magic shots glow and burst on impact; 0 for plain things (feathers, coins, arrows).
@export_range(0.0, 1.0) var glow: float = 1.0
## Fired by a passive (a family's ring of bolts...): its hits trigger no on-hit perk
## (HitInfo.is_secondary). Leave off for skills.
@export var secondary: bool = false
## Turns the aim (degrees): a second ring shifted by half a gap closes the safe lanes.
@export var angle_offset: float = 0.0


func apply(user: Actor, aim: Vector2) -> void:
	var spec := ProjectileSpec.new()
	spec.damage = flat_damage + roundi(user.get_skill_power() * damage_multiplier)
	spec.speed = speed
	spec.radius = radius
	spec.max_distance = max_distance
	spec.count = count
	spec.spread_degrees = spread_degrees
	spec.pierce = pierce
	spec.knockback = knockback
	spec.explosion_radius = explosion_radius
	spec.color = color
	spec.texture = texture
	spec.status = status
	spec.glow = glow
	spec.secondary = secondary
	user.world.fire_projectiles(user, aim.rotated(deg_to_rad(angle_offset)) if angle_offset != 0.0 else aim, spec)
