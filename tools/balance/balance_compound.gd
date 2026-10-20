class_name BalanceCompound
extends Node
## Compound checks, measured on the engine (BalanceLab): things that multiply. On the act's
## expected build (Normal), the boss of the act as a dummy (DPS) and rooms of its monsters:
## 1. attack speed x crit x damage: Frenzy, Precision, Strength at max alone, then together;
## 2. extra projectiles: Multishot and Prism runes on every ranged weapon, at 64, 128, 256 px;
## 3. echo: the Echo perk, Echo runes, the "of Echoes" affix, alone and together (skill uses);
## 4. burn stacking: Ignite, Ember runes, the Burning affix, Kindling, the Inferno family;
## 5. armor against many weak hits: the most armor a build stacks vs every act's monsters
##    (share brought down to the 1-damage floor), and rooms with/without it;
## 6. healing vs the sustain cap: lifesteal stacks in rooms, with the shared budget (SustainRules)
##    and without it: how much each stack asked for and how much the cap cut.

const DISTANCES := [64.0, 128.0, 256.0]

var lab: BalanceLab
var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var seed_value := 1
var quick := false
var verbose := true
## Acts the stacks are measured on (expected builds).
var acts: Array[int] = [2, 4]


func run() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance compound checks"
	var started := Time.get_ticks_msec()
	lab.override_chances()
	if quick:
		acts = [2]
	await _stacks(report)
	if not quick:
		await _projectiles(report)
	_armor(report)
	await _sustain(report)
	lab.restore_chances()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Compound checks: %.0f s of real time (acts %s, Normal, seed %d)." % [seconds, acts, seed_value])
	report.timings["compound"] = seconds
	return report


## DPS on the act's boss as a dummy (scaled so the expected build needs ~12 s).
func _dummy_dps(s: Dictionary, build: BalanceBuildDef, boss: BossDef, hp_scale: float, hold: float = 0.0) -> Dictionary:
	if hold > 0.0:
		BalanceBot.hold_override = hold
	var d: Dictionary = await lab.dummy(s, build, boss, hp_scale, 40.0, seed_value)
	BalanceBot.hold_override = 0.0
	return d


func _session(act: int) -> Dictionary:
	var normal := BalanceContent.difficulty(content, "normal")
	return lab.session(BalanceContent.boss_depth(content, act) - 1, normal)


func _scale(s: Dictionary, build: BalanceBuildDef, boss: BossDef) -> float:
	var probe: Dictionary = await lab.dummy(s, build, boss, 1.0, 6.0, seed_value)
	return clampf(12.0 * float(probe.dps) / maxf(float(probe.full_hp), 1.0), 0.05, 1.0)


