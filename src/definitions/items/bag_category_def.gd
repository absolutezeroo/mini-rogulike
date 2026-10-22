class_name BagCategoryDef
extends Resource
## One tab of the bag (data/items/bag_categories.tres): a name, an icon and which items it holds.
## Items are sorted into tabs by what they are (their class: every weapon and armor is an
## EquipmentDef) or, for a few, by name (`item_ids`: the Scroll of Fire is a consumable but reads
## like a tome). See BagCategorySet for the order the rules are tried in.

@export var id: StringName
## The tab's name, English (translated where shown).
@export var display_name := ""
## Drawn on the tab (an item's icon: a katana for the gear, a rune for the runes...).
@export var icon: Texture2D
## The item classes it holds (class_name of an ItemDef subclass); a subclass counts as its parent
## ("EquipmentDef" holds weapons and armors).
@export var kinds: Array[StringName] = []
## Items it holds whatever their class (ItemDef.id): it wins over `kinds`.
@export var item_ids: Array[StringName] = []
## Holds whatever no other tab claims (one tab should).
@export var catch_all := false
## Its tab only shows while it holds something (the keys' tab: rarely anything in it).
@export var hidden_when_empty := false
