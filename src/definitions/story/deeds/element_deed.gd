class_name ElementDeed
extends DeedCondition
## The killing blow was made of `element` (fire against the ice wyrm): a burn's tick counts, as
## does a fire weapon's swing (Actor.killing_element()).

@export var element: VfxElementDef


func achieved(kill: Dictionary) -> bool:
	return element != null and kill.get("killing_element") == element