## Groups of picks measured alone and together: does the whole multiply past the target?
func _stacks(report: BalanceReport) -> void:
	var groups := [
		["attack speed x crit x damage", [["perk", "frenzy"], ["perk", "precision"], ["perk", "strength"], ["perk", "war_banner"]]],
		["echo (skills ready again)", [["perk", "echo"], ["rune", "echo_rune"], ["rune", "echo_rune"], ["rune", "echo_rune"], ["affix", "of_echoes"], ["perk", "arcane_focus"]]],
		["burn stacking", [["perk", "ignite"], ["rune", "ember_rune"], ["rune", "ember_rune"], ["affix", "burning"], ["perk", "kindling"], ["family", "inferno"]]],
	]
	var rows: Array = []
	for act in acts:
		var expected := BalanceBuild.expected(all_builds, act)
		if expected == null:
			continue
		var s := _session(act)
		var boss := content.dungeon.acts[act - 1].boss
		var scale := await _scale(s, expected, boss)
		var base: Dictionary = await _dummy_dps(s, expected, boss, scale)
		for group: Array in groups:
			var product := 1.0
			var combined := expected
			var parts := PackedStringArray()
			for pick: Array in group[1]:
				var level := 99 if pick[0] == "perk" else 1
				var alone := BalanceBuild.variant(expected, content, pick[0], pick[1], level)
				var combined_next := BalanceBuild.variant(combined, content, pick[0], pick[1], level)
				if alone == null or combined_next == null:
					continue
				combined = combined_next
				var m: Dictionary = await _dummy_dps(s, alone, boss, scale)
				var gain: float = m.dps / maxf(float(base.dps), 0.01)
				product *= gain
				parts.append("%s %s" % [pick[1], BalanceReport.delta(gain - 1.0)])
				rows.append([act, group[0], "%s %s alone" % [pick[0], pick[1]], m.dps, "x%.2f" % gain, "", m.skills])
			var all: Dictionary = await _dummy_dps(s, combined, boss, scale)
			var together: float = all.dps / maxf(float(base.dps), 0.01)
			rows.append([act, group[0], "all together", all.dps, "x%.2f" % together, "x%.2f" % product, all.skills])
			if together > targets.compound_dps_ratio_max:
				report.flag(BalanceReport.WARN, "compound: stack", "%s (act %d)" % [group[0], act], "x%.2f DPS" % together,
					"<= x%.1f" % targets.compound_dps_ratio_max, "%s; product of the parts x%.2f" % [", ".join(parts), product])
		rows.append([act, "base", expected.name, base.dps, "x1.00", "", base.skills])
		await lab.close(s)
		if verbose:
			print("  compound: stacks act %d done" % act)
	report.table("compound_stacks", "Compound checks", "Stacks measured on the engine (act's boss as a dummy, expected build, Normal): DPS of each pick alone and all together vs the product of the parts",
		PackedStringArray(["Act", "Stack", "Variant", "Dummy DPS", "vs base", "Product of parts", "Skill uses"]), rows)


## Multishot and Prism on every ranged weapon, at three distances.
func _projectiles(report: BalanceReport) -> void:
	var rows: Array = []
	var act := 2
	var expected := BalanceBuild.expected(all_builds, act)
	if expected == null:
		return
	var s := _session(act)
	var boss := content.dungeon.acts[act - 1].boss
	var scale := await _scale(s, expected, boss)
	for weapon in BalanceContent.weapons():
		if weapon.kind != WeaponDef.Kind.RANGED:
			continue
		var plain := BalanceBuild.variant(expected, content, "weapon", String(weapon.id), 2, weapon)
		var variants := [["plain (Rare)", plain],
			["+ Multishot 1", BalanceBuild.variant(plain, content, "perk", "multishot", 1)],
			["+ Multishot 2", BalanceBuild.variant(plain, content, "perk", "multishot", 2)],
			["+ Prism", BalanceBuild.variant(plain, content, "rune", "prism_rune")],
			["+ Prism x2", BalanceBuild.variant(BalanceBuild.variant(plain, content, "rune", "prism_rune"), content, "rune", "prism_rune")]]
		variants.append(["+ Multishot 2 + Prism x2", BalanceBuild.variant(variants[4][1], content, "perk", "multishot", 2)])
		for distance: float in DISTANCES:
			var base_dps := 0.0
			for v: Array in variants:
				if v[1] == null:
					continue
				var m: Dictionary = await _dummy_dps(s, v[1], boss, scale, distance)
				if base_dps <= 0.0:
					base_dps = m.dps
				var ratio: float = m.dps / maxf(base_dps, 0.01)
				rows.append([String(weapon.id), "%d px" % roundi(distance), v[0], m.dps, "x%.2f" % ratio])
				if ratio > targets.compound_dps_ratio_max:
					report.flag(BalanceReport.WARN, "compound: projectiles", "%s %s at %d px" % [weapon.id, v[0], roundi(distance)], "x%.2f DPS" % ratio,
						"<= x%.1f" % targets.compound_dps_ratio_max, "extra projectiles on a single target (the act II boss)")
	await lab.close(s)
	report.table("compound_projectiles", "Compound checks", "Extra projectiles (Multishot, Prism) on every ranged weapon (Rare, act II expected build otherwise) at 64, 128 and 256 px from the act II boss as a dummy (engine)",
		PackedStringArray(["Weapon", "Distance", "Variant", "Dummy DPS", "vs plain"]), rows)


