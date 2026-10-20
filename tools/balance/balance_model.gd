class_name BalanceModel
extends RefCounted
## The fast, static half of the balance tools: from the real content (ContentDB, FloorRules,
## StatBlock, WeaponDef, monster and boss defs, the passives' exported numbers) it works out
## damage per second, time to kill, sustain and a face-tank estimate for every build against
## every boss and monster, then checks them against BalanceTargets.
## No game runs: a build is put on a real Player (BalanceBuild.make_player) so its stats come
## from the game's own code, but fights are arithmetic. The arena (BalanceArena) measures them.
##
## Assumptions (also in docs/balance.md):
## - damage is the average over the ±15% variance and the crit chance, after armor (Combat);
## - DPS assumes 100% uptime (always hitting); against a boss, a fan of projectiles lands
##   1 + (count - 1) x BOSS_FAN_SHARE of its shots, against a common monster one;
## - a skill's damaging effects each hit the target once (rings and fans: see the fan share);
## - statuses: a burn or slow source's uptime is 1 - exp(-rate x duration);
## - face-tank: the boss melees every max(wind-up + recovery, weapon cooldown) unless it is
##   casting, uses each skill it can at melee range off cooldown, and every damaging effect hits;
##   the hero can't be hit more often than its 0.6 s of invulnerability allows; the boss'
##   anti face-tank shockwave costs SHOCKWAVE_DOWNTIME seconds of hitting each time.

## Share of the extra projectiles of a fan or ring that hit a boss (big body, close range).
const BOSS_FAN_SHARE := 0.6
## Seconds a boss' shockwave (700 knockback) costs the hero: thrown ~175 px, walking back.
const SHOCKWAVE_DOWNTIME := 1.0
## Longest a "time to die" can be (a build that out-heals everything).
const TTD_CAP := 600.0
## Average monsters on the hero in a room (the room context of perk values).
const ROOM_PACK := 3

var content: ContentDB
var targets: BalanceTargets
## Builds to report on (all of them by default).
var builds: Array[BalanceBuildDef] = []
## Every build (the reference build and the expected builds are looked up here).
var all_builds: Array[BalanceBuildDef] = []
var difficulties: Array[DifficultyDef] = []
## Bosses to report on (all of them by default).
var bosses: Array[BossDef] = []
var report := BalanceReport.new()

## Players made for builds, freed by free_players().
var _players := {}


func _init(content_db: ContentDB, balance_targets: BalanceTargets, every_build: Array[BalanceBuildDef]) -> void:
	content = content_db
	targets = balance_targets
	all_builds = every_build
	builds = every_build
	difficulties = content.difficulties.duplicate()
	for act in content.dungeon.acts:
		for boss in act.all_bosses():
			if not bosses.has(boss):
				bosses.append(boss)


## Works everything out; returns the report (also in `report`).
func run() -> BalanceReport:
	report.title = "Balance model"
	report.notes.append("Static estimates from the content (no game running). Targets: data/balance/targets.tres. See docs/balance.md for the assumptions.")
	report.notes.append("Difficulties: %s. Builds: %s." % [", ".join(difficulties.map(func(d: DifficultyDef) -> String: return String(d.id))), ", ".join(builds.map(func(b: BalanceBuildDef) -> String: return b.name))])
	_check_build_data()
	_build_table()
	_boss_tables()
	_monster_tables()
	_weapon_table()
	_perk_table()
	_degenerate_ratios()
	free_players()
	return report


func free_players() -> void:
	for player: Player in _players.values():
		if is_instance_valid(player):
			player.free()
	_players.clear()


# --- Lookups -------------------------------------------------------------------------

func player_for(build: BalanceBuildDef) -> Player:
	if not _players.has(build):
		_players[build] = BalanceBuild.make_player(build, content)
	return _players[build]


func act_of(boss: BossDef) -> int:
	for i in content.dungeon.acts.size():
		if content.dungeon.acts[i].all_bosses().has(boss):
			return i + 1
	return 0


## The boss floor of act `act` (1-based).
func boss_depth(act: int) -> int:
	return content.dungeon.first_depth(act - 1) + content.dungeon.acts[act - 1].floors - 1


func expected_build(act: int) -> BalanceBuildDef:
	for build in all_builds:
		if build.act == act and build.has_tag("expected"):
			return build
	return null


func builds_of_act(act: int) -> Array[BalanceBuildDef]:
	return builds.filter(func(b: BalanceBuildDef) -> bool: return b.act == act)


func difficulty_index(id: StringName) -> int:
	for i in content.difficulties.size():
		if content.difficulties[i].id == id:
			return i
	return -1


## [passive, stacks, tag] for everything granting passives to `actor` (perks, families, gear).
static func passives_of(actor: Actor) -> Array:
	var result: Array = []
	for entry: PerkSet.Entry in actor.perks._all:
		for passive in entry.passives():
			if passive:
				result.append([passive, entry.stacks, String(entry.source_tag())])
	return result


# --- Damage arithmetic ------------------------------------------------------------------

## Average damage of a hit of `base` (before variance and crit) against `defense`, and the
## average rounded heal of each lifesteal ratio in `ratios` on it.
static func hit_stats(base: float, crit: float, defense: int, ratios: Array = []) -> Dictionary:
	var samples := 9
	var total := 0.0
	var heals: Array[float] = []
	heals.resize(ratios.size())
	heals.fill(0.0)
	crit = clampf(crit, 0.0, 1.0)
	for i in samples:
		var u := 1.0 - Combat.DAMAGE_VARIANCE + 2.0 * Combat.DAMAGE_VARIANCE * (i + 0.5) / samples
		var normal := maxi(1, maxi(1, roundi(base * u)) - defense)
		var critical := maxi(1, maxi(1, roundi(base * u * Combat.CRIT_MULTIPLIER)) - defense)
		total += (1.0 - crit) * normal + crit * critical
		for r in ratios.size():
			var ratio: float = ratios[r]
			heals[r] += (1.0 - crit) * roundi(normal * ratio) + crit * roundi(critical * ratio)
	for r in heals.size():
		heals[r] /= samples
	return { "mean": total / samples, "heals": heals }


