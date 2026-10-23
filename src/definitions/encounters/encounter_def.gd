class_name EncounterDef
extends ContentDef
## Something strange met in a room: a spring, a blood altar, a grinning spirit, a statue...
## Stand by it, press Interact (its `verb`) and choose. `display_name` is the title, `description` the text,
## `icon` the sprite (16x16, drawn at 2x). Each one can be used once.
## Listed in content_db.tres > Encounters (`min_depth`, `spawn_weight`).

@export var choices: Array[EncounterChoice] = []
## The word on the Interact button by it ("Pray", "Drink"...).
@export var verb: String = "Approach"
## Text of the button that walks away.
@export var leave_label: String = "Leave"
## Shown on it once used.
@export var used_text: String = "Nothing more happens."
## What it says as it is opened, in quotes in place of its description (Dialogues; null or
## nothing open: the description). The Grinning Spirit's past, told over the runs.
@export var dialogue: DialogueDef
## An empty niche standing beside it, drawn on the floor and told under its description (the
## Keeper's Statue: the niche cut for the last keeper; its inscription waits for the reveal).
@export var niche: EncounterNiche