## Armor: the build with the most armor (any build) vs every monster's hit, static.
func _armor(report: BalanceReport) -> void:
	var rows: Array = []
	var normal := BalanceContent.difficulty(content, "normal")
	for act in range(1, content.dungeon.acts.size() + 1):
		var candidates: Array = all_builds.filter(func(b: BalanceBuildDef) -> bool: return b.act == act)
		for build: BalanceBuildDef in candidates:
			var player := BalanceBuild.make_player(build, content)
			var armor := player.get_stats().defense
			var floor_hits := 0
			var total := 0
			for monster in content.dungeon.acts[act - 1].monsters:
				if monster == null:
					continue
				for depth in BalanceContent.monster_depths(content, act, monster):
					var rules := FloorRules.make(content.dungeon, normal, null, depth)
					var stats := rules.scale_monster(monster.stats, false)
					var raw := maxi(1, roundi(((monster.weapon.damage if monster.weapon else 1) + stats.attack) * rules.monster_damage()))
					total += 1
					if raw * (1.0 + Combat.DAMAGE_VARIANCE) - armor <= 1.0:
						floor_hits += 1
			player.free()
			var share := floor_hits / maxf(total, 1.0)
			rows.append([act, build.name, armor, total, floor_hits, BalanceReport.pct(share)])
			if share > targets.min_damage_share_max:
				report.flag(BalanceReport.WARN, "compound: armor", "%s (act %d, armor %d)" % [build.name, act, armor], BalanceReport.pct(share),
					"<= %s" % BalanceReport.pct(targets.min_damage_share_max), "of the act's monsters (each depth) hit it for 1 at most")
	report.table("compound_armor", "Compound checks", "Armor vs many weak hits: share of the act's monsters (every depth, Normal) whose best hit is brought down to 1 by each build's armor (Combat.mitigate)",
		PackedStringArray(["Act", "Build", "Armor", "Monster x depth", "Hit for 1", "Share"]), rows)


