class_name RemoteConfigDef
extends Resource
## The remote settings' allow-list and timing (data/online/remote_config.tres, read by the
## RemoteConfig autoload; docs/online.md "Remote settings"): every key the game takes from Talo's
## game config, and how often it asks.

@export var keys: Array[RemoteKeyDef] = []
## Seconds the config read is trusted before it is read again (the title screen asks again after
## that; Talo itself caches it 10 minutes).
@export_range(60, 86400) var refresh_seconds := 900.0
## Seconds between two checks of the title screen's event plaque while the title stays open: an
## event that ended meanwhile is hidden (its bonus no longer applies to a run started then), and
## the time left is told again.
@export_range(1, 3600) var title_refresh_seconds := 30.0
## Seconds after the game starts before the first read (the start isn't slowed).
@export_range(0, 60) var start_delay := 2.0


## The key named `key` in Talo, or null when it isn't on the list.
func find(key: String) -> RemoteKeyDef:
	for def in keys:
		if def and def.key == key:
			return def
	return null


## The keys acting on `hook` (several for a per-difficulty or per-language hook).
func for_hook(hook: RemoteKeyDef.Hook) -> Array[RemoteKeyDef]:
	var result: Array[RemoteKeyDef] = []
	for def in keys:
		if def and def.hook == hook:
			result.append(def)
	return result
