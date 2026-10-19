class_name Monster
extends Actor
## A monster built from a MonsterDef (or a BossDef). Its behaviour lives in the StateMachine child
## (res://src/ai/), which steers it through `move_direction`, `attack()` and skills.


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
## Elite monsters only (see make_elite()): what makes them special.
var elite: EliteAffixDef

## Big monsters shake the floor when they walk.
const HEAVY_RADIUS := 14.0
const HEAVY_STEP_INTERVAL := 0.45

var _step_timer := 0.0
var _phases_done := 0
var _windup_multiplier := 1.0
var _damage_multiplier := 1.0
var _phase_tint := Color.WHITE
var _xp_multiplier := 1
## Called in by another monster (SummonEffect): gives no XP, loot or gold.
var summoned := false
var _bonus_drops := 0
## Per-monster values of the def's traits (see trait_state()).
var _trait_state := {}
var _under: MonsterOverlay
var _over: MonsterOverlay
## Fell into a hole: no loot, no burst, nothing comes out.
var _fell := false

## Bosses: hits taken in a row, and the shockwave that answers them (see BossDef).
var _hit_streak := 0
var _streak_time := 0.0
var _shockwave_after := 0
var _shockwave_cooldown := 0.0
var _roar_time := 0.0


func setup(monster_def: MonsterDef, depth: int, config: DungeonConfig) -> void:
	def = monster_def
	faction = Faction.MONSTER
	display_name = def.display_name
	glyph = def.glyph
	body_color = def.color
	frames = def.frames
	frames_offset = def.frames_offset
	head_height = def.head_height
	flies = def.flies
	set_body_radius(def.radius)
	collision_layer = Layers.MONSTERS
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.MONSTERS | (0 if def.flies else Layers.WATER)
	add_to_group("monsters")

	# Depth, difficulty and the floor's event (see FloorRules).
	var rules := world.rules if world and world.rules else FloorRules.make(config, null, null, depth)
	base_stats = rules.scale_monster(def.stats, def is BossDef)
	_damage_multiplier = rules.monster_damage()
	_windup_multiplier = rules.telegraph_time()
	if def is BossDef:
		_shockwave_after = (def as BossDef).shockwave_after_hits
	if def.weapon:
		equipment.equip(def.weapon)
	skills.set_skills(def.skills)
	invalidate_stats()
	hp = get_max_hp()
	for monster_trait in def.traits:
		monster_trait.on_spawn(self)


func _ready() -> void:
	super._ready()
	# Warnings and auras under the body, name and health bar over it.
	_under = MonsterOverlay.create(self, MonsterOverlay.Layer.UNDER)
	add_child(_under)
	move_child(_under, 0)
	_over = MonsterOverlay.create(self, MonsterOverlay.Layer.OVER)
	add_child(_over)


## Turns the monster into an elite: affix perk, more HP, bigger, more XP, guaranteed loot.
## Call after it was added to the world.
func make_elite(affix: EliteAffixDef, config: DungeonConfig) -> void:
	elite = affix
	display_name = "%s %s" % [affix.display_name, def.display_name]
	if affix.perk:
		perks.add(affix.perk)
	base_stats.max_hp = roundi(base_stats.max_hp * config.elite_hp_multiplier * affix.hp_multiplier)
	invalidate_stats()
	hp = get_max_hp()
	head_height *= config.elite_scale
	set_body_radius(radius * lerpf(1.0, config.elite_scale, 0.5))
	if rig:
		rig.position = Vector2(0, _feet_y())
		rig.scale = Vector2.ONE * config.elite_scale
	_xp_multiplier = config.elite_xp_multiplier
	_bonus_drops = config.elite_drops


func is_elite() -> bool:
	return elite != null


func get_knockback_resistance() -> float:
	var resistance := def.knockback_resistance
	if elite:
		resistance = maxf(resistance, world.config().elite_knockback_resistance if world else 0.5)
	return resistance


func can_attack() -> bool:
	for monster_trait in def.traits:
		if not monster_trait.can_attack(self):
			return false
	return super.can_attack()


