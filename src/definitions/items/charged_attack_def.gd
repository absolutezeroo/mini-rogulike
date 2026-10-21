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


## Its effects dressed in what the weapon carries, per pair of elements (`dressed`).
var _dressed := {}


## The element the charge glows in for `weapon`: what the weapon carries first (its own
## element, a rune's: ItemLook), else this attack's own, else steel (`physical`).
func element_for(weapon: WeaponDef) -> VfxElementDef:
	var carried := ItemLook.swing_element(weapon, true)
	if carried:
		return carried
	if element:
		return element
	return VfxElementDef.named(&"physical")


## Unleashed: its sound and its effects toward `aim`, in what the weapon carries (`dressed`).
func release(user: Actor, weapon: WeaponDef, aim: Vector2) -> void:
	var played := sound if sound else (weapon.attack_sound if weapon else null)
	Sfx.play_at(played, user.global_position)
	Effect.apply_all(dressed(weapon), user, aim)


## Its effects in what `weapon` carries (docs/vfx.md, "Elemental attacks"): a plain weapon's are
## as written; a weapon carrying an element (its own, a rune's, an affix's: ItemLook) gathers it
## into the blow, which is drawn and lands in it (a fire katana's crescent burns, a frost bow's
## heavy arrow flies in rime): the first element the weapon carries replaces the effect's, and
## the effect's own (the hammer's earth, the Templar's holy) or the weapon's second adds its
## bits. Copies, made once per pair of elements (the data stays as written).
func dressed(weapon: WeaponDef) -> Array[Effect]:
	var first := ItemLook.swing_element(weapon, true)
	if first == null:
		return effects
	var second := ItemLook.second_element(weapon, true)
	var key := [first, second]
	if not _dressed.has(key):
		var copies: Array[Effect] = []
		for effect in effects:
			copies.append(ChargedAttackDef._dress(effect, first, second))
		_dressed[key] = copies
	return _dressed[key]


## The weapon card's line: "Hold: Moonless Cut. A wide double crescent in front of you."
func describe() -> String:
	return tr("Hold: {name}. {text}").format({ "name": tr(display_name), "text": tr(description) })


static func _dress(effect: Effect, first: VfxElementDef, second: VfxElementDef) -> Effect:
	if effect == null:
		return null
	var copy := effect.duplicate() as Effect
	if copy is ProjectileEffect:
		var shot := copy as ProjectileEffect
		if shot.element == null:
			# A thing (the heavy arrow, the stars) flies in the element without being made of it.
			shot.look_element = first
			shot.second_element = second
		else:
			# A magic shot stays itself (the Frost Staff's shard); another element adds its bits.
			shot.second_element = second if second else (first if shot.element != first else null)
		return copy
	if not (&"element" in copy):
		return copy
	var own := copy.get(&"element") as VfxElementDef
	copy.set(&"element", first)
	if &"second_element" in copy:
		copy.set(&"second_element", second if second else (own if own != first else null))
	return copy
