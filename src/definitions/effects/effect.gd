class_name Effect
extends Resource
## Something that happens when a skill or a consumable is used.
## Subclasses override apply(). `aim` is a normalized direction chosen by the user.


func apply(_user: Actor, _aim: Vector2) -> void:
	pass
