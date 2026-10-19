class_name Effect
extends Resource
## Something that happens when a skill or a consumable is used.
## Subclasses override apply(). `aim` is a normalized direction chosen by the user.

## Seconds after the skill is used before this effect happens (combos: three quick stabs,
## a fissure running forward...). The aim is the one chosen when the skill was used.
@export var delay: float = 0.0


func apply(_user: Actor, _aim: Vector2) -> void:
	pass


## Runs a list of effects, each after its own delay (skipped if the user died meanwhile).
static func apply_all(effects: Array[Effect], user: Actor, aim: Vector2) -> void:
	for effect in effects:
		if effect == null:
			continue
		if effect.delay <= 0.0:
			effect.apply(user, aim)
			continue
		var floor_id := user.world.floor_id
		user.get_tree().create_timer(effect.delay, false).timeout.connect(func() -> void:
			if is_instance_valid(user) and not user.is_dead and user.is_inside_tree() and user.world.floor_id == floor_id:
				effect.apply(user, aim))
