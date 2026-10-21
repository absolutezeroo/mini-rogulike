class_name HitInfo
extends RefCounted
## One hit, before the defender's armor is applied.

var amount: int = 0
var is_crit: bool = false
## Who dealt the hit. May be null (e.g. the shooter died before the projectile landed).
var source: Actor
var knockback := Vector2.ZERO
## Where the blow comes from (the attacker for a swing or a dash, the shot for a projectile).
## INF = unknown: shields then guess from the knockback.
var origin := Vector2.INF
## Impact sound (from the weapon). Null = the defender's own hurt sound.
var sound: AudioStream
## Damage caused by another effect (burn, thorns, shockwave...). Secondary hits don't trigger
## on-hit perks, so effects can't chain into each other forever, and they skip hit stop.
var is_secondary: bool = false
## A small repeated tick (burn, poison, cold, quicksand): no invulnerability frames, no hit stop
## or shake, or a burn would shield the hero from monster hits half the time.
var is_tick: bool = false
## The color of its damage number (a burn's orange, a poison's green); transparent: the usual.
var text_color := Color.TRANSPARENT
## Lands even on an invulnerable actor (a price paid at an altar, giving up...).
var unavoidable: bool = false
## Statuses left on the target (burn, slow...). Optional.
var status: OnHitStatus
