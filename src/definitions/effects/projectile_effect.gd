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
## What it is made of (data/vfx/elements/): without a texture, the shot is the element's own
## projectile; it lands and hits in the element's language (docs/vfx.md).
@export var element: VfxElementDef
## Sprite (or frames in a row) of the projectile. Without one (and no element), a glowing dot.
@export var texture: Texture2D
## Frames in a row of `texture` (0 = square frames).
@export_range(0, 64) var texture_frames: int = 0
## A drawn sheet instead of `texture`, for a shot drawn in 16 directions rather than turned
## (the Demon Cyclops' rays of fire). Wins over `texture` and the element's own projectile.
@export var sheet: VfxSheetDef
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
	spec.color = element.color() if element else color
	spec.texture = texture
	spec.texture_frames = texture_frames
	spec.sheet = sheet
	spec.element = element
	spec.status = status
	spec.glow = glow
	spec.secondary = secondary
	user.world.fire_projectiles(user, aim.rotated(deg_to_rad(angle_offset)) if angle_offset != 0.0 else aim, spec)
