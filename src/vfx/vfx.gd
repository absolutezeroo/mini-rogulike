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
	particles.position = at
	particles.color = color
	if direction != Vector2.ZERO:
		particles.direction = direction
	if not is_equal_approx(size, 1.0):
		particles.scale_amount_min *= size
		particles.scale_amount_max *= size
		particles.initial_velocity_min *= size
		particles.initial_velocity_max *= size
	world.spawn_vfx(particles)


## Sparks flying away from an impact.
static func hit(world: World, at: Vector2, direction: Vector2, color: Color = Color.WHITE) -> void:
	burst(world, HIT_SPARKS, at, color, direction)


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


static func explosion(world: World, at: Vector2, radius: float) -> void:
	var size := clampf(radius / 80.0, 0.6, 1.6)
	world.spawn_vfx(SheetVfx.create(EXPLOSION_SHEET, at, 0.0, radius * 2.2 / EXPLOSION_SHEET.get_height(), 18.0))
	world.flash_light(at, Color(1.0, 0.62, 0.32), radius * 3.0)
	burst(world, FIRE, at, Color.WHITE, Vector2.ZERO, size * 0.7)
	burst(world, SMOKE, at, Color.WHITE, Vector2.ZERO, size)
	Sfx.play_at(Sfx.bank.explosion, at)
	if world.player and world.player.global_position.distance_to(at) < 600.0:
		Events.screen_shake.emit(0.45 * size)


static func sparkles(world: World, at: Vector2, color: Color) -> void:
	burst(world, SPARKLES, at, color)


## Magic circle on the ground (heals, buffs, level up).
static func magic(world: World, at: Vector2, color: Color) -> void:
	world.spawn_vfx(SheetVfx.create(MAGIC_CIRCLE_SHEET, at, 0.0, 2.5, 12.0).with_color(color))
	world.flash_light(at, color, 200.0)
	sparkles(world, at + Vector2(0, -10), color)


## "!" bubble above a monster that just noticed the player.
static func alert(world: World, at: Vector2) -> void:
	world.spawn_vfx(EmoteVfx.create(ALERT_EMOTE, at))


static func dust(world: World, at: Vector2, size: float = 1.0) -> void:
	burst(world, DUST, at, Color.WHITE, Vector2.ZERO, size)
