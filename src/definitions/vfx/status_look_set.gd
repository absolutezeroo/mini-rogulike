class_name StatusLookSet
extends Resource
## Every status's look (StatusLookDef), by status id.

@export var looks: Array[StatusLookDef] = []


func look(status: StringName) -> StatusLookDef:
	for each in looks:
		if each and each.status == status:
			return each
	return null
