class_name ChallengeDeed
extends DeedCondition
## A deed that is a bestiary challenge's way of killing (HuntChallenge: with a given weapon,
## untouched, without a potion, fast, losing little Health...), reused as it is. Done when the
## warden falls that way, or already done as the bestiary challenge of the same id (a save from
## before the chronicles keeps it).

@export var challenge: HuntChallenge


func is_met(subject: Resource = null) -> bool:
	if super(subject):
		return true
	return challenge != null and subject is MonsterDef and Profile.is_challenge_done((subject as MonsterDef).id, challenge.id)


func achieved(kill: Dictionary) -> bool:
	return challenge != null and challenge.met(kill)
