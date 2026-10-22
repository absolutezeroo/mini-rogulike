class_name Inventory
extends RefCounted
## The items carried by the player (not the equipped ones), in compartments: one per kind of
## thing (BagCategorySet, data/items/bag_categories.tres: weapons, armor, runes, tomes and
## scrolls, consumables, the rest), each with its own places (BagCategoryDef.capacity). A
## compartment fills on its own: a bag full of runes still takes a sword. "Is there room?" is
## always asked for an item, of its compartment (can_add()).
## Identical items (the same ItemDef.stack_key(): the same potion, or two rolled katanas of the
## same rarity, level and affixes) stack: a stack takes one place, however many it holds.
## Without compartments (`categories` null: a list to group, a test) it is one plain bag of
## `capacity` places.

signal changed

## The game's compartments.
const CATEGORIES: BagCategorySet = preload("res://data/items/bag_categories.tres")

## Places of the plain bag (no compartments); with compartments, see capacity_of().
var capacity: int
## The compartments (null: one plain bag).
var categories: BagCategorySet
## Places added to every compartment (PlayerDef.bag_bonus; an upgrade could add more).
var extra_places := 0
## Places added to one compartment: its BagCategoryDef.id -> places.
var extra_by_category := {}
## Every item carried, one entry each (a stack of three is three entries).
var items: Array[ItemDef] = []


func _init(max_items: int = 16, compartments: BagCategorySet = null) -> void:
	capacity = max_items
	categories = compartments


## How many compartments (1 for a plain bag).
func compartment_count() -> int:
	return categories.categories.size() if categories else 1


## The compartment `item` goes in (0 in a plain bag).
func compartment_of(item: ItemDef) -> int:
	return maxi(categories.index_of(item), 0) if categories else 0


## Places of compartment `index`, upgrades included.
func capacity_of(index: int) -> int:
	if categories == null:
		return capacity
	var category := categories.categories[index]
	return category.capacity + extra_places + int(extra_by_category.get(category.id, 0))


## Places taken in compartment `index`: one per stack.
func places_used_in(index: int) -> int:
	var keys := {}
	for item in items:
		if compartment_of(item) == index:
			keys[item.stack_key()] = true
	return keys.size()


## Places taken in the whole bag.
func places_used() -> int:
	var keys := {}
	for item in items:
		keys[item.stack_key()] = true
	return keys.size()


## Places left in compartment `index` (0 when full, or over capacity).
func free_in(index: int) -> int:
	return maxi(capacity_of(index) - places_used_in(index), 0)


## More stacks than places in compartment `index` (an old save, a compartment made smaller):
## they are kept, and nothing new goes in until the player makes room. 0 normally.
func over_capacity(index: int) -> int:
	return maxi(places_used_in(index) - capacity_of(index), 0)


func is_compartment_full(index: int) -> bool:
	return places_used_in(index) >= capacity_of(index)


## Every compartment full (a plain bag: its places all taken).
func is_full() -> bool:
	for i in compartment_count():
		if not is_compartment_full(i):
			return false
	return true


## Room for `item`: a free place in its compartment, or a stack it joins.
func can_add(item: ItemDef) -> bool:
	return item != null and (find_like(item) != null or not is_compartment_full(compartment_of(item)))


func add(item: ItemDef) -> bool:
	if not can_add(item):
		return false
	items.append(item)
	changed.emit()
	return true


## Puts `item` in even past its compartment's places (a saved run coming back: nothing it
## carried is lost; over_capacity() then says so).
func force_add(item: ItemDef) -> void:
	if item:
		items.append(item)
		changed.emit()


## What to say when `item` finds no room: its compartment's words ("No room left for runes"),
## translated.
func full_text(item: ItemDef) -> String:
	if categories and item:
		var category := categories.category_of(item)
		if category and not category.full_text.is_empty():
			return TranslationServer.tr(category.full_text)
	return TranslationServer.tr("Your bag is full")


## Takes one `item` out: that very object if it is carried, else one of its stack.
func remove(item: ItemDef) -> bool:
	return take(item) != null


## Like remove(), but gives back the object taken out (null if none).
func take(item: ItemDef) -> ItemDef:
	var index := items.find(item)
	if index == -1:
		var like := find_like(item)
		index = items.find(like) if like else -1
	if index == -1:
		return null
	var taken := items[index]
	items.remove_at(index)
	changed.emit()
	return taken


## A carried item that stacks with `item` (itself first), or null.
func find_like(item: ItemDef) -> ItemDef:
	if item == null:
		return null
	if items.has(item):
		return item
	var key := item.stack_key()
	for carried in items:
		if carried.stack_key() == key:
			return carried
	return null


## How many of `item`'s stack are carried.
func count_of(item: ItemDef) -> int:
	if item == null:
		return 0
	var key := item.stack_key()
	return items.reduce(func(total: int, carried: ItemDef) -> int: return total + (1 if carried.stack_key() == key else 0), 0)


## Would `incoming` still fit once one `outgoing` has left the bag? (Equipping one of a stack sends
## the worn item to the bag, but frees no place; a rune set in a weapon of a stack frees none in
## the weapons' compartment.) Only a place of `incoming`'s own compartment counts.
func fits_after_taking(outgoing: ItemDef, incoming: ItemDef) -> bool:
	if incoming == null:
		return true
	var incoming_key := incoming.stack_key()
	var outgoing_key := outgoing.stack_key() if outgoing else ""
	if incoming_key == outgoing_key or find_like(incoming) != null:
		return true
	var compartment := compartment_of(incoming)
	var frees := 1 if outgoing and count_of(outgoing) == 1 and compartment_of(outgoing) == compartment else 0
	return places_used_in(compartment) - frees < capacity_of(compartment)


## Stacks, in pickup order: [{ "item": ItemDef (the first of the stack), "count": int }].
func grouped() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index_of := {}
	for item in items:
		var key := item.stack_key()
		if index_of.has(key):
			result[index_of[key]].count += 1
		else:
			index_of[key] = result.size()
			result.append({ "item": item, "count": 1 })
	return result
