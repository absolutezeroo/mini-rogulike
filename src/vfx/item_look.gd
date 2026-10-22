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


## The elements of what reaches every hit of the hero, his weapon's skills included: the runes
## set in `item` and its affixes' passives (they work like perks: docs/design/loot.md), in that
## order. Not the weapon's own element nor the status its plain hits leave (`on_hit` is its
## basic attack's alone), so a skill shot dressed in these never shows what it doesn't do.
static func passive_elements(item: EquipmentDef) -> Array[VfxElementDef]:
	var found: Array[VfxElementDef] = []
	if item == null:
		return found
	for rune in item.runes:
		_add(found, rune_element(rune))
	for affix in item.affixes:
		if affix == null:
			continue
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


## The second element the hero's blows show (a few of its bits beside the first's): the next one
## the weapon carries, null when it carries one or none. Monsters' blows show one.
static func second_element(weapon: WeaponDef, hero: bool) -> VfxElementDef:
	if weapon == null or not hero:
		return null
	var first := swing_element(weapon, hero)
	for element in elements(weapon):
		if element != first:
			return element
	return null


## The element a hit of the hero's weapon lands in (its flash, the death it gives: HitInfo.element):
## the weapon's own, else a status every hit leaves (a Burning affix: fire). A rune that works by
## chance (the Ember Rune's 50%) lands in its element only on the hits it fires on (its passive
## says so: BurnOnHitPassive); the swing shows it always (`swing_element`).
static func hit_element(weapon: WeaponDef) -> VfxElementDef:
	if weapon == null:
		return null
	if weapon.element:
		return weapon.element
	var status := weapon.on_hit
	if status == null:
		return null
	if status.burn_damage > 0:
		return VfxElementDef.named(&"fire")
	if status.poison_damage > 0:
		return VfxElementDef.named(&"poison")
	if status.slow > 0.0:
		return status.slow_element if status.slow_element else VfxElementDef.named(&"frost")
	return null


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
