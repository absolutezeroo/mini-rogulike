class_name Actor
extends CharacterBody2D
## Base class for everything that moves and fights: the player and monsters.
## Handles stats, health, attacking, knockback, dashing, perks, statuses and hit feedback.
## Subclasses decide where to go (_get_desired_velocity) and what to do (_think).
## How it looks is the job of the ActorRig child ("Rig"): this script only tells it what happens.

signal health_changed(current: int, maximum: int)
signal stats_changed
signal died(actor: Actor)
## HP actually restored by heal(), and who did it (see heal_source). Nothing in the game listens:
## it is a measuring hook for the balance tools (tools/balance/), so they can tell a Leech rune's
## healing from Vampirism's or a potion's. Changes nothing.
signal healed(amount: int, source: StringName)

## What is healing right now ("perk:vampirism", "rune:leech_rune", "skill:smite", "item:health_potion"...),
## set for the length of a call by PerkSet, SkillSet and ConsumableDef; empty otherwise. Read only by
## heal() to fill the `healed` signal (balance tools). Never affects gameplay.
static var heal_source: StringName = &""

enum Faction { PLAYER, MONSTER }

const KNOCKBACK_FRICTION := 1400.0
const FLASH_TIME := 0.1
const HIT_TEXT_COLOR := Color("ffffff")
const CRIT_TEXT_COLOR := Palette.GOLD
const SECONDARY_TEXT_COLOR := Color("ffb26b")
## Pixel art is 16x16 and drawn at 2x.
const SPRITE_SCALE := 2.0
const AFTERIMAGE_INTERVAL := 0.03
## Seconds of falling into a hole before it counts.
const FALL_TIME := 0.5


## A stat bonus for a while (elixirs, war cries...).
class TimedBonus:
	var stats: StatBlock
	var time_left := 0.0

var faction: Faction = Faction.MONSTER
## Debug god mode (DebugPanel): nothing hurts.
var invincible := false
## Multiplies every heal (the Blood Pact node: more Health, weaker heals).
var healing_scale := 1.0
## Added to the critical hit multiplier (an oath: Combat.make_hit()).
var crit_damage_bonus := 0.0
## How fast skill cooldowns run (a boss in a later phase: faster).
var cooldown_speed := 1.0
## The last hit taken (how it was finished: a crit...). Null before any.
var last_hit: HitInfo
## A ward (AllyEffect): damage soaked up before HP, for a while.
var ward := 0
var _ward_time := 0.0
var world: World
var display_name := "Actor"
## Animations of the body (see ActorRig). Without frames, a simple shape is drawn.
var frames: SpriteFrames
var frames_offset := Vector2(0, -8)
## Height of the sprite above the feet, in world pixels (damage numbers start there).
var head_height := 34.0
## Fallback drawing when there is no sprite.
var glyph := ""
var body_color := Color.WHITE
var radius := 12.0
## Monsters disappear when they die; the player stays on screen for the game over.
var free_on_death := true
## Flying actors (bats, ghosts...) don't fall into holes or wade in quicksand.
var flies := false
## Dropping into a hole (see fall()).
var is_falling := false
## Who hit this actor last: credited if it falls into a hole.
var last_attacker: Actor
## What killed it, for the run history ("Skeleton", "a fall"...). Empty while alive.
var killed_by := ""

var base_stats := StatBlock.new()
var equipment := Equipment.new()
var skills := SkillSet.new()
var perks := PerkSet.new()
var statuses := StatusSet.new()
## Draws the statuses on the body (StatusFx).
var status_fx: StatusFx
## Healing from "per hit" and "per kill" perks (see sustain_heal()).
var sustain := SustainMeter.new()
var hp := 1
var facing := Vector2.RIGHT
var is_dead := false

var _stats_cache: StatBlock
var _timed_bonuses: Array[TimedBonus] = []
var _attack_cooldown := 0.0
var _invulnerable_time := 0.0
var _knockback := Vector2.ZERO
var _dash_velocity := Vector2.ZERO
var _dash_time := 0.0
var _flash_time := 0.0
var _afterimage_timer := 0.0
## What the current dash is made of: its afterimages take its color (steel when null).
var _dash_element: VfxElementDef

## Visual body (sprite, hand, weapon, animations). Null for actors without sprite.
@onready var rig: ActorRig = get_node_or_null("Rig")


func _init() -> void:
	motion_mode = MOTION_MODE_FLOATING
	equipment.changed.connect(invalidate_stats)
	perks.changed.connect(invalidate_stats)


