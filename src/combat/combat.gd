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
		amount *= CRIT_MULTIPLIER + (source.crit_damage_bonus if source else 0.0)
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


## A damage-over-time tick (see HitInfo.is_tick).
static func make_tick(source: Actor, amount: int) -> HitInfo:
	var hit := make_secondary_hit(source, amount)
	hit.is_tick = true
	return hit


## Armor with diminishing returns: a hit of A against D armor deals A x A / (A + ARMOR_WEIGHT x D).
## Against a hit much bigger than the armor it is close to removing D points (35 vs 5: 30.6);
## against a hit about the armor's size it halves it (20 vs 20: 10); it never makes a hit
## harmless (20 vs 36: 7, where "D points off" gave 1). At least 1. Negative armor (a curse)
## adds its points instead.
const ARMOR_WEIGHT := 1.0


static func mitigate(amount: int, defense: int) -> int:
	if defense <= 0 or amount <= 0:
		return maxi(1, amount - defense)
	return maxi(1, roundi(float(amount) * amount / (amount + ARMOR_WEIGHT * defense)))


## The smallest hit that deals at least `damage` through `defense` armor (mitigate's inverse).
static func hit_for(damage: int, defense: int) -> int:
	var amount := maxi(damage, 1)
	while mitigate(amount, defense) < damage:
		amount += 1
	return amount


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
		hit.origin = attacker.global_position
		hit.sound = weapon.hit_sound
		hit.status = weapon.on_hit
		# The hero's hits land in what the weapon carries for sure (docs/vfx.md, "Elemental
		# attacks"); a rune that works by chance says so itself (BurnOnHitPassive).
		hit.element = ItemLook.hit_element(weapon) if attacker is Player else weapon.element
		target.take_hit(hit)

	# Crates, pots, barrels in the arc break too.
	for prop in world.get_breakable_props():
		var to_prop := prop.global_position - attacker.global_position
		if to_prop.length() <= reach + Prop.SIZE * 0.4 and absf(direction.angle_to(to_prop)) <= half_arc + 0.3:
			prop.take_hit(make_hit_from(attacker, attacker.get_power()))


