class_name BagDismantleAction
extends BagAction
## Breaks one of the picked stack down for gold (PlayerPack.dismantle, DismantleRules): gear in the
## bag only, never what is worn. A rare or better piece, or one with runes set, asks a second
## press (its button says "Sure?", the card "Press [X] again to break it: +40 gold";
## DismantleRules.needs_confirm); plainer ones go at once. One press, one item: a stack of three
## takes three presses (the rest stays picked), so nothing breaks by the dozen.
## X on a keyboard (or Delete), X on an Xbox gamepad.


func _init() -> void:
	input = &"item_dismantle"
	node_name = "DismantleButton"


func available(selection: BagSelection) -> bool:
	return selection.in_bag() and gold(selection) > 0


func label(_selection: BagSelection) -> String:
	return TranslationServer.tr("Dismantle")


func needs_confirm(selection: BagSelection) -> bool:
	return PlayerPack.DISMANTLE.needs_confirm(selection.item)


func confirm_label(_selection: BagSelection) -> String:
	return TranslationServer.tr("Sure?")


func confirm_note(selection: BagSelection) -> String:
	return Prompts.pick("Tap again to break it: +%d gold", "Press {item_dismantle} again to break it: +%d gold") % gold(selection)  # i18n


## The gold one of the picked stack gives (0 if it can't be broken down).
func gold(selection: BagSelection) -> int:
	if selection.item == null or not DismantleRules.can_dismantle(selection.item):
		return 0
	return PlayerPack.DISMANTLE.gold_for(selection.item)


func run(selection: BagSelection) -> bool:
	if not available(selection):
		return false
	return selection.player.pack.dismantle(selection.item) > 0
