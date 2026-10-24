class_name FloorLedger
extends RefCounted
## What the hero used up of the things a floor's seed lays, kept for the floor's save
## (World.spent_data() "spent"): a resumed run rebuilds the floor from its seed, and these must
## stay used up, or putting the app away and coming back would hand them out again.
##
## While the floor is being built (`numbering`), each thing laid of a kind (an item lying around,
## a gold pile, a prop, an encounter) gets the next number of its kind: the seed lays them in the
## same order every time, so a number names the same thing on the rebuilt floor. What is spent is
## kept as [number, id]; the id is a guard: a number that came out as something else (a floor not
## rebuilt quite the same) is left alone, better one too many than the wrong one gone.
## What comes later (a monster's drop, a chest's loot) gets no number: it is never laid again.
## The floor's own monsters keep their own numbers (Monster.floor_index, World "slain").

const ITEM := "items"
const GOLD := "gold"
const PROP := "props"
const ENCOUNTER := "encounters"
const KINDS: Array[String] = [ITEM, GOLD, PROP, ENCOUNTER]

## Numbers are handed out: the floor is being laid (World.build_floor()).
var numbering := false
## Kind -> the things laid, by number: [node, id] (the node may be freed since).
var _laid := {}
## Kind -> the numbers spent, as [number, id].
var _spent := {}


## A new floor: nothing laid, nothing spent.
func reset() -> void:
	_laid.clear()
	_spent.clear()
	numbering = false


## `node` was laid by the floor's seed: its number among its kind, -1 outside the build.
func lay(kind: String, node: Object, id: String) -> int:
	if not numbering:
		return -1
	var laid: Array = _laid.get_or_add(kind, [])
	laid.append([node, id])
	return laid.size() - 1


## `node` was used up (taken, broken, used): kept for the save, once. Nothing if it was not laid.
func spend(kind: String, node: Object) -> void:
	var index := _index_of(kind, node)
	if index < 0 or is_spent(kind, index):
		return
	var spent: Array = _spent.get_or_add(kind, [])
	spent.append([index, (_laid[kind][index] as Array)[1]])


func is_spent(kind: String, index: int) -> bool:
	for pair: Array in _spent.get(kind, []):
		if int(pair[0]) == index:
			return true
	return false


## How many were spent of `kind` (the tests).
func spent_count(kind: String) -> int:
	return (_spent.get(kind, []) as Array).size()


## What the save keeps: kind -> [[number, id], ...].
func to_data() -> Dictionary:
	return _spent.duplicate(true)


## A saved floor built again: every thing saved as spent (`saved`: to_data(), as a save file reads
## it) whose number still names a thing of the same id is handed to `take_back` (kind, node), and
## is spent again for the next save. Damaged entries are skipped.
func restore(saved: Variant, take_back: Callable) -> void:
	if not saved is Dictionary:
		return
	for kind in KINDS:
		var entries: Variant = (saved as Dictionary).get(kind, [])
		if not entries is Array:
			continue
		var laid: Array = _laid.get(kind, [])
		for pair: Variant in entries:
			if not pair is Array or (pair as Array).size() != 2 or not (pair[0] is float or pair[0] is int):
				continue
			var index := int(pair[0])
			if index < 0 or index >= laid.size() or is_spent(kind, index):
				continue
			var entry: Array = laid[index]
			if str(pair[1]) != entry[1] or not is_instance_valid(entry[0]):
				continue  # not the same thing: it stays
			(_spent.get_or_add(kind, []) as Array).append([index, entry[1]])
			take_back.call(kind, entry[0])


func _index_of(kind: String, node: Object) -> int:
	var laid: Array = _laid.get(kind, [])
	for i in laid.size():
		if is_same((laid[i] as Array)[0], node):
			return i
	return -1
