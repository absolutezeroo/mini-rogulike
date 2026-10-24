class_name FloorRoute
extends RefCounted
## One way down: what the next floor will be if the hero takes these stairs. Normal floors end
## on two stairs (and a boss arena opens two once the boss falls), each leading to a different
## world of the next act floor, maybe cursed (harder, better loot) or with an event. A sign over
## each stairs tells which. Floors before a boss have one way only: the boss's arena.
##
## The offer is fixed by the run's seed (same seed, same choice; a saved run gets it back), and
## the floor itself is still built from its own seed (see Game._enter_floor()).

var biome: BiomeDef
var curse: CurseDef
var floor_event: FloorEventDef


## The ways down to floor `depth` (empty: no choice there, the floor rolls its own world).
## `tuning`: the run's remote settings (RunState.tuning): a running event's floor event comes
## more often, and the Dawn Knell's omen is on every way (after the usual rolls: the rest of the
## offer stays the same).
static func offer(content: ContentDB, depth: int, difficulty: DifficultyDef, offer_seed: int, tuning: RemoteTuning = null) -> Array[FloorRoute]:
	var result: Array[FloorRoute] = []
	var config := content.dungeon
	if config.route_count < 2 or depth <= 1 or config.boss_for_depth(depth) != null:
		return result
	var act := config.act_for_depth(depth)
	if act == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = offer_seed
	var worlds: Array = act.biomes.filter(func(b: BiomeDef) -> bool: return b != null and b.min_depth <= depth)
	if worlds.is_empty():
		return result
	var curse_chance := difficulty.curse_chance if difficulty else 0.0
	var omen := DailyRun.twist(content, tuning.omen) if tuning else null
	for i in config.route_count:
		var route := FloorRoute.new()
		# A different world for each way while there are some left.
		var left: Array = worlds.filter(func(b: BiomeDef) -> bool: return not result.any(func(r: FloorRoute) -> bool: return r.biome == b))
		route.biome = ContentDB.pick_from(left if not left.is_empty() else worlds, depth, rng) as BiomeDef
		if rng.randf() < curse_chance:
			route.curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
		if route.curse == null and rng.randf() < config.floor_event_chance:
			route.floor_event = pick_event(content, depth, rng, tuning)
		# The second way is often the bold one: a twist if it rolled none.
		if i > 0 and route.is_plain() and rng.randf() < config.route_twist_chance:
			var curse_share := curse_chance / maxf(curse_chance + config.floor_event_chance, 0.01)
			if rng.randf() < curse_share:
				route.curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
			if route.curse == null:
				route.floor_event = pick_event(content, depth, rng, tuning)
		if omen:
			route.curse = omen as CurseDef
			route.floor_event = omen as FloorEventDef
		result.append(route)
	return result


## A floor event for a floor at `depth`, by spawn weight, a running remote event's one boosted
## (`tuning`, the run's RemoteTuning).
static func pick_event(content: ContentDB, depth: int, rng: RandomNumberGenerator, tuning: RemoteTuning = null) -> FloorEventDef:
	return ContentDB.pick_from(content.floor_events, depth, rng, tuning.event_boost if tuning else {}) as FloorEventDef


## The seed of the offer leading to floor `depth` in a run of seed `run_seed`.
static func seed_for(run_seed: int, depth: int) -> int:
	return hash("well-of-souls-routes-%d-%d" % [run_seed, depth])


func is_plain() -> bool:
	return curse == null and floor_event == null


## The sign over its stairs: the world's name.
func title() -> String:
	return tr(biome.display_name) if biome else tr("The depths")


## The second line of the sign: the curse or event and what it means, or "".
func twist() -> String:
	if curse:
		return tr("%s - better loot") % tr(curse.display_name)
	if floor_event:
		return tr(floor_event.display_name)
	return ""


func twist_color() -> Color:
	if curse:
		return curse.color
	if floor_event:
		return floor_event.color
	return Color.WHITE


## For the log: "the Drowned Caverns, cursed: Frostbound".
func summary() -> String:
	if curse:
		return tr("%s (cursed: %s)") % [title(), tr(curse.display_name)]
	if floor_event:
		return tr("{route} ({event})").format({ "route": title(), "event": tr(floor_event.display_name) })
	return title()
