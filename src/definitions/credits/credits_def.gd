class_name CreditsDef
extends Resource
## The credits (data/credits/credits.tres, shown by CreditsPanel from the title screen and the
## Options): who made the game and every pack, font, sound and service it uses, with their
## licence and the licence file shipped in the game. Godot's own licence and its third-party
## notices are read from the engine (Engine.get_license_text(), get_copyright_info()), so they
## always match the engine the game was exported with.

## Sections in order (the game, art, sound, font, engine, services...).
@export var sections: Array[CreditSectionDef] = []


## Every entry, in order.
func entries() -> Array[CreditEntryDef]:
	var result: Array[CreditEntryDef] = []
	for section in sections:
		result.append_array(section.entries)
	return result
