class_name Bestiary
## What the hero knows of each kind of monster (Profile: seen, kills, ranks paid) and the
## hunter ranks it earns (BestiaryRules): unknown, seen (met, never slain), then ranks 1..3.

## Never met.
const UNSEEN := -1
## Met but never slain: the page shows its name and look, nothing else.
const SEEN := 0


## -1 unseen, 0 seen, 1.. the hunter rank (kills reached).
static func rank_of(monster: MonsterDef, rules: BestiaryRules) -> int:
	var kills := Profile.kill_count(monster.id)
	var rank := 0
	for needed in rules.kills_for(monster):
		if kills >= needed:
			rank += 1
	if rank == 0 and not Profile.has_seen(monster.id):
		return UNSEEN
	return rank


## Kills needed for the next rank (0 when mastered).
static func next_kills(monster: MonsterDef, rules: BestiaryRules) -> int:
	var rank := maxi(rank_of(monster, rules), 0)
	var thresholds := rules.kills_for(monster)
	return thresholds[rank] if rank < thresholds.size() else 0


static func rank_name(rank: int, rules: BestiaryRules) -> String:
	if rank <= SEEN:
		return TranslationServer.tr("Seen") if rank == SEEN else TranslationServer.tr("Unknown")
	return TranslationServer.tr(rules.rank_names[mini(rank, rules.rank_count()) - 1])


static func is_mastered(monster: MonsterDef, rules: BestiaryRules) -> bool:
	return rules != null and rank_of(monster, rules) >= rules.rank_count()


## Damage multiplier for the hero's hits on this kind (mastered: a bit more).
static func damage_multiplier(monster: MonsterDef, rules: BestiaryRules) -> float:
	return 1.0 + rules.mastery_damage if is_mastered(monster, rules) else 1.0


## Pays the ranks reached and not paid yet. Returns [{ rank, souls }] for each new one.
static func claim(monster: MonsterDef, rules: BestiaryRules) -> Array[Dictionary]:
	var reached := maxi(rank_of(monster, rules), 0)
	var paid := Profile.bestiary_rank(monster.id)
	var result: Array[Dictionary] = []
	var souls := rules.souls_for(monster)
	for rank in range(paid + 1, reached + 1):
		var reward: int = souls[rank - 1] if rank - 1 < souls.size() else 0
		result.append({ "rank": rank, "souls": reward })
		Profile.pay_bestiary_rank(monster.id, rank, reward)
	return result


## Whether a `monster` of this kind can ever come at the Celestial rank (the rare rank with
## `shimmer`), by the rules that roll the rare ranks: a floor's own monsters (an act's or the
## hidden floor's, with a spawn weight: World.roll_elite()) and a warden that starts its fight
## alone and as it varies (BossDef.rolls_rank(): World.roll_boss_rank()), with a chance above
## zero. Never the Deeps' demons and their warden (plain elites at most), a fight's later form
## (the Maw, risen from Tôma), a fight of several forms (Tôma) nor one as written (the Nameless
## Keeper). The bestiary lists no Celestial for those.
static func can_be_celestial(monster: MonsterDef, content: ContentDB) -> bool:
	if monster == null or content == null or content.dungeon == null:
		return false
	var celestial: MonsterRankDef = null
	for rank in content.dungeon.rare_ranks:
		if rank and rank.shimmer:
			celestial = rank
			break
	if celestial == null:
		return false
	var dungeon := content.dungeon
	var hidden_def := dungeon.hidden_floor
	var boss := monster as BossDef
	if boss:
		if celestial.boss_chance <= 0.0 or not boss.rolls_rank():
			return false
		for act in dungeon.acts:
			if act and act.all_bosses().has(boss):
				return true
		return (hidden_def != null and hidden_def.boss == boss) or (dungeon.finale != null and dungeon.finale.boss == boss)
	if (celestial.chance <= 0.0 and celestial.chance_per_depth <= 0.0) or monster.spawn_weight <= 0:
		return false
	for act in dungeon.acts:
		if act and act.monsters.has(monster):
			return true
	return hidden_def != null and hidden_def.monsters.has(monster)
