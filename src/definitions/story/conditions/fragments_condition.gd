class_name FragmentsCondition
extends ProgressCondition
## Fragments found (FragmentDef, picked up on the floors before a warden): one in particular, or
## `count` of a warden's (its BossChronicleDef.fragments). Without `boss`: the subject's.
## How a warden "remembers" what the hero carries: a waking line, a chapter, a deed's rule.

## A given fragment (then `count` and `boss` are not used).
@export var fragment: FragmentDef
## Empty: the warden whose chronicle this is.
@export var boss: BossDef
@export_range(1, 20) var count: int = 1


func is_met(subject: Resource = null) -> bool:
	if fragment:
		return Narrative.is_found(fragment)
	var owner := _owner(subject)
	return owner != null and Narrative.found_count(owner) >= count


func describe(subject: Resource = null) -> String:
	if fragment:
		return tr("Find the fragment \"%s\"") % tr(fragment.title)
	var owner := _owner(subject)
	if owner == null:
		return ""
	var total := owner.chronicle.fragments.size() if owner.chronicle else count
	if owner == subject:
		if count >= total:
			return tr("Find every fragment about it")
		return tr("Find a fragment about it") if count <= 1 else tr("Find %d fragments about it") % count
	return tr("Find %d fragments about %s") % [count, tr(owner.display_name)]


func _owner(subject: Resource) -> BossDef:
	return boss if boss else subject as BossDef
