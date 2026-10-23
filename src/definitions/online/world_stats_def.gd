class_name WorldStatsDef
extends Resource
## The world counters, "The Well's Toll" (data/online/world_stats.tres, read by the WorldStats
## autoload; docs/online.md "World counters"): the counters (WorldStatDef), how often the world's
## numbers are read again, how often the title screen's line turns.

@export var stats: Array[WorldStatDef] = []
## Seconds the world's numbers are kept before they are read again (Talo is asked at most this
## often, whatever the screens do).
@export_range(30, 86400) var refresh_seconds := 300.0
## Seconds between two tries to send what waits while there is no network.
@export_range(10, 3600) var retry_seconds := 120.0
## Seconds each counter stays on the title screen before the next one.
@export_range(2, 60) var title_line_seconds := 7.0
## A counter shows on the title screen only from this number (a lonely "1 bell rung" reads
## wrong, and an empty world says nothing).
@export_range(1, 1000000) var title_min_count := 2


## The counter with Talo's internal name `internal_name`, or null.
func stat(internal_name: String) -> WorldStatDef:
	for def in stats:
		if def and def.internal_name == internal_name:
			return def
	return null


## The counters that are on.
func enabled_stats() -> Array[WorldStatDef]:
	var result: Array[WorldStatDef] = []
	for def in stats:
		if def and def.enabled:
			result.append(def)
	return result
