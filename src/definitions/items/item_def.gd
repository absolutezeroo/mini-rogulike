class_name ItemDef
extends ContentDef
## Base class for anything the player can carry.


func get_type_label() -> String:
	return "Item"


## Text shown in the inventory details panel.
func get_details() -> String:
	return description
