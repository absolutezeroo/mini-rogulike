class_name BagCategorySet
extends Resource
## The bag's tabs (data/items/bag_categories.tres, InventoryPanel): which tab an item lands in,
## and the order items are shown in inside a tab.
##
## An item goes to the first tab naming its id (BagCategoryDef.item_ids); else to the tab naming
## its own class or, failing that, the nearest class it inherits from (a WeaponDef is an
## EquipmentDef); else to the catch-all tab (the last tab if none is marked).

const PATH := "res://data/items/bag_categories.tres"

@export var categories: Array[BagCategoryDef] = []


## The index of `item`'s tab in `categories` (-1 if there are none).
func index_of(item: ItemDef) -> int:
	if categories.is_empty() or item == null:
		return -1
	for i in categories.size():
		if categories[i].item_ids.has(item.id):
			return i
	for kind in class_chain(item):
		for i in categories.size():
			if categories[i].kinds.has(kind):
				return i
	for i in categories.size():
		if categories[i].catch_all:
			return i
	return categories.size() - 1


func category_of(item: ItemDef) -> BagCategoryDef:
	var index := index_of(item)
	return categories[index] if index >= 0 else null


## The class names of `item`, its own first, then each one it extends ("WeaponDef",
## "EquipmentDef", "ItemDef", ...).
static func class_chain(item: Object) -> Array[StringName]:
	var chain: Array[StringName] = []
	var script := item.get_script() as Script
	while script:
		var global := script.get_global_name()
		if global != &"":
			chain.append(global)
		script = script.get_base_script()
	return chain


## The bag's stacks (Inventory.grouped()) that belong to tab `index`, in the tab's order: the
## rarest first, then by kind (weapons, helms, body armors; a rune's family...), the highest item
## level, then by name.
func entries_in(index: int, grouped: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in grouped:
		if index_of(entry.item) == index:
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return before(a.item, b.item))
	return result


## How many items (a stack counts its items) of `grouped` are in tab `index`.
func count_in(index: int, grouped: Array[Dictionary]) -> int:
	var total := 0
	for entry in grouped:
		if index_of(entry.item) == index:
			total += entry.count
	return total


## Does `a` come before `b` inside a tab?
static func before(a: ItemDef, b: ItemDef) -> bool:
	var keys_a := _sort_keys(a)
	var keys_b := _sort_keys(b)
	for i in keys_a.size():
		if keys_a[i] != keys_b[i]:
			return keys_a[i] < keys_b[i]
	return false


static func _sort_keys(item: ItemDef) -> Array:
	var equipment := item as EquipmentDef
	return [
		-ItemRarity.of(item),
		int(equipment.slot) if equipment else 0,
		item.get_type_label(),
		-(equipment.item_level if equipment else 0),
		TranslationServer.tr(item.display_name),
	]
