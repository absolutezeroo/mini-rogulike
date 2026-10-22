class_name SlainCondition
extends ProgressCondition
## A kind of monster slain at least `count` times, in all runs (Profile.kill_count, the
## bestiary's count). Without a monster: the subject itself ("slay it 3 times").
## The monster is given by its def, or by its id when the def would make a loop of resources (a
## condition used inside that very monster's chronicle: "the Nameless Effigy slain" gates the
## Effigy's own lines); then `text` says it in words.

@export var monster: MonsterDef
## Instead of `monster` (the def's `id`).
@export var monster_id: StringName
@export_range(1, 999) var count: int = 1
## Plain words for the codex instead of the monster's name (a hidden warden must not be named
## before it is met: "Find the one who does not rest").
@export var text: String = ""


func is_met(subject: Resource = null) -> bool:
	var id := _target_id(subject)
	return id != &"" and Profile.kill_count(id) >= count


func describe(subject: Resource = null) -> String:
	if not text.is_empty():
		return tr(text)
	var target := monster if monster else subject as MonsterDef
	if target == null:
		return ""
	if (monster == null and monster_id == &"") or target == subject:
		return tr("Slay it once") if count <= 1 else tr("Slay it %d times") % count
	var name := tr(target.display_name)
	return tr("Slay %s") % name if count <= 1 else tr("Slay %s %d times") % [name, count]


func _target_id(subject: Resource) -> StringName:
	if monster:
		return monster.id
	if monster_id != &"":
		return monster_id
	return (subject as MonsterDef).id if subject is MonsterDef else &""
