class_name MetCondition
extends ProgressCondition
## A kind of monster met at least once (seen, or its arena walked into). Without a `monster`:
## the subject itself. Keeps a hidden warden's fragments off the floors until the hero has found
## it (its name must not be given away earlier).
## The monster is given by its def, or by its id when the def would make a loop of resources
## ("Tôma met" opens the reveal, which Tôma's own chronicle asks for); then `text` says it.

@export var monster: MonsterDef
## Instead of `monster` (the def's `id`).
@export var monster_id: StringName
## Plain words for the codex (the default names the monster).
@export var text: String = ""


func is_met(subject: Resource = null) -> bool:
	var id := monster.id if monster else monster_id
	if id == &"" and subject is MonsterDef:
		id = (subject as MonsterDef).id
	if id == &"":
		return false
	return Profile.has_seen(id) or int(Profile.boss_meetings.get(String(id), 0)) > 0


func describe(subject: Resource = null) -> String:
	if not text.is_empty():
		return tr(text)
	if monster == null and monster_id != &"":
		return ""  # (by id: its words are its `text`)
	var target := monster if monster else subject as MonsterDef
	return tr("Meet %s") % tr(target.display_name) if target else ""
