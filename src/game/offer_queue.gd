class_name OfferQueue
extends RefCounted
## Perk choices waiting to be shown, in order: level ups, relics, encounters' gifts.
## The game shows them one at a time when no menu is open (see Game._show_next_offer()).
## Saved with the run, the one on screen included.


class Offer:
	var rarity: PerkDef.Rarity = PerkDef.Rarity.COMMON
	var count := 3
	var title := ""
	var subtitle := ""


	func to_data() -> Dictionary:
		return { "rarity": rarity, "count": count, "title": title, "subtitle": subtitle }


	static func from_data(data: Dictionary) -> Offer:
		var offer := Offer.new()
		offer.rarity = int(data.get("rarity", 0)) as PerkDef.Rarity
		offer.count = int(data.get("count", 3))
		offer.title = str(data.get("title", ""))
		offer.subtitle = str(data.get("subtitle", ""))
		return offer


## The choice on screen right now (null when none).
var shown: Offer

var _pending: Array[Offer] = []


func add(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String) -> void:
	var offer := Offer.new()
	offer.rarity = rarity
	offer.count = count
	offer.title = title
	offer.subtitle = subtitle
	_pending.append(offer)


## The relics a boss leaves behind (if it has any).
func add_relic(boss: BossDef) -> void:
	if boss and boss.relic_choices > 0:
		add(PerkDef.Rarity.RARE, boss.relic_choices, "Relic", "The boss left a relic behind. Choose one.")


func is_empty() -> bool:
	return _pending.is_empty()


## Takes the next offer out of the queue.
func pop() -> Offer:
	return _pending.pop_front()


func clear() -> void:
	_pending.clear()
	shown = null


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