static func uptime(rate: float, duration: float) -> float:
	return clampf(1.0 - exp(-rate * duration), 0.0, 1.0)


## What `player` deals to a target with `defense` (boss: fans land better), per second, and the
## healing that comes with it. `hp_ratio_low`: share of the fight below the Executioner threshold.
func hero_output(player: Player, defense: int, is_boss: bool) -> Dictionary:
	var stats := player.get_stats()
	var weapon := player.get_weapon()
	var power := float(player.get_power())
	var crit := clampf(stats.crit_chance, 0.0, 1.0)
	var attacks_per_s := 1.0 / player.get_attack_cooldown(weapon) if weapon else 0.0
	var passives := passives_of(player)

	var extra_projectiles := 0
	var lifesteal: Array = []  # ratios, one per source (each rounds on its own)
	var lifesteal_tags := PackedStringArray()
	var kill_heal := 0.0
	var kill_heal_tags := PackedStringArray()
	var skill_heal_flat := 0  # devotion, per skill use (skills with cooldown >= its min)
	var skill_heal_min_cd := 0.0
	var echo := 0.0
	var execute_mult := 1.0
	var execute_threshold := 0.0
	var low_hp_bonus := 0.0
	var shock_sources: Array = []  # crit shockwave amounts
	var burn_sources: Array = []  # [tick, interval, duration, chance]
	var slow_sources: Array = []  # [duration, chance]
	var status_bonus: Array = []  # [condition, bonus]
	var skill_effects_extra: Array[Effect] = []
	var ward := 0
	var cheat_death := 0.0
	for item: Array in passives:
		var passive: Passive = item[0]
		var stacks: int = item[1]
		var tag: String = item[2]
		if passive is LifestealPassive:
			lifesteal.append((passive as LifestealPassive).ratio_per_stack * stacks)
			lifesteal_tags.append(tag)
		elif passive is HealOnKillPassive:
			kill_heal += (passive as HealOnKillPassive).heal_per_stack * stacks
			kill_heal_tags.append(tag)
		elif passive is BloodlustPassive:
			var blood := passive as BloodlustPassive
			kill_heal += maxi(1, roundi(player.get_max_hp() * blood.heal_per_kill))
			kill_heal_tags.append(tag)
			low_hp_bonus += blood.low_health_bonus
		elif passive is HealOnSkillPassive:
			skill_heal_flat += (passive as HealOnSkillPassive).heal_per_stack * stacks
			skill_heal_min_cd = (passive as HealOnSkillPassive).min_cooldown
		elif passive is SkillEchoPassive:
			echo += (passive as SkillEchoPassive).chance_per_stack * stacks
		elif passive is ExecutePassive:
			var ex := passive as ExecutePassive
			execute_mult *= 1.0 + ex.bonus_per_stack * stacks
			execute_threshold = maxf(execute_threshold, ex.hp_threshold)
		elif passive is CritShockwavePassive:
			var cs := passive as CritShockwavePassive
			shock_sources.append(roundi(power * cs.damage_multiplier * stacks))
		elif passive is BurnOnHitPassive:
			var b := passive as BurnOnHitPassive
			if b.status_id == &"burn":
				burn_sources.append([b.damage_per_stack * stacks, b.interval, b.duration, b.chance])
		elif passive is SlowOnHitPassive:
			slow_sources.append([(passive as SlowOnHitPassive).duration, 1.0])
		elif passive is StatusDamagePassive:
			var sd := passive as StatusDamagePassive
			status_bonus.append([sd.condition, sd.bonus_per_stack * stacks])
		elif passive is ExtraProjectilesPassive:
			extra_projectiles += (passive as ExtraProjectilesPassive).count_per_stack * stacks
		elif passive is EffectsOnSkillPassive:
			skill_effects_extra.append_array((passive as EffectsOnSkillPassive).effects)
		elif passive is FloorWardPassive:
			ward += (passive as FloorWardPassive).ward_per_stack * stacks
		elif passive is CheatDeathPassive:
			cheat_death += (passive as CheatDeathPassive).heal_ratio * stacks

	var poison_tick := 0
	if weapon and weapon.on_hit:
		if weapon.on_hit.burn_damage > 0:
			burn_sources.append([weapon.on_hit.burn_damage, 0.5, weapon.on_hit.burn_duration, 1.0])
		if weapon.on_hit.poison_damage > 0:
			poison_tick = weapon.on_hit.poison_damage
		if weapon.on_hit.slow > 0.0:
			slow_sources.append([weapon.on_hit.slow_duration, 1.0])

	# Shots per attack that land on this target.
	var hits_per_attack := 1.0
	if weapon and weapon.kind == WeaponDef.Kind.RANGED:
		var count := weapon.projectile_count + extra_projectiles
		hits_per_attack = 1.0 + (count - 1) * (BOSS_FAN_SHARE if is_boss else 0.0)
	var hit_rate := attacks_per_s * hits_per_attack
	var weapon_base := power * (weapon.projectile_damage if weapon and weapon.kind == WeaponDef.Kind.RANGED else 1.0)

	# Statuses kept up by the hits.
	var burn_dps := 0.0
	var burn_up := 0.0
	for source: Array in burn_sources:
		var up := uptime(hit_rate * float(source[3]), float(source[2]))
		var dps := maxi(1, int(source[0]) - defense) / float(source[1]) * up
		if dps > burn_dps:
			burn_dps = dps
		burn_up = maxf(burn_up, up)
	var poison_up := uptime(hit_rate, weapon.on_hit.poison_duration) if poison_tick > 0 else 0.0
	var poison_dps := maxi(1, poison_tick - defense) * poison_up if poison_tick > 0 else 0.0
	var slow_up := 0.0
	for source: Array in slow_sources:
		slow_up = maxf(slow_up, uptime(hit_rate * float(source[1]), float(source[0])))
	var mult := 1.0
	for bonus: Array in status_bonus:
		var up := burn_up if bonus[0] == StatusDamagePassive.Condition.BURNING else (poison_up if bonus[0] == StatusDamagePassive.Condition.POISONED else slow_up)
		mult *= 1.0 + float(bonus[1]) * up

	var hit := hit_stats(weapon_base * mult, crit, defense, lifesteal)
	var direct_dps: float = hit.mean * hit_rate
	var lifesteal_hps := 0.0
	for h: float in hit.heals:
		lifesteal_hps += h * hit_rate
	var shock_dps := 0.0
	for amount: int in shock_sources:
		shock_dps += hit_rate * crit * maxi(1, amount - defense)

	# Skills (the weapon's two and the learned spell; not the roll).
	var skill_power := player.get_skill_power()
	var cdr := clampf(stats.cooldown_reduction, 0.0, SkillSet.MAX_COOLDOWN_REDUCTION)
	var skill_dps := 0.0
	var skill_heal_hps := 0.0
	var skill_lifesteal := 0.0
	var skills_used := PackedStringArray()
	for i in range(1, player.skills.skills.size()):
		var skill := player.skills.skills[i]
		if skill == null:
			continue
		var cooldown := skill.cooldown * (1.0 - cdr) * (1.0 - clampf(echo, 0.0, 0.9))
		if cooldown <= 0.0:
			continue
		var per_use := effects_damage(skill.effects, skill_power * mult, crit, defense, is_boss)
		per_use += effects_damage(skill_effects_extra, skill_power * mult, crit, defense, is_boss)
		var heal := effects_heal(skill.effects, player.get_max_hp())
		if skill.cooldown >= skill_heal_min_cd:
			heal += skill_heal_flat
		skill_dps += per_use / cooldown
		skill_heal_hps += heal / cooldown
		skills_used.append(String(skill.id))
	var total_ratio := 0.0
	for r: float in lifesteal:
		total_ratio += r
	skill_lifesteal = skill_dps * total_ratio

	var total := direct_dps + shock_dps + burn_dps + poison_dps + skill_dps
	return {
		"power": power, "crit": crit, "attacks_per_s": attacks_per_s, "hits_per_attack": hits_per_attack,
		"hit": hit.mean, "direct_dps": direct_dps, "shock_dps": shock_dps, "burn_dps": burn_dps,
		"poison_dps": poison_dps, "skill_dps": skill_dps, "dps": total, "skills": skills_used,
		"lifesteal_ratio": total_ratio, "lifesteal_tags": lifesteal_tags,
		"lifesteal_hps": lifesteal_hps + skill_lifesteal, "skill_heal_hps": skill_heal_hps,
		"kill_heal": kill_heal, "kill_heal_tags": kill_heal_tags,
		"execute_mult": execute_mult, "execute_threshold": execute_threshold, "low_hp_bonus": low_hp_bonus,
		"ward": ward, "cheat_death": cheat_death, "burn_uptime": burn_up, "slow_uptime": slow_up,
		"max_hp": player.get_max_hp(), "defense": stats.defense,
	}


