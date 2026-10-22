class_name ChronicleChapter
extends Resource
## A chapter of a warden's chronicle (BossChronicleDef): a few lines told before its fight, in
## the Well's voice, the first time the chapter is open. It opens when the warden was slain
## `slain` times and every condition is met (a floor reached, a fragment found, a deed done:
## ProgressCondition). Kept in the codex once open.

## Unique in its chronicle (saved as told: never rename).
@export var id: StringName
## Its name in the codex and over the narration: "The First Mouthful".
@export var title: String = ""
## 2 to 4 lines, each at most two short sentences (they must fit a phone's box at Fonts.BODY).
@export var lines: PackedStringArray = []
## Times the warden must have been slain (0: the first meeting).
@export_range(0, 99) var slain: int = 0
## Anything else it waits for (docs/lore.md section 7: the reveals' order).
@export var conditions: Array[ProgressCondition] = []


func is_open(boss: BossDef) -> bool:
	return Profile.kill_count(boss.id) >= slain and ProgressCondition.all_met(conditions, boss)


## What is still missing, in plain words (or a deed's riddle), one per line.
func requirements(boss: BossDef) -> PackedStringArray:
	var lines_left := PackedStringArray()
	var kills := Profile.kill_count(boss.id)
	if kills < slain:
		lines_left.append(TranslationServer.tr("Slay it once") if slain <= 1 else TranslationServer.tr("Slay it %d times") % slain)
	lines_left.append_array(ProgressCondition.describe_unmet(conditions, boss))
	return lines_left


func deeds() -> Array[DeedCondition]:
	var result: Array[DeedCondition] = []
	for condition in conditions:
		if condition:
			result.append_array(condition.deeds())
	return result
