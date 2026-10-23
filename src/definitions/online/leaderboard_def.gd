class_name LeaderboardDef
extends Resource
## One online leaderboard (design/progression.md "Online leaderboards", docs/online.md): which
## runs it takes, what it ranks them by, which way, over what period, and its name on the server
## (Talo's "internal name": the dashboard's board must have exactly this one). Listed in
## data/leaderboards/leaderboards.tres (LeaderboardsConfig). A new board is a new file there and
## the same board created in the dashboard; no code.

## What a run is ranked by (RunSummary has them all).
## DAILY_SCORE: the Dawn Knell's points (DailyRun.score()). DEPTH: the deepest floor reached.
## WIN_TIME: a won run's time, in milliseconds. NIGHTS: nights the seal was held (La Veille,
## not in the game yet: no run has any, so nothing is sent). ASCENSION: the ascension level of a
## won run (Nightmare +N).
enum Score { DAILY_SCORE, DEPTH, WIN_TIME, NIGHTS, ASCENSION }
## Which runs it takes. DAILY: only the official (first) attempt of a Dawn Knell. NORMAL: only
## runs that aren't daily runs.
enum Runs { DAILY, NORMAL }
## How long an entry stays on it. DAILY and WEEKLY boards are rebuilt from nothing each UTC day
## (week from Monday): the server's refresh interval, and every entry carries its day (or week) as
## a prop, so the page asks for one day's (or week's) entries. ALL_TIME never empties.
enum Period { DAILY, WEEKLY, ALL_TIME }

@export var id: StringName
## Its name on the page's tab, in the Well's voice (translated where shown).
@export var display_name: String
## One plain line under the list: what is ranked and how (translated where shown).
@export var rule: String
## Talo's internal name for the board (the dashboard's "Internal name").
@export var talo_name: String
@export var score: Score = Score.DAILY_SCORE
## Higher first (points, depth) or lower first (times). The dashboard's sort mode must match.
@export var higher_first := true
@export var period: Period = Period.DAILY
@export var runs: Runs = Runs.DAILY
## Only runs on this difficulty (its id: easy, normal, hard, nightmare); empty: any.
@export var difficulty: StringName = &""
## Only runs at this ascension level (Nightmare +N); -1: any.
@export var ascension := -1
## Runs are sent to it (the board exists on the server). Off for a board planned but not
## created in the dashboard yet: nothing queued for it.
@export var submits := false
## It has a tab on the Leaderboards page.
@export var shown := false


## Whether `summary` (a run that ended) goes on this board.
func accepts(summary: RunSummary) -> bool:
	if summary.debug or not submits:
		return false
	if runs == Runs.DAILY and not (summary.daily_day >= 0 and summary.daily_official):
		return false
	if runs == Runs.NORMAL and summary.daily_day >= 0:
		return false
	if difficulty != &"" and summary.difficulty != difficulty:
		return false
	if ascension >= 0 and summary.ascension != ascension:
		return false
	match score:
		Score.WIN_TIME:
			return summary.won and summary.finish_time > 0.0
		Score.NIGHTS:
			return summary.nights > 0
		Score.ASCENSION:
			return summary.won
	return true


## The run's score on this board.
func score_of(summary: RunSummary) -> float:
	match score:
		Score.DEPTH:
			return summary.depth
		Score.WIN_TIME:
			return roundf(summary.finish_time * 1000.0)
		Score.NIGHTS:
			return summary.nights
		Score.ASCENSION:
			return summary.ascension
	return summary.score


## Which day (or week) an entry of `summary` belongs to: the period's key, "" for ALL_TIME.
## A daily run's own day, even if it ends after midnight.
func period_of(summary: RunSummary, now: int = -1) -> String:
	match period:
		Period.DAILY:
			return str(summary.daily_day if summary.daily_day >= 0 else QuestBoard.day_index(now))
		Period.WEEKLY:
			return str(QuestBoard.week_index(now))
	return ""


## The key of the current period (today, this week), and `back` periods before it.
func period_key(back: int = 0, now: int = -1) -> String:
	match period:
		Period.DAILY:
			return str(QuestBoard.day_index(now) - back)
		Period.WEEKLY:
			return str(QuestBoard.week_index(now) - back)
	return ""


## An entry of period `key` can still be sent: its period isn't over (the server's board was
## emptied at midnight UTC; sent later, it would land on the next day's).
func is_open(key: String, now: int = -1) -> bool:
	return period == Period.ALL_TIME or key == period_key(0, now)


## A score as the page shows it ("1 234", "Floor 12", "12:04.50").
func format_score(value: float) -> String:
	match score:
		Score.DEPTH:
			return TranslationServer.tr("Floor %d") % int(value)
		Score.WIN_TIME:
			return TimeText.of(value / 1000.0)
		Score.NIGHTS:
			return TranslationServer.tr("%d nights") % int(value)
		Score.ASCENSION:
			return TranslationServer.tr("Ascension %d") % int(value)
	return TranslationServer.tr("%d points") % int(value)


## What is wrong with it (empty: nothing). For the data checks.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if id == &"":
		found.append("no id")
	if display_name.is_empty() or rule.is_empty():
		found.append("%s: no name or rule" % id)
	var valid := RegEx.create_from_string("^[a-z0-9_-]{3,64}$")
	if valid.search(talo_name) == null:
		found.append("%s: Talo internal name '%s' (lowercase letters, digits, _ and - only)" % [id, talo_name])
	if score == Score.DAILY_SCORE and (runs != Runs.DAILY or period != Period.DAILY):
		found.append("%s: the daily score is for the daily run's daily board" % id)
	if score == Score.WIN_TIME and higher_first:
		found.append("%s: a time ranks the lowest first" % id)
	if shown and not submits:
		found.append("%s: shown but nothing is sent to it" % id)
	return found