## Average damage of one use of `effects` on one target (damage areas, dash strikes, projectiles;
## fans and rings land 1 + (count - 1) x BOSS_FAN_SHARE shots on a boss, at most 3).
static func effects_damage(effects: Array[Effect], skill_power: float, crit: float, defense: int, is_boss: bool) -> float:
	var total := 0.0
	for effect in effects:
		if effect is DamageAreaEffect:
			var area := effect as DamageAreaEffect
			total += hit_stats(area.flat_damage + roundf(skill_power * area.damage_multiplier), crit, defense).mean
		elif effect is DashStrikeEffect:
			var strike := effect as DashStrikeEffect
			total += hit_stats(strike.flat_damage + roundf(skill_power * strike.damage_multiplier), crit, defense).mean
		elif effect is ProjectileEffect:
			var shot := effect as ProjectileEffect
			var landing := 1.0 + (shot.count - 1) * (BOSS_FAN_SHARE if is_boss else 0.0)
			total += hit_stats(shot.flat_damage + roundf(skill_power * shot.damage_multiplier), crit, defense).mean * minf(landing, 3.0)
	return total


static func effects_heal(effects: Array[Effect], max_hp: int) -> float:
	var total := 0.0
	for effect in effects:
		if effect is HealEffect:
			var heal := effect as HealEffect
			total += heal.amount + roundi(max_hp * heal.max_hp_ratio)
	return total


# --- Bosses -------------------------------------------------------------------------------

## A boss on a difficulty, phase by phase: { hp, phases: [{ from, to, defense, power, melee,
## cycle, skills: [{ id, rate, damage, hits, cast, summons }], roar }] } against `hero_defense`.
func boss_profile(boss: BossDef, difficulty: DifficultyDef, hero_defense: int, melee_distance: float) -> Dictionary:
	var depth := boss_depth(act_of(boss))
	var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
	var stats := rules.scale_monster(boss.stats, true)
	var hp := stats.max_hp
	var windup_mult := rules.telegraph_time()
	var cooldown_speed := 1.0
	var skill_list: Array[SkillDef] = boss.skills
	var phases: Array = []
	var ratios: Array[float] = [1.0]
	for phase in boss.phases:
		ratios.append(phase.hp_ratio)
	ratios.append(0.0)
	for i in ratios.size() - 1:
		if i > 0:
			var phase := boss.phases[i - 1]
			if phase.bonuses:
				stats = stats.plus(phase.bonuses)
			if not phase.skills.is_empty():
				skill_list = phase.skills
			windup_mult *= phase.windup_multiplier
			cooldown_speed /= phase.cooldown_multiplier
		var power := maxi(1, roundi(((boss.weapon.damage if boss.weapon else 1) + stats.attack) * rules.monster_damage()))
		var skill_power := power * maxf(1.0 + stats.skill_power, 0.1)
		var melee: float = hit_stats(power, stats.crit_chance, hero_defense).mean
		var cycle := maxf(boss.attack_windup * windup_mult + boss.attack_recovery, boss.weapon.cooldown if boss.weapon else 1.0) + 1.0 / 60.0
		var skills: Array = []
		for skill in skill_list:
			if skill == null:
				continue
			if melee_distance < skill.ai_min_range or melee_distance > skill.ai_max_range:
				continue
			if skill.ai_below_hp_ratio < ratios[i]:
				continue  # only used below some HP: counted from the phase it can happen in
			var damage := 0.0
			var hits := 0
			var delays := {}
			var summons := 0
			for effect in skill.effects:
				var one := effects_damage([effect] as Array[Effect], skill_power, stats.crit_chance, hero_defense, true)
				if effect is SummonEffect:
					summons += (effect as SummonEffect).count
				if one > 0.0:
					# Hits within the hero's 0.6 s of invulnerability count once.
					var slot := floori(effect.delay / Player.HIT_INVULNERABILITY)
					if not delays.has(slot):
						delays[slot] = one
						hits += 1
					else:
						delays[slot] = maxf(delays[slot], one)
			for value: float in delays.values():
				damage += value
			skills.append({
				"id": String(skill.id), "rate": 1.0 / (skill.cooldown / cooldown_speed),
				"damage": damage, "hits": hits, "cast": skill.cast_time * windup_mult, "summons": summons,
			})
		phases.append({
			"from": ratios[i], "to": ratios[i + 1], "defense": stats.defense, "power": power,
			"melee": melee, "cycle": cycle, "skills": skills, "roar": boss.phase_roar_time if i > 0 else 0.0,
		})
	var shock := rules.dungeon_damage(4.0, 0.6)
	return { "id": String(boss.id), "depth": depth, "hp": hp, "phases": phases, "shockwave": shock,
		"shockwave_after": boss.shockwave_after_hits, "streak_gap": boss.streak_gap }


