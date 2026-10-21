class_name StoryDef
extends Resource
## The game's identity: its name and the story around the run.
## The hero is a ninja going down the Well under their village to bring back the souls it stole:
## souls are what monsters drop, what the shrine turns into upgrades, what bosses guard.

@export var title: String = "The Well of Souls"
@export var tagline: String = ""
## Told before the first run (and from the title screen). One page per entry.
@export_multiline var intro_pages: PackedStringArray = []
## Shown when the last boss falls.
@export_multiline var victory_text: String = ""
## One is picked when the hero dies.
@export_multiline var death_lines: PackedStringArray = []
## Under the shrine's title.
@export var shrine_text: String = ""


func random_death_line() -> String:
	return death_lines[randi() % death_lines.size()] if not death_lines.is_empty() else ""
