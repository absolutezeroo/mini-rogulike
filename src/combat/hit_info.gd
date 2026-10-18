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
