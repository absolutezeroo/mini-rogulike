class_name OnHitStatus
extends Resource
## Statuses a hit leaves on its target (fire, frost...). Put one on a skill effect,
## a projectile or a weapon: every enemy it hits gets them.

## Burn: damage every half second for `burn_duration` seconds. 0 = no burn.
@export var burn_damage: int = 0
@export var burn_duration: float = 3.0
## Slow: fraction of move speed lost (0.4 = 40% slower). 0 = no slow.
@export_range(0.0, 0.9, 0.05) var slow: float = 0.0
@export var slow_duration: float = 2.0


func apply_to(target: Actor, source: Actor) -> void:
	if target.is_dead:
		return
	if burn_damage > 0:
		target.statuses.apply_dot(&"burn", burn_damage, 0.5, burn_duration, source, Color("ff8c42"))
	if slow > 0.0:
		target.statuses.apply_slow(slow, slow_duration)
