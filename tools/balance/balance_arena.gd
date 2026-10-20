class_name BalanceArena
extends Node
## The measured half of the balance tools: real fights in the real Game scene, headless, with a
## bot at the controls (BalanceBot).
## - run_bosses(): for each (boss, build, difficulty, bot) the act's boss floor of a run whose
##   boss is that one, the build put on the hero (BalanceBuild.apply), the bot walks into the
##   arena and fights until someone dies or `timeout` game seconds pass.
## - run_packs(): the build against a pack of its act's common monsters, then an elite, on the
##   act's last normal floor: time to kill each, damage taken.
## Every fight starts from the same run seed and global random seed (`seed_value`): the same
## command gives the same numbers. Hit stop is off (it freezes real time, not game time: the
## fight is the same, only faster to simulate); times are game seconds at 60 physics frames/s.
## Nothing is saved: the profile, settings and run save are kept in memory (isolate_profile()).

const GAME_SCENE := "res://src/game/game.tscn"
## Frames allowed to walk from the floor's start into the arena.
const APPROACH_LIMIT := 60 * 40
## Monsters in a pack (plus the difficulty's extra monsters per room), and packs per measure.
const PACK_SIZE := 4
const PACK_ROUNDS := 2
## Game seconds a pack or an elite gets before it counts as a timeout.
const PACK_TIMEOUT := 60.0

var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var builds: Array[BalanceBuildDef] = []
var difficulties: Array[DifficultyDef] = []
var bosses: Array[BossDef] = []
var bots: PackedStringArray = ["face_tank", "kite"]
var seed_value := 1
## Every build against every boss (default: each build against the bosses of its own act).
var all_pairs := false
## Game seconds before a boss fight is called a timeout.
var timeout := 240.0
## Print a line per fight.
var verbose := true

## Dungeon and rank chances changed for the measures (restored by _restore_chances()).
var _saved_chances := {}


## Sound off, the profile, settings and run save in memory only (like tests/run_tests.gd), every
## difficulty open.
static func isolate_profile() -> void:
	Sfx.enabled = false
	Profile.save_path = ""
	Profile.reset()
	Settings.path = ""
	Settings.tutorial_hints = false
	RunSave.path = "user://balance_run_%d.json" % OS.get_process_id()
	RunSave.erase()


## A clean profile for one fight: no bestiary mastery (+10% damage) carried over from the
## previous fights, every difficulty unlocked.
static func _fresh_profile(content: ContentDB) -> void:
	Profile.reset()
	for difficulty in content.difficulties:
		Profile.wins[String(difficulty.id)] = 1


# --- Boss fights -------------------------------------------------------------------------

func run_bosses() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance arena"
	report.notes.append("Real fights in the Game scene, headless, bots at the controls. Seed %d, timeout %.0f game s, hit stop off. Times are game seconds." % [seed_value, timeout])
	var started := Time.get_ticks_msec()
	_override_chances()
	var fights: Array = []
	for boss in bosses:
		var act := _act_of(boss)
		for build in builds:
			if not all_pairs and build.act != act:
				continue
			for difficulty in difficulties:
				for bot in bots:
					var result := await fight_boss(boss, build, difficulty, bot)
					fights.append(result)
					if verbose:
						print("  %s" % _fight_line(result))
	_restore_chances()
	report.notes.append("%d fights in %.0f s of real time." % [fights.size(), (Time.get_ticks_msec() - started) / 1000.0])
	report.data["fights"] = fights
	_boss_report(report, fights)
	return report


