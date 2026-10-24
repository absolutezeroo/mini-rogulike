class_name FeedbackDef
extends Resource
## "Send feedback" (data/online/feedback.tres, read by the Feedback autoload; docs/online.md
## "Player feedback"): the categories a message can go to, how long it may be, how often the
## player may send one, how much waits without network, and how much of the game's log goes with
## the game's details.

@export var categories: Array[FeedbackCategoryDef] = []
## A message shorter than this (after trimming) is refused: "ok" says nothing.
@export_range(1, 100) var min_length := 5
## The most a message may hold (Talo takes 5000; a phone's keyboard makes long ones rare, and the
## dashboard reads better short).
@export_range(50, 5000) var max_length := 1000
## Seconds between two messages (a held Send button, a bored player): the form says how long.
@export_range(0, 3600) var min_seconds_between := 60
## Messages kept while there is no network (the oldest dropped past it).
@export_range(1, 100) var max_queue := 10
## Seconds between two tries to send what waits while there is no network.
@export_range(10, 3600) var retry_seconds := 120.0
## Lines from the end of the game's log sent with the game's details (0: none).
@export_range(0, 100) var log_lines := 20


## The category `id`, or null.
func category(id: StringName) -> FeedbackCategoryDef:
	for def in categories:
		if def and def.id == id:
			return def
	return null
