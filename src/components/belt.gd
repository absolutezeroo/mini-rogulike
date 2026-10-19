class_name Belt
extends RefCounted
## Potions, bombs and scrolls: a few slots outside the bag, each holding a stack of one kind,
## each with its own button on screen. They don't take room in the bag.

signal changed

const SLOTS := 3
const MAX_STACK := 9

## One entry per slot: { "item": ConsumableDef, "count": int }, or {} when empty.
var slots: Array[Dictionary] = []


func _init() -> void:
	for i in SLOTS:
		slots.append({})


func item_at(index: int) -> ConsumableDef:
	return slots[index].get("item") if index >= 0 and index < SLOTS else null


func count_at(index: int) -> int:
	return int(slots[index].get("count", 0)) if index >= 0 and index < SLOTS else 0


func count_of(item: ItemDef) -> int:
	var total := 0
	for slot in slots:
		if slot.get("item") == item:
			total += int(slot.count)
	return total


## True if `item` would fit (on its stack, or in an empty slot).
func can_add(item: ItemDef) -> bool:
	return _slot_for(item) >= 0


## Puts `item` on its stack, or in the first empty slot. False if it doesn't fit.
func add(item: ItemDef) -> bool:
	var index := _slot_for(item)
	if index < 0:
		return false
	if slots[index].is_empty():
		slots[index] = { "item": item, "count": 1 }
	else:
		slots[index].count += 1
	changed.emit()
	return true


## Takes one item from slot `index` (null if empty).
func take(index: int) -> ConsumableDef:
	var item := item_at(index)
	if item == null:
		return null
	slots[index].count -= 1
	if slots[index].count <= 0:
		slots[index] = {}
	changed.emit()
	return item


## Takes one `item` from wherever it is. False if there is none.
func remove(item: ItemDef) -> bool:
	for i in SLOTS:
		if item_at(i) == item:
			take(i)
			return true
	return false


func is_empty() -> bool:
	return slots.all(func(slot: Dictionary) -> bool: return slot.is_empty())


func _slot_for(item: ItemDef) -> int:
	if not item is ConsumableDef:
		return -1
	for i in SLOTS:
		if item_at(i) == item and count_at(i) < MAX_STACK:
			return i
	for i in SLOTS:
		if slots[i].is_empty():
			return i
	return -1


# --- Saving -------------------------------------------------------------------

func to_data() -> Array:
	return slots.map(func(slot: Dictionary) -> Dictionary:
		return {} if slot.is_empty() else { "item": RunSave.ref(slot.item), "count": slot.count })


func load_data(data: Array) -> void:
	for i in SLOTS:
		slots[i] = {}
		if i >= data.size() or not data[i] is Dictionary or (data[i] as Dictionary).is_empty():
			continue
		var item := RunSave.load_ref(data[i].get("item")) as ConsumableDef
		if item:
			slots[i] = { "item": item, "count": clampi(int(data[i].get("count", 1)), 1, MAX_STACK) }
	changed.emit()
