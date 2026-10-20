class_name HuntChallenge
extends Resource
## A bestiary challenge: slay a kind of monster in a particular way (an elite one, pushed into a
## hole, with a bow, without a potion...). Done once per kind, paid in souls. The bestiary rules
## hold the challenges every monster (or every boss) gets; a monster can add its own
## (MonsterDef.challenges: "slay the King Slime with the Templar Sword"). See HuntTracker.

enum Goal {
	## An elite of this kind.
	ELITE,
	## Pushed (or knocked) into a hole by the hero. Never for flying kinds.
	PIT,
	## `count` of this kind within `seconds`.
	STREAK,
	## The hero not hurt since this one spotted them.
	UNTOUCHED,
	## Finished by a critical hit.
	CRIT,
	## Slain while holding a ranged weapon.
	RANGED,
	## Slain while holding a melee weapon.
	MELEE,
	## Bosses: the fight won within `seconds`.
	FAST,
	## Bosses: no potion (or other consumable) used during the fight.
	NO_POTION,
	## Bosses: less than `ratio` of the hero's max HP lost during the fight.
	HEALTHY,
	## Slain while holding `weapon` (any rarity of it).
	WEAPON,
}

@export var id: StringName
@export var goal: Goal = Goal.ELITE
## Shown in the bestiary; "{monster}" becomes the monster's name. Empty: a default text.
@export var text: String = ""
@export var souls: int = 20
@export_group("Goal")
@export var count: int = 3
@export var seconds: float = 5.0
@export_range(0.0, 1.0) var ratio: float = 0.25
@export var weapon: WeaponDef


## Makes sense for this kind (no hole for flyers, boss goals for bosses only).
func applies_to(monster: MonsterDef) -> bool:
	match goal:
		Goal.PIT:
			return not monster.flies and not monster is BossDef
		Goal.FAST, Goal.NO_POTION, Goal.HEALTHY:
			return monster is BossDef
		Goal.ELITE, Goal.STREAK:
			return not monster is BossDef
	return true


func describe(monster: MonsterDef) -> String:
	var name := monster.display_name
	if not text.is_empty():
		return text.replace("{monster}", name)
	match goal:
		Goal.ELITE:
			return "Slay an elite %s" % name
		Goal.PIT:
			return "Push a %s into a hole" % name
		Goal.STREAK:
			return "Slay %d %s within %d seconds" % [count, name, roundi(seconds)]
		Goal.UNTOUCHED:
			return "Slay a %s without being hurt once it has seen you" % name
		Goal.CRIT:
			return "Finish a %s with a critical hit (a lucky hit for extra damage)" % name
		Goal.RANGED:
			return "Slay %s with a ranged weapon" % name
		Goal.MELEE:
			return "Slay %s with a melee weapon" % name
		Goal.FAST:
			return "Slay %s within %d seconds of the fight's start" % [name, roundi(seconds)]
		Goal.NO_POTION:
			return "Slay %s without drinking a potion during the fight" % name
		Goal.HEALTHY:
			return "Slay %s losing less than %d%% of your Health" % [name, roundi(ratio * 100.0)]
		Goal.WEAPON:
			return "Slay %s with the %s" % [name, weapon.display_name if weapon else "?"]
	return name


## The kill described by `kill` (see HuntTracker.kill_context()) meets the goal.
func met(kill: Dictionary) -> bool:
	match goal:
		Goal.ELITE:
			return kill.elite
		Goal.PIT:
			return kill.pushed_in
		Goal.STREAK:
			var recent: Array = kill.kill_times.filter(func(t: float) -> bool: return t >= kill.now - seconds)
			return recent.size() >= count
		Goal.UNTOUCHED:
			return kill.untouched
		Goal.CRIT:
			return kill.crit
		Goal.RANGED:
			return kill.weapon != null and (kill.weapon as WeaponDef).kind == WeaponDef.Kind.RANGED
		Goal.MELEE:
			return kill.weapon != null and (kill.weapon as WeaponDef).kind == WeaponDef.Kind.MELEE
		Goal.FAST:
			return kill.fight_time >= 0.0 and kill.fight_time <= seconds
		Goal.NO_POTION:
			return kill.fight_time >= 0.0 and kill.potions_in_fight == 0
		Goal.HEALTHY:
			return kill.fight_time >= 0.0 and kill.hp_lost_in_fight < ratio
		Goal.WEAPON:
			return weapon != null and kill.weapon_base == weapon
	return false
