class_name WorldStatDef
extends Resource
## One world counter, "The Well's Toll" (WorldStatsDef, the WorldStats autoload; docs/online.md
## "World counters"): a number every player adds to (Talo's global game stats), like the demons
## slain in the Well by everyone. Each player's own share is kept too (their lifetime total).
##
## The stat must exist in Talo's dashboard with exactly this internal name, global, a max change
## at least `max_change` and no time between updates (docs/online.md says how to add one).

## What feeds it, all told by the Events bus during a run (or at the shrine).
## KILLS: a monster slain (Events.monster_killed; not one called in by another). BOSSES: a
## warden's form defeated (Events.boss_defeated). DEATHS: a run ended with the hero dead
## (Events.run_ended). FLOORS: a floor descended to (Events.depth_changed, deeper than before).
## POTIONS: a healing potion drunk (the hero's consumable_used). ENDING: the ending `ending`
## chosen at the bottom of the Well (Events.ending_chosen). DAILY_RUNS: a Dawn Knell begun
## (Events.run_started, a new daily run). SOULS_OFFERED: souls offered to the Tree of Souls
## (Events.souls_offered).
enum Feed { KILLS, BOSSES, DEATHS, FLOORS, POTIONS, ENDING, DAILY_RUNS, SOULS_OFFERED }

## Talo's internal name (never renamed: the dashboard and the data must keep matching).
@export var internal_name: String
## Its name on the Well's Toll page, in the Well's voice (translated where shown).
@export var display_name: String
## The title screen's line, with {count} for the world's number (translated where shown); empty:
## never on the title.
@export var title_line: String
@export var feed: Feed = Feed.KILLS
## For an ENDING feed: the ending's id (EndingDef.id).
@export var ending: StringName = &""
## The most one update may add (Talo's maxChange for it: the server refuses more). A run's share is
## capped to it too: no real run adds more.
@export_range(1, 10000000) var max_change := 1000
## Off: nothing counted, sent or shown.
@export var enabled := true
