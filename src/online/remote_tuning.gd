class_name RemoteTuning
extends RefCounted
## What the remote settings (RemoteConfig) change in one run, fixed when the run starts and saved
## with it (RunState.tuning): a run keeps the values it began with, even if it is resumed after
## the config changed. Neutral (every multiplier 1, no omen, no boost) when nothing remote applies,
## which is the game exactly as its data makes it.
##
## The multipliers land on the run's own copy of its DifficultyDef (apply_to(), like an ascension
## level), so FloorRules and RunState.souls() read them where they read the difficulty's: nothing
## multiplies them by hand anywhere else.
##
## The game's classes (Game, RunState, DailyRun) ask through the static hooks below, which the
## RemoteConfig autoload fills when it starts: calling the autoload by name from them would make
## World and RunState depend on the online autoloads, a load cycle that breaks the World's
## subclasses. Unset (a tool, a script run alone), every answer is neutral.

## (difficulty id: StringName, daily day: int) -> RemoteTuning: a new run's values.
static var for_run_hook: Callable
## (day: int) -> StringName: the Dawn Knell's omen for that day.
static var omen_hook: Callable
## () -> void: a run starts (a safe point: what was read applies now).
static var run_starting_hook: Callable

## Monsters' and bosses' Health, and everything that hurts the hero (the run's difficulty's).
var enemy_health := 1.0
var enemy_damage := 1.0
## The souls at the end (souls_multiplier times a running event's bonus).
var souls := 1.0
## The Dawn Knell's omen for its day: a curse or floor event id put on each of its normal floors
## (DailyRun.omen()); &"" none.
var omen: StringName = &""
## Floor event id -> how much more likely it is (a running event's boost).
var event_boost := {}
## The event running when the run began ("" none): told in the log at the start.
var event_name := ""


## A new run's values (RemoteConfig.tuning()); neutral without the autoload.
static func for_run(difficulty_id: StringName, daily_day: int = -1) -> RemoteTuning:
	if for_run_hook.is_valid():
		return for_run_hook.call(difficulty_id, daily_day) as RemoteTuning
	return RemoteTuning.new()


## The Dawn Knell's omen for day `day` (RemoteConfig.omen_for()); &"" none.
static func omen_of_day(day: int) -> StringName:
	return omen_hook.call(day) as StringName if omen_hook.is_valid() else &""


## Tells the remote settings a run starts (RemoteConfig.begin_run()), before it is made.
static func run_starting() -> void:
	if run_starting_hook.is_valid():
		run_starting_hook.call()


func is_neutral() -> bool:
	return is_equal_approx(enemy_health, 1.0) and is_equal_approx(enemy_damage, 1.0) and is_equal_approx(souls, 1.0) \
		and omen == &"" and event_boost.is_empty()


## `base` with the multipliers applied: a copy (the shared resource is never changed), or `base`
## itself when they are all 1.
func apply_to(base: DifficultyDef) -> DifficultyDef:
	if base == null or (is_equal_approx(enemy_health, 1.0) and is_equal_approx(enemy_damage, 1.0) and is_equal_approx(souls, 1.0)):
		return base
	var result := base.duplicate() as DifficultyDef
	result.ascension = base.ascension  # (not an export: duplicate() leaves it at 0)
	result.monster_hp *= enemy_health
	result.boss_hp *= enemy_health
	result.monster_damage *= enemy_damage
	result.souls *= souls
	return result


## The weight multiplier of floor event `id` (1: no boost).
func boost_of(id: StringName) -> float:
	return float(event_boost.get(String(id), 1.0))


func to_data() -> Dictionary:
	return {
		"enemy_health": enemy_health,
		"enemy_damage": enemy_damage,
		"souls": souls,
		"omen": String(omen),
		"event_boost": event_boost.duplicate(),
		"event_name": event_name,
	}


## From a run's save (a missing or broken field stays neutral).
static func from_data(data: Dictionary) -> RemoteTuning:
	var tuning := RemoteTuning.new()
	tuning.enemy_health = _number(data.get("enemy_health"))
	tuning.enemy_damage = _number(data.get("enemy_damage"))
	tuning.souls = _number(data.get("souls"))
	tuning.omen = StringName(str(data.get("omen", "")))
	var boost: Variant = data.get("event_boost", {})
	if boost is Dictionary:
		for id: Variant in boost:
			tuning.event_boost[str(id)] = _number((boost as Dictionary)[id])
	tuning.event_name = str(data.get("event_name", ""))
	return tuning


static func _number(value: Variant) -> float:
	return float(value) if (value is float or value is int) and float(value) > 0.0 else 1.0
