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
		return "Seen" if rank == SEEN else "Unknown"
	return rules.rank_names[mini(rank, rules.rank_count()) - 1]


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
