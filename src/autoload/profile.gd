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


## Souls for a run: monsters, depth reached, bosses, and a big bonus for winning.
static func souls_for_run(kills: int, depth: int, bosses: int, won: bool) -> int:
	return kills + (depth - 1) * 5 + bosses * 20 + (100 if won else 0)


func record_run(earned: int, depth: int, won: bool) -> void:
	souls += earned
	best_depth = maxi(best_depth, depth)
	if won:
		victories += 1
	save_profile()
	changed.emit()


func count_run() -> void:
	runs += 1
	save_profile()


func reset() -> void:
	souls = 0
	levels = {}
	runs = 0
	victories = 0
	best_depth = 0
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