## The monster's attack or skill hurt the hero (thieves grab gold...).
func on_hit_player(player: Player) -> void:
	for monster_trait in def.traits:
		monster_trait.on_hit_player(self, player)


func _incoming_damage(hit: HitInfo, damage: int) -> int:
	for monster_trait in def.traits:
		damage = monster_trait.incoming_damage(self, hit, damage)
	return damage


## The first trait of type `kind` (a GuardTrait, a ThiefTrait...), or null.
func get_trait(kind: Script) -> MonsterTrait:
	for monster_trait in def.traits:
		if is_instance_of(monster_trait, kind):
			return monster_trait
	return null


## Per-monster values of a trait (a trait resource is shared by every monster of its kind).
func trait_state(owner: MonsterTrait) -> Dictionary:
	if not _trait_state.has(owner):
		_trait_state[owner] = {}
	return _trait_state[owner]


## Went down a hole (rather than being slain).
func has_fallen() -> bool:
	return _fell


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
	_update_heavy_steps()
	var direction := move_direction
	var delta := get_physics_process_delta_time()
	for monster_trait in def.traits:
		monster_trait.update(self, delta)
		direction = monster_trait.steer(self, direction)
	if direction != Vector2.ZERO and not flies:
		direction = _avoid_holes(direction)
	return direction * get_move_speed()


## Walking monsters don't step into holes on their own (being knocked in is another story):
## they veer off, or stop.
func _avoid_holes(direction: Vector2) -> Vector2:
	var look_ahead := radius + 12.0
	for angle: float in [0.0, 0.6, -0.6, 1.3, -1.3]:
		var turned := direction.rotated(angle)
		if not world.has_pit(world.map.world_to_cell(global_position + turned.normalized() * look_ahead)):
			return turned
	return Vector2.ZERO


func _update_heavy_steps() -> void:
	if radius < HEAVY_RADIUS or move_direction.length() < 0.3:
		return
	_step_timer -= get_physics_process_delta_time()
	if _step_timer > 0.0:
		return
	_step_timer = HEAVY_STEP_INTERVAL
	Sfx.play_at(Sfx.bank.footstep, global_position, -6.0, 0.55)
	Vfx.dust(world, global_position + Vector2(0, _feet_y()), 1.2)
	if world.player and world.player.global_position.distance_to(global_position) < 260.0:
		Events.screen_shake.emit(0.15 if not is_boss() else 0.3)


func get_move_direction() -> Vector2:
	return move_direction


func _on_damaged(hit: HitInfo, _damage: int) -> void:
	# Getting hit always makes a monster aggressive, even from out of sight.
	if hit.source and is_hostile_to(hit.source):
		target = hit.source
	if hit.source is Player and not hit.is_secondary:
		HitStop.freeze(0.07 if hit.is_crit else 0.035)
		Settings.vibrate(0.15 if hit.is_crit else 0.05)
	if dormant and hit.source:
		wake_up(hit.source)
	_update_boss_phase()
	if is_boss() and not hit.is_tick and hit.source and is_hostile_to(hit.source):
		_count_hit()


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
	cooldown_speed /= phase.cooldown_multiplier
	if phase.shockwave_after_hits > 0:
		_shockwave_after = phase.shockwave_after_hits
	_phase_tint = phase.tint
	# A roar: untouchable for a moment, and whoever stands close is thrown off.
	invincible = true
	_roar_time = (def as BossDef).phase_roar_time
	_shockwave(0.35)
	if not phase.message.is_empty():
		world.spawn_floating_text(head_position() + Vector2(0, -12), phase.message, Palette.DANGER)
		Events.log_message("%s: %s" % [display_name, phase.message], Palette.DANGER)
	Vfx.magic(world, global_position, Palette.DANGER)
	Sfx.play_at(Sfx.bank.boss_roar, global_position)
	Events.screen_shake.emit(0.6)

