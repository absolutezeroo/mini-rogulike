class_name ChargedAttackDef
extends Resource
## A weapon's charged attack: hold the attack button past the hero's `charge_delay` (a tap
## never charges), the charge fills over `charge_time`, and letting go when it is full unleashes
## these effects (the ones skills use: a great crescent, a ground slam, a heavy arrow, a big
## shot that bursts...). Only the hero charges; monsters ignore it. One file per weapon in
## data/skills/charged/, named in the weapon's `charged` (docs/design/builds.md).
##
## Its damage goes through the effects, like a skill's: `user.get_skill_power()` x their
## multipliers (the weapon's damage + Attack, raised by skill power). A basic hit is the
## wielder's power (x `projectile_damage` for a shot): the multipliers are set to about 2.2-3
## times that, the price being the charge and moving slower meanwhile. It is no skill: no
## cooldown, no "on skill" perk (Echo, Devotion, the Arcane ring).

@export var id: StringName
@export var display_name: String
## What it does, in plain words (the weapon's card: "Hold: <name>. <description>").
@export_multiline var description: String
## Seconds of holding (after the hero's charge delay) until it is full.
@export_range(0.2, 3.0, 0.05) var charge_time: float = 0.9
## Move speed while charging, as a share of the normal one.
@export_range(0.1, 1.0, 0.05) var move_speed_scale: float = 0.55
## What happens on release, in order (each after its own delay).
@export var effects: Array[Effect] = []
## Played on release (the weapon's attack sound when empty).
@export var sound: AudioStream
## The charge's colors (the gauge, the glow in the hand): its ramp. The weapon's element when
## empty, steel (`physical`) for a plain blade.
@export var element: VfxElementDef


## The element the charge glows in for `weapon`.
func element_for(weapon: WeaponDef) -> VfxElementDef:
	if element:
		return element
	if weapon and weapon.element:
		return weapon.element
	return VfxElementDef.named(&"physical")


## Unleashed: its sound and its effects toward `aim`.
func release(user: Actor, weapon: WeaponDef, aim: Vector2) -> void:
	var played := sound if sound else (weapon.attack_sound if weapon else null)
	Sfx.play_at(played, user.global_position)
	Effect.apply_all(effects, user, aim)


## The weapon card's line: "Hold: Moonless Cut. A wide double crescent in front of you."
func describe() -> String:
	return tr("Hold: {name}. {text}").format({ "name": tr(display_name), "text": tr(description) })
