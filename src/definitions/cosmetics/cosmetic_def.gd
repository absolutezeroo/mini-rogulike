class_name CosmeticDef
extends Resource
## Something the hero wears for the look alone (docs/design/progression.md, "The Wardrobe"): no
## number of the game changes with it. A resource in data/cosmetics/, listed in content_db.tres
## (Cosmetics). The profile keeps only which one of each slot is worn (Profile.worn); what
## opens it is its `unlock` (CosmeticUnlock), asked of the profile each time, so a rule changed
## in the data applies to every profile at once.

enum Slot {
	## Light and motes around the hero, a glow on the ground at his feet (AuraDef).
	AURA,
}

@export var id: StringName
@export var display_name: String = ""
## One line of the Well's voice, under its name in the Wardrobe.
@export_multiline var description: String = ""
@export var slot: Slot = Slot.AURA
## What opens it; null: open from the start.
@export var unlock: CosmeticUnlock
## Its place in the Wardrobe's list (lower first).
@export var order: int = 0


## Worn by right: its unlock met.
func is_open() -> bool:
	return unlock == null or unlock.is_met()


## What opens it, in a sentence ("" when it is open from the start).
func unlock_text() -> String:
	return unlock.describe() if unlock else ""
