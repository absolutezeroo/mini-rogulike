class_name Monster
extends Actor
## A monster built from a MonsterDef (or a BossDef). Its behaviour lives in the StateMachine child
## (res://src/ai/), which steers it through `move_direction`, `attack()` and skills.

const HP_BAR_WIDTH := 26.0
## Delay between a monster's death and its death burst (time to step away).
const DEATH_BURST_FUSE := 0.35

var def: MonsterDef
var target: Actor
## Set by the AI states every frame (length 0..1).
var move_direction := Vector2.ZERO
## 0..1 while winding up an attack or a skill; drawn as a warning for the player.
var telegraph := 0.0
## Skill being cast (see the Cast state), -1 when none.
var casting_index := -1
## A dormant monster ignores the player (a boss waiting in its arena). See wake_up().
var dormant := false

var _phases_done := 0
var _windup_multiplier := 1.0
var _damage_multiplier := 1.0
var _phase_tint := Color.WHITE


func setup(monster_def: MonsterDef, depth: int, config: DungeonConfig) -> void:
	def = monster_def
	faction = Faction.MONSTER
	display_name = def.display_name
	glyph = def.glyph
	body_color = def.color
	frames = def.frames
	frames_offset = def.frames_offset
	head_height = def.head_height
	set_body_radius(def.radius)
	collision_layer = Layers.MONSTERS
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.MONSTERS
	add_to_group("monsters")

	base_stats = def.stats.duplicate()
	var levels := depth - 1
	base_stats.max_hp = roundi(base_stats.max_hp * (1.0 + config.monster_hp_scale_per_depth * levels))
	base_stats.attack += config.monster_attack_per_depth * levels
	var difficulty := world.difficulty if world else null
	if difficulty:
		base_stats.max_hp = roundi(base_stats.max_hp * (difficulty.boss_hp if def is BossDef else difficulty.monster_hp))
		base_stats.move_speed *= difficulty.monster_speed
		_damage_multiplier = difficulty.monster_damage
		_windup_multiplier = difficulty.telegraph_time
	if def.weapon:
		equipment.equip(def.weapon)
	skills.set_skills(def.skills)
	invalidate_stats()
	hp = get_max_hp()


## Attacks and skills hit harder (or softer) with the difficulty.
func get_power() -> int:
	return maxi(1, roundi(super.get_power() * _damage_multiplier))


## Wind-ups and casts last longer on easy, shorter on hard (and in late boss phases).
func get_telegraph_scale() -> float:
	return _windup_multiplier


func is_boss() -> bool:
	return def is BossDef


## Ends dormancy and goes straight for `new_target`.
func wake_up(new_target: Actor) -> void:
	dormant = false
	target = new_target
	if rig:
		rig.play_intro()


## Returns true if the monster has (or just acquired) a target to fight.
func notice_target() -> bool:
	if dormant:
		return false
	if target != null and is_instance_valid(target) and not target.is_dead:
		return true
	target = null
	var player := world.player
	if player and not player.is_dead and can_see(player, def.detect_radius):
		target = player
		return true
	return false


func can_see(other: Actor, max_distance: float) -> bool:
	return global_position.distance_to(other.global_position) <= max_distance \
		and world.has_line_of_sight(global_position, other.global_position)


## Distance from which the weapon can hit the target.
func attack_range(other: Actor) -> float:
	var weapon := get_weapon()
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponDef.Kind.MELEE:
		return radius + weapon.reach + other.radius - 4.0
	return weapon.reach * 0.9


## Index of the first ready skill whose AI conditions match, or -1.
func pick_skill(distance: float) -> int:
	for i in skills.skills.size():
		var skill := skills.skills[i]
		if skill == null or not skills.is_ready(i):
			continue
		if distance < skill.ai_min_range or distance > skill.ai_max_range:
			continue
		if float(hp) / get_max_hp() > skill.ai_below_hp_ratio:
			continue
		return i
	return -1


func casting_skill() -> SkillDef:
	return skills.skills[casting_index] if casting_index >= 0 and casting_index < skills.skills.size() else null


## Telegraph time before attacking (shorter in later boss phases).
func get_attack_windup() -> float:
	return def.attack_windup * _windup_multiplier


func _get_desired_velocity() -> Vector2:
	return move_direction * get_move_speed()


func get_move_direction() -> Vector2:
	return move_direction


func _on_damaged(hit: HitInfo, _damage: int) -> void:
	# Getting hit always makes a monster aggressive, even from out of sight.
	if hit.source and is_hostile_to(hit.source):
		target = hit.source
	if hit.source is Player and not hit.is_secondary:
		HitStop.freeze(0.07 if hit.is_crit else 0.035)
	if dormant and hit.source:
		wake_up(hit.source)
	_update_boss_phase()


## Bosses get stronger as they lose HP (see BossDef.phases).
func _update_boss_phase() -> void:
	var boss := def as BossDef
	if boss == null or is_dead or hp <= 0:
		return
	while _phases_done < boss.phases.size() and float(hp) / get_max_hp() <= boss.phases[_phases_done].hp_ratio:
		_enter_phase(boss.phases[_phases_done])
		_phases_done += 1


