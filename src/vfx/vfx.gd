class_name Vfx
## One-line helpers to spawn visual effects, so gameplay code stays readable:
##     Vfx.hit(world, position, direction, Color.WHITE)

const HIT_SPARKS: PackedScene = preload("res://src/vfx/particles/hit_sparks.tscn")
const DEATH_CHUNKS: PackedScene = preload("res://src/vfx/particles/death_chunks.tscn")
const SMOKE: PackedScene = preload("res://src/vfx/particles/smoke.tscn")
const DUST: PackedScene = preload("res://src/vfx/particles/dust.tscn")
const FIRE: PackedScene = preload("res://src/vfx/particles/fire.tscn")
const SPARKLES: PackedScene = preload("res://src/vfx/particles/sparkles.tscn")
const EXPLOSION_SHEET: Texture2D = preload("res://assets/fx/explosion.png")
const SMOKE_SHEET: Texture2D = preload("res://assets/fx/smoke.png")
const MAGIC_CIRCLE_SHEET: Texture2D = preload("res://assets/fx/magic_circle.png")
const ALERT_EMOTE: Texture2D = preload("res://assets/ui/emotes/emote22.png")


static func burst(world: World, scene: PackedScene, at: Vector2, color: Color = Color.WHITE, direction: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	var particles := scene.instantiate() as CPUParticles2D
	if Settings.fewer_effects:
		particles.amount = maxi(1, particles.amount / 2)
	particles.position = at
	particles.z_index = LightField.Z + 2  # sparks shine on their own, over the floor's light
	particles.color = color
	if direction != Vector2.ZERO:
		particles.direction = direction
	if not is_equal_approx(size, 1.0):
		particles.scale_amount_min *= size
		particles.scale_amount_max *= size
		particles.initial_velocity_min *= size
		particles.initial_velocity_max *= size
	world.spawn_vfx(particles)


## A flash and sparks flying away from an impact (bigger for a critical hit): sparks in `color`
## (what the target is made of), the flash in the hitting `element`'s language (ImpactVfx).
static func hit(world: World, at: Vector2, direction: Vector2, color: Color = Color.WHITE, big: bool = false, element: VfxElementDef = null) -> void:
	burst(world, HIT_SPARKS, at, color, direction)
	world.spawn_vfx(ImpactVfx.create(at, direction, color, big, element))


## The arc of a melee swing (or the streak of a thrust), at the weapon's reach.
static func swing(attacker: Actor, aim: Vector2, weapon: WeaponDef, duration: float) -> void:
	if weapon.trail_color.a <= 0.0 or weapon.kind != WeaponDef.Kind.MELEE:
		return
	if weapon.attack_animation == WeaponDef.AttackAnimation.SMASH:
		return  # an overhead blow: its ring and dust say it
	var thrust := weapon.attack_animation == WeaponDef.AttackAnimation.THRUST
	var reach := attacker.radius + weapon.reach
	attacker.world.spawn_vfx(SwingVfx.create(attacker.global_position + Vector2(0, -6), aim, reach, weapon.arc_degrees, thrust, weapon.trail_color, duration))


## A shot of `element` landing (an ice shard cracking, a fireball bursting): the element's
## impact sheet, or a burst in its ramp when its kit has none. `direction`: where it flew.
static func pop(world: World, at: Vector2, element: VfxElementDef, radius: float = 14.0, direction: Vector2 = Vector2.RIGHT) -> void:
	if element.impact:
		world.spawn_vfx(SheetVfx.play(element.impact, at, direction, element))
	else:
		world.spawn_vfx(BlastVfx.create(at, radius, element))
	if element.emissive:
		world.flash_light(at, element.color(), radius * 5.0)
	if element.impact_sound:
		Sfx.play_at(element.impact_sound, at, -6.0)


## A nova of `element` filling `radius` around `at` (Frost Nova, a cold wave): its pieces
## composed around the ring (ComposedVfx), or a ring in its ramp.
static func nova(world: World, at: Vector2, radius: float, element: VfxElementDef) -> void:
	world.spawn_vfx(ComposedVfx.ring(at, radius, element))
	if element and element.emissive:
		world.flash_light(at, element.color(), radius * 2.0)


## `element` left along a line (a dash through ice): its pieces one after the other.
static func trail(world: World, from: Vector2, to: Vector2, element: VfxElementDef, duration: float = 0.15) -> void:
	var line := ComposedVfx.line(from, to, element, duration)
	if line:
		world.spawn_vfx(line)


## A ripple running through the picture around a blast.
static func shockwave(world: World, at: Vector2, reach: float, strength: float = 6.0) -> void:
	world.spawn_vfx(ShockwaveVfx.create(at, reach, strength))


## Chunks in the monster's color plus a puff of smoke.
static func death(world: World, at: Vector2, color: Color) -> void:
	burst(world, DEATH_CHUNKS, at, color)
	world.spawn_vfx(SheetVfx.create(SMOKE_SHEET, at + Vector2(0, -12), 0.0, 2.0, 14.0))


## Puff of smoke (something appears or vanishes).
static func puff(world: World, at: Vector2) -> void:
	world.spawn_vfx(SheetVfx.create(SMOKE_SHEET, at + Vector2(0, -12), 0.0, 2.0, 14.0))


## A chain of explosions over a big body, for boss deaths.
static func boss_death(world: World, at: Vector2, size: float) -> void:
	for i in 6:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, size)
		var delay := 0.12 * i
		world.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(world):
				explosion(world, at + offset, 50.0 + 12.0 * i))


