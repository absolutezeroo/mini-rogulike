class_name RemoteKeyDef
extends Resource
## One value the game takes from Talo's game config (the allow-list: data/online/remote_config.tres,
## read by the RemoteConfig autoload; docs/online.md "Remote settings"). Only the keys listed there
## are read; a key the server has that isn't listed is ignored, and so is a value of the wrong form
## or outside its bounds: the game then keeps its own value (`default_number`, or nothing). A key
## never names a file or code: what it changes is one of the fixed `Hook`s below, read by the game
## where that number is used.

## The value's form, as Talo keeps it (every value is a text there).
## NUMBER: a decimal number inside [min_number, max_number]. FLAG: true/false (also 1/0, on/off).
## TEXT: a short line shown as it is (at most max_length characters, no line breaks). CONTENT_ID:
## the id of a curse or floor event of the game (`pool`). DATE: "2026-10-26" (that whole day, UTC)
## or "2026-10-26T18:00:00Z". VERSION: a game version, "0.3.0".
enum Kind { NUMBER, FLAG, TEXT, CONTENT_ID, DATE, VERSION }

## What the value changes (the only places a remote value reaches).
## ENEMY_HEALTH / ENEMY_DAMAGE: multiply the run's DifficultyDef monster_hp and boss_hp /
## monster_damage (`difficulty`'s runs), so FloorRules scales them like the rest.
## SOULS: multiplies the run's DifficultyDef souls (every run).
## DAILY_OMEN (+ DAILY_OMEN_DATE): the Dawn Knell of that day only puts this curse or event on
## each of its normal floors (DailyRun.omen()).
## EVENT_NAME (per `language`), EVENT_ENDS, EVENT_SOULS, EVENT_FLOOR_EVENT, EVENT_FLOOR_WEIGHT:
## a limited-time event (a weekend's): its name on the title screen, its end, a souls bonus, a
## floor event made more likely. Nothing of it applies without a name and an end to come.
## MESSAGE (per `language`): a line on the title screen.
## SCORES_OFF / STATISTICS_OFF: stop sending scores / gameplay statistics and world counters
## (a kill switch; the only values that apply at once).
## MIN_VERSION / MAX_VERSION: the game versions the whole config is for (outside: all ignored).
enum Hook {
	ENEMY_HEALTH, ENEMY_DAMAGE, SOULS,
	DAILY_OMEN, DAILY_OMEN_DATE,
	EVENT_NAME, EVENT_ENDS, EVENT_SOULS, EVENT_FLOOR_EVENT, EVENT_FLOOR_WEIGHT,
	MESSAGE, SCORES_OFF, STATISTICS_OFF, MIN_VERSION, MAX_VERSION,
}

## Which content a CONTENT_ID may name.
enum Pool { CURSES_AND_EVENTS, FLOOR_EVENTS }

## The key in Talo's game config (dashboard > Game config). Never rename it once in use.
@export var key: String
@export var kind: Kind = Kind.NUMBER
@export var hook: Hook = Hook.SOULS
## ENEMY_* only: the difficulty (DifficultyDef.id) whose runs it changes.
@export var difficulty: StringName
## EVENT_NAME / MESSAGE only: the language it is shown in ("en" is the fallback).
@export var language := ""
@export_group("Number")
## The game's own value (a multiplier: 1 = the data's numbers unchanged).
@export var default_number := 1.0
@export var min_number := 0.0
@export var max_number := 1.0
@export_group("Text")
## TEXT: the longest value taken (the title screen's room).
@export_range(1, 512) var max_length := 120
## CONTENT_ID: where its id is looked for.
@export var pool: Pool = Pool.CURSES_AND_EVENTS
@export_group("")
## What it is for, for whoever sets it (the dashboard, the debug panel, docs/online.md). Not shown
## to players.
@export_multiline var purpose := ""