## Damage the boss deals per second to a hero standing in melee and the hits per second
## (capped by the hero's invulnerability), for one phase.
static func phase_incoming(phase: Dictionary, hero_hp: int) -> Dictionary:
	var busy := 0.0
	var skill_dps := 0.0
	var skill_hits := 0.0
	var summons := 0.0
	for skill: Dictionary in phase.skills:
		busy += skill.rate * skill.cast
		skill_dps += skill.rate * skill.damage
		skill_hits += skill.rate * skill.hits
		summons += skill.rate * skill.summons
	busy = clampf(busy, 0.0, 0.9)
	var melee_rate := (1.0 - busy) / float(phase.cycle)
	var hits := melee_rate + skill_hits
	var dps: float = melee_rate * phase.melee + skill_dps
	var cap := 1.0 / Player.HIT_INVULNERABILITY
	if hits > cap:
		dps *= cap / hits
		hits = cap
	var average_hit := dps / hits if hits > 0.0 else 0.0
	return { "dps": dps, "hits_per_s": hits, "average_hit": average_hit, "summons_per_s": summons,
		"hits_to_kill": hero_hp / average_hit if average_hit > 0.0 else INF }


## A face-tank fight, phase by phase: the hero stands in melee, hits, never dodges or drinks.
## { win, time, hp_left, death_time, healed, taken, heal_share, dps_out, ttk }.
func face_tank(player: Player, profile: Dictionary) -> Dictionary:
	var cache := {}
	var out := _out_at(player, int(profile.phases[0].defense), cache)
	var max_hp: int = out.max_hp
	var hp: float = float(max_hp) + out.ward
	var revives: float = out.cheat_death
	var time := 0.0
	var healed := 0.0
	var taken := 0.0
	var hero_hits_per_s: float = out.attacks_per_s * out.hits_per_attack
	var total_hp: float = profile.hp
	for phase: Dictionary in profile.phases:
		var incoming := phase_incoming(phase, max_hp)
		out = _out_at(player, int(phase.defense), cache)
		var dps: float = out.dps
		# Shockwaves answer N hits in a row: each costs time and some HP.
		var shock_rate := 0.0
		if int(profile.shockwave_after) > 0:
			shock_rate = minf(hero_hits_per_s / float(profile.shockwave_after), 1.0 / 3.0)
		var uptime_share := 1.0 / (1.0 + shock_rate * SHOCKWAVE_DOWNTIME)
		var in_dps: float = incoming.dps + shock_rate * float(profile.shockwave)
		var heal_hps: float = (out.lifesteal_hps + out.skill_heal_hps) * uptime_share + out.kill_heal * incoming.summons_per_s
		# Phase HP, with the Executioner's bonus below its threshold.
		var share: float = phase.from - phase.to
		var low := clampf(minf(phase.from, out.execute_threshold) - phase.to, 0.0, share)
		var phase_time: float = total_hp * ((share - low) + low / out.execute_mult) / maxf(dps * uptime_share, 0.01) + phase.roar
		var net := heal_hps - in_dps
		if net >= 0.0:
			# Out-heals the boss: stays topped up.
			healed += minf(heal_hps * phase_time, in_dps * phase_time + (max_hp - minf(hp, max_hp)))
			taken += in_dps * phase_time
			hp = minf(float(max_hp), hp + net * phase_time)
		else:
			var left := phase_time
			while hp / -net < left:
				var lasts := hp / -net
				healed += heal_hps * lasts
				taken += in_dps * lasts
				left -= lasts
				if revives < 0.25:
					var dead_at := time + phase_time - left
					return { "win": false, "time": dead_at, "death_time": dead_at, "hp_left": 0.0,
						"healed": healed, "taken": taken, "heal_share": healed / maxf(taken, 1.0) }
				# A Phoenix Feather: back to half health once per stack.
				revives -= 0.5
				hp = max_hp * 0.5
			healed += heal_hps * left
			taken += in_dps * left
			hp += net * left
		time += phase_time
	return { "win": true, "time": time, "death_time": INF, "hp_left": hp, "healed": healed, "taken": taken,
		"heal_share": healed / maxf(taken, 1.0) }


## hero_output against `defense`, worked out once per defense value.
func _out_at(player: Player, defense: int, cache: Dictionary) -> Dictionary:
	if not cache.has(defense):
		cache[defense] = hero_output(player, defense, true)
	return cache[defense]


## Seconds to kill the boss with pure damage (no downtime): the model's TTK.
func boss_ttk(player: Player, profile: Dictionary) -> float:
	var time := 0.0
	var cache := {}
	for phase: Dictionary in profile.phases:
		var out := _out_at(player, int(phase.defense), cache)
		var share: float = phase.from - phase.to
		var low := clampf(minf(phase.from, out.execute_threshold) - phase.to, 0.0, share)
		time += float(profile.hp) * ((share - low) + low / out.execute_mult) / maxf(out.dps, 0.01) + phase.roar
	return time


