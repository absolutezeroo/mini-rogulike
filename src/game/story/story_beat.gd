class_name StoryBeat
extends RefCounted
## What one telling holds (Narrative.plan()): whose story, the chapter told this time (if any),
## what its subject says (if anything), the line the short version recalls. The cinematic's
## steps read it; nothing in it decides anything.

var boss: BossDef
## English keys, translated where shown.
var name := ""
var title := ""
## The chapter told now (null: none new, or the short version).
var chapter: ChronicleChapter
## Not the first chapter ever told of this warden: marked "New".
var chapter_is_new := false
## Its waking words (null: it carries no memory of the hero yet).
var speech: WakingLine
var speech_is_new := false
## A line of a chapter already told (the short version), English key; "" if none.
var echo := ""
## Worth the full cinematic (something new to tell).
var is_full := false


## Something to say at all.
func has_words() -> bool:
	return chapter != null or speech != null or not echo.is_empty()
