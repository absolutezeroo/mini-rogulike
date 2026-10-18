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


## Damage from a side effect (burn, thorns...): no crit, no variance, no on-hit perks.
static func make_secondary_hit(source: Actor, amount: int) -> HitInfo:
	var hit := HitInfo.new()
	hit.source = source
	hit.amount = maxi(1, amount)
	hit.is_secondary = true
	return hit


## Each point of defense removes one damage, but a hit always does at least 1.
static func mitigate(amount: int, defense: int) -> int:
	return maxi(1, amount - defense)


## Hits every enemy of the attacker inside an arc in front of them.
static func melee_strike(attacker: Actor, direction: Vector2, weapon: WeaponDef) -> void:
	var world := attacker.world
	var reach := attacker.radius + weapon.reach
	var half_arc := deg_to_rad(weapon.arc_degrees) * 0.5

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
		hit.sound = weapon.hit_sound
		target.take_hit(hit)

	# Crates, pots, barrels in the arc break too.
	for prop in world.get_breakable_props():
		var to_prop := prop.global_position - attacker.global_position
		if to_prop.length() <= reach + Prop.SIZE * 0.4 and absf(direction.angle_to(to_prop)) <= half_arc + 0.3:
			prop.take_hit(make_hit_from(attacker, attacker.get_power()))


## Hits every enemy of the attacker inside a circle. `secondary`: see HitInfo.is_secondary.
static func damage_area(world: World, attacker: Actor, center: Vector2, radius: float, base_amount: int, knockback: float, secondary: bool = false) -> void:
	for target in world.get_hostiles(attacker.faction):
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = offset.normalized() * knockback
		hit.is_secondary = secondary
		target.take_hit(hit)
	hit_props(world, attacker, center, radius)


## Breaks the props inside a circle.
static func hit_props(world: World, source: Actor, center: Vector2, radius: float) -> void:
	for prop in world.get_breakable_props():
		if prop.global_position.distance_to(center) <= radius + Prop.SIZE * 0.4:
			var hit := HitInfo.new()
			hit.source = source
			prop.take_hit(hit)


## An explosion that hurts everyone around, friend or foe, and breaks props
## (explosive barrels set each other off). `source` gets the credit for kills.
static func blast(world: World, center: Vector2, radius: float, amount: int, knockback: float, source: Actor = null) -> void:
	for target in world.get_actors():
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_secondary_hit(source, amount)
		hit.knockback = offset.normalized() * knockback
		target.take_hit(hit)
	hit_props(world, source, center, radius)


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
	spec.texture = weapon.projectile_texture
	return spec
