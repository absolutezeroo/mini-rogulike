class_name LeaderboardsConfig
extends Resource
## The online leaderboards' data (data/leaderboards/leaderboards.tres, read by the Leaderboards
## autoload): the boards, how much the page shows, how often a waiting score is retried, the
## pseudonym's rules and the limits a run must stay within to be sent (docs/online.md).

@export var boards: Array[LeaderboardDef] = []

@export_group("Page")
## Entries shown at the top (Talo's page is 50 entries long: more would need a second request).
@export_range(1, 50) var top_count := 50
## Entries shown above and below the player's own when it is past the top.
@export_range(0, 10) var around := 3
## For a past period (yesterday), the player's rank is found by reading the board this many
## pages deep (the server's rank counts every past day's entries); past them, only the score.
@export_range(1, 10) var rank_scan_pages := 4

@export_group("Sending")
## Seconds between two tries to send what waits (no network, server down).
@export var retry_seconds := 60.0
## Scores kept waiting at most (the oldest go first).
@export var max_queue := 20

@export_group("Pseudonym")
@export var name_min := 3
@export var name_max := 16
## The name before the player picks one (shown with the player's tag like any name: "Soul#4821").
@export var default_name := "Soul"
## Refused in a name, whatever the case, accents or digits standing for letters (0 for o...).
## Words of `short_word` letters or fewer only as a whole word ("ass" in "Assassin" is fine).
@export var banned_words: PackedStringArray = []
@export var short_word := 3

@export_group("Plausible runs")
## Fewer seconds than this per floor gone down: not sent (no hero clears floors that fast).
@export var min_seconds_per_floor := 8.0
## More kills than this per floor reached: not sent.
@export var max_kills_per_floor := 400
## More bosses than floors, or more gold than this per floor: not sent.
@export var max_gold_per_floor := 20000


## The board `id`, or null.
func board(board_id: StringName) -> LeaderboardDef:
	for def in boards:
		if def.id == board_id:
			return def
	return null


## The boards with a tab on the page.
func shown_boards() -> Array[LeaderboardDef]:
	return boards.filter(func(def: LeaderboardDef) -> bool: return def.shown)
