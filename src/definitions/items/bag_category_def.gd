class_name BagCategoryDef
extends Resource
## One compartment of the bag, and its tab (data/items/bag_categories.tres): a name, an icon,
## which items it holds and how many places it has. Each compartment fills on its own: 16 runes
## never take a weapon's place (Inventory).
## Items are sorted into tabs by what they are (their class: every weapon and armor is an
## EquipmentDef) or, for a few, by name (`item_ids`: the Scroll of Fire is a consumable but reads
## like a tome). See BagCategorySet for the order the rules are tried in.

@export var id: StringName
## The tab's name, English (translated where shown).
@export var display_name := ""
## Said when it has no room left ("No room left for runes"), English (translated where shown):
## the toast of loot left on the ground, the merchant's Buy, the forge.
@export var full_text := ""
## Places in it (a stack takes one). Upgrades add to it: Inventory.extra_places (every
## compartment), Inventory.extra_by_category (this one, by id).
@export_range(1, 99) var capacity := 16
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
