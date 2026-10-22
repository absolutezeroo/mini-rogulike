class_name FragmentDef
extends Resource
## A fragment of the past, found on a floor before its warden (BossChronicleDef.fragments): a
## page, a tablet, a letter, written by someone who was there (docs/lore.md; the lore skill: a
## real author, a place, 2 to 5 short lines ending on an image). Found once for good (Profile);
## read again in the codex. Finding them opens more of the warden's story (FragmentsCondition).

## Unique in the game (saved: never rename).
@export var id: StringName
## Its name in the reading panel and the codex: "A Tithe Ledger, Last Page".
@export var title: String = ""
## Who wrote it: "A tithe-keeper of Solhar".
@export var author: String = ""
## Where or when: "Solhar, the year of the last harvest".
@export var place: String = ""
@export var lines: PackedStringArray = []
## Its look on the floor (the kind of thing it is).
@export var look: FragmentLookDef
## It only lies on a floor once these are met (Tôma's journal waits for the reveal).
@export var conditions: Array[ProgressCondition] = []


func can_appear(boss: BossDef) -> bool:
	return ProgressCondition.all_met(conditions, boss)