func _ready() -> void:
	# What its statuses look like (flames, bubbles, frost), drawn over the body.
	status_fx = StatusFx.new(self)
	add_child(status_fx)
	status_fx.visible = false
	status_fx.set_process(false)
	if rig == null:
		return
	rig.visible = frames != null
	rig.position = Vector2(0, _feet_y())
	rig.setup(frames, frames_offset)
	_refresh_look()
	equipment.changed.connect(_refresh_look)


## Weapon in hand and worn armor, from the equipment.
func _refresh_look() -> void:
	rig.set_weapon(get_weapon())
	for slot: EquipmentDef.Slot in [EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
		var armor := equipment.get_item(slot) as ArmorDef
		if armor and armor.wear_frames:
			rig.set_wear(slot, armor.wear_frames, armor.wear_color)
		else:
			rig.set_wear(slot, null, Color.WHITE)


# --- Stats -------------------------------------------------------------------

func get_stats() -> StatBlock:
	if _stats_cache == null:
		var total := base_stats.plus(equipment.total_bonuses()).plus(perks.total_bonuses())
		for bonus in _timed_bonuses:
			total = total.plus(bonus.stats)
		_stats_cache = total
	return _stats_cache


## Call whenever base stats, equipment or buffs change.
func invalidate_stats() -> void:
	_stats_cache = null
	hp = mini(hp, get_max_hp())
	stats_changed.emit()
	health_changed.emit(hp, get_max_hp())


func get_max_hp() -> int:
	return maxi(1, get_stats().max_hp)


## 0 = pushed by every hit, 1 = immovable (see MonsterDef.knockback_resistance).
func get_knockback_resistance() -> float:
	return 0.0


func get_move_speed() -> float:
	return maxf(get_stats().move_speed * statuses.speed_multiplier(), 20.0)


func get_weapon() -> WeaponDef:
	return equipment.get_item(EquipmentDef.Slot.WEAPON) as WeaponDef


## Base damage of skills: power boosted by skill power.
func get_skill_power() -> float:
	return get_power() * maxf(1.0 + get_stats().skill_power, 0.1)


## Seconds between two attacks with `weapon`, after attack speed bonuses.
func get_attack_cooldown(weapon: WeaponDef) -> float:
	return weapon.cooldown / maxf(1.0 + get_stats().attack_speed, 0.25)


## Base damage of this actor's attacks: weapon damage + attack stat.
func get_power() -> int:
	var weapon := get_weapon()
	return (weapon.damage if weapon else 1) + get_stats().attack


## The same bonus again (a second elixir, a war cry recast) refreshes it instead of stacking.
func add_timed_bonus(bonus: StatBlock, duration: float) -> void:
	for active in _timed_bonuses:
		if active.stats == bonus:
			active.time_left = maxf(active.time_left, duration)
			return
	var timed := TimedBonus.new()
	timed.stats = bonus
	timed.time_left = duration
	_timed_bonuses.append(timed)
	invalidate_stats()


func set_body_radius(value: float) -> void:
	radius = value
	var shape := CircleShape2D.new()
	shape.radius = value
	($CollisionShape2D as CollisionShape2D).shape = shape


func is_hostile_to(other: Actor) -> bool:
	return other != null and other.faction != faction


# --- Actions -----------------------------------------------------------------

func can_attack() -> bool:
	return not is_dead and not is_falling and _attack_cooldown <= 0.0 and get_weapon() != null


func attack(direction: Vector2) -> bool:
	if not can_attack():
		return false
	var weapon := get_weapon()
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	_attack_cooldown = get_attack_cooldown(weapon)
	Sfx.play_at(weapon.attack_sound, global_position)
	if rig:
		rig.play_attack(weapon, facing, _attack_cooldown)
	Vfx.swing(self, facing, weapon, minf(_attack_cooldown * 0.45, 0.15))
	if weapon.kind == WeaponDef.Kind.MELEE:
		Combat.melee_strike(self, facing, weapon)
	else:
		world.fire_projectiles(self, facing, Combat.spec_from_weapon(self, weapon))
	_on_attacked(weapon)
	return true


## After an attack goes out (the hero's camera recoils).
func _on_attacked(_weapon: WeaponDef) -> void:
	pass


func start_dash(dash_velocity: Vector2, duration: float, invulnerable: bool, element: VfxElementDef = null) -> void:
	_dash_velocity = dash_velocity
	_dash_time = duration
	_afterimage_timer = 0.0
	_dash_element = element
	Vfx.dust(world, global_position + Vector2(0, _feet_y()), 1.4)
	if invulnerable:
		_invulnerable_time = maxf(_invulnerable_time, duration + 0.05)
	perks.on_dash(self)


func is_dashing() -> bool:
	return _dash_time > 0.0


## Direction the actor is currently trying to move in (zero when standing still).
func get_move_direction() -> Vector2:
	return Vector2.ZERO


# --- Health ------------------------------------------------------------------

func take_hit(hit: HitInfo) -> void:
	if is_dead or invincible or (_invulnerable_time > 0.0 and not hit.unavoidable):
		return
	# Perks of the attacker can change the hit (direct hits only, see HitInfo.is_secondary).
	var attacker := hit.source if is_instance_valid(hit.source) and not hit.is_secondary else null
	if attacker:
		attacker.perks.modify_outgoing_hit(attacker, self, hit)
	last_hit = hit
	var damage := _incoming_damage(hit, Combat.mitigate(hit.amount, get_stats().defense))
	if ward > 0 and damage > 0:
		var soaked := mini(ward, damage)
		ward -= soaked
		damage -= soaked
		if ward <= 0:
			Vfx.pop(world, global_position + Vector2(0, -radius), VfxElementDef.named(&"spirit"), 16.0, Vector2.UP)  # it breaks
	hp = maxi(hp - damage, 0)
	_knockback += hit.knockback * (1.0 - get_knockback_resistance())
	_flash_time = FLASH_TIME
	if rig:
		rig.play_hurt()
	if not hit.is_secondary:
		var spark_direction := hit.knockback.normalized() if hit.knockback != Vector2.ZERO else Vector2.UP
		Vfx.hit(world, global_position + Vector2(0, -radius * 0.5), spark_direction, _hit_spark_color(hit), hit.is_crit, hit.element, _impact_material())
		Sfx.play_at(_hurt_sound(hit), global_position)
		var impact := _impact_material()
		if impact and impact.sound:
			Sfx.play_at(impact.sound, global_position, impact.volume_db)
	world.spawn_floating_text(head_position(), str(damage) + ("!" if hit.is_crit else ""), _hit_text_color(hit))
	health_changed.emit(hp, get_max_hp())
	if is_instance_valid(hit.source) and hit.source != self:
		last_attacker = hit.source
	if hit.status:
		# Credited to whoever caused it, secondary hits too (a burn from a blast kills for the hero).
		hit.status.apply_to(self, hit.source if is_instance_valid(hit.source) else null)
	# Lethal or not is decided by this hit alone: side effects below (thorns killing the attacker,
	# a level up, a heal on kill) must not pull the actor back from 0 HP.
	var lethal := hp <= 0
	if attacker:
		attacker.perks.on_hit_dealt(attacker, self, hit, damage)
	_on_damaged(hit, damage)
	perks.on_damaged(self, hit, damage)
	if lethal and not is_dead:
		hp = 0
		if not perks.prevent_death(self):
			die(hit.source)


## Returns how much was actually healed.
## A ward soaking up `amount` damage for `duration` seconds (a new one replaces a weaker one).
func add_ward(amount: int, duration: float) -> void:
	ward = maxi(ward, amount)
	_ward_time = maxf(_ward_time, duration)


func heal(amount: int) -> int:
	if is_dead:
		return 0
	var before := hp
	if healing_scale != 1.0 and amount > 0:
		amount = maxi(1, roundi(amount * healing_scale))
	hp = mini(hp + amount, get_max_hp())
	health_changed.emit(hp, get_max_hp())
	if hp > before:
		healed.emit(hp - before, heal_source)  # balance tools only (see `healed`)
	return hp - before


## Healing from a "per hit", "per kill" or "per skill" perk (lifesteal, heal on kill, the Blood
## family...): fractions add up and are paid in whole points, and the hero's are limited by
## SustainRules (one budget for all of them). Returns how much was actually healed.
func sustain_heal(amount: float) -> int:
	if is_dead:
		return 0
	var max_hp := get_max_hp()
	var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	var boss_fight := world != null and world.is_boss_fight()
	var whole := sustain.take(amount, max_hp, max_hp - hp, now, _sustain_rules(), boss_fight)
	return heal(whole) if whole > 0 else 0


## Limits on sustain_heal() (null: none, only whole points).
func _sustain_rules() -> SustainRules:
	return null


## Killing this actor may feed "on kill" heals (Vampirism, the Blood family...).
func can_heal_killer() -> bool:
	return true


func die(killer: Actor) -> void:
	if is_dead:
		return
	is_dead = true
	if killed_by.is_empty():  # a cause may be set just before (a fall, giving up)
		killed_by = _death_cause(killer)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	Sfx.play_at(_death_sound(), global_position)
	if rig:
		rig.play_death()
		rig.modulate = _body_modulate()
	var valid_killer := killer if is_instance_valid(killer) else null
	perks.on_died(self)
	_on_died(valid_killer)
	if valid_killer:
		valid_killer.perks.on_kill(valid_killer, self)  # still burning, slowed...: perks may care
	statuses.clear()
	died.emit(self)
	if free_on_death:
		if rig and rig.visible:
			rig.dissolve(0.45, queue_free)
		else:
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.25)
			tween.tween_callback(queue_free)
	queue_redraw()


