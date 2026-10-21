class_name VfxElementSet
extends Resource
## Every element's look (VfxElementDef), so code can ask for one by id: data/vfx/elements.tres.

@export var elements: Array[VfxElementDef] = []


func find(element_id: StringName) -> VfxElementDef:
	for element in elements:
		if element and element.id == element_id:
			return element
	return null