## One fight. Returns what happened (see the keys at the end).
func fight_boss(boss: BossDef, build: BalanceBuildDef, difficulty: DifficultyDef, bot_name: String) -> Dictionary:
	var act := _act_of(boss)
	var depth := content.dungeon.first_depth(act - 1) + content.dungeon.acts[act - 1].floors - 1
	var game := await _start_game(depth, difficulty, boss, false)
	var result := { "boss": String(boss.id), "act": act, "build": build.name, "tags": build.tags,
		"build_act": build.act, "difficulty": String(difficulty.id), "bot": bot_name, "depth": depth }
	var world := game.world
	if world.arena == null or world.arena.boss == null:
		result["result"] = "error"
		result["error"] = "no boss arena on depth %d" % depth
		await _end_game(game)
		return result
	var player := game.player
	BalanceBuild.apply(build, player, content, difficulty)
	player.perks.on_floor_started(player)  # floor-start perks (a ward) as on arrival
	player.xp = -1000000  # the build keeps its level: no level up (and no perk menu) mid-fight
	var boss_actor := world.arena.boss
	var log := FightLog.new(player, boss_actor)
	var bot := BalanceBot.create(bot_name, player, world, boss_actor)
	var frames := 0
	var fight_frames := 0
	var limit := roundi(timeout * Engine.physics_ticks_per_second)
	var outcome := "timeout"
	while true:
		await get_tree().physics_frame
		frames += 1
		_unpause(game)
		if player.is_dead:
			outcome = "loss"
			break
		if boss_actor.is_dead:
			outcome = "win"
			break
		if world.arena.is_started:
			fight_frames += 1
			log.frame()
			if fight_frames >= limit:
				break
		elif frames > APPROACH_LIMIT:
			outcome = "error"
			result["error"] = "never reached the arena"
			break
		bot.step()
	BalanceBot.release_all()
	log.frame()
	result.merge(log.summary(fight_frames / float(Engine.physics_ticks_per_second)))
	result["result"] = outcome
	result["hero_max_hp"] = player.get_max_hp()
	result["boss_max_hp"] = boss_actor.get_max_hp()
	result["boss_hp_left"] = maxi(boss_actor.hp, 0)
	result["rolls"] = bot.rolls
	result["skills_used"] = bot.skills_used
	await _end_game(game)
	return result


# --- Packs --------------------------------------------------------------------------------

func run_packs() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance pack"
	report.notes.append("The build against packs of its act's common monsters (%d + the difficulty's extra), then an elite, %d rounds, on the act's last normal floor. Seed %d. Times are game seconds." % [PACK_SIZE, PACK_ROUNDS, seed_value])
	var started := Time.get_ticks_msec()
	_override_chances()
	var results: Array = []
	for build in builds:
		for difficulty in difficulties:
			for bot in bots:
				var result := await fight_packs(build, difficulty, bot)
				results.append(result)
				if verbose:
					print("  pack %s %s %s: commons %.2f s, elite %.2f s, taken %d%%, %s" % [build.name, difficulty.id, bot,
						result.get("common_ttk", -1.0), result.get("elite_ttk", -1.0), roundi(result.get("damage_share", 0.0) * 100.0), result.get("result", "?")])
	_restore_chances()
	report.notes.append("%d measures in %.0f s of real time." % [results.size(), (Time.get_ticks_msec() - started) / 1000.0])
	report.data["packs"] = results
	_pack_report(report, results)
	return report