# --- Holes ------------------------------------------------------------------

## Standing on the floor: can fall into holes, sink in quicksand, set off cracked floor.
func is_grounded() -> bool:
	return not flies and not is_dashing() and not is_falling and not is_dead


## Drops into the hole under the actor; _on_fell() decides what happens next.
func fall(pit: PitDef) -> void:
	if is_falling or is_dead:
		return
	is_falling = true
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_dash_time = 0.0
	Sfx.play_world(Sfx.bank.fall, global_position)
	var into := world.map.cell_to_world(world.map.world_to_cell(global_position))
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", global_position.lerp(into, 0.6), FALL_TIME)
	if rig:
		tween.tween_property(rig, "scale", Vector2.ZERO, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(rig, "rotation", TAU * 0.75, FALL_TIME)
	tween.chain().tween_callback(_on_fell.bind(pit))
	queue_redraw()


## Back on solid ground after a fall (the player climbing out).
func _recover_from_fall() -> void:
	is_falling = false
	if rig:
		rig.scale = Vector2.ONE
		rig.rotation = 0.0
	queue_redraw()


func _check_ground() -> void:
	if not is_grounded():
		return
	var pit := world.pit_under(global_position)
	if pit:
		fall(pit)


# --- Hooks for subclasses ----------------------------------------------------

func _death_cause(killer: Actor) -> String:
	if is_falling:
		return tr("a fall")
	if is_instance_valid(killer):
		return killer.display_name
	return tr("the dungeon")


## The fall is over: the actor is at the bottom of `pit`.
func _on_fell(_pit: PitDef) -> void:
	die(last_attacker if is_instance_valid(last_attacker) else null)


func _think(_delta: float) -> void:
	pass


func _get_desired_velocity() -> Vector2:
	return Vector2.ZERO


func _on_damaged(_hit: HitInfo, _damage: int) -> void:
	pass


## Last say on the damage of a hit, after armor (a shield blocking it...).
func _incoming_damage(_hit: HitInfo, damage: int) -> int:
	return damage


func _on_died(_killer: Actor) -> void:
	pass


func _hurt_sound(hit: HitInfo) -> AudioStream:
	return hit.sound


## What it is made of (the sound under its cry, its sparks), or null.
func _impact_material() -> ImpactMaterialDef:
	return null


func _death_sound() -> AudioStream:
	return null


func _hit_spark_color(hit: HitInfo) -> Color:
	if hit.is_crit:
		return CRIT_TEXT_COLOR
	var impact := _impact_material()
	return impact.spark_color if impact else Color.WHITE


func _hit_text_color(hit: HitInfo) -> Color:
	if hit.text_color.a > 0.0:
		return hit.text_color
	if hit.is_secondary:
		return SECONDARY_TEXT_COLOR
	return CRIT_TEXT_COLOR if hit.is_crit else HIT_TEXT_COLOR


# --- Frame update ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead or is_falling:
		return
	_tick_timers(delta)
	if is_dead:
		return
	_think(delta)
	if is_dead:
		return

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0 and rig and rig.visible and rig.current_frame():
			_afterimage_timer = AFTERIMAGE_INTERVAL
			world.spawn_vfx(AfterimageVfx.from_body(rig, _dash_element))
	else:
		velocity = _get_desired_velocity() + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	move_and_slide()
	_check_ground()
	if rig:
		rig.update_state(facing, velocity.length(), is_dashing(), delta)
		rig.modulate = _body_modulate()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_flash_time = maxf(_flash_time - delta, 0.0)
	skills.tick(delta * cooldown_speed)
	if ward > 0:
		_ward_time -= delta
		if _ward_time <= 0.0:
			ward = 0
	if not statuses.is_empty():
		statuses.tick(self, delta)
		if status_fx:
			status_fx.wake()

	if not _timed_bonuses.is_empty():
		var expired := false
		for bonus in _timed_bonuses:
			bonus.time_left -= delta
			expired = expired or bonus.time_left <= 0.0
		if expired:
			_timed_bonuses = _timed_bonuses.filter(func(b: TimedBonus) -> bool: return b.time_left > 0.0)
			invalidate_stats()


# --- Drawing -----------------------------------------------------------------

## Point above the actor's head, in world space (for damage numbers, labels...).
func head_position() -> Vector2:
	if frames:
		return global_position + Vector2(0, _feet_y() - head_height)
	return global_position + Vector2(0, -radius - 6.0)


## Collision is a circle at the actor's feet; the sprite stands on it.
func _feet_y() -> float:
	return radius * 0.7 + 1.0


## Tint of the whole body: death, blinking, telegraph glow... (the hit flash is a shader in the rig).
func _body_modulate() -> Color:
	if is_dead:
		return Color(0.45, 0.4, 0.4, 1.0)
	if not statuses.is_empty():
		# Burning, poisoned, chilled...: tinted a steady 45% toward the status's color (a body
		# that pulses reads as one about to strike, docs/vfx.md). Quicksand and sand: no tint.
		var tint := statuses.tint()
		if tint.a > 0.0:
			return Color.WHITE.lerp(Color(tint, 1.0), 0.45)
	return Color.WHITE


func _draw() -> void:
	if is_falling:
		return
	# Shadow under the feet: a flat oval of art pixels.
	PixelDraw.disc(self, Vector2(0, _feet_y() - 1.0), radius, Color(0, 0, 0, 0.35), 1.0, 0.4)
	if frames == null:
		var color := Color.WHITE if _flash_time > 0.0 else body_color * _body_modulate()
		_draw_fallback_body(color)
	if ward > 0 and not self is Monster:
		draw_ward(self)


## A shimmering bubble around a warded actor, drawn on `canvas` (centered on the actor; monsters
## draw it over their body, see MonsterOverlay).
## In the spirit element's language, on the art's grid: a hollow shell (a sparse dithered inside,
## a rim that flickers by whole pixels, gaps running around it), a glint circling, and small pale
## flames licking up off its top (docs/vfx.md: no smooth circle, no translucent fill).
func draw_ward(canvas: CanvasItem) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var spirit := VfxElementDef.named(&"spirit")
	var center := Vector2(0, -radius * 0.7)
	var size := PixelDraw.snap_length(radius + 9.0)
	PixelDraw.disc(canvas, center, size - PixelDraw.PX, spirit.shade(0.75), 0.12)
	# The rim, its gaps turning: a hollow ring, not a solid bubble.
	var cells := int(TAU * size / PixelDraw.PX)
	var turn := int(t * 10.0)
	for i in cells:
		if (i + turn) % 9 < 2:
			continue
		var at := center + Vector2.from_angle(TAU * i / cells) * size
		PixelDraw.pixel(canvas, at - Vector2.ONE, spirit.shade(0.5) if (i + turn) % 9 != 2 else spirit.shade(0.25))
	for i in 3:
		PixelDraw.pixel(canvas, center + Vector2.from_angle(t * 2.5 + i * 0.18) * size - Vector2.ONE, spirit.core())
	# Pale flames licking up off its top, rising and going down the ramp.
	for i in 3:
		var life := fmod(t * 1.6 + i * 0.37, 1.0)
		var x := (i - 1) * size * 0.45 + sin(t * 5.0 + i * 2.0) * PixelDraw.PX
		var top := center + Vector2(x, -sqrt(maxf(size * size - x * x, 0.0)) - life * 10.0)
		PixelDraw.pixel(canvas, top, spirit.shade(0.25 + life * 0.75))
		if life < 0.5:
			PixelDraw.pixel(canvas, top + Vector2(0, PixelDraw.PX), spirit.shade(0.5))


func _draw_fallback_body(color: Color) -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius, color.darkened(0.4), false, 2.0)
	var tip := facing * (radius + 6.0)
	var side := facing.orthogonal() * 4.0
	draw_colored_polygon(PackedVector2Array([tip, facing * radius + side, facing * radius - side]), color.lightened(0.3))
	if not glyph.is_empty():
		var font := Fonts.MAIN
		var font_size := 16
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(-text_size.x * 0.5, font_size * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.darkened(0.7))
