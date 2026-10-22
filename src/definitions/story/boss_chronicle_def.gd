class_name BossChronicleDef
extends Resource
## A warden's story (BossDef.chronicle), told a chapter at a time before its fight, as if it had
## lived: who it was, its life before the Well, how it fell, the keeper who bound it, what it
## knows of the Maw. Chapters open with its deaths, the progress of the story (docs/lore.md
## section 7), the fragments found and the deeds done; Narrative decides which one is told.
## In data/story/chronicles/<boss id>.tres; its fragments in data/story/fragments/.

## In the order they are told.
@export var chapters: Array[ChronicleChapter] = []
## What it says as it wakes when the hero carries a memory of it (the last open one).
@export var waking_lines: Array[WakingLine] = []
## Found on the floors of its act before its arena (FragmentPlacer).
@export var fragments: Array[FragmentDef] = []


## Every deed its chapters and lines ask for (watched at its death).
func deeds() -> Array[DeedCondition]:
	var result: Array[DeedCondition] = []
	for chapter in chapters:
		if chapter:
			for deed in chapter.deeds():
				if not result.has(deed):
					result.append(deed)
	for line in waking_lines:
		if line:
			for deed in line.deeds():
				if not result.has(deed):
					result.append(deed)
	return result


func chapter_by_id(id: StringName) -> ChronicleChapter:
	for chapter in chapters:
		if chapter and chapter.id == id:
			return chapter
	return null