## Hit again soon after the last hit: the streak grows; too long, and it throws the hero off.
func _count_hit() -> void:
	_hit_streak = _hit_streak + 1 if _streak_time > 0.0 else 1
	_streak_time = (def as BossDef).streak_gap
	if _shockwave_after > 0 and _hit_streak >= _shockwave_after and _shockwave_cooldown <= 0.0:
		_hit_streak = 0
		_shockwave(0.45)


## A warning ring, then a blast all around that pushes its enemies far away.
func _shockwave(fuse: float) -> void:
	var boss := def as BossDef
	_shockwave_cooldown = 3.0
	var damage := world.rules.dungeon_damage(4.0, 0.6) if world.rules else 6
	Combat.shockwave(world, self, boss.shockwave_radius + radius, damage, boss.shockwave_knockback, fuse)


func _tick_timers(delta: float) -> void:
	super._tick_timers(delta)
	if not is_boss():
		return
	_streak_time = maxf(_streak_time - delta, 0.0)
	_shockwave_cooldown = maxf(_shockwave_cooldown - delta, 0.0)
	if _roar_time > 0.0:
		_roar_time -= delta
		if _roar_time <= 0.0:
			invincible = false


func _hurt_sound(hit: HitInfo) -> AudioStream:
	if hit.sound:
		return hit.sound
	return def.hurt_sound if def.hurt_sound else Sfx.bank.monster_hurt


func _death_sound() -> AudioStream:
	return def.death_sound if def.death_sound else Sfx.bank.monster_death


## Gone for good, nothing drops (the XP still goes to whoever pushed it).
func _on_fell(pit: PitDef) -> void:
	_fell = true
	super._on_fell(pit)


func _on_died(killer: Actor) -> void:
	Events.monster_killed.emit(self)
	_free_souls()
	var fell := _fell or is_falling
	for monster_trait in def.traits:
		monster_trait.on_died(self, killer, fell, not summoned)
	if fell:
		if killer is Player:
			(killer as Player).gain_xp(def.xp_reward * _xp_multiplier)
		world.spawn_floating_text(global_position, "Fell!", Palette.GOLD)
		return
	if is_boss():
		Vfx.boss_death(world, global_position + Vector2(0, -head_height * 0.5), radius * 1.5)
		HitStop.freeze(0.25)
	else:
		Vfx.death(world, global_position, def.color)
	if summoned:
		return  # called in by another monster: no rewards, or a summoner could be farmed forever
	if killer is Player:
		(killer as Player).gain_xp(def.xp_reward * _xp_multiplier)
	var config := world.config()
	var quality := config.boss_loot_quality if is_boss() else (config.elite_loot_quality if elite else 1.0)
	if def.loot:
		for item in def.loot.roll(world.rng, world.rules.loot_chance()):
			var offset := Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(4.0, 14.0)
			world.spawn_loot(item, global_position + offset, quality)
	for i in _bonus_drops:
		var item := world.pick_random_item()
		if item:
			world.spawn_loot(item, global_position + Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(6.0, 16.0), quality)
	_drop_gold()


func _drop_gold() -> void:
	var config := world.config()
	var multiplier := config.boss_gold_multiplier if is_boss() else (config.elite_gold_multiplier if elite else 1.0)
	if multiplier > 1.0 or world.rng.randf() < config.gold_drop_chance:
		world.spawn_gold(global_position, config.gold_for_kill(world.depth, multiplier, world.rng))


## The souls it fed on fly back to the hero's lantern (bosses hold many).
func _free_souls() -> void:
	if world.player == null or world.player.is_dead:
		return
	for i in (def as BossDef).soul_wisps if is_boss() else 1:
		world.spawn_vfx(SoulWisp.create(global_position + Vector2(randf_range(-8.0, 8.0), -radius), world.player))


## Glows red while winding up an attack, so the player sees it coming.
func _body_modulate() -> Color:
	var color := super._body_modulate() * _phase_tint
	if telegraph > 0.0 and _flash_time <= 0.0:
		color = color.lerp(Color(2.0, 0.7, 0.7), telegraph)
	return color
