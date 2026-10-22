class_name UnhealedDeed
extends DeedCondition
## The hero's wounds were never mended during the fight (no potion, no life drawn from blows,
## no heal of any kind): the warden met as the pyres meet what they burn.


func achieved(kill: Dictionary) -> bool:
	return float(kill.get("fight_time", -1.0)) >= 0.0 and int(kill.get("healed_in_fight", 0)) == 0
