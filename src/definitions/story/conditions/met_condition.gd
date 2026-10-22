class_name MetCondition
extends ProgressCondition
## A kind of monster met at least once (seen, or its arena walked into). Without a `monster`:
## the subject itself. Keeps a hidden warden's fragments off the floors until the hero has found
## it (its name must not be given away earlier).

@export var monster: MonsterDef
## Plain words for the codex (the default names the monster).
@export var text: String = ""


func is_met(subject: Resource = null) -> bool:
	var target := monster if monster else subject as MonsterDef
	if target == null:
		return false
	return Profile.has_seen(target.id) or int(Profile.boss_meetings.get(String(target.id), 0)) > 0


func describe(subject: Resource = null) -> String:
	if not text.is_empty():
		return tr(text)
	var target := monster if monster else subject as MonsterDef
	return tr("Meet %s") % tr(target.display_name) if target else ""