## A blast of `element` (fire when none: barrels, bombs): a burst in its ramp, a ripple through
## the picture, its particles (fire and smoke; dust and chips for earth...), its mark on the floor
## (a scorch, cracks).
static func explosion(world: World, at: Vector2, radius: float, element: VfxElementDef = null) -> void:
	if element == null:
		element = VfxElementDef.named(&"fire")
	var size := clampf(radius / 80.0, 0.6, 1.6)
	world.spawn_vfx(BlastVfx.create(at, radius * 1.05, element))
	if element.mark.a > 0.0:
		world.add_splat(at, element.mark, clampf(radius / 45.0, 0.8, 2.5))
	if element.emissive:
		world.flash_light(at, element.shade(0.5), radius * 3.0)
	if element.id == &"fire":
		burst(world, FIRE, at, Color.WHITE, Vector2.ZERO, size * 0.7)
		burst(world, SMOKE, at, Color.WHITE, Vector2.ZERO, size)
	else:
		burst(world, DEATH_CHUNKS, at, element.color(), Vector2.ZERO, size)
		if element.residue.a > 0.0:
			burst(world, DUST, at, Color(element.residue, 1.0), Vector2.ZERO, size * 1.6)
	shockwave(world, at, radius * 1.4, clampf(radius / 12.0, 4.0, 9.0))
	Sfx.play_at(Sfx.bank.explosion, at)
	if world.player and world.player.global_position.distance_to(at) < 600.0:
		Events.screen_shake.emit(0.45 * size)


static func sparkles(world: World, at: Vector2, color: Color) -> void:
	burst(world, SPARKLES, at, color)


## Magic circle on the ground (heals, buffs, level up).
static func magic(world: World, at: Vector2, color: Color) -> void:
	world.spawn_vfx(SheetVfx.create(MAGIC_CIRCLE_SHEET, at, 0.0, 2.0, 12.0).with_color(color))
	world.flash_light(at, color, 200.0)
	sparkles(world, at + Vector2(0, -10), color)


## "!" bubble above a monster that just noticed the player.
static func alert(world: World, at: Vector2) -> void:
	world.spawn_vfx(EmoteVfx.create(ALERT_EMOTE, at))


static func dust(world: World, at: Vector2, size: float = 1.0) -> void:
	burst(world, DUST, at, Color.WHITE, Vector2.ZERO, size)
