class_name ItemLook
## What an item shows of itself (docs/vfx.md, "Rarity and runes"): its rarity's look and the
## elements it carries. One place reads the data, so new content shows for free: a weapon's
## own `element` (the Frost Staff), the statuses its hits leave (`on_hit`: a Burning affix is
## fire, a Frozen one frost, a Venomous one poison), its affixes' and runes' passives
## (`Passive.look_element()`: the Ember Rune is fire, the Spark Rune storm, Vampiric and Leech
## blood, Echo and Prism arcane) and a rune's family as a last resort.

## Most elements a weapon shows at once (the first paints the blade, the rest add their motes).
const MOST := 2


## The elements `item` carries, the strongest sign first, each once (empty: a plain item).
static func elements(item: ItemDef) -> Array[VfxElementDef]:
	var found: Array[VfxElementDef] = []
	if item is RuneDef:
		_add(found, rune_element(item as RuneDef))
		return found
	var equipment := item as EquipmentDef
	if equipment == null:
		return found
	var weapon := item as WeaponDef
	if weapon:
		_add(found, weapon.element)
		for rune in equipment.runes:
			_add(found, rune_element(rune))
		_add_status(found, weapon.on_hit)
	for affix in equipment.affixes:
		if affix == null:
			continue
		_add_status(found, affix.on_hit if weapon else null)
		for passive in affix.passives:
			_add(found, passive.look_element() if passive else null)
	return found


## What `rune` is made of: its passives' element, else its family's color.
static func rune_element(rune: RuneDef) -> VfxElementDef:
	if rune == null:
		return null
	for passive in rune.passives:
		var element := passive.look_element() if passive else null
		if element:
			return element
	return VfxElementDef.or_color(null, rune.family.color) if rune.family else null


## The element the hero's swing is drawn in: the weapon's own, else the first one it carries
## (a katana with an Ember Rune swings in fire). Monsters' blows keep their weapon's.
static func swing_element(weapon: WeaponDef, hero: bool) -> VfxElementDef:
	if weapon == null:
		return null
	if weapon.element or not hero:
		return weapon.element
	var carried := elements(weapon)
	return carried[0] if not carried.is_empty() else null


## The rarity look of `item` (Common's for anything that isn't found equipment).
static func rarity_look(item: ItemDef) -> RarityLookDef:
	return ItemRarity.look(ItemRarity.of(item))


static func _add_status(found: Array[VfxElementDef], status: OnHitStatus) -> void:
	if status == null:
		return
	if status.burn_damage > 0:
		_add(found, VfxElementDef.named(&"fire"))
	if status.poison_damage > 0:
		_add(found, VfxElementDef.named(&"poison"))
	if status.slow > 0.0:
		_add(found, status.slow_element if status.slow_element else VfxElementDef.named(&"frost"))


static func _add(found: Array[VfxElementDef], element: VfxElementDef) -> void:
	if element and not found.has(element):
		found.append(element)
