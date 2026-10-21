class_name Inventory
extends RefCounted
## The items carried by the player (not the equipped ones).
## Identical items (the same ItemDef.stack_key(): the same potion, or two rolled katanas of the
## same rarity, level and affixes) stack: a stack takes one place, however many it holds.
## `capacity` counts places, not items.

signal changed

## Places in the bag (stacks).
var capacity: int
## Every item carried, one entry each (a stack of three is three entries).
var items: Array[ItemDef] = []


func _init(max_items: int = 16) -> void:
	capacity = max_items


## Places taken: one per stack.
func places_used() -> int:
	var keys := {}
	for item in items:
		keys[item.stack_key()] = true
	return keys.size()


func is_full() -> bool:
	return places_used() >= capacity


## Room for `item`: a free place, or a stack it joins.
func can_add(item: ItemDef) -> bool:
	return item != null and (not is_full() or find_like(item) != null)


func add(item: ItemDef) -> bool:
	if not can_add(item):
		return false
	items.append(item)
	changed.emit()
	return true


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
## the worn item to the bag, but frees no place.)
func fits_after_taking(outgoing: ItemDef, incoming: ItemDef) -> bool:
	if incoming == null:
		return true
	var incoming_key := incoming.stack_key()
	var outgoing_key := outgoing.stack_key() if outgoing else ""
	if incoming_key == outgoing_key:
		return true
	var frees := 1 if outgoing and count_of(outgoing) == 1 else 0
	return find_like(incoming) != null or places_used() - frees < capacity


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
