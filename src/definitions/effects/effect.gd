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
		# A weak reference, not the user itself: the timer outlives a monster freed meanwhile, and
		# Godot checks a lambda's captured nodes before running it ("Lambda capture at index 0 was
		# freed"), even one whose first line asks is_instance_valid().
		var user_ref: WeakRef = weakref(user)
		user.get_tree().create_timer(effect.delay, false).timeout.connect(func() -> void:
			var who := user_ref.get_ref() as Actor
			if who and not who.is_dead and who.is_inside_tree() and who.world.floor_id == floor_id:
				effect.apply(who, aim))
