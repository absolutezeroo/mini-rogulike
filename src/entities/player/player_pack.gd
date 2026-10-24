class_name PlayerPack
extends RefCounted
## What the hero does with what he carries (Player.pack): picking things up, the bag (Inventory)
## and the belt (Belt), wearing and taking off gear, drinking and throwing, dropping, breaking
## gear down for gold (DismantleRules). The bag's panel and its actions (BagAction), the
## pickups and the shops come here; the Player keeps the bag, the belt and the gear themselves,
## and the signals the HUD listens to (consumable_used, dismantled, item_dropped).

## Gold for breaking gear down from the bag.
const DISMANTLE: DismantleRules = preload("res://data/items/dismantle.tres")

var _player: Player


func _init(player: Player) -> void:
	_player = player


## Puts an item away: consumables on the belt if there is room, everything else (and the
## overflow) in the bag. False if neither has room.
func store(item: ItemDef) -> bool:
	return _player.belt.add(item) or _player.inventory.add(item)


func can_store(item: ItemDef) -> bool:
	return _player.belt.can_add(item) or _player.inventory.can_add(item)


## Auto loot (Settings.auto_loot, `mode`): does walking over `item` take it? Potions, runes,
## tomes and keys always (gold flies to the hero on its own). "Better only" leaves the gear that
## is worse than what is worn (ItemCompare.is_worse), "By hand" all gear: it waits on the ground,
## and walking over it shows it with a Take button (LootPrompt).
func wants(item: ItemDef, mode: int) -> bool:
	if mode == Settings.LOOT_ALL or not item is EquipmentDef:
		return true
	if mode == Settings.LOOT_OFF:
		return false
	return not ItemCompare.is_worse(item as EquipmentDef, _player.equipment.get_item((item as EquipmentDef).slot))


## Called when walking over an item. Returns false if it could not be taken.
func pick_up(item: ItemDef) -> bool:
	var player := _player
	if item is EquipmentDef and player.equipment.get_item(item.slot) == null:
		player.equipment.equip(item)
		Events.log_message(tr("Equipped %s") % tr(item.display_name), item.color)
		_pickup_feedback(item, Sfx.bank.equip)
		return true
	if store(item):
		Events.log_message(tr("Picked up %s") % tr(item.display_name), item.rarity_color() if item is RuneDef else item.color)
		_pickup_feedback(item, Sfx.bank.pickup)
		return true
	Events.log_message(player.inventory.full_text(item), Palette.DANGER)
	Events.bag_full.emit(item)
	return false


func _pickup_feedback(item: ItemDef, sound: AudioStream) -> void:
	if item is EquipmentDef and (item as EquipmentDef).rarity == ItemRarity.EPIC:
		Events.stat_counted.emit("epics", 1)
	Sfx.play_world(sound, _player.global_position)
	Vfx.sparkles(_player.world, _player.global_position, item.color)


## Uses `item` from the bag: what that means is the item's own (ItemDef.use_from_bag(): a potion
## is drunk, a tome read, gear worn).
func use_item(item: ItemDef) -> void:
	if _player.is_dead or not _player.inventory.items.has(item):
		return
	item.use_from_bag(_player)


## Drinks, throws or reads `item` (a consumable taken from the bag or the belt), toward the
## closest enemy.
func consume(item: ConsumableDef) -> void:
	var player := _player
	item.use(player, player.get_aim_direction(player.tuning().skill_aim_range))
	Events.log_message(tr("Used %s") % tr(item.display_name), item.color)
	player.consumable_used.emit(item)


## Wears `item`, from the bag, what was worn in its slot going back to the bag (EquipmentDef).
func wear_from_bag(item: EquipmentDef) -> void:
	var inventory := _player.inventory
	# One of a stack: it frees no place, and what is worn now needs one.
	var worn := _player.equipment.get_item(item.slot)
	if not inventory.fits_after_taking(item, worn):
		Events.log_message(inventory.full_text(worn), Palette.DANGER)
		Events.bag_full.emit(worn)
		return
	inventory.remove(item)
	var previous := _player.equipment.equip(item)
	if previous:
		inventory.add(previous)
	Sfx.play_ui(Sfx.bank.equip)
	Events.log_message(tr("Equipped %s") % tr(item.display_name), item.color)


