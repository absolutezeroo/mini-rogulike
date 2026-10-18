class_name ArmorDef
extends EquipmentDef
## Head or body protection. All of its numbers live in `bonuses`.


func get_type_label() -> String:
	return "Armor (%s)" % SLOT_NAMES[slot]
