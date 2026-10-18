class_name Actor
extends CharacterBody2D
## Base class for everything that moves and fights: the player and monsters.
## Handles stats, health, attacking, knockback, dashing, perks, statuses and hit feedback.
## Subclasses decide where to go (_get_desired_velocity) and what to do (_think).
## How it looks is the job of the ActorRig child ("Rig"): this script only tells it what happens.

signal health_changed(current: int, maximum: int)
signal stats_changed
signal died(actor: Actor)

enum Faction { PLAYER, MONSTER }

const KNOCKBACK_FRICTION := 1400.0
const FLASH_TIME := 0.1
const HIT_TEXT_COLOR := Color("ffffff")
const CRIT_TEXT_COLOR := Color("ffd166")
const SECONDARY_TEXT_COLOR := Color("ffb26b")
## Pixel art is 16x16 and drawn at 2x.
const SPRITE_SCALE := 2.0
const AFTERIMAGE_INTERVAL := 0.03
## Seconds of falling into a hole before it counts.
const FALL_TIME := 0.5

var faction: Faction = Faction.MONSTER
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

var base_stats := StatBlock.new()
var equipment := Equipment.new()
var skills := SkillSet.new()
var perks := PerkSet.new()
var statuses := StatusSet.new()
var hp := 1
var facing := Vector2.RIGHT
var is_dead := false

var _stats_cache: StatBlock
var _timed_bonuses: Array = []  # [{ "stats": StatBlock, "time_left": float }]
var _attack_cooldown := 0.0
var _invulnerable_time := 0.0
var _knockback := Vector2.ZERO
var _dash_velocity := Vector2.ZERO
var _dash_time := 0.0
var _flash_time := 0.0
var _afterimage_timer := 0.0

## Visual body (sprite, hand, weapon, animations). Null for actors without sprite.
@onready var rig: ActorRig = get_node_or_null("Rig")


func _init() -> void:
	motion_mode = MOTION_MODE_FLOATING
	equipment.changed.connect(invalidate_stats)
	perks.changed.connect(invalidate_stats)


func _ready() -> void:
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


func add_timed_bonus(bonus: StatBlock, duration: float) -> void:
	_timed_bonuses.append({ "stats": bonus, "time_left": duration })
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
	return not is_dead and _attack_cooldown <= 0.0 and get_weapon() != null


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
	if weapon.kind == WeaponDef.Kind.MELEE:
		Combat.melee_strike(self, facing, weapon)
	else:
		world.fire_projectiles(self, facing, Combat.spec_from_weapon(self, weapon))
	return true


func start_dash(dash_velocity: Vector2, duration: float, invulnerable: bool) -> void:
	_dash_velocity = dash_velocity
	_dash_time = duration
	_afterimage_timer = 0.0
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
	if is_dead or _invulnerable_time > 0.0:
		return
	# Perks of the attacker can change the hit (direct hits only, see HitInfo.is_secondary).
	var attacker := hit.source if is_instance_valid(hit.source) and not hit.is_secondary else null
	if attacker:
		attacker.perks.modify_outgoing_hit(attacker, self, hit)
	var damage := Combat.mitigate(hit.amount, get_stats().defense)
	hp = maxi(hp - damage, 0)
	_knockback += hit.knockback
	_flash_time = FLASH_TIME
	if rig:
		rig.play_hurt()
	if not hit.is_secondary:
		var spark_direction := hit.knockback.normalized() if hit.knockback != Vector2.ZERO else Vector2.UP
		Vfx.hit(world, global_position + Vector2(0, -radius * 0.5), spark_direction, _hit_spark_color(hit))
		Sfx.play_at(_hurt_sound(hit), global_position)
	world.spawn_floating_text(head_position(), str(damage) + ("!" if hit.is_crit else ""), _hit_text_color(hit))
	health_changed.emit(hp, get_max_hp())
	if is_instance_valid(hit.source) and hit.source != self:
		last_attacker = hit.source
	if hit.status:
		hit.status.apply_to(self, attacker)
	if attacker:
		attacker.perks.on_hit_dealt(attacker, self, hit, damage)
	_on_damaged(hit, damage)
	perks.on_damaged(self, hit, damage)
	if hp <= 0 and not is_dead and not perks.prevent_death(self):
		die(hit.source)


## Returns how much was actually healed.
func heal(amount: int) -> int:
	if is_dead:
		return 0
	var before := hp
	hp = mini(hp + amount, get_max_hp())
	health_changed.emit(hp, get_max_hp())
	return hp - before


func die(killer: Actor) -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	Sfx.play_at(_death_sound(), global_position)
	if rig:
		rig.play_death()
		rig.modulate = _body_modulate()
	statuses.clear()
	var valid_killer := killer if is_instance_valid(killer) else null
	perks.on_died(self)
	_on_died(valid_killer)
	if valid_killer:
		valid_killer.perks.on_kill(valid_killer, self)
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
	Sfx.play_at(Sfx.bank.fall, global_position)
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

## The fall is over: the actor is at the bottom of `pit`.
func _on_fell(_pit: PitDef) -> void:
	die(last_attacker if is_instance_valid(last_attacker) else null)


func _think(_delta: float) -> void:
	pass


func _get_desired_velocity() -> Vector2:
	return Vector2.ZERO


func _on_damaged(_hit: HitInfo, _damage: int) -> void:
	pass


func _on_died(_killer: Actor) -> void:
	pass


func _hurt_sound(hit: HitInfo) -> AudioStream:
	return hit.sound


func _death_sound() -> AudioStream:
	return null


func _hit_spark_color(hit: HitInfo) -> Color:
	return CRIT_TEXT_COLOR if hit.is_crit else Color.WHITE


func _hit_text_color(hit: HitInfo) -> Color:
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
			world.spawn_vfx(AfterimageVfx.from_body(rig, Color(0.7, 0.9, 1.2)))
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
	skills.tick(delta)
	if not statuses.is_empty():
		statuses.tick(self, delta)

	if not _timed_bonuses.is_empty():
		var expired := false
		for bonus in _timed_bonuses:
			bonus.time_left -= delta
			expired = expired or bonus.time_left <= 0.0
		if expired:
			_timed_bonuses = _timed_bonuses.filter(func(b: Dictionary) -> bool: return b.time_left > 0.0)
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
		# Burning, poisoned...: tinted, pulsing slightly.
		var tint := statuses.tint()
		return Color.WHITE.lerp(tint * 1.4, 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.02))
	return Color.WHITE


func _draw() -> void:
	if is_falling:
		return
	# Shadow under the feet.
	draw_set_transform(Vector2(0, _feet_y() - 1.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if frames == null:
		var color := Color.WHITE if _flash_time > 0.0 else body_color * _body_modulate()
		_draw_fallback_body(color)


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
