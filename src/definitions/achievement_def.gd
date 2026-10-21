class_name AchievementDef
extends Resource
## A goal across runs: "slay 500 monsters", "win on Hard"... Reaching it pays souls.
## Progress comes from the profile's counters (see Profile.stat_value()).
## Listed in content_db.tres > Achievements.

enum Stat {
	KILLS, ELITES, BOSSES, SPECIES, BEST_DEPTH, VICTORIES, HARD_WINS, NIGHTMARE_WINS,
	PUSHED, EPICS, ENCOUNTERS, CHESTS, RUN_GOLD, RUN_LEVEL, ASCENSION,
	## Trials of the Threshold won (back to life with a second life).
	THRESHOLDS,
}

## The Profile key of each Stat.
const STAT_KEYS := {
	Stat.KILLS: "kills", Stat.ELITES: "elites", Stat.BOSSES: "bosses", Stat.SPECIES: "species",
	Stat.BEST_DEPTH: "best_depth", Stat.VICTORIES: "victories", Stat.HARD_WINS: "hard_wins",
	Stat.NIGHTMARE_WINS: "nightmare_wins", Stat.PUSHED: "pushed", Stat.EPICS: "epics",
	Stat.ENCOUNTERS: "encounters", Stat.CHESTS: "chests", Stat.RUN_GOLD: "run_gold",
	Stat.RUN_LEVEL: "run_level", Stat.ASCENSION: "ascension", Stat.THRESHOLDS: "thresholds",
}

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var stat: Stat = Stat.KILLS
@export var target: int = 1
@export var reward_souls: int = 10


func stat_key() -> String:
	return STAT_KEYS[stat]


func progress() -> int:
	return mini(Profile.stat_value(stat_key()), target)


func is_unlocked() -> bool:
	return Profile.is_achieved(id)


func is_met() -> bool:
	return Profile.stat_value(stat_key()) >= target


## Unlocks (and pays) every achievement of `list` whose goal is reached. Returns the new ones.
static func unlock_reached(list: Array[AchievementDef]) -> Array[AchievementDef]:
	var unlocked: Array[AchievementDef] = []
	for achievement in list:
		if not achievement.is_unlocked() and achievement.is_met() and Profile.unlock_achievement(achievement):
			unlocked.append(achievement)
	return unlocked