func _enter_phase(phase: BossPhase) -> void:
	if phase.bonuses:
		base_stats = base_stats.plus(phase.bonuses)
		invalidate_stats()
	if not phase.skills.is_empty():
		skills.set_skills(phase.skills)
		casting_index = -1
	_windup_multiplier *= phase.windup_multiplier
	_phase_tint = phase.tint
	if not phase.message.is_empty():
		world.spawn_floating_text(head_position() + Vector2(0, -12), phase.message, Color("ff6b6b"))
		Events.log_message("%s: %s" % [display_name, phase.message], Color("ff6b6b"))
	Vfx.magic(world, global_position, Color("ff6b6b"))
	Sfx.play_at(Sfx.bank.boss_roar, global_position)
	if world.player:
		world.player.camera.shake(0.6)

func _hurt_sound(hit: HitInfo) -> AudioStream:
	if hit.sound:
		return hit.sound
	return def.hurt_sound if def.hurt_sound else Sfx.bank.monster_hurt


func _death_sound() -> AudioStream:
	return def.death_sound if def.death_sound else Sfx.bank.monster_death


func _on_died(killer: Actor) -> void:
	Events.monster_killed.emit(self)
	if is_boss():
		Vfx.boss_death(world, global_position + Vector2(0, -head_height * 0.5), radius * 1.5)
		HitStop.freeze(0.25)
	else:
		Vfx.death(world, global_position, def.color)
	if killer is Player:
		(killer as Player).gain_xp(def.xp_reward)
	_death_burst()
	_death_spawns()
	if def.loot:
		for item in def.loot.roll(world.rng, world.loot_scale()):
			var offset := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 14.0)
			world.spawn_item(item, global_position + offset)


## A short warning ring, then the burst (the monster is already gone).
func _death_burst() -> void:
	if def.death_burst_radius <= 0.0:
		return
	var at := global_position
	var target_world := world
	var monster_def := def
	var damage := roundi((def.death_burst_damage + target_world.depth) * target_world.damage_scale())
	target_world.spawn_vfx(RingVfx.create(at, def.death_burst_radius, Color(1.0, 0.3, 0.2, 0.8)))
	target_world.get_tree().create_timer(DEATH_BURST_FUSE, false).timeout.connect(func() -> void:
		if not is_instance_valid(target_world):
			return
		if monster_def.death_burst_fx:
			var size := monster_def.death_burst_radius * 2.0 / monster_def.death_burst_fx.get_height()
			target_world.spawn_vfx(SheetVfx.create(monster_def.death_burst_fx, at, 0.0, size))
			Sfx.play_at(Sfx.bank.explosion, at, -4.0)
		else:
			Vfx.explosion(target_world, at, monster_def.death_burst_radius)
		Combat.blast(target_world, at, monster_def.death_burst_radius, damage, 260.0, null, monster_def.death_burst_status))


func _death_spawns() -> void:
	if def.death_spawns.is_empty() or def.death_spawn_count <= 0:
		return
	var at := global_position
	var target_world := world
	var spawns := def.death_spawns
	var count := def.death_spawn_count
	var hunted := target
	# Deferred: we may be inside a physics callback.
	(func() -> void:
		for i in count:
			var minion := target_world.spawn_monster(spawns.pick_random(), target_world.find_open_point_near(at, 24.0))
			minion.target = hunted if is_instance_valid(hunted) else null
			Vfx.puff(target_world, minion.global_position)
	).call_deferred()


func _draw() -> void:
	if telegraph > 0.0 and not is_dead:
		_draw_telegraph()
	super._draw()
	# Bosses have a big bar in the HUD instead.
	if not is_dead and hp < get_max_hp() and not is_boss():
		var top_left := head_position() - global_position + Vector2(-HP_BAR_WIDTH * 0.5, -6.0)
		draw_rect(Rect2(top_left - Vector2.ONE, Vector2(HP_BAR_WIDTH + 2.0, 6.0)), Color("3f2631"))
		draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH * hp / get_max_hp(), 4.0)), Color("e84537"))


## Glows red while winding up an attack, so the player sees it coming.
func _body_modulate() -> Color:
	var color := super._body_modulate() * _phase_tint
	if telegraph > 0.0 and _flash_time <= 0.0:
		color = color.lerp(Color(2.0, 0.7, 0.7), telegraph)
	return color


func _draw_telegraph() -> void:
	var weapon := get_weapon()
	var warning := Color(1.0, 0.2, 0.2, 0.15 + 0.35 * telegraph)
	var skill := casting_skill()
	if skill:
		# Casting: circle showing the area (if any), filling up until it goes off.
		if skill.telegraph_radius > 0.0:
			draw_circle(Vector2.ZERO, skill.telegraph_radius, Color(1.0, 0.2, 0.2, 0.12))
			if skill.telegraph_radius * telegraph > 1.0:
				draw_circle(Vector2.ZERO, skill.telegraph_radius * telegraph, warning)
			draw_arc(Vector2.ZERO, skill.telegraph_radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.7), 2.0)
		return
	if weapon and weapon.kind == WeaponDef.Kind.MELEE:
		# Red cone showing where the hit will land.
		var reach := (radius + weapon.reach) * telegraph
		if reach < 2.0:
			return
		if weapon.arc_degrees >= 359.0:
			draw_circle(Vector2.ZERO, reach, warning)
			return
		var half := deg_to_rad(weapon.arc_degrees) * 0.5
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			points.append(Vector2.from_angle(facing.angle() - half + half * 2.0 * i / 12.0) * reach)
		draw_colored_polygon(points, warning)
	else:
		# Aiming line for ranged attacks.
		var length := (weapon.reach if weapon else 200.0) * 0.6
		draw_line(Vector2.ZERO, facing * length, warning, 2.0 + 3.0 * telegraph)
