class_name Equipment
extends RefCounted
## What an actor is wearing: one item per EquipmentDef.Slot.

signal changed

var _slots := {}


func get_item(slot: EquipmentDef.Slot) -> EquipmentDef:
	return _slots.get(slot)


## Equips the item and returns whatever was in that slot before (or null).
func equip(item: EquipmentDef) -> EquipmentDef:
	var previous: EquipmentDef = _slots.get(item.slot)
	_slots[item.slot] = item
	changed.emit()
	return previous


func unequip(slot: EquipmentDef.Slot) -> EquipmentDef:
	var previous: EquipmentDef = _slots.get(slot)
	_slots.erase(slot)
	if previous:
		changed.emit()
	return previous


func total_bonuses() -> StatBlock:
	var total := StatBlock.new()
	for item: EquipmentDef in _slots.values():
		if item.bonuses:
			total = total.plus(item.bonuses)
	return total
