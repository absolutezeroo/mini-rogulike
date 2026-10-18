class_name HitInfo
extends RefCounted
## One hit, before the defender's armor is applied.

var amount: int = 0
var is_crit: bool = false
## Who dealt the hit. May be null (e.g. the shooter died before the projectile landed).
var source: Actor
var knockback := Vector2.ZERO
## Impact sound (from the weapon). Null = the defender's own hurt sound.
var sound: AudioStream
## Damage caused by another effect (burn, thorns, shockwave...). Secondary hits don't trigger
## on-hit perks, so effects can't chain into each other forever, and they skip hit stop.
var is_secondary: bool = false
## Statuses left on the target (burn, slow...). Optional.
var status: OnHitStatus
