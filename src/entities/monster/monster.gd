class_name Monster
extends Actor
## A monster built from a MonsterDef. Its behaviour lives in the StateMachine child
## (res://src/ai/), which steers it through `move_direction` and `attack()`.

const HP_BAR_WIDTH := 26.0

var def: MonsterDef
var target: Actor
## Set by the AI states every frame (length 0..1).
var move_direction := Vector2.ZERO
## 0..1 while winding up an attack; drawn as a warning for the player.
var telegraph := 0.0


func setup(monster_def: MonsterDef, depth: int, config: DungeonConfig) -> void:
	def = monster_def
	faction = Faction.MONSTER
	display_name = def.display_name
	glyph = def.glyph
	body_color = def.color
	set_body_radius(def.radius)
	collision_layer = Layers.MONSTERS
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.MONSTERS
	add_to_group("monsters")

	base_stats = def.stats.duplicate()
	var levels := depth - 1
	base_stats.max_hp = roundi(base_stats.max_hp * (1.0 + config.monster_hp_scale_per_depth * levels))
	base_stats.attack += config.monster_attack_per_depth * levels
	if def.weapon:
		equipment.equip(def.weapon)
	skills.set_skills(def.skills)
	invalidate_stats()
	hp = get_max_hp()


## Returns true if the monster has (or just acquired) a target to fight.
func notice_target() -> bool:
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


## Uses the first ready skill whose AI conditions match. Returns true if one was used.
func try_use_skill(distance: float, aim: Vector2) -> bool:
	for i in skills.skills.size():
		var skill := skills.skills[i]
		if not skills.is_ready(i):
			continue
		if distance < skill.ai_min_range or distance > skill.ai_max_range:
			continue
		if float(hp) / get_max_hp() > skill.ai_below_hp_ratio:
			continue
		facing = aim
		return skills.try_use(i, self, aim)
	return false


func _get_desired_velocity() -> Vector2:
	return move_direction * get_move_speed()


func get_move_direction() -> Vector2:
	return move_direction


func _on_damaged(hit: HitInfo, _damage: int) -> void:
	# Getting hit always makes a monster aggressive, even from out of sight.
	if hit.source and is_hostile_to(hit.source):
		target = hit.source


func _on_died(killer: Actor) -> void:
	Events.monster_killed.emit(self)
	if killer is Player:
		(killer as Player).gain_xp(def.xp_reward)
	if def.loot:
		for item in def.loot.roll(world.rng):
			var offset := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 14.0)
			world.spawn_item(item, global_position + offset)


func _draw() -> void:
	if telegraph > 0.0 and not is_dead:
		_draw_telegraph()
	super._draw()
	if not is_dead and hp < get_max_hp():
		var top_left := Vector2(-HP_BAR_WIDTH * 0.5, -radius - 9.0)
		draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH, 4.0)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH * hp / get_max_hp(), 4.0)), Color("ef476f"))


func _draw_telegraph() -> void:
	var weapon := get_weapon()
	var warning := Color(1.0, 0.2, 0.2, 0.15 + 0.35 * telegraph)
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
