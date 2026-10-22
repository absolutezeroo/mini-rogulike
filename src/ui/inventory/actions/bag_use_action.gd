class_name BagUseAction
extends BagAction
## Equip (gear in the bag), Unequip (what is worn), Learn (a tome) or Use (a potion, in the bag or
## on the belt). Runes go in at a forge and keys wait for their door: nothing to do with them here.
## Enter, Space or the gamepad's A on an item's slot.


func _init() -> void:
	input = &"ui_accept"
	node_name = "UseButton"


func available(selection: BagSelection) -> bool:
	return selection.item != null and not selection.item is RuneDef and not selection.item is KeyItemDef


func label(selection: BagSelection) -> String:
	if selection.is_worn():
		return TranslationServer.tr("Unequip")
	if selection.item is EquipmentDef:
		return TranslationServer.tr("Equip")
	if selection.item is SkillTomeDef:
		return TranslationServer.tr("Learn")
	return TranslationServer.tr("Use")


func run(selection: BagSelection) -> bool:
	if not available(selection):
		return false
	if selection.on_belt():
		selection.player.use_belt(selection.belt)
	elif selection.is_worn():
		selection.player.unequip(selection.worn_slot as EquipmentDef.Slot)
	else:
		selection.player.use_item(selection.item)
	return true