func fight_packs(build: BalanceBuildDef, difficulty: DifficultyDef, bot_name: String) -> Dictionary:
	var act := build.act
	var depth := content.dungeon.first_depth(act - 1) + content.dungeon.acts[act - 1].floors - 2
	var game := await _start_game(maxi(depth, 1), difficulty, null, true)
	var world := game.world
	var player := game.player
	BalanceBuild.apply(build, player, content, difficulty)
	player.xp = -1000000
	var result := { "build": build.name, "tags": build.tags, "act": act, "difficulty": String(difficulty.id), "bot": bot_name, "depth": world.depth }
	for monster in world.get_hostiles(player.faction):
		monster.queue_free()
	await get_tree().physics_frame
	var common_ttks: Array[float] = []
	var elite_ttks: Array[float] = []
	var taken := 0
	var hp_spent := 0.0
	var outcome := "ok"
	var kinds := PackedStringArray()
	var elites := PackedStringArray()
	for round_index in PACK_ROUNDS:
		for elite in [false, true]:
			player.hp = player.get_max_hp()
			player.health_changed.emit(player.hp, player.get_max_hp())
			var spawned: Array[Monster] = []
			var count := 1 if elite else PACK_SIZE + difficulty.extra_monsters
			for i in count:
				var def := world.pick_monster()
				if def == null:
					continue
				var at := world.find_open_point_near(player.global_position, world.rng.randf_range(140.0, 200.0))
				var monster := world.spawn_monster(def, at)
				if elite:
					world.make_elite(monster)
					elites.append(monster.display_name)
				else:
					kinds.append(String(def.id))
				monster.target = player
				spawned.append(monster)
			var watch := PackLog.new(player, spawned)
			var bot := BalanceBot.create(bot_name, player, world)
			var frames := 0
			var limit := roundi(PACK_TIMEOUT * Engine.physics_ticks_per_second)
			while frames < limit:
				await get_tree().physics_frame
				frames += 1
				_unpause(game)
				watch.frame()
				if player.is_dead or spawned.all(func(m: Variant) -> bool: return not is_instance_valid(m) or (m as Monster).is_dead):
					break
				bot.step()
			BalanceBot.release_all()
			watch.frame()
			watch.close()
			taken += watch.taken
			hp_spent += watch.taken / float(player.get_max_hp())
			for ttk in watch.ttks:
				(elite_ttks if elite else common_ttks).append(ttk)
			if player.is_dead:
				outcome = "died"
				break
			if frames >= limit:
				outcome = "timeout"
			for monster in spawned:
				if is_instance_valid(monster) and not monster.is_dead:
					monster.queue_free()
			await get_tree().physics_frame
		if player.is_dead:
			break
	result["result"] = outcome
	result["common_ttk"] = _mean(common_ttks)
	result["common_ttk_max"] = common_ttks.max() if not common_ttks.is_empty() else -1.0
	result["elite_ttk"] = _mean(elite_ttks)
	result["damage_taken"] = taken
	result["damage_share"] = hp_spent / float(PACK_ROUNDS * 2)  # per pack or elite, as a share of max HP
	result["pack_damage_share"] = hp_spent / float(PACK_ROUNDS * 2)
	result["monsters"] = kinds
	result["elites"] = elites
	result["hero_max_hp"] = player.get_max_hp()
	await _end_game(game)
	return result


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


# --- The game ------------------------------------------------------------------------------

## A run resumed at `depth` (RunSave in memory: the same seed every time), with `boss` drawn for
## its act and every difficulty open. `plain`: no floor event or curse.
func _start_game(depth: int, difficulty: DifficultyDef, boss: BossDef, plain: bool) -> Game:
	_fresh_profile(content)
	HitStop.enabled = false
	HitStop.reset()
	get_tree().paused = false
	seed(seed_value)
	var run_bosses: Array = []
	for act in content.dungeon.acts:
		run_bosses.append(boss if boss and act.all_bosses().has(boss) else act.boss)
	var base := content.player.base_stats
	RunSave.write({
		"seed": seed_value, "depth": depth, "difficulty": String(difficulty.id), "ascension": 0,
		"bosses": RunSave.refs(run_bosses), "rerolls": 0, "banishes": 0, "time": 0.0,
		"player": { "level": 1, "hp": base.max_hp, "base_stats": base.to_dict() },
	})
	Game.resume_requested = true
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.show_act_cards = false
	(game.get_node("World") as World).forced_plain = plain
	add_child(game)
	for i in 3:
		await get_tree().physics_frame
	return game


func _end_game(game: Game) -> void:
	BalanceBot.release_all()
	get_tree().paused = false
	HitStop.reset()
	# Delayed effects (a blast's fuse, a combo's next stab) hold the world in their timers: let
	# them go off on a frozen game before freeing it, or they would call into freed objects.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 90:
		await get_tree().physics_frame
	game.queue_free()
	for i in 2:
		await get_tree().process_frame
	RunSave.erase()


## A menu opened by itself (a level up, a shop...) is closed: the fight goes on.
func _unpause(game: Game) -> void:
	if not get_tree().paused:
		return
	game.offers.clear()
	game.menus.hide_all()
	get_tree().paused = false


