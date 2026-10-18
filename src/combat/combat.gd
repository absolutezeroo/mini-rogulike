class_name Combat
## Shared combat rules. Every damage number in the game goes through here.

const CRIT_MULTIPLIER := 1.75
const DAMAGE_VARIANCE := 0.15


static func make_hit(base_amount: int, crit_chance: float, source: Actor) -> HitInfo:
	var hit := HitInfo.new()
	hit.source = source
	var amount := float(base_amount) * randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	if randf() < crit_chance:
		hit.is_crit = true
		amount *= CRIT_MULTIPLIER
	hit.amount = maxi(1, roundi(amount))
	return hit


static func make_hit_from(attacker: Actor, base_amount: int) -> HitInfo:
	return make_hit(base_amount, attacker.get_stats().crit_chance, attacker)


## Each point of defense removes one damage, but a hit always does at least 1.
static func mitigate(amount: int, defense: int) -> int:
	return maxi(1, amount - defense)


## Hits every enemy of the attacker inside an arc in front of them.
static func melee_strike(attacker: Actor, direction: Vector2, weapon: WeaponDef) -> void:
	var world := attacker.world
	var reach := attacker.radius + weapon.reach
	var half_arc := deg_to_rad(weapon.arc_degrees) * 0.5
	world.spawn_vfx(SlashVfx.create(attacker.global_position, direction, reach, weapon.arc_degrees, attacker.body_color.lightened(0.4)))

	for target in world.get_hostiles(attacker.faction):
		var to_target := target.global_position - attacker.global_position
		var distance := to_target.length()
		if distance > reach + target.radius:
			continue
		# Targets pressed against the attacker are always hit, whatever the angle.
		var touching := distance <= attacker.radius + target.radius + 4.0
		if not touching and absf(direction.angle_to(to_target)) > half_arc:
			continue
		if not world.has_line_of_sight(attacker.global_position, target.global_position):
			continue
		var hit := make_hit_from(attacker, attacker.get_power())
		hit.knockback = to_target.normalized() * weapon.knockback
		target.take_hit(hit)


## Hits every enemy of the attacker inside a circle.
static func damage_area(world: World, attacker: Actor, center: Vector2, radius: float, base_amount: int, knockback: float) -> void:
	for target in world.get_hostiles(attacker.faction):
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = offset.normalized() * knockback
		target.take_hit(hit)


static func spec_from_weapon(attacker: Actor, weapon: WeaponDef) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.damage = attacker.get_power()
	spec.speed = weapon.projectile_speed
	spec.radius = weapon.projectile_radius
	spec.max_distance = weapon.reach
	spec.count = weapon.projectile_count
	spec.spread_degrees = weapon.spread_degrees
	spec.pierce = weapon.pierce
	spec.knockback = weapon.knockback
	spec.color = weapon.color
	return spec
