class_name EncounterDef
extends ContentDef
## Something strange met in a room: a spring, a blood altar, a grinning spirit, a statue...
## Walk up to it and choose. `display_name` is the title, `description` the text,
## `icon` the sprite (16x16, drawn at 2x). Each one can be used once.
## Listed in content_db.tres > Encounters (`min_depth`, `spawn_weight`).

@export var choices: Array[EncounterChoice] = []
## Text of the button that walks away.
@export var leave_label: String = "Leave"
## Shown on it once used.
@export var used_text: String = "Nothing more happens."
