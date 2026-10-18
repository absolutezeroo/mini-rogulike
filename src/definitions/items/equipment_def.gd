class_name EquipmentDef
extends ItemDef
## An item worn in an equipment slot. Its stat bonuses apply while equipped.

enum Slot { WEAPON, HEAD, BODY }

const SLOT_NAMES := {
	Slot.WEAPON: "Weapon",
	Slot.HEAD: "Head",
	Slot.BODY: "Body",
}

@export var slot: Slot = Slot.BODY
@export var bonuses: StatBlock


func get_type_label() -> String:
	return SLOT_NAMES[slot]


func get_details() -> String:
	var text := description
	if bonuses:
		var bonus_text := bonuses.describe()
		if not bonus_text.is_empty():
			text += "\n" + bonus_text
	return text
