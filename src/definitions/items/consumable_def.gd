class_name ConsumableDef
extends ItemDef
## A single-use item. Runs its effects, exactly like a skill does.

@export var effects: Array[Effect] = []


func get_type_label() -> String:
	return "Consumable"


func use(user: Actor, aim: Vector2) -> void:
	for effect in effects:
		effect.apply(user, aim)
