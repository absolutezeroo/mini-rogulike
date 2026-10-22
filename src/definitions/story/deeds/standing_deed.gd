class_name StandingDeed
extends DeedCondition
## The warden fell to a hero who met it standing: at most `max_rolls` rolls (the hero's innate
## skill) during the fight. A master who taught every way to step aside waits to see his pupil
## hold his guard (Tôma).

@export_range(0, 20) var max_rolls: int = 0


func achieved(kill: Dictionary) -> bool:
	return float(kill.get("fight_time", -1.0)) >= 0.0 and int(kill.get("rolls_in_fight", max_rolls + 1)) <= max_rolls
