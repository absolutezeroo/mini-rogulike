extends Node
## What lasts between runs (autoload "Profile"): souls, shrine upgrades and records.
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
## The story was told once (it plays before the first run).
var seen_intro := false
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
