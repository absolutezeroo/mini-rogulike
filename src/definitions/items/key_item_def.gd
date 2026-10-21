class_name KeyItemDef
extends ItemDef
## A key carried in the bag: it does nothing by itself and can't be sold or used. Something
## further down asks for it (HiddenFloorDef.key). Say what it is in `description`, in the
## Well's voice: a key tells no rules.


func get_type_label() -> String:
	return tr("Key")


func rarity_color() -> Color:
	return color
