class_name QuestDef
extends ContentDef
## A daily or weekly quest: "Slay 60 monsters", "Defeat 4 bosses"... Every day (and every
## week) the same few are drawn for everyone, from the date (QuestBoard). Progress counts what
## the hero does in any run during that day or week (Profile.period_stat); done, it pays souls.
## Listed in content_db.tres > Quests.

enum Period { DAILY, WEEKLY }

@export var period: Period = Period.DAILY
## What it counts (a Profile stat: kills, elites, bosses, chests, encounters, floors, gold,
## pushed, cursed_floors, wins, runs) or, for `best`, the best value in one run (run_depth...).
@export var stat: String = "kills"
@export var best: bool = false
## The goal, drawn in this range (rounded to `step`), and the souls it pays (scaled with it).
@export var target: Vector2i = Vector2i(40, 80)
@export var step: int = 5
@export var reward: Vector2i = Vector2i(15, 30)
## Shown with the goal: "Slay %d monsters".
@export var goal_text: String = "Slay %d monsters"