## No ambush, merchant, forge, encounter or event in the way; bosses never roll a rare rank.
func _override_chances() -> void:
	var dungeon := content.dungeon
	_saved_chances = { "ambush": dungeon.ambush_chance, "merchant": dungeon.merchant_chance, "forge": dungeon.forge_chance,
		"forge_growth": dungeon.forge_chance_growth, "encounters": dungeon.encounters_max, "event": dungeon.floor_event_chance, "ranks": {} }
	dungeon.ambush_chance = 0.0
	dungeon.merchant_chance = 0.0
	dungeon.forge_chance = 0.0
	dungeon.forge_chance_growth = 0.0
	dungeon.encounters_max = 0
	dungeon.floor_event_chance = 0.0
	for rank in dungeon.rare_ranks:
		if rank:
			_saved_chances.ranks[rank] = rank.boss_chance
			rank.boss_chance = 0.0


func _restore_chances() -> void:
	if _saved_chances.is_empty():
		return
	var dungeon := content.dungeon
	dungeon.ambush_chance = _saved_chances.ambush
	dungeon.merchant_chance = _saved_chances.merchant
	dungeon.forge_chance = _saved_chances.forge
	dungeon.forge_chance_growth = _saved_chances.forge_growth
	dungeon.encounters_max = _saved_chances.encounters
	dungeon.floor_event_chance = _saved_chances.event
	for rank: MonsterRankDef in _saved_chances.ranks:
		rank.boss_chance = _saved_chances.ranks[rank]
	_saved_chances = {}


func _act_of(boss: BossDef) -> int:
	for i in content.dungeon.acts.size():
		if content.dungeon.acts[i].all_bosses().has(boss):
			return i + 1
	return 0


func _difficulty_index(id: StringName) -> int:
	for i in content.difficulties.size():
		if content.difficulties[i].id == id:
			return i
	return -1


# --- Reports -------------------------------------------------------------------------------

static func _fight_line(r: Dictionary) -> String:
	return "%s | %s | %s | %s: %s in %.1f s, phase %d, boss %d%% left, hero min %d%%, taken %d (%d hits), healed %d (%s)" % [
		r.boss, r.build, r.difficulty, r.bot, str(r.get("result", "?")).to_upper(), r.get("time", 0.0), r.get("phases", 0),
		roundi(100.0 * r.get("boss_hp_left", 0) / maxf(r.get("boss_max_hp", 1), 1.0)), roundi(r.get("min_hp_share", 0.0) * 100.0),
		r.get("damage_taken", 0), r.get("hits_taken", 0), r.get("healed", 0), FightLog.sources_text(r.get("heal_sources", {}))]


func _boss_report(report: BalanceReport, fights: Array) -> void:
	var rows: Array = []
	for r: Dictionary in fights:
		rows.append([r.boss, r.build, r.difficulty, r.bot, str(r.get("result", "?")).to_upper(), r.get("time", 0.0), r.get("phases", 0),
			BalanceReport.pct(r.get("boss_hp_left", 0) / maxf(r.get("boss_max_hp", 1), 1.0)), r.get("dps", 0.0),
			r.get("damage_taken", 0), r.get("hits_taken", 0), r.get("healed", 0), BalanceReport.pct(r.get("heal_share", 0.0)),
			FightLog.sources_text(r.get("heal_sources", {})), BalanceReport.pct(r.get("min_hp_share", 0.0))])
		_check_fight(report, r)
	report.table("fights", "Boss fights (measured)", PackedStringArray(["Boss", "Build", "Difficulty", "Bot", "Result", "Time s", "Phase",
		"Boss HP left", "Hero DPS", "Taken", "Hits", "Healed", "Heal/taken", "Heal sources", "Hero min HP"]), rows)


