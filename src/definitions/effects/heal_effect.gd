class_name HealEffect
extends Effect
## Restores health to the user.
## Its `element` (Effect.element): whose light it is (Holy Light, Smite: holy): its sigil on the
## ground is drawn in the element's ramp instead of the plain green of a heal.

@export var amount: int = 20
## Extra healing as a fraction of max HP.
@export_range(0.0, 1.0) var max_hp_ratio: float = 0.0
## Share of the heal paid during a boss fight (World.is_boss_fight): healing spells forgive
## mistakes, they must not out-heal a boss when cast on cooldown (Holy Shield and Smite carried
## builds that never dodged through act IV bosses). 1 = the same everywhere.
@export_range(0.0, 1.0) var boss_fight_ratio: float = 1.0


## What a cast heals now.
func heal_amount(user: Actor) -> int:
	var total := amount + roundi(user.get_max_hp() * max_hp_ratio)
	if boss_fight_ratio < 1.0 and user.world and user.world.is_boss_fight():
		total = roundi(total * boss_fight_ratio)
	return total


func apply(user: Actor, _aim: Vector2) -> void:
	var healed := user.heal(heal_amount(user))
	if healed > 0:
		user.world.spawn_floating_text(user.head_position(), "+%d" % healed, Palette.HEAL)
	Vfx.magic(user.world, user.global_position, Palette.HEAL, element)


func play_preview(preview: EffectPreview) -> void:
	preview.ring(0.0, preview.caster_radius() + 22.0, Palette.HEAL, false)