func _melee_distance(player: Player, boss: BossDef) -> float:
	var weapon := player.get_weapon()
	if weapon and weapon.kind == WeaponDef.Kind.RANGED:
		return minf(weapon.reach * 0.5, 200.0)
	return player.radius + boss.radius + (weapon.reach if weapon else 20.0) * 0.6


func _boss_tables() -> void:
	var rows: Array = []
	var phase_rows: Array = []
	var results: Array = []
	for boss in bosses:
		var act := act_of(boss)
		for difficulty in difficulties:
			for build in builds:
				var player := player_for(build)
				var profile := boss_profile(boss, difficulty, player.get_stats().defense, _melee_distance(player, boss))
				var out := hero_output(player, int(profile.phases[0].defense), true)
				var ttk := boss_ttk(player, profile)
				var tank := face_tank(player, profile)
				var first := phase_incoming(profile.phases[0], player.get_max_hp())
				var last := phase_incoming(profile.phases.back(), player.get_max_hp())
				var heal_hps: float = out.lifesteal_hps + out.skill_heal_hps + out.kill_heal * first.summons_per_s
				var own := build.act == act
				var entry := {
					"boss": String(boss.id), "act": act, "difficulty": String(difficulty.id), "build": build.name,
					"tags": build.tags, "own_act": own, "boss_hp": profile.hp, "boss_defense": profile.phases[0].defense,
					"hero_max_hp": player.get_max_hp(), "hero_defense": player.get_stats().defense,
					"dps": out.dps, "direct_dps": out.direct_dps, "skill_dps": out.skill_dps,
					"dot_dps": out.burn_dps + out.poison_dps, "shock_dps": out.shock_dps, "ttk": ttk,
					"heal_hps": heal_hps, "lifesteal_hps": out.lifesteal_hps, "boss_dps_p1": first.dps,
					"boss_dps_last": last.dps, "net_hps_p1": heal_hps - first.dps,
					"hits_to_kill_p1": first.hits_to_kill, "hits_to_kill_last": last.hits_to_kill,
					"facetank_win": tank.win, "facetank_time": tank.time, "facetank_hp_left": tank.hp_left,
					"facetank_heal_share": tank.heal_share,
				}
				results.append(entry)
				if own:
					rows.append([String(boss.id), String(difficulty.id), build.name, profile.hp, out.dps, ttk,
						first.dps, heal_hps, heal_hps - first.dps, first.hits_to_kill,
						"WINS" if tank.win else "dies at %.0f s" % tank.death_time, tank.heal_share])
					_check_boss(entry, build, boss, difficulty)
		var normal := content.default_difficulty
		var reference := expected_build(act)
		if reference:
			var hero := player_for(reference)
			var profile := boss_profile(boss, normal, hero.get_stats().defense, _melee_distance(hero, boss))
			for p: Dictionary in profile.phases:
				var incoming := phase_incoming(p, hero.get_max_hp())
				var skill_text := PackedStringArray()
				for s: Dictionary in p.skills:
					skill_text.append("%s %.0f x%d /%.1fs" % [s.id, s.damage, s.hits, 1.0 / s.rate])
				phase_rows.append([String(boss.id), "%d-%d%%" % [roundi(p.to * 100), roundi(p.from * 100)], p.defense, p.power,
					p.melee, p.cycle, "; ".join(skill_text), incoming.dps, incoming.hits_to_kill])
	report.data["bosses"] = results
	report.table("boss_fights", "Bosses vs the builds of their act (model)",
		PackedStringArray(["Boss", "Difficulty", "Build", "Boss HP", "Hero DPS", "TTK s", "Boss DPS in (p1)", "Heal/s", "Net HP/s (p1)", "Boss hits to kill hero", "Face-tank", "Heal / taken"]), rows)
	report.table("boss_phases", "Boss phases on Normal vs the act's expected build (damage after its armor)",
		PackedStringArray(["Boss", "HP range", "Def", "Power", "Melee hit", "Melee cycle s", "Skills at melee (dmg x hits / cooldown)", "DPS in", "Hits to kill"]), phase_rows)


func _check_boss(entry: Dictionary, build: BalanceBuildDef, boss: BossDef, difficulty: DifficultyDef) -> void:
	var subject := "%s vs %s (%s)" % [build.name, boss.id, difficulty.id]
	var is_normal := difficulty == content.default_difficulty
	if build.has_tag("expected") and is_normal:
		var ttk: float = entry.ttk
		if ttk < targets.boss_ttk_min or ttk > targets.boss_ttk_max:
			report.flag(BalanceReport.WARN, "model: boss TTK", subject, BalanceReport.secs(ttk), "%d-%d s" % [targets.boss_ttk_min, targets.boss_ttk_max],
				"expected build kills the boss %s (100%% uptime)" % ("too fast" if ttk < targets.boss_ttk_min else "too slowly"))
		var hits: float = entry.hits_to_kill_p1
		if hits < targets.boss_hits_to_kill_min or hits > targets.boss_hits_to_kill_max:
			report.flag(BalanceReport.WARN, "model: boss hits to kill", subject, "%.1f hits" % hits, "%d-%d" % [targets.boss_hits_to_kill_min, targets.boss_hits_to_kill_max],
				"average boss hit vs the expected build's max HP")
	var must_lose := false
	for tag in targets.facetank_must_lose_tags:
		must_lose = must_lose or build.has_tag(tag)
	if must_lose and difficulty_index(difficulty.id) >= difficulty_index(targets.facetank_must_lose_from) and entry.facetank_win:
		report.flag(BalanceReport.WARN, "model: face-tank wins", subject, "wins with %.0f HP left" % entry.facetank_hp_left, "must die from %s" % targets.facetank_must_lose_from,
			"standing and hitting beats the boss (net %+.1f HP/s in phase 1)" % entry.net_hps_p1)
	var share_max := targets.heal_share_max_degenerate if build.has_tag("degenerate") else targets.heal_share_max_expected
	if (build.has_tag("expected") or build.has_tag("degenerate")) and entry.facetank_heal_share > share_max:
		report.flag(BalanceReport.WARN, "model: heal share", subject, BalanceReport.pct(entry.facetank_heal_share), "<= %s" % BalanceReport.pct(share_max),
			"healing during the face-tank fight / damage taken")


