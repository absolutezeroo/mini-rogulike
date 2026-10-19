class_name BestiaryRules
extends Resource
## The bestiary's hunter ranks: slaying enough of a kind of monster raises your rank with it
## (Known, Hunted, Mastered), each rank paying souls once. Mastered: you deal more damage to
## that kind for good. Bosses need fewer kills and pay more. See Bestiary.

## Rank names, from the first.
@export var rank_names: PackedStringArray = ["Known", "Hunted", "Mastered"]
## Kills for each rank (the first one: the first kill, which also reveals the monster's page).
@export var monster_kills: PackedInt32Array = [1, 10, 30]
@export var boss_kills: PackedInt32Array = [1, 3, 6]
## Souls paid when a rank is reached.
@export var monster_souls: PackedInt32Array = [10, 25, 60]
@export var boss_souls: PackedInt32Array = [40, 80, 150]
## Extra damage against a mastered kind (0.1 = +10%).
@export var mastery_damage: float = 0.1
## Challenges every monster gets (those that make sense for it, see HuntChallenge.applies_to)...
@export var monster_challenges: Array[HuntChallenge] = []
## ...and every boss.
@export var boss_challenges: Array[HuntChallenge] = []


func kills_for(monster: MonsterDef) -> PackedInt32Array:
	return boss_kills if monster is BossDef else monster_kills


func souls_for(monster: MonsterDef) -> PackedInt32Array:
	return boss_souls if monster is BossDef else monster_souls


## The challenges of this kind: the common ones that apply, then its own.
func challenges_for(monster: MonsterDef) -> Array[HuntChallenge]:
	var result: Array[HuntChallenge] = []
	for challenge in (boss_challenges if monster is BossDef else monster_challenges):
		if challenge and challenge.applies_to(monster):
			result.append(challenge)
	for challenge in monster.challenges:
		if challenge:
			result.append(challenge)
	return result


func rank_count() -> int:
	return rank_names.size()
