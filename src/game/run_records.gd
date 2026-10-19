class_name RunRecords
extends Node
## Keeps the profile's records up to date during a run: kills (the bestiary), stats, gold,
## achievements, and the history entry when the run ends. Listens to Events; owned by the Game.

var run: RunState
var player: Player
var content: ContentDB

## The purse a moment ago (gold_changed only gives the new total).
var _last_gold := 0


func _ready() -> void:
	Events.monster_killed.connect(_on_monster_killed)
	Events.stat_counted.connect(func(stat: String, amount: int) -> void:
		Profile.add_stat(stat, amount)
		check_achievements())


## Follows a new run (and its hero).
func bind(new_run: RunState, new_player: Player) -> void:
	run = new_run
	player = new_player
	_last_gold = player.gold  # a saved purse is not new gold
	player.gold_changed.connect(_on_gold_changed)
	player.leveled_up.connect(func(level: int) -> void:
		Profile.raise_stat("run_level", level)
		check_achievements())


## Unlocks (and pays) every achievement whose goal is reached.
func check_achievements() -> void:
	for achievement in AchievementDef.unlock_reached(content.achievements):
		Events.achievement_unlocked.emit(achievement)


## Adds the run to the history (once).
func record_history() -> void:
	if run == null or run.history_recorded or player == null:
		return
	run.history_recorded = true
	var weapon := player.get_weapon()
	Profile.add_history({
		"difficulty": run.difficulty.display_name,
		"depth": run.depth,
		"level": player.level,
		"kills": run.kills,
		"bosses": run.bosses_slain,
		"won": run.has_won,
		"souls": run.souls_awarded,
		"weapon": weapon.display_name if weapon else "Bare hands",
		"cause": player.killed_by if player.is_dead else "",
	})


func _on_monster_killed(monster: Monster) -> void:
	if run == null:
		return
	run.kills += 1
	Profile.record_kill(monster.def.id)
	Profile.add_stat("kills")
	if monster.is_elite():
		Profile.add_stat("elites")
	if monster.is_boss():
		Profile.add_stat("bosses")
	if monster.has_fallen() and monster.last_attacker is Player:
		Profile.add_stat("pushed")
	check_achievements()


func _on_gold_changed(gold: int) -> void:
	if gold > _last_gold:
		run.run_gold += gold - _last_gold
		Profile.raise_stat("run_gold", run.run_gold)
		check_achievements()
	_last_gold = gold
