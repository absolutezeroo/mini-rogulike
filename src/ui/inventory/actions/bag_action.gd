class_name BagAction
extends RefCounted
## One thing the bag screen does with the picked item (BagSelection): equip or use it, drop it,
## break it down, move it to the belt. The panel gives each one a button on the item's card (touch,
## mouse, the focus) and, when it has an `input`, a key and a gamepad button that do it straight
## from the bag's slots without opening anything (InventoryPanel._input). Extend it for a new one.

## The input action that does it on keys and gamepads (its cap shows on its button); empty: only
## its button. `ui_accept` does it only while an item's slot holds the focus (Enter elsewhere
## presses the focused button).
var input: StringName = &""
## The button's node name (reachable as %Name from the panel: tests).
var node_name := ""


## Can it be done with `selection` now? (Its button shows only then.)
func available(_selection: BagSelection) -> bool:
	return false


## Its button's words for `selection` ("Equip", "Learn"...), translated.
func label(_selection: BagSelection) -> String:
	return ""


## Does it ask a second press first? (A rare piece broken down.)
func needs_confirm(_selection: BagSelection) -> bool:
	return false


## Its button's words once armed, waiting for the second press ("Sure?": short, the buttons
## share a row).
func confirm_label(selection: BagSelection) -> String:
	return label(selection)


## The card's line once armed: what a second press does, in the device's words ("Tap again:
## +40 gold", "Press [X] again: +40 gold").
func confirm_note(_selection: BagSelection) -> String:
	return ""


## Does it. True if something changed (the bag is shown again).
func run(_selection: BagSelection) -> bool:
	return false
