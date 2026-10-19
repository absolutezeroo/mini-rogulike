class_name FloorWardPassive
extends Passive
## Every floor starts with a ward around the owner: damage soaked up before HP (see Actor.add_ward).

@export var ward_per_stack: int = 20
## How long it lasts if nothing breaks it.
@export var duration: float = 600.0


func on_floor_started(owner: Actor, perk: PerkSet.Entry) -> void:
	owner.add_ward(ward_per_stack * perk.stacks, duration)
