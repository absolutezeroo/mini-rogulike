class_name TelemetryEventDef
extends Resource
## One kind of gameplay statistics event (TelemetryDef): its name on Talo, on or off, and the
## fields it sends. A field ending in "*" stands for every field starting so ("skill.*": each
## skill's uses and damage).

## The event's name in Talo's dashboard.
@export var name: StringName
## Off: never queued.
@export var enabled := true
## What it is for, said in docs/online.md (not shown in the game).
@export_multiline var purpose := ""
@export var fields: PackedStringArray = []


## Whether `field` is sent.
func allows(field: String) -> bool:
	for allowed in fields:
		if allowed == field or (allowed.ends_with("*") and field.begins_with(allowed.trim_suffix("*"))):
			return true
	return false
