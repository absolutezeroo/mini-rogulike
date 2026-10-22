class_name DeedCondition
extends ProgressCondition
## A precise thing done when a warden fell: slain with a blade of its own school, by fire, with
## an empty purse... Met once, for good (Profile, through Narrative). The deeper chapters and
## lines of a chronicle ask for one, so the story is earned, not only waited for.
## The HuntTracker checks every deed of a warden's chronicle when it dies (achieved(), with the
## kill's context: HuntTracker.kill_context()). Subclass it for a new kind of deed
## (src/definitions/story/deeds/): override achieved(), and give the data a `hint` and a `rule`.
##
## The codex shows the `hint` (a riddle in the Well's voice, fair but never the rule) until the
## `revealed_by` fragment is found; then the plain `rule`.

## Unique among this warden's deeds (saved: never rename).
@export var id: StringName
## The riddle, in the Well's voice: « Il ne parle qu'à une lame de son école. »
@export var hint: String = ""
## The plain rule: "Slay it with a Katana."
@export var rule: String = ""
## Finding this fragment gives the rule away (empty: only the riddle, until done).
@export var revealed_by: FragmentDef


func is_met(subject: Resource = null) -> bool:
	return subject is MonsterDef and Narrative.is_deed_done(subject as MonsterDef, self)


func describe(_subject: Resource = null) -> String:
	if is_revealed():
		return tr(rule)
	return tr(hint) if not hint.is_empty() else tr(rule)


## The rule may be shown (its fragment found).
func is_revealed() -> bool:
	return revealed_by != null and Narrative.is_found(revealed_by)


## The warden's death described by `kill` (HuntTracker.kill_context()) is this deed.
func achieved(_kill: Dictionary) -> bool:
	return false


func deeds() -> Array[DeedCondition]:
	return [self]
