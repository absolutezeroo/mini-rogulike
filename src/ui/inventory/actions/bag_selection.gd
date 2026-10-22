class_name BagSelection
extends RefCounted
## What is picked in the bag screen, for its actions (BagAction): one item of the bag, what is
## worn in a slot, or a belt slot (at most one of them), and whose it is.

const NONE := -1

var player: Player
## The item picked: in the bag, worn, or on the belt (null: nothing).
var item: ItemDef
## The worn slot picked (EquipmentDef.Slot), NONE if the item isn't worn.
var worn_slot := NONE
## The belt slot picked, NONE if the item isn't on the belt.
var belt := NONE


func _init(owner: Player, picked: ItemDef = null, slot: int = NONE, belt_index: int = NONE) -> void:
	player = owner
	item = picked
	worn_slot = slot
	belt = belt_index


## An item of the bag (not worn, not on the belt).
func in_bag() -> bool:
	return item != null and worn_slot == NONE and belt == NONE


func is_worn() -> bool:
	return item != null and worn_slot != NONE


func on_belt() -> bool:
	return item != null and belt != NONE


## Names the picked thing for a confirmation armed on it: the same stack, the same slot.
func key() -> String:
	if item == null:
		return ""
	return "%s|%d|%d" % [item.stack_key(), worn_slot, belt]