func _check_fight(report: BalanceReport, r: Dictionary) -> void:
	if r.get("result") == "error":
		report.flag(BalanceReport.ERROR, "arena: error", "%s vs %s (%s, %s)" % [r.build, r.boss, r.difficulty, r.bot], str(r.get("error", "?")), "a fight", "the fight could not be measured")
		return
	var tags: PackedStringArray = r.tags
	var subject := "%s vs %s (%s, %s)" % [r.build, r.boss, r.difficulty, r.bot]
	var must_lose := false
	for tag in targets.facetank_must_lose_tags:
		must_lose = must_lose or tags.has(tag)
	if r.bot == "face_tank" and must_lose and r.build_act == r.act \
			and _difficulty_index(StringName(r.difficulty)) >= _difficulty_index(targets.facetank_must_lose_from) and r.result == "win":
		report.flag(BalanceReport.ERROR, "arena: face-tank wins", subject, "won in %.0f s, %d%% HP left at worst" % [r.time, roundi(r.min_hp_share * 100.0)],
			"must die from %s" % targets.facetank_must_lose_from, "healed %d of %d taken (%s)" % [r.healed, r.damage_taken, FightLog.sources_text(r.heal_sources)])
	var share_max := -1.0
	if tags.has("degenerate"):
		share_max = targets.heal_share_max_degenerate
	elif tags.has("expected"):
		share_max = targets.heal_share_max_expected
	if share_max >= 0.0 and r.build_act == r.act and r.damage_taken > 0 and r.heal_share > share_max:
		report.flag(BalanceReport.ERROR, "arena: heal share", subject, BalanceReport.pct(r.heal_share), "<= %s" % BalanceReport.pct(share_max),
			"healed %d of %d taken (%s)" % [r.healed, r.damage_taken, FightLog.sources_text(r.heal_sources)])
	if tags.has("expected") and r.build_act == r.act and r.bot == "kite":
		if not String(targets.kite_should_win_on).is_empty() and r.difficulty == String(targets.kite_should_win_on) and r.result != "win":
			report.flag(BalanceReport.WARN, "arena: kite loses", subject, "%s (boss at %d%%)" % [r.result, roundi(100.0 * r.boss_hp_left / maxf(r.boss_max_hp, 1.0))],
				"wins on %s" % targets.kite_should_win_on, "the boss could not be beaten by keeping range and rolling")
		if r.result == "win" and r.difficulty == "normal" and (r.time < targets.boss_ttk_min or r.time > targets.boss_ttk_max):
			report.flag(BalanceReport.WARN, "arena: boss TTK", subject, BalanceReport.secs(r.time), "%d-%d s" % [targets.boss_ttk_min, targets.boss_ttk_max],
				"the expected build's fight is %s" % ("too short" if r.time < targets.boss_ttk_min else "too long"))


func _pack_report(report: BalanceReport, results: Array) -> void:
	var rows: Array = []
	for r: Dictionary in results:
		rows.append([r.build, r.act, r.difficulty, r.bot, r.result, r.common_ttk, r.common_ttk_max, r.elite_ttk,
			BalanceReport.pct(r.damage_share), ", ".join(r.elites)])
		var tags: PackedStringArray = r.tags
		if not tags.has("expected") or r.difficulty != "normal":
			continue
		var subject := "%s (%s, %s)" % [r.build, r.difficulty, r.bot]
		if r.common_ttk >= 0.0 and (r.common_ttk < targets.common_ttk_min or r.common_ttk > targets.common_ttk_max):
			report.flag(BalanceReport.WARN, "pack: monster TTK", subject, BalanceReport.secs(r.common_ttk), "%.1f-%.1f s" % [targets.common_ttk_min, targets.common_ttk_max], "average time from first hit to death, common monsters")
		if r.elite_ttk >= 0.0 and (r.elite_ttk < targets.elite_ttk_min or r.elite_ttk > targets.elite_ttk_max):
			report.flag(BalanceReport.WARN, "pack: elite TTK", subject, BalanceReport.secs(r.elite_ttk), "%.0f-%.0f s" % [targets.elite_ttk_min, targets.elite_ttk_max], "elites: %s" % ", ".join(r.elites))
		if r.bot == "kite" and r.damage_share > targets.pack_damage_share_max:
			report.flag(BalanceReport.WARN, "pack: damage taken", subject, BalanceReport.pct(r.damage_share), "<= %s" % BalanceReport.pct(targets.pack_damage_share_max), "average per pack or elite, as a share of max HP")
	report.table("packs", "Packs and elites (measured): time from a monster's first hurt to its death, damage taken per pack / elite",
		PackedStringArray(["Build", "Act", "Difficulty", "Bot", "Result", "Common TTK s", "Slowest", "Elite TTK s", "Taken per fight", "Elites"]), rows)


