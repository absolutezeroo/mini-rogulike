class_name BagDropAction
extends BagAction
## Drops one of the picked stack at the hero's feet (it can be picked up again: no confirmation).
## G on a keyboard, Y on an Xbox gamepad.


func _init() -> void:
	input = &"item_drop"
	node_name = "DropButton"


func available(selection: BagSelection) -> bool:
	return selection.in_bag()


func label(_selection: BagSelection) -> String:
	return TranslationServer.tr("Drop")


func run(selection: BagSelection) -> bool:
	if not available(selection):
		return false
	selection.player.drop_item(selection.item)
	return true