func unequip(slot: EquipmentDef.Slot) -> void:
	var equipment := _player.equipment
	var inventory := _player.inventory
	if equipment.get_item(slot) == null:
		return
	if not inventory.can_add(equipment.get_item(slot)):
		Events.log_message(inventory.full_text(equipment.get_item(slot)), Palette.DANGER)
		return
	inventory.add(equipment.unequip(slot))
	Sfx.play_ui(Sfx.bank.equip)


func drop_item(item: ItemDef) -> void:
	var player := _player
	if player.inventory.remove(item):
		player.world.spawn_item(item, player.global_position, false)
		Sfx.play_world(Sfx.bank.drop, player.global_position)
		player.item_dropped.emit(item)


## Breaks `item` (one of its stack in the bag) down for gold (DismantleRules). The gold it gave,
## 0 if it can't be (not equipment, not in the bag).
func dismantle(item: ItemDef) -> int:
	var one: Array[ItemDef] = [item]
	return dismantle_all(one)


## Breaks these down at once (each entry is one item of the bag). Only gear in the bag: what is
## worn, potions, runes, tomes and keys are never touched. The gold it gave.
func dismantle_all(list: Array[ItemDef]) -> int:
	var player := _player
	var gold_gained := 0
	var broken: Array[ItemDef] = []
	for item in list:
		if not DismantleRules.can_dismantle(item):
			continue
		var taken := player.inventory.take(item)
		if taken == null:
			continue
		gold_gained += DISMANTLE.gold_for(taken)
		broken.append(taken)
	if broken.is_empty():
		return 0
	player.add_gold(gold_gained)
	Sfx.play_ui(Sfx.bank.dismantle)
	Sfx.play_ui(Sfx.bank.coin)
	if broken.size() == 1:
		Events.log_message(tr("Dismantled %s: +%d gold") % [tr(broken[0].display_name), gold_gained], Palette.GOLD)
	else:
		Events.log_message(tr("Dismantled %d pieces of gear: +%d gold") % [broken.size(), gold_gained], Palette.GOLD)
	player.dismantled.emit(broken, gold_gained)
	return gold_gained


## The gear in the bag worse than what is worn in its slot (ItemCompare.is_worse): what
## "Dismantle the worse" breaks down. Every item of a stack is listed. `compartment` >= 0: only
## those of that compartment of the bag (the tab open: weapons or armor).
func worse_gear(compartment: int = -1) -> Array[ItemDef]:
	var inventory := _player.inventory
	var result: Array[ItemDef] = []
	for item in inventory.items:
		var gear := item as EquipmentDef
		if compartment >= 0 and inventory.compartment_of(item) != compartment:
			continue
		if gear and DismantleRules.can_dismantle(gear) and ItemCompare.is_worse(gear, _player.equipment.get_item(gear.slot)):
			result.append(item)
	return result


## Uses the item in belt slot `index` (the buttons next to the skills).
func use_belt(index: int) -> void:
	if _player.is_dead or _player.belt.item_at(index) == null:
		return
	var item := _player.belt.take(index)
	consume(item)


## Belt slot 1 (the quick item key).
func use_quick_item() -> void:
	use_belt(0)


## Moves a consumable from the bag to the belt (or back). False if there is no room.
func move_to_belt(item: ItemDef) -> bool:
	var belt := _player.belt
	if not belt.can_add(item) or not _player.inventory.remove(item):
		return false
	belt.add(item)
	return true


func move_to_bag(index: int) -> bool:
	var belt := _player.belt
	if belt.item_at(index) == null or not _player.inventory.can_add(belt.item_at(index)):
		return false
	_player.inventory.add(belt.take(index))
	return true


## Healing potions carried, belt and bag (a consumable that heals: HealEffect).
func healing_carried() -> int:
	var total := 0
	for slot in _player.belt.slots:
		if not slot.is_empty() and PlayerPack.heals(slot.item):
			total += slot.count
	for item in _player.inventory.items:
		if item is ConsumableDef and PlayerPack.heals(item as ConsumableDef):
			total += 1
	return total


## `item` mends the one who drinks it (a potion, not a bomb or a scroll).
static func heals(item: ConsumableDef) -> bool:
	return item != null and item.effects.any(func(effect: Effect) -> bool: return effect is HealEffect)


## How many of `item` the hero carries (belt and bag).
func carried_count(item: ItemDef) -> int:
	return _player.belt.count_of(item) + _player.inventory.count_of(item)
