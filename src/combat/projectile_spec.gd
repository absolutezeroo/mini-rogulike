class_name ProjectileSpec
extends RefCounted
## Everything needed to fire projectiles. Built from a ranged WeaponDef or a ProjectileEffect.

var damage: int = 1
var speed: float = 400.0
var radius: float = 5.0
var max_distance: float = 400.0
var count: int = 1
var spread_degrees: float = 0.0
var pierce: int = 0
var knockback: float = 100.0
var explosion_radius: float = 0.0
var color := Color.WHITE
var texture: Texture2D
## Statuses left on the enemies hit (burn, slow...).
var status: OnHitStatus
## Fired by a passive (shards out of a body, a family's ring of bolts): its hits are secondary
## (HitInfo.is_secondary): they trigger no on-hit perk, so effects can't feed each other.
var secondary: bool = false
## Magic shots (fireballs, bolts) glow in their color, light up the dark and burst on impact;
## 0 for plain things (shurikens, arrows).
var glow: float = 1.0
