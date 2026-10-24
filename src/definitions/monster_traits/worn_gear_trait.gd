class_name WornGearTrait
extends MonsterTrait
## Wears armor as the hero does (the Nameless Keeper: the pieces his hero wore, NamelessKeeperDef):
## their bonuses count in its stats, their layers show on its body (ActorRig.wear(), with
## MonsterDef.shows_gear), and the affixes and runes of everything it wears (its weapon's too)
## work as they do on the hero (PerkSet.set_gear()). It starts whole, its armor's health counted.

@export var pieces: Array[EquipmentDef] = []


func on_spawn(monster: Monster) -> void:
	for piece in pieces:
		if piece and not piece is WeaponDef:
			monster.equipment.equip(piece)
	monster.perks.set_gear(monster.equipment.affixes(), monster.equipment.runes())
	monster.invalidate_stats()
	monster.hp = monster.get_max_hp()
