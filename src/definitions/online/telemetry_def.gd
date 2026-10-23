class_name TelemetryDef
extends Resource
## The gameplay statistics (data/online/telemetry.tres, read by the Telemetry autoload;
## docs/online.md "Gameplay statistics"): which events exist and which of their fields are sent
## (a field not listed is dropped before it is queued), how many wait at most, how many go in one
## request. Turning an event or a field off is data; a new field needs its line in RunTelemetry
## and here.
##
## Talo refuses a prop whose key is longer than 128 characters or whose value is longer than 512
## (its backend's MAX_KEY_LENGTH / MAX_VALUE_LENGTH, src/entities/prop.ts): sanitize() keeps every
## event inside, and caps the number of props.

## Talo's own limits.
const MAX_KEY_LENGTH := 128
const MAX_VALUE_LENGTH := 512

@export var events: Array[TelemetryEventDef] = []
## Events kept waiting on the device at most (the oldest go first).
@export_range(1, 1000) var max_queue := 120
## Events in one request.
@export_range(1, 100) var batch_size := 20
## Props in one event at most (the per-skill and per-element ones grow with the build).
@export_range(8, 500) var max_props := 160
## Seconds between two tries to send what waits while there is no network.
@export var retry_seconds := 120.0


## The event `event_name`, or null.
func event(event_name: StringName) -> TelemetryEventDef:
	for def in events:
		if def.name == event_name:
			return def
	return null


## `props` as Talo takes them: only the fields `def` lists, keys and values as strings within
## Talo's limits (a long list is cut at its last comma), at most max_props.
func sanitize(def: TelemetryEventDef, props: Dictionary) -> Dictionary:
	var result := {}
	var keys := props.keys()
	keys.sort()
	for key: Variant in keys:
		var name := str(key)
		if result.size() >= max_props:
			break
		if name.is_empty() or name.length() > MAX_KEY_LENGTH or name.begins_with("META_") or not def.allows(name):
			continue
		result[name] = clip(str(props[key]))
	return result


## `value` no longer than Talo takes: a comma list loses its last items whole.
static func clip(value: String) -> String:
	if value.length() <= MAX_VALUE_LENGTH:
		return value
	var cut := value.substr(0, MAX_VALUE_LENGTH)
	var comma := cut.rfind(",")
	return cut.substr(0, comma) if comma > 0 else cut
