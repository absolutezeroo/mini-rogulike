class_name BagBeltAction
extends BagAction
## Moves a consumable between the bag and the belt ("To belt" / "To bag"). Its button only (the
## focus reaches it): no key of its own.


func _init() -> void:
	node_name = "BeltButton"


func available(selection: BagSelection) -> bool:
	if not selection.item is ConsumableDef:
		return false
	return selection.on_belt() or (selection.in_bag() and selection.player.belt.can_add(selection.item))


func label(selection: BagSelection) -> String:
	return TranslationServer.tr("To bag") if selection.on_belt() else TranslationServer.tr("To belt")


func run(selection: BagSelection) -> bool:
	if not available(selection):
		return false
	if selection.on_belt():
		return selection.player.pack.move_to_bag(selection.belt)
	return selection.player.pack.move_to_belt(selection.item)
