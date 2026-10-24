class_name HitFeedback
extends RefCounted
## What a blow taken shows and sounds like (Actor.take_hit()): the sparks off the body in the
## hit's element and the body's material, the cry and the material's knock (direct hits only:
## a burn's tick or a blast's splash stays quiet), and the damage number over the head. The
## Actor says what it is made of and how it cries (its hooks); this plays it.

const HIT_TEXT_COLOR := Color("ffffff")
const CRIT_TEXT_COLOR := Palette.GOLD
const SECONDARY_TEXT_COLOR := Color("ffb26b")


## `actor` took `hit` for `damage`: `spark` its sparks' color, `cry` its hurt sound, `impact`
## what its body is made of (null: nothing particular).
static func play(actor: Actor, hit: HitInfo, damage: int, spark: Color, cry: AudioStream, impact: ImpactMaterialDef) -> void:
	var world := actor.world
	if not hit.is_secondary:
		var spark_direction := hit.knockback.normalized() if hit.knockback != Vector2.ZERO else Vector2.UP
		Vfx.hit(world, actor.global_position + Vector2(0, -actor.radius * 0.5), spark_direction, spark, hit.is_crit, hit.element, impact)
		Sfx.play_at(cry, actor.global_position)
		if impact and impact.sound:
			Sfx.play_at(impact.sound, actor.global_position, impact.volume_db)
	world.spawn_floating_text(actor.head_position(), str(damage) + ("!" if hit.is_crit else ""), text_color(hit))


## The damage number's color: the hit's own, else pale orange for a secondary hit, gold for a
## crit, white otherwise.
static func text_color(hit: HitInfo) -> Color:
	if hit.text_color.a > 0.0:
		return hit.text_color
	if hit.is_secondary:
		return SECONDARY_TEXT_COLOR
	return CRIT_TEXT_COLOR if hit.is_crit else HIT_TEXT_COLOR


## A body's sparks: gold on a crit, else its material's (white for none).
static func spark_color(hit: HitInfo, impact: ImpactMaterialDef) -> Color:
	if hit.is_crit:
		return CRIT_TEXT_COLOR
	return impact.spark_color if impact else Color.WHITE
