class_name WeaponDef
extends EquipmentDef
## A weapon. Used by the player and by monsters alike.
## Melee weapons hit everything in an arc; ranged weapons fire projectiles.

enum Kind { MELEE, RANGED }

@export var kind: Kind = Kind.MELEE
@export var damage: int = 4
## Seconds between two attacks.
@export var cooldown: float = 0.45
## Melee: reach beyond the body. Ranged: max projectile travel distance.
@export var reach: float = 36.0
@export var knockback: float = 140.0

@export_group("Melee")
@export_range(10.0, 360.0) var arc_degrees: float = 110.0

@export_group("Ranged")
@export var projectile_speed: float = 460.0
@export var projectile_radius: float = 5.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
## How many extra enemies a projectile can pass through.
@export var pierce: int = 0


func _init() -> void:
	slot = Slot.WEAPON


func get_type_label() -> String:
	return "Melee weapon" if kind == Kind.MELEE else "Ranged weapon"


func get_details() -> String:
	var text := "%d damage, %.1f hits/s" % [damage, 1.0 / maxf(cooldown, 0.01)]
	if kind == Kind.RANGED and projectile_count > 1:
		text += ", %d projectiles" % projectile_count
	if kind == Kind.RANGED and pierce > 0:
		text += ", pierces %d" % pierce
	var base := super.get_details()
	return text + ("\n" + base if not base.is_empty() else "")