## Healing vs the shared budget: lifesteal stacks, with and without SustainRules, in a room of
## monsters that don't fight back (the hero held at half health, so every heal shows) and on the
## act's boss as a dummy (the hero held at 45% for its second half). The boss dummy is not a
## real boss fight (no arena): its budget refills at the normal rate; the boss-fight rate
## (SustainRules.boss_fight_rate) is shown next to it.
func _sustain(report: BalanceReport) -> void:
	var rows: Array = []
	for act in acts:
		var expected := BalanceBuild.expected(all_builds, act)
		if expected == null:
			continue
		var depth := BalanceContent.boss_depth(content, act) - 1
		var normal := BalanceContent.difficulty(content, "normal")
		var s := _session(act)
		var boss := content.dungeon.acts[act - 1].boss
		var scale := await _scale(s, expected, boss)
		var foes := lab.roll_room(act, depth, lab.room_size(depth, normal) + 6, seed_value * 13 + act)
		# The expected build without any sustain of its own: each stack alone on it.
		var bare := _without_sustain(expected)
		var stacks := [
			["no sustain (the expected build without its own)", [], false],
			["one Leech rune", [["rune", "leech_rune"]], true],
			["Vampirism 3", [["perk", "vampirism"]], true],
			["Fury rune", [["rune", "fury_rune"]], true],
			["three Leech runes", [["rune", "leech_rune"], ["rune", "leech_rune"], ["rune", "leech_rune"]], false],
			["3 Leech + Vampirism 3 + Blood + Fury + Vampiric", [["rune", "leech_rune"], ["rune", "leech_rune"], ["rune", "leech_rune"], ["perk", "vampirism"], ["family", "blood"], ["rune", "fury_rune"], ["affix", "vampiric"]], false],
		]
		var rules := content.dungeon.sustain
		for stack: Array in stacks:
			var build := bare
			for pick: Array in stack[1]:
				var next := BalanceBuild.variant(build, content, pick[0], pick[1], 99 if pick[0] == "perk" else 1)
				if next:
					build = next
			var room: Dictionary = await lab.dummy_pack(s, build, foes, 0.5, 40.0, seed_value)
			var duel: Dictionary = await lab.dummy(s, build, boss, scale, 40.0, seed_value)
			content.dungeon.sustain = null
			var room_free: Dictionary = await lab.dummy_pack(s, build, foes, 0.5, 40.0, seed_value)
			var duel_free: Dictionary = await lab.dummy(s, build, boss, scale, 40.0, seed_value)
			content.dungeon.sustain = rules
			var max_hp := BalanceBuild.make_player(build, content)
			var hp := max_hp.get_max_hp()
			max_hp.free()
			var room_capped := _sustain_healing(room.heal_sources)
			var room_asked := _sustain_healing(room_free.heal_sources)
			var duel_capped := _sustain_healing(duel.heal_sources) / maxf(float(duel.time) * 0.5, 0.01)
			var duel_asked := _sustain_healing(duel_free.heal_sources) / maxf(float(duel_free.time) * 0.5, 0.01)
			var room_cut := 1.0 - room_capped / room_asked if room_asked > 0.01 else 0.0
			var duel_cut := 1.0 - duel_capped / duel_asked if duel_asked > 0.01 else 0.0
			var boss_rate := rules.refill_per_second(hp, true) if rules else INF
			rows.append([act, stack[0], hp, foes.size(), room.clear_time, room_asked, room_capped, BalanceReport.pct(room_cut), duel_asked, duel_capped, BalanceReport.pct(duel_cut),
				boss_rate, BalanceReport.pct(minf(duel_asked, boss_rate) / maxf(duel_asked, 0.01)) if duel_asked > 0.01 else "-",
				BalanceLab.sources_text(room_free.heal_sources)])
			if stack[2] and room_cut > targets.single_source_cut_max:
				report.flag(BalanceReport.WARN, "compound: sustain cap", "%s (act %d, a room)" % [stack[0], act], "%s cut" % BalanceReport.pct(room_cut),
					"<= %s" % BalanceReport.pct(targets.single_source_cut_max), "a single sustain source should not hit the shared budget against packs")
		await lab.close(s)
		if verbose:
			print("  compound: sustain act %d done" % act)
	report.table("compound_sustain", "Compound checks", "Healing vs the sustain cap (engine): lifesteal stacks on the expected build, Health/s asked (budget off) and paid (budget on), in a room of monsters that don't fight back (hero at half health) and on the act's boss as a dummy (hero at 45%); last columns: the budget's boss-fight refill rate and the share of the asked healing it would pay",
		PackedStringArray(["Act", "Stack", "Max HP", "Room: monsters", "Room: clear s", "Room: asked (Health)", "Room: paid", "Room: cut", "Boss: asked /s", "Boss: paid /s", "Boss: cut", "Boss-fight rate /s", "Boss fight pays", "Sources (no cap)"]), rows)


## `build` without its sustain: perks, runes and affixes with a heal from hits, kills or skills
## removed, families with one kept asleep.
func _without_sustain(build: BalanceBuildDef) -> BalanceBuildDef:
	var result := BalanceBuild.variant(build, content, "buff", "", 0, StatBlock.new())  # a copy
	result.buffs.clear()
	for id: Variant in build.perks.keys():
		var p := BalanceContent.perk(String(id))
		if p and p.passives.any(_is_sustain):
			result.perks.erase(id)
	var kept_runes := PackedStringArray()
	for id in build.runes:
		var r := BalanceBuild.rune(content, id)
		if r == null or not r.passives.any(_is_sustain):
			kept_runes.append(id)
	result.runes = kept_runes
	var kept_affixes := PackedStringArray()
	for id in build.weapon_affixes:
		var a := BalanceBuild.affix(content, id)
		if a == null or not a.passives.any(_is_sustain):
			kept_affixes.append(id)
	result.weapon_affixes = kept_affixes
	for synergy in content.synergies:
		if synergy.passives.any(_is_sustain):
			result.suppress_families.append(synergy)
	return result


static func _is_sustain(passive: Passive) -> bool:
	return passive is LifestealPassive or passive is HealOnKillPassive or passive is BloodlustPassive or passive is HealOnSkillPassive


## Healing from hits, kills and skills (not potions or other).
static func _sustain_healing(sources: Dictionary) -> float:
	var total := 0.0
	for k: String in sources:
		if k.begins_with("perk:") or k.begins_with("rune:") or k.begins_with("affix:") or k.begins_with("family:"):
			total += float(sources[k])
	return total
