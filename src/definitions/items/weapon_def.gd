class_name WeaponDef
extends EquipmentDef
## A weapon. Used by the player and by monsters alike.
## Melee weapons hit everything in an arc; ranged weapons fire projectiles.

enum Kind { MELEE, RANGED }
## Which attack animation the wielder plays (see the WeaponAnimator in actor_rig.tscn).
## A weapon without icon (claws, bites) makes the wielder lunge instead.
enum AttackAnimation { SLASH, THRUST, SMASH, SHOOT }

@export var kind: Kind = Kind.MELEE
@export var damage: int = 4
## Seconds between two attacks.
@export var cooldown: float = 0.45
## Melee: reach beyond the body. Ranged: max projectile travel distance.
@export var reach: float = 36.0
@export var knockback: float = 140.0
@export var attack_animation: AttackAnimation = AttackAnimation.SLASH
## Weapon in hand during the attack: attack_down/up/left/right, frame by frame with the hero's attack.
@export var attack_frames: SpriteFrames
## Slash effect sheet (frames in a row) played in front of the wielder, rotated toward the target.
@export var attack_fx: Texture2D
## Extra rotation of the slash effect, in degrees (depends on how the sheet is drawn).
@export var attack_fx_rotation: float = 0.0

## Skills you get while holding this weapon (2 at most): a staff makes you a mage,
## an axe a warrior... Monsters ignore them (their skills are in their MonsterDef).
@export var skills: Array[SkillDef] = []

## Statuses left on whatever this weapon hits (poison fangs, burning claws...).
@export var on_hit: OnHitStatus

@export_group("Melee")
@export_range(10.0, 360.0) var arc_degrees: float = 110.0

@export_group("Sounds")
@export var attack_sound: AudioStream
## Played on the target when this weapon hits (monsters fall back to their own hurt sound).
@export var hit_sound: AudioStream

@export_group("Ranged")
@export var projectile_texture: Texture2D
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
	if not skills.is_empty():
		var names := PackedStringArray()
		for skill in skills:
			names.append(skill.display_name)
		text += "\nSkills: " + ", ".join(names)
	var base := super.get_details()
	return text + ("\n" + base if not base.is_empty() else "")
