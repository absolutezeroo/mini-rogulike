class_name ItemLevelRules
extends Resource
## Item level: equipment is as strong as the floor it was found on (or bought on), and never grows
## after that. A weapon from floor 1 is weaker than one from floor 2: to get stronger, loot.
## Rarity (ItemRarity) and affixes come on top of it.
##
## Weapons: every level above 1 adds the same damage PER SECOND to any weapon (so a slow hammer
## gets more per hit than a quick rapier, and the weapons stay as even as at level 1).
## Armor: every level above 1 adds Health.
## Monsters grow with depth at the same pace (DungeonConfig > Difficulty), so a hero who keeps
## his first sword falls behind.

## Damage per second added to a weapon per level above 1.
@export var weapon_dps_per_level: float = 2.0
## Health added to a body armor per level above 1.
@export var body_health_per_level: float = 1.5
## Health added to a head armor per level above 1.
@export var head_health_per_level: float = 1.0


## Extra damage per hit of `weapon` (the plain item) at `level`.
func weapon_damage(weapon: WeaponDef, level: int) -> int:
	if level <= 1 or weapon == null:
		return 0
	# Shots that hit for a share of the power (fans, bows) get more, so the second gain stays the same.
	var share := 1.0
	if weapon.kind == WeaponDef.Kind.RANGED:
		share = maxf(weapon.projectile_damage * maxi(weapon.projectile_count, 1), 0.1)
	return roundi(weapon_dps_per_level * weapon.cooldown * (level - 1) / share)


## Extra Health of an armor in `slot` at `level`.
func armor_health(slot: EquipmentDef.Slot, level: int) -> int:
	if level <= 1:
		return 0
	var per_level := body_health_per_level if slot == EquipmentDef.Slot.BODY else head_health_per_level
	return roundi(per_level * (level - 1))