# --- Monsters ---------------------------------------------------------------------------

func _monster_tables() -> void:
	var rows: Array = []
	var elite_rows: Array = []
	var results: Array = []
	for act_index in content.dungeon.acts.size():
		var act := content.dungeon.acts[act_index]
		var build := expected_build(act_index + 1)
		if build == null:
			continue
		var player := player_for(build)
		var first_depth := content.dungeon.first_depth(act_index)
		var last_normal := boss_depth(act_index + 1) - 1
		for difficulty in difficulties:
			var rules := FloorRules.make(content.dungeon, difficulty, null, last_normal)
			for monster in act.monsters:
				if monster == null:
					continue
				var info := _monster_numbers(monster, rules, player, 1.0, 0)
				var first_rules := FloorRules.make(content.dungeon, difficulty, null, maxi(first_depth, monster.min_depth))
				var first := _monster_numbers(monster, first_rules, player, 1.0, 0)
				var entry := {
					"act": act_index + 1, "monster": String(monster.id), "difficulty": String(difficulty.id),
					"depth": last_normal, "hp": info.hp, "defense": info.defense, "hit": info.hit, "ttk": info.ttk,
					"hits_to_kill_hero": info.hits_to_kill_hero, "first_depth": first_rules.depth, "hp_first": first.hp,
					"hit_first": first.hit, "build": build.name,
				}
				results.append(entry)
				rows.append([act_index + 1, String(monster.id), String(difficulty.id), "%d-%d" % [first_rules.depth, last_normal],
					"%d-%d" % [first.hp, info.hp], info.defense, "%.1f-%.1f" % [first.hit, info.hit], info.ttk, info.hits_to_kill_hero])
				if difficulty == content.default_difficulty and monster.spawn_weight > 0:
					if info.ttk < targets.common_ttk_min or info.ttk > targets.common_ttk_max:
						report.flag(BalanceReport.WARN, "model: monster TTK", "%s vs %s (normal, depth %d)" % [build.name, monster.id, last_normal],
							BalanceReport.secs(info.ttk), "%.1f-%.1f s" % [targets.common_ttk_min, targets.common_ttk_max],
							"%d HP, %d armor vs %.1f per hit" % [info.hp, info.defense, info.per_hit])
				# Elites: each affix.
				if difficulty == content.default_difficulty:
					var times := PackedFloat32Array()
					for affix in content.elite_affixes:
						var elite := _monster_numbers(monster, rules, player, content.dungeon.elite_rank.hp_multiplier * affix.hp_multiplier,
							affix.perk.bonuses.defense if affix.perk and affix.perk.bonuses else 0)
						times.append(elite.ttk)
					var average := 0.0
					for t in times:
						average += t
					average /= maxf(times.size(), 1.0)
					elite_rows.append([act_index + 1, String(monster.id), average, Array(times).min(), Array(times).max()])
					if monster.spawn_weight > 0 and (average < targets.elite_ttk_min or average > targets.elite_ttk_max):
						report.flag(BalanceReport.WARN, "model: elite TTK", "%s vs elite %s (normal)" % [build.name, monster.id],
							BalanceReport.secs(average), "%.0f-%.0f s" % [targets.elite_ttk_min, targets.elite_ttk_max], "average over the elite affixes")
	report.data["monsters"] = results
	report.table("monsters", "Monsters of each act: HP and hit (first floor - last normal floor), TTK and hits to kill with the act's expected build at its last normal floor",
		PackedStringArray(["Act", "Monster", "Difficulty", "Depths", "HP", "Def", "Hit on hero", "TTK s", "Hits to kill hero"]), rows)
	report.table("elites", "Elites on Normal (the act's last normal floor): TTK with the act's expected build, over the elite affixes",
		PackedStringArray(["Act", "Monster", "Avg TTK s", "Min", "Max"]), elite_rows)


func _monster_numbers(monster: MonsterDef, rules: FloorRules, player: Player, hp_mult: float, extra_defense: int) -> Dictionary:
	var stats := rules.scale_monster(monster.stats, false)
	var hp := roundi(stats.max_hp * hp_mult)
	var defense := stats.defense + extra_defense
	var out := hero_output(player, defense, false)
	var per_hit: float = out.hit
	var hits := ceilf(hp / maxf(per_hit, 0.01))
	var hit_rate: float = out.attacks_per_s * out.hits_per_attack
	var ttk := hits / maxf(hit_rate, 0.01)
	var dot: float = out.burn_dps + out.poison_dps + out.shock_dps
	if dot > 0.0:
		ttk = minf(ttk, hp / maxf(out.direct_dps + dot, 0.01))
	var power := maxi(1, roundi(((monster.weapon.damage if monster.weapon else 1) + stats.attack) * rules.monster_damage()))
	var hit: float = hit_stats(power, stats.crit_chance, player.get_stats().defense).mean
	return { "hp": hp, "defense": defense, "per_hit": per_hit, "ttk": ttk, "hit": hit,
		"hits_to_kill_hero": player.get_max_hp() / maxf(hit, 0.01), "power": power,
		"cycle": maxf(monster.attack_windup * rules.telegraph_time() + monster.attack_recovery, monster.weapon.cooldown if monster.weapon else 1.0) }


# --- Builds, weapons, perks -------------------------------------------------------------

func _check_build_data() -> void:
	for build in builds:
		for problem in BalanceBuild.problems(build, content):
			report.flag(BalanceReport.ERROR, "build data", build.name, problem, "valid ids", "fix data/balance/builds/%s.tres" % build.name)


