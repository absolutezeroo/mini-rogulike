class_name OfferQueue
extends RefCounted
## Perk choices waiting to be made, in order: level ups, relics, encounters' gifts.
## Two kinds (Offer.on_demand): a level up's choice waits for the player to ask for it (the HUD's
## perk button, Game.open_offers()); the others (a boss' or a pact's relics, an encounter's gift)
## come up by themselves when no menu is open (Game._show_next_offer()). A choice put off with
## "Later" waits like a level up, with the same cards.
## Saved with the run, the one on screen included (with its cards: quitting can't reroll them).

## The waiting choices changed (one more, one taken): the HUD's count.
signal changed


class Offer:
	var rarity: PerkDef.Rarity = PerkDef.Rarity.COMMON
	var count := 3
	var title := ""
	var subtitle := ""
	## Waits for the player to open it (a level up, or a choice put off).
	var on_demand := false
	## The cards dealt (after rerolls and banishes), kept when the choice is put off or saved;
	## empty until it is first shown.
	var cards: Array[PerkDef] = []


	func to_data() -> Dictionary:
		return { "rarity": rarity, "count": count, "title": title, "subtitle": subtitle,
			"on_demand": on_demand, "cards": RunSave.refs(cards) }


	static func from_data(data: Dictionary) -> Offer:
		var offer := Offer.new()
		offer.rarity = int(data.get("rarity", 0)) as PerkDef.Rarity
		offer.count = int(data.get("count", 3))
		offer.title = str(data.get("title", ""))
		offer.subtitle = str(data.get("subtitle", ""))
		# Saves from before choices waited: whatever was pending waits for the player.
		offer.on_demand = bool(data.get("on_demand", true))
		for ref: Variant in data.get("cards", []):
			var perk := RunSave.load_ref(ref) as PerkDef
			if perk:
				offer.cards.append(perk)
		return offer


## The choice on screen right now (null when none).
var shown: Offer

var _pending: Array[Offer] = []


## `on_demand`: it waits for the player (a level up) instead of coming up by itself.
func add(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String, on_demand: bool = false) -> Offer:
	var offer := Offer.new()
	offer.rarity = rarity
	offer.count = count
	offer.title = title
	offer.subtitle = subtitle
	offer.on_demand = on_demand
	_pending.append(offer)
	changed.emit()
	return offer


## The relics a boss leaves behind (if it has any).
## `extra`: more relics to choose from (a Legendary or Shiny boss).
func add_relic(boss: BossDef, extra: int = 0) -> void:
	if boss and boss.relic_choices > 0:
		add(PerkDef.Rarity.RARE, boss.relic_choices + extra, tr("Relic"), tr("A relic lies in the warden's remains. Choose one."))


func is_empty() -> bool:
	return _pending.is_empty()


## How many choices wait (the one on screen not counted).
func size() -> int:
	return _pending.size()


## Takes the next offer out of the queue: the first one, or with `automatic_only` the first one
## that comes up by itself (null if none).
func pop(automatic_only: bool = false) -> Offer:
	for i in _pending.size():
		if not automatic_only or not _pending[i].on_demand:
			var offer: Offer = _pending.pop_at(i)
			changed.emit()
			return offer
	return null


## Puts `offer` back at the head of the line, waiting for the player (the choice was put off).
func put_back(offer: Offer) -> void:
	offer.on_demand = true
	_pending.push_front(offer)
	changed.emit()


func clear() -> void:
	_pending.clear()
	shown = null
	changed.emit()


## The offers to save: the one on screen first, then the waiting ones.
func to_data(include_shown: bool) -> Array:
	var data := []
	if include_shown and shown:
		data.append(shown.to_data())
	for offer in _pending:
		data.append(offer.to_data())
	return data


func load_data(data: Array) -> void:
	for entry: Variant in data:
		if entry is Dictionary:
			_pending.append(Offer.from_data(entry))
	changed.emit()
