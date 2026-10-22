class_name SpeakerDef
extends Resource
## Someone who talks in a DialogueBox or on a keeper's panel: the Vigil-Keeper at the shrine, the
## Old Wanderer, Brann, the Grinning Spirit (docs/lore.md section 6: who they are and how they
## speak). Only the look and the voice of the box: what they say is their DialogueDefs.

## Unique (the codex's Voices groups the lines it kept by speaker).
@export var id: StringName
@export var display_name: String = ""
## Under the name ("Priestess of the bell").
@export var title: String = ""
## The face in the box and the codex (a 38x38 Ninja Adventure faceset, drawn at whole steps).
@export var portrait: Texture2D
## The body where the speaker stands (a sheet of 16x16 cells: the first row is its idle frames).
@export var figure: Texture2D
## Its name's color in the box.
@export var color: Color = Color(1.0, 0.82, 0.4)
## A short sound as each line begins (UI bus). Null: silent.
@export var voice: AudioStream
@export_range(-30.0, 6.0, 0.5) var voice_db: float = -8.0
## How fast its words are typed (a slow, ritual voice types slower).
@export_range(5.0, 200.0, 1.0) var letters_per_second: float = 45.0