## What a boss fight did, frame by frame: damage both ways, heals by source, phases, the lowest HP.
class FightLog:
	var player: Player
	var boss: Monster
	var dealt := 0
	var taken := 0
	var hits_taken := 0
	var tick_damage := 0
	var healed_by := {}
	var phases := 0
	var min_hp := 0
	var summons_killed := 0
	var _expected_hp := 0
	var _boss_hp := 0

	func _init(hero: Player, boss_actor: Monster) -> void:
		player = hero
		boss = boss_actor
		min_hp = player.hp
		_expected_hp = player.hp
		_boss_hp = boss.hp
		player.healed.connect(_on_healed)
		player.damaged.connect(_on_damaged)
		boss.health_changed.connect(_on_boss_health)
		boss.phase_entered.connect(func(index: int) -> void: phases = maxi(phases, index))
		Events.monster_killed.connect(_on_killed)

	func _on_healed(amount: int, source: StringName) -> void:
		var key := String(source) if not String(source).is_empty() else "unattributed"
		healed_by[key] = int(healed_by.get(key, 0)) + amount
		_expected_hp += amount

	func _on_damaged(amount: int) -> void:
		if amount <= 0:
			return
		taken += amount
		_expected_hp -= amount
		var hit := player.last_hit
		if hit and hit.is_tick:
			tick_damage += amount
		else:
			hits_taken += 1

	func _on_boss_health(current: int, _maximum: int) -> void:
		if current < _boss_hp:
			dealt += _boss_hp - current
		_boss_hp = current

	func _on_killed(monster: Monster) -> void:
		if monster != boss:
			summons_killed += 1

	## Called every frame: HP that came back by another way than heal() (a level up, a Phoenix
	## Feather) is counted as "other".
	func frame() -> void:
		if not is_instance_valid(player):
			return
		if player.hp > maxi(_expected_hp, 0):
			healed_by["other (level up, revive)"] = int(healed_by.get("other (level up, revive)", 0)) + player.hp - maxi(_expected_hp, 0)
		_expected_hp = player.hp
		min_hp = mini(min_hp, player.hp)

	func summary(seconds: float) -> Dictionary:
		if Events.monster_killed.is_connected(_on_killed):
			Events.monster_killed.disconnect(_on_killed)
		var healed := 0
		for value: int in healed_by.values():
			healed += value
		return {
			"time": seconds, "phases": phases + 1, "damage_dealt": dealt, "dps": dealt / maxf(seconds, 0.01),
			"damage_taken": taken, "hits_taken": hits_taken, "tick_damage": tick_damage, "healed": healed,
			"heal_sources": healed_by.duplicate(), "heal_share": healed / maxf(taken, 1.0),
			"min_hp": min_hp, "min_hp_share": min_hp / float(maxi(player.get_max_hp(), 1)),
			"summons_killed": summons_killed,
		}

	## "rune:leech_rune 120, perk:vampirism 14"
	static func sources_text(sources: Dictionary) -> String:
		var keys := sources.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(sources[a]) > int(sources[b]))
		var parts := PackedStringArray()
		for key: Variant in keys:
			parts.append("%s %d" % [key, int(sources[key])])
		return ", ".join(parts) if not parts.is_empty() else "-"


## A pack fight: when each monster was first hurt and when it died, and the damage taken.
class PackLog:
	var player: Player
	var monsters: Array[Monster] = []
	var ttks: Array[float] = []
	var taken := 0
	var _first_hurt := {}
	var _done := {}
	var _frame := 0

	func _init(hero: Player, spawned: Array[Monster]) -> void:
		player = hero
		monsters = spawned
		player.damaged.connect(_on_damaged)

	func _on_damaged(amount: int) -> void:
		taken += maxi(amount, 0)

	func frame() -> void:
		_frame += 1
		for monster in monsters:
			if _done.has(monster):
				continue
			if not is_instance_valid(monster) or monster.is_dead:
				_done[monster] = true
				if _first_hurt.has(monster):
					ttks.append((_frame - int(_first_hurt[monster])) / float(Engine.physics_ticks_per_second))
				continue
			if not _first_hurt.has(monster) and monster.hp < monster.get_max_hp():
				_first_hurt[monster] = _frame

	## Stops listening (the next pack has its own log).
	func close() -> void:
		if is_instance_valid(player) and player.damaged.is_connected(_on_damaged):
			player.damaged.disconnect(_on_damaged)
