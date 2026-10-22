class_name DialogueLineDef
extends Resource
## One thing a speaker may say: one to three short pages, gated by ProgressConditions (the
## story's, and the run's facts: RunFacts, the subject of the conditions here), ranked by
## `priority` among the open ones, said once or again after a few runs. Picked and remembered by
## Dialogues (through Narrative: Profile.lines_told). Texts are English keys with {codes} filled
## from the run (RunFacts.codes(): {killer}, {a_killer}, {place}, {floor}, {level}...).

## Unique in its dialogue (saved as told: never rename).
@export var id: StringName
## The pages, in order: each at most two sentences (a phone's box at Fonts.BODY).
@export var lines: PackedStringArray = []
@export var conditions: Array[ProgressCondition] = []
## Among the open lines the highest is said (a precise advice before a general one, something
## new before a line said before).
@export var priority: int = 0
## Said once ever.
@export var once: bool = false
## Runs to wait before it may be said again (0: any time).
@export_range(0, 99) var cooldown_runs: int = 0
## Kept in the codex's Voices once said (false: a line made of one run's facts).
@export var remembered: bool = true


func is_open(facts: Resource = null) -> bool:
	return ProgressCondition.all_met(conditions, facts)
