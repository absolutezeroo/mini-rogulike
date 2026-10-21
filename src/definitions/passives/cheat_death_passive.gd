class_name CheatDeathPassive
extends Passive
## A second life, once per stack for the whole run (the Phoenix Feather, Death Denied's feather).
## The killing blow sends the hero to the trial of the Threshold (`trial`, run by `Threshold`):
## won, he comes back where he fell with `heal_ratio` of his max Health and a blast around him;
## lost, he dies. A hit taken inside the trial is the trial's to judge (no second feather there).
## Where there is no Threshold (a bare World: the balance tools' arena), he is healed in place.

@export_range(0.0, 1.0) var heal_ratio: float = 0.5
## The share of max Health it brings back during a boss fight instead (a second life, not a
## second full fight: two feathers must not carry a hero who only stands and hits).
@export_range(0.0, 1.0) var boss_fight_heal_ratio: float = 0.5
@export var color: Color = Palette.GOLD
## The trial the killing blow opens (null: healed in place, no trial).
@export var trial: ThresholdDef


func prevent_death(owner: Actor, perk: PerkSet.Entry) -> bool:
	var threshold := Threshold.of(owner)
	if threshold and threshold.is_open():
		return threshold.absorb_death(owner)
	var used: int = perk.memory.get(&"used", 0)
	if used >= perk.stacks:
		return false
	perk.memory[&"used"] = used + 1
	if trial and threshold and threshold.can_host(owner):
		threshold.open(owner as Player, trial, come_back.bind(owner, perk))
		return true
	come_back(owner, perk)
	return true


## Back to life: Health as the rules say (less in a boss fight), and a blast to clear some room.
func come_back(owner: Actor, perk: PerkSet.Entry) -> void:
	var ratio := boss_fight_heal_ratio if owner.world and owner.world.is_boss_fight() else heal_ratio
	owner.hp = maxi(1, roundi(owner.get_max_hp() * ratio))
	owner.health_changed.emit(owner.hp, owner.get_max_hp())
	owner.world.spawn_floating_text(owner.head_position(), tr(perk.perk.display_name).to_upper(), color)
	Vfx.magic(owner.world, owner.global_position, color)
	Combat.damage_area(owner.world, owner, owner.global_position, 110.0, owner.get_power(), 320.0, true)
