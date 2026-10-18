class_name Inventory
extends RefCounted
## The items carried by the player (not the equipped ones).

signal changed

var capacity: int
var items: Array[ItemDef] = []


func _init(max_items: int = 16) -> void:
	capacity = max_items


func is_full() -> bool:
	return items.size() >= capacity


func add(item: ItemDef) -> bool:
	if item == null or is_full():
		return false
	items.append(item)
	changed.emit()
	return true


func remove(item: ItemDef) -> bool:
	var index := items.find(item)
	if index == -1:
		return false
	items.remove_at(index)
	changed.emit()
	return true


func count_of(item: ItemDef) -> int:
	return items.count(item)


func first_consumable() -> ConsumableDef:
	for item in items:
		if item is ConsumableDef:
			return item
	return null


## Identical items grouped together, in pickup order: [{ "item": ItemDef, "count": int }].
func grouped() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index_of := {}
	for item in items:
		if index_of.has(item):
			result[index_of[item]].count += 1
		else:
			index_of[item] = result.size()
			result.append({ "item": item, "count": 1 })
	return result