## Hits every enemy of the attacker inside a circle. `secondary`: see HitInfo.is_secondary.
## `element`: what the blow is made of (its hits flash in its language).
static func damage_area(world: World, attacker: Actor, center: Vector2, radius: float, base_amount: int, knockback: float, secondary: bool = false, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	for target in world.get_hostiles(attacker.faction):
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = offset.normalized() * knockback
		hit.origin = attacker.global_position if is_instance_valid(attacker) else center
		hit.is_secondary = secondary
		hit.status = status
		hit.element = element
		target.take_hit(hit)
	hit_props(world, attacker, center, radius)


## Hits every enemy of the attacker close to the segment from `from` to `to` (dash strikes).
static func damage_segment(world: World, attacker: Actor, from: Vector2, to: Vector2, width: float, base_amount: int, knockback: float, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	var direction := from.direction_to(to) if from != to else Vector2.RIGHT
	for target in world.get_hostiles(attacker.faction):
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, from, to)
		if closest.distance_to(target.global_position) > width + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = direction.orthogonal() * signf(direction.cross(target.global_position - from)) * knockback
		hit.origin = from
		hit.status = status
		hit.element = element
		target.take_hit(hit)
	for prop in world.get_breakable_props():
		var closest := Geometry2D.get_closest_point_to_segment(prop.global_position, from, to)
		if closest.distance_to(prop.global_position) <= width + Prop.SIZE * 0.4:
			var hit := HitInfo.new()
			hit.source = attacker
			prop.take_hit(hit)


## Breaks the props inside a circle.
static func hit_props(world: World, source: Actor, center: Vector2, radius: float) -> void:
	for prop in world.get_breakable_props():
		if prop.global_position.distance_to(center) <= radius + Prop.SIZE * 0.4:
			var hit := HitInfo.new()
			hit.source = source
			prop.take_hit(hit)


## An explosion that hurts everyone around, friend or foe, and breaks props
## (explosive barrels set each other off). `source` gets the credit for kills.
static func blast(world: World, center: Vector2, radius: float, amount: int, knockback: float, source: Actor = null, status: OnHitStatus = null) -> void:
	for target in world.get_actors():
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_secondary_hit(source, amount)
		hit.knockback = offset.normalized() * knockback
		hit.status = status
		hit.cause = &"blast"
		target.take_hit(hit)
	hit_props(world, source, center, radius)


## A warning ring around `source`, then after `fuse` seconds a blast that hurts and pushes
## away its enemies only (a boss throwing the hero off). Follows `source` while it moves.
static func shockwave(world: World, source: Actor, radius: float, amount: int, knockback: float, fuse: float) -> void:
	world.spawn_vfx(RingVfx.create(source.global_position, radius, Color(1.0, 0.3, 0.2, 0.8)))
	var floor_id := world.floor_id
	world.get_tree().create_timer(fuse, false).timeout.connect(func() -> void:
		if not is_instance_valid(world) or world.floor_id != floor_id or not is_instance_valid(source) or source.is_dead:
			return
		if not world.is_inside_tree():
			return  # its floor waits out of the tree (the hero is at the Threshold): it fizzles
		var center := source.global_position
		# A stomp: the ground bursts in dust and rubble whatever the boss is made of.
		Vfx.explosion(world, center, radius, VfxElementDef.named(&"earth"), false)
		Events.screen_shake.emit(0.5)
		for target in world.get_hostiles(source.faction):
			var offset := target.global_position - center
			if offset.length() > radius + target.radius:
				continue
			var hit := make_secondary_hit(source, amount)
			hit.knockback = (offset.normalized() if offset != Vector2.ZERO else Vector2.DOWN) * knockback
			hit.cause = &"shockwave"  # a boss answering a hero who struck too often (RunFacts)
			target.take_hit(hit)
		hit_props(world, source, center, radius))


## A warning ring, then after `fuse` seconds a blast (see blast()). `fx`: a sheet of square
## frames to play instead of the usual explosion; `element`: its nova instead (a frost skull
## bursting into a ring of ice).
static func delayed_blast(world: World, center: Vector2, radius: float, amount: int, fuse: float, fx: Texture2D = null, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	world.spawn_vfx(RingVfx.create(center, radius, Color(1.0, 0.3, 0.2, 0.8)))
	var floor_id := world.floor_id
	world.get_tree().create_timer(fuse, false).timeout.connect(func() -> void:
		if not is_instance_valid(world) or world.floor_id != floor_id:
			return  # the hero took the stairs meanwhile
		if not world.is_inside_tree():
			return  # its floor waits out of the tree (the hero is at the Threshold): it fizzles
		if element:
			Vfx.nova(world, center, radius, element)
			Sfx.play_at(Sfx.bank.explosion, center, -4.0)
		elif fx:
			world.spawn_vfx(SheetVfx.create(fx, center, 0.0, radius * 2.0 / fx.get_height()))
			Sfx.play_at(Sfx.bank.explosion, center, -4.0)
		else:
			Vfx.explosion(world, center, radius)
		blast(world, center, radius, amount, 260.0, null, status))


static func spec_from_weapon(attacker: Actor, weapon: WeaponDef) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.damage = maxi(1, roundi(attacker.get_power() * weapon.projectile_damage))
	spec.glow = weapon.projectile_glow
	spec.speed = weapon.projectile_speed
	spec.radius = weapon.projectile_radius
	spec.max_distance = weapon.reach
	spec.count = weapon.projectile_count
	spec.spread_degrees = weapon.spread_degrees
	spec.pierce = weapon.pierce
	spec.knockback = weapon.knockback
	spec.color = weapon.element.color() if weapon.element else weapon.color
	spec.texture = weapon.projectile_texture
	spec.texture_frames = weapon.projectile_frames
	spec.sheet = weapon.projectile_sheet
	spec.element = weapon.element
	spec.status = weapon.on_hit
	if attacker is Player and weapon.element == null:
		# A plain thing (an arrow, a star) from a weapon carrying an element flies in it (flames
		# riding an arrow, an ember trail) and lands in it when the hit is elemental for sure.
		spec.look_element = ItemLook.swing_element(weapon, true)
		spec.second_element = ItemLook.second_element(weapon, true)
		spec.hit_element = ItemLook.hit_element(weapon)
	elif attacker is Player:
		spec.second_element = ItemLook.second_element(weapon, true)
	return spec