func _build_table() -> void:
	var rows: Array = []
	var data := {}
	for build in builds:
		var player := player_for(build)
		var stats := player.get_stats()
		var weapon := player.get_weapon()
		var boss := content.dungeon.acts[build.act - 1].boss
		var defense := FloorRules.make(content.dungeon, content.default_difficulty, null, boss_depth(build.act)).scale_monster(boss.stats, true).defense
		var out := hero_output(player, defense, true)
		var families := PackedStringArray()
		for synergy in player.perks.awakened():
			families.append(String(synergy.id))
		var sustain := PackedStringArray()
		if out.lifesteal_ratio > 0.0:
			sustain.append("lifesteal %d%% (%s)" % [roundi(out.lifesteal_ratio * 100.0), ", ".join(out.lifesteal_tags)])
		if out.kill_heal > 0.0:
			sustain.append("%.0f HP/kill (%s)" % [out.kill_heal, ", ".join(out.kill_heal_tags)])
		if out.skill_heal_hps > 0.0:
			sustain.append("%.1f HP/s from skills" % out.skill_heal_hps)
		if out.ward > 0:
			sustain.append("ward %d" % out.ward)
		if out.cheat_death > 0.0:
			sustain.append("cheat death x%.0f" % (out.cheat_death / 0.5))
		rows.append([build.name, ",".join(build.tags), build.act, build.level, weapon.display_name if weapon else "-",
			stats.max_hp, player.get_power(), stats.defense, BalanceReport.pct(stats.crit_chance),
			"%.2f" % out.attacks_per_s, out.dps, ", ".join(families), "; ".join(sustain)])
		data[build.name] = {
			"act": build.act, "level": build.level, "tags": build.tags, "weapon": weapon.display_name if weapon else "",
			"max_hp": stats.max_hp, "power": player.get_power(), "attack": stats.attack, "defense": stats.defense,
			"crit_chance": stats.crit_chance, "attack_speed": stats.attack_speed, "skill_power": stats.skill_power,
			"cooldown_reduction": stats.cooldown_reduction, "move_speed": stats.move_speed, "families": families,
			"vs_act_boss": out, "description": build.description,
		}
	report.data["builds"] = data
	report.table("builds", "Builds (DPS vs their act's main boss on Normal, 100% uptime)",
		PackedStringArray(["Build", "Tags", "Act", "Lvl", "Weapon", "Max HP", "Power", "Armor", "Crit", "Attacks/s", "DPS", "Families", "Sustain"]), rows)


func _all_weapons() -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	var pools: Array = [content.items, content.locked_items, content.player.starting_equipment]
	for pool: Array in pools:
		for item: Variant in pool:
			if item is WeaponDef and not result.has(item):
				result.append(item)
	return result


func _weapon_table() -> void:
	var reference := BalanceBuild.find(all_builds, targets.perk_reference_build)
	if reference == null:
		return
	var rows: Array = []
	var dps_values: Array[float] = []
	var act := reference.act
	var boss := content.dungeon.acts[act - 1].boss
	var boss_defense := FloorRules.make(content.dungeon, content.default_difficulty, null, boss_depth(act)).scale_monster(boss.stats, true).defense
	var entries: Array = []
	for weapon in _all_weapons():
		var build := reference.duplicate() as BalanceBuildDef
		build.weapon = weapon
		build.weapon_rarity = 0
		build.weapon_affixes = PackedStringArray()
		build.runes = PackedStringArray()
		var player := BalanceBuild.make_player(build, content)
		var open := hero_output(player, 0, false)
		var vs_boss := hero_output(player, boss_defense, true)
		player.free()
		var hits_per_s: float = open.attacks_per_s
		entries.append({ "weapon": String(weapon.id), "kind": "ranged" if weapon.kind == WeaponDef.Kind.RANGED else "melee",
			"damage": weapon.damage, "cooldown": weapon.cooldown, "attacks_per_s": hits_per_s, "power": open.power,
			"crit": open.crit, "dps_def0": open.direct_dps, "skill_dps_def0": open.skill_dps,
			"dps_boss": vs_boss.direct_dps, "skill_dps_boss": vs_boss.skill_dps, "total_boss": vs_boss.dps })
		dps_values.append(vs_boss.dps)
	var sorted := dps_values.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
	for e: Dictionary in entries:
		var ratio: float = e.total_boss / maxf(median, 0.01)
		e["ratio_to_median"] = ratio
		rows.append([e.weapon, e.kind, e.damage, e.cooldown, e.attacks_per_s, e.power, BalanceReport.pct(e.crit),
			e.dps_def0, e.skill_dps_def0, e.dps_boss, e.skill_dps_boss, e.total_boss, "%.2fx" % ratio])
		if ratio < targets.weapon_dps_ratio_min or ratio > targets.weapon_dps_ratio_max:
			report.flag(BalanceReport.WARN, "model: weapon DPS", "%s (Common, %s hero vs %s)" % [e.weapon, reference.name, boss.id],
				"%.2fx median" % ratio, "%.1f-%.1fx" % [targets.weapon_dps_ratio_min, targets.weapon_dps_ratio_max],
				"%.1f DPS vs a median of %.1f (armor %d)" % [e.total_boss, median, boss_defense])
	report.data["weapons"] = entries
	report.table("weapons", "Weapons (Common) on the %s hero: DPS = hits/s x average hit (variance, crit, armor) + skills" % reference.name,
		PackedStringArray(["Weapon", "Kind", "Damage", "Cooldown", "Attacks/s", "Power", "Crit", "DPS (armor 0)", "Skill DPS (armor 0)", "DPS vs %s" % boss.id, "Skill DPS vs boss", "Total vs boss", "vs median"]), rows)


