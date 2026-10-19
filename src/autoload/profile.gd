extends Node
## What lasts between runs (autoload "Profile"): souls, shrine upgrades, records, the bestiary,
## achievements and the last runs.
## Saved as JSON in user://profile.json (works on phones too).

signal changed

const SAVE_PATH := "user://profile.json"

var souls := 0
## Upgrade id -> level bought.
var levels := {}
var runs := 0
var victories := 0
var best_depth := 0
## Difficulty picked on the title screen (DifficultyDef id).
var difficulty: StringName = &"normal"
## Victories per difficulty id (unlocks the next difficulty).
var wins := {}
## Nightmare ascension: the level picked for the next run, and the highest one open.
var ascension := 0
var ascension_unlocked := 0
## The story was told once (it plays before the first run).
var seen_intro := false
## Monster id -> how many were slain (the bestiary).
var kills_by_monster := {}
## Lifetime counters and bests (see AchievementDef.STAT_KEYS).
var stats := {}
## Achievement id -> when it was unlocked (Unix time).
var achievements := {}
## The last runs, newest first (see add_history()).
var history: Array = []

const HISTORY_SIZE := 20
## Empty = nothing is read or written (tests).
var save_path := SAVE_PATH


func _ready() -> void:
	load_profile()


func level_of(upgrade: UpgradeDef) -> int:
	return levels.get(String(upgrade.id), 0)


func can_buy(upgrade: UpgradeDef) -> bool:
	var level := level_of(upgrade)
	return level < upgrade.max_level and souls >= upgrade.cost_for_level(level)


func buy(upgrade: UpgradeDef) -> bool:
	if not can_buy(upgrade):
		return false
	souls -= upgrade.cost_for_level(level_of(upgrade))
	levels[String(upgrade.id)] = level_of(upgrade) + 1
	save_profile()
	changed.emit()
	return true


## Souls for a run: monsters, depth reached, bosses, a big bonus for winning, times the difficulty.
static func souls_for_run(kills: int, depth: int, bosses: int, won: bool, multiplier: float = 1.0) -> int:
	return roundi((kills + (depth - 1) * 5 + bosses * 20 + (100 if won else 0)) * multiplier)


func is_unlocked(def: DifficultyDef) -> bool:
	return def.unlocked_by == null or wins.get(String(def.unlocked_by.id), 0) > 0


## A Nightmare win at ascension `level` opens the next level (up to `max_level`).
func win_ascension(level: int, max_level: int) -> void:
	ascension_unlocked = clampi(maxi(ascension_unlocked, level + 1), 0, max_level)
	raise_stat("ascension", level)
	save_profile()


func select_ascension(level: int) -> void:
	ascension = clampi(level, 0, ascension_unlocked)
	save_profile()
	changed.emit()


func select_difficulty(def: DifficultyDef) -> void:
	difficulty = def.id
	save_profile()
	changed.emit()


func record_run(earned: int, depth: int, won: bool, difficulty_id: StringName = &"") -> void:
	souls += earned
	best_depth = maxi(best_depth, depth)
	if won:
		victories += 1
		if difficulty_id != &"":
			wins[String(difficulty_id)] = wins.get(String(difficulty_id), 0) + 1
	save_profile()
	changed.emit()


# --- Records ------------------------------------------------------------------

func record_kill(monster_id: StringName) -> void:
	kills_by_monster[String(monster_id)] = kill_count(monster_id) + 1


func kill_count(monster_id: StringName) -> int:
	return int(kills_by_monster.get(String(monster_id), 0))


func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


## Keeps the best value ever seen (deepest floor, most gold in a run...).
func raise_stat(key: String, value: int) -> void:
	stats[key] = maxi(int(stats.get(key, 0)), value)


## A counter, a best, or a record kept elsewhere in the profile.
func stat_value(key: String) -> int:
	match key:
		"species":
			return kills_by_monster.size()
		"best_depth":
			return best_depth
		"victories":
			return victories
		"hard_wins":
			return int(wins.get("hard", 0)) + int(wins.get("nightmare", 0))
		"nightmare_wins":
			return int(wins.get("nightmare", 0))
	return int(stats.get(key, 0))


func is_achieved(id: StringName) -> bool:
	return achievements.has(String(id))


## Unlocks it and pays its souls. Returns false if it was already unlocked.
func unlock_achievement(def: AchievementDef) -> bool:
	if is_achieved(def.id):
		return false
	achievements[String(def.id)] = int(Time.get_unix_time_from_system())
	souls += def.reward_souls
	save_profile()
	changed.emit()
	return true


## A finished run, kept for the run history (only the last HISTORY_SIZE).
func add_history(entry: Dictionary) -> void:
	entry["time"] = int(Time.get_unix_time_from_system())
	history.push_front(entry)
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	save_profile()


func mark_intro_seen() -> void:
	seen_intro = true
	save_profile()


func count_run() -> void:
	runs += 1
	save_profile()


func reset() -> void:
	souls = 0
	levels = {}
	runs = 0
	victories = 0
	best_depth = 0
	difficulty = &"normal"
	wins = {}
	seen_intro = false
	ascension = 0
	ascension_unlocked = 0
	kills_by_monster = {}
	stats = {}
	achievements = {}
	history = []
	changed.emit()


func save_profile() -> void:
	if save_path.is_empty():
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the profile: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"souls": souls, "levels": levels, "runs": runs, "victories": victories, "best_depth": best_depth,
		"difficulty": String(difficulty), "wins": wins, "seen_intro": seen_intro,
		"ascension": ascension, "ascension_unlocked": ascension_unlocked,
		"kills_by_monster": kills_by_monster, "stats": stats, "achievements": achievements, "history": history,
	}, "\t"))


func load_profile() -> void:
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		push_warning("Profile file is damaged, starting fresh.")
		return
	souls = int(data.get("souls", 0))
	levels = data.get("levels", {})
	for key in levels:
		levels[key] = int(levels[key])
	runs = int(data.get("runs", 0))
	victories = int(data.get("victories", 0))
	best_depth = int(data.get("best_depth", 0))
	difficulty = StringName(data.get("difficulty", "normal"))
	wins = data.get("wins", {})
	for key in wins:
		wins[key] = int(wins[key])
	seen_intro = bool(data.get("seen_intro", false))
	ascension = int(data.get("ascension", 0))
	ascension_unlocked = int(data.get("ascension_unlocked", 0))
	kills_by_monster = _ints(data.get("kills_by_monster", {}))
	stats = _ints(data.get("stats", {}))
	achievements = _ints(data.get("achievements", {}))
	history = data.get("history", [])


## JSON numbers come back as floats.
static func _ints(data: Variant) -> Dictionary:
	var result := {}
	if data is Dictionary:
		for key in data:
			result[key] = int(data[key])
	return result
