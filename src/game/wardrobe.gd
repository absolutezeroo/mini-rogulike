class_name Wardrobe
extends RefCounted
## What the hero wears for the look alone (CosmeticDef, docs/design/progression.md "The
## Wardrobe"): the one worn in each slot, kept in the profile (Profile.worn) by id. A worn one
## whose unlock is no longer met (the data changed) or that the game no longer has is worn as
## nothing, without touching what the profile keeps.


## The profile's key for `slot` ("aura").
static func slot_key(slot: CosmeticDef.Slot) -> String:
	return String(CosmeticDef.Slot.keys()[slot]).to_lower()


## What is worn in `slot`, or null.
static func worn(content: ContentDB, slot: CosmeticDef.Slot) -> CosmeticDef:
	if content == null:
		return null
	var id := StringName(str(Profile.worn.get(slot_key(slot), "")))
	if id.is_empty():
		return null
	var cosmetic := content.get_cosmetic(id)
	return cosmetic if cosmetic and cosmetic.slot == slot and cosmetic.is_open() else null


## The aura worn, or null.
static func aura(content: ContentDB) -> AuraDef:
	return worn(content, CosmeticDef.Slot.AURA) as AuraDef


## Wears `cosmetic` in its slot (only if it is open), saved; `take_off` in `slot`: nothing there.
static func wear(cosmetic: CosmeticDef) -> bool:
	if cosmetic == null or not cosmetic.is_open():
		return false
	Profile.worn[slot_key(cosmetic.slot)] = String(cosmetic.id)
	Profile.save_profile()
	Profile.changed.emit()
	return true


static func take_off(slot: CosmeticDef.Slot) -> void:
	Profile.worn.erase(slot_key(slot))
	Profile.save_profile()
	Profile.changed.emit()