## A build's fight power against its act's main boss (Normal): [ttk, time to die standing in
## melee] and in a room of ROOM_PACK common monsters: [clear time, time to die].
func _fight_power(player: Player, act: int) -> Dictionary:
	var boss := content.dungeon.acts[act - 1].boss
	var profile := boss_profile(boss, content.default_difficulty, player.get_stats().defense, _melee_distance(player, boss))
	var out := hero_output(player, int(profile.phases[0].defense), true)
	var incoming := phase_incoming(profile.phases[0], player.get_max_hp())
	var ehp: float = player.get_max_hp() * (1.0 + out.cheat_death) + out.ward
	var heal: float = out.lifesteal_hps + out.skill_heal_hps + out.kill_heal * incoming.summons_per_s
	var ttd := minf(ehp / maxf(incoming.dps - heal, 0.001), TTD_CAP) if incoming.dps > heal else TTD_CAP
	# A room: the act's monsters by spawn weight at its last normal floor.
	var rules := FloorRules.make(content.dungeon, content.default_difficulty, null, boss_depth(act) - 1)
	var weight := 0.0
	var ttk := 0.0
	var room_dps := 0.0
	var room_hits := 0.0
	var room_out := {}
	for monster in content.dungeon.acts[act - 1].monsters:
		if monster == null or monster.spawn_weight <= 0:
			continue
		var numbers := _monster_numbers(monster, rules, player, 1.0, 0)
		weight += monster.spawn_weight
		ttk += numbers.ttk * monster.spawn_weight
		room_dps += numbers.hit / numbers.cycle * monster.spawn_weight
		room_hits += 1.0 / numbers.cycle * monster.spawn_weight
	ttk /= maxf(weight, 1.0)
	room_dps = room_dps / maxf(weight, 1.0) * ROOM_PACK
	room_hits = room_hits / maxf(weight, 1.0) * ROOM_PACK
	if room_hits > 1.0 / Player.HIT_INVULNERABILITY:
		room_dps *= (1.0 / Player.HIT_INVULNERABILITY) / room_hits
	room_out = hero_output(player, 1, false)
	var room_heal: float = room_out.lifesteal_hps + room_out.skill_heal_hps + room_out.kill_heal / maxf(ttk, 0.1)
	var room_ttd := minf(ehp / maxf(room_dps - room_heal, 0.001), TTD_CAP) if room_dps > room_heal else TTD_CAP
	return { "boss_ttk": boss_ttk(player, profile), "boss_ttd": ttd, "room_clear": ttk * ROOM_PACK, "room_ttd": room_ttd }


func _perk_table() -> void:
	var reference := BalanceBuild.find(all_builds, targets.perk_reference_build)
	if reference == null:
		report.flag(BalanceReport.ERROR, "targets", "perk_reference_build", targets.perk_reference_build, "an existing build", "no such build: perk values skipped")
		return
	var base_player := BalanceBuild.make_player(reference, content)
	var base := _fight_power(base_player, reference.act)
	base_player.free()
	var entries: Array = []
	for perk in content.perks:
		if perk == null:
			continue
		var build := reference.duplicate() as BalanceBuildDef
		build.perks = reference.perks.duplicate()
		build.perks[String(perk.id)] = perk.max_stacks
		var player := BalanceBuild.make_player(build, content)
		var power := _fight_power(player, reference.act)
		player.free()
		var boss_value: float = (base.boss_ttk / maxf(power.boss_ttk, 0.01)) * (power.boss_ttd / maxf(base.boss_ttd, 0.01)) - 1.0
		var room_value: float = (base.room_clear / maxf(power.room_clear, 0.01)) * (power.room_ttd / maxf(base.room_ttd, 0.01)) - 1.0
		entries.append({ "perk": String(perk.id), "rarity": "relic" if perk.rarity == PerkDef.Rarity.RARE else "common",
			"stacks": perk.max_stacks, "boss_value": boss_value, "room_value": room_value,
			"boss_ttk": power.boss_ttk, "boss_ttd": power.boss_ttd, "room_clear": power.room_clear, "room_ttd": power.room_ttd })
	var rows: Array = []
	for rarity in ["common", "relic"]:
		var group := entries.filter(func(e: Dictionary) -> bool: return e.rarity == rarity)
		for context in ["boss_value", "room_value"]:
			var values: Array[float] = []
			for e: Dictionary in group:
				if e[context] > 0.001:
					values.append(e[context])
			values.sort()
			var median: float = values[values.size() / 2] if not values.is_empty() else 0.0
			for e: Dictionary in group:
				e[context + "_median"] = median
				if median > 0.0 and e[context] > median * targets.perk_value_max_vs_median:
					report.flag(BalanceReport.WARN, "model: perk value", "%s x%d (%s, %s)" % [e.perk, e.stacks, rarity, context.trim_suffix("_value")],
						"%.2fx median" % (e[context] / median), "<= %.1fx" % targets.perk_value_max_vs_median,
						"+%d%% fight power on %s vs a median of +%d%%" % [roundi(e[context] * 100.0), reference.name, roundi(median * 100.0)])
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.boss_value > b.boss_value)
		for e: Dictionary in group:
			rows.append([e.perk, e.rarity, e.stacks, BalanceReport.pct(e.boss_value), BalanceReport.pct(e.room_value),
				e.boss_ttk, e.boss_ttd, e.room_clear, e.room_ttd])
	report.data["perks"] = { "reference": reference.name, "base": base, "values": entries }
	report.table("perks", "Perk values at max level on %s (fight power = faster kill x longer life, vs the act's main boss on Normal and vs a room of %d monsters; TTD capped at %d s)" % [reference.name, ROOM_PACK, TTD_CAP],
		PackedStringArray(["Perk", "Rarity", "Stacks", "Boss value", "Room value", "Boss TTK s", "Boss TTD s", "Room clear s", "Room TTD s"]), rows)


func _degenerate_ratios() -> void:
	var rows: Array = []
	for build in builds:
		if not build.has_tag("degenerate"):
			continue
		var expected := expected_build(build.act)
		if expected == null:
			continue
		var boss := content.dungeon.acts[build.act - 1].boss
		var defense := FloorRules.make(content.dungeon, content.default_difficulty, null, boss_depth(build.act)).scale_monster(boss.stats, true).defense
		var mine: float = hero_output(player_for(build), defense, true).dps
		var theirs: float = hero_output(player_for(expected), defense, true).dps
		var ratio := mine / maxf(theirs, 0.01)
		rows.append([build.name, expected.name, String(boss.id), mine, theirs, "%.2fx" % ratio])
		if ratio > targets.degenerate_dps_ratio_max:
			report.flag(BalanceReport.WARN, "model: degenerate DPS", "%s vs %s" % [build.name, expected.name], "%.2fx" % ratio,
				"<= %.1fx" % targets.degenerate_dps_ratio_max, "single-target DPS vs %s" % boss.id)
	report.table("degenerate_dps", "Degenerate builds: DPS against their act's main boss (Normal) vs the expected build",
		PackedStringArray(["Build", "Expected", "Boss", "DPS", "Expected DPS", "Ratio"]), rows)
