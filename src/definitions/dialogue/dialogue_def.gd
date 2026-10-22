class_name DialogueDef
extends Resource
## What a speaker may say at one moment (the Vigil-Keeper telling a death, her advice, her words
## at the shrine; the merchant as his shop opens...): a pool of lines, one said at a time
## (Dialogues.pick()). Hung where it is said: NarrativeDef (the death screen, the victory, the
## shrine), ShopDef, ForgeDef, EncounterDef; every one listed in NarrativeDef.dialogues (the
## codex's Voices, the tests).

## Unique (saved with its lines' ids as told: never rename).
@export var id: StringName
@export var speaker: SpeakerDef
@export var lines: Array[DialogueLineDef] = []


func line(line_id: StringName) -> DialogueLineDef:
	for entry in lines:
		if entry and entry.id == line_id:
			return entry
	return null
