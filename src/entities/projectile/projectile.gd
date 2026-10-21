class_name Projectile
extends Area2D
## A moving shot. Hits the first enemy of its shooter (or several with pierce),
## stops on walls, and optionally explodes. Shots from traps have no shooter and hit everyone.

var _world: World
var _shooter: Actor
var _faction: Actor.Faction
## Trap shots: no side, hurt players and monsters alike.
var _hits_everyone := false
var _crit_chance := 0.0
var _spec: ProjectileSpec
var _direction := Vector2.RIGHT
var _travelled := 0.0
var _pierce_left := 0
var _already_hit: Array[Actor] = []
var _done := false
var _trail: Array[Vector2] = []  # recent global positions, newest last
## How it looks in flight (its sprite or its element's shot); null: a dot.
var _sheet: VfxSheetDef
## Its element, or one made from its color (old content).
var _element: VfxElementDef
var _age := 0.0
## Its sheet's first frame, picked at random: a ring of twelve sparks doesn't flicker in step.
var _phase := 0

const TRAIL_LENGTH := 6
## Light of a glowing shot, above the floor's own (LightSource.relative).
const GLOW_LEVEL := 3


func setup(shooter: Actor, direction: Vector2, spec: ProjectileSpec) -> void:
	_world = shooter.world
	_shooter = shooter
	_faction = shooter.faction
	_crit_chance = shooter.get_stats().crit_chance
	_configure(direction, spec)
	collision_mask = Layers.WORLD | (Layers.MONSTERS if _faction == Actor.Faction.PLAYER else Layers.PLAYER)


## A shot fired by the dungeon itself (arrow traps): hits players and monsters.
func setup_trap(world: World, direction: Vector2, spec: ProjectileSpec) -> void:
	_world = world
	_hits_everyone = true
	_configure(direction, spec)
	collision_mask = Layers.WORLD | Layers.MONSTERS | Layers.PLAYER


func _configure(direction: Vector2, spec: ProjectileSpec) -> void:
	_spec = spec
	_direction = direction.normalized()
	_pierce_left = spec.pierce
	collision_layer = 0
	var shape := CircleShape2D.new()
	shape.radius = spec.radius
	($CollisionShape2D as CollisionShape2D).shape = shape
	# Its look: its own drawn sheet or sprite, else its element's shot, else a dot in its color.
	if spec.sheet:
		_sheet = spec.sheet
	elif spec.texture:
		_sheet = VfxSheetDef.from_texture(spec.texture, spec.texture_frames)
	elif spec.element and spec.element.projectile:
		_sheet = spec.element.projectile
	_element = VfxElementDef.or_color(spec.element, spec.color)
	if _sheet:
		_phase = randi() % maxi(_sheet.frame_count(), 1)
	# Magic shots light up the dark in their color (not a boss's whole ring: too many lights);
	# plain things (shurikens, arrows) and matter (blood, water) don't shine at all.
	var shines := spec.glow > 0.0 and (spec.element == null or spec.element.emissive)
	var glow := $Glow as LightSource
	glow.visible = shines and (spec.count <= 3 or spec.explosion_radius > 0.0)
	glow.color = _element.color()
	glow.level = maxi(1, roundi(GLOW_LEVEL * spec.glow))
	# A glow halo around a few shots' cores (GlowHalo: dithered rings of added light, its light
	# on the floor is the Glow above): never around each of a boss's sixteen shards, it would fog
	# the screen. A storm spark flickers.
	if shines and spec.count <= 3:
		var storm := _element.bit == VfxElementDef.Bit.FORK
		GlowHalo.attach(self, _element, maxf(spec.radius, 5.0), Vector2.ZERO, GlowHalo.Pulse.FLICKER if storm else GlowHalo.Pulse.BREATHE)
	# Shadow and arcane bend the picture toward them (the screen pass keeps the nearest few).
	DistortionStamp.of_element(self, spec.element, maxf(spec.radius, 5.0) * 3.0, 1.0)
	# Drawn on the grid; a shining shot keeps its colors out of the floor's grading.
	material = FxLook.sprite(shines or (spec.element != null and spec.element.emissive))


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	var step := _spec.speed * delta
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	position += _direction * step
	queue_redraw()
	_travelled += step
	if _travelled >= _spec.max_distance:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if _done:
		return
	if not body is Actor:
		# A wall or a prop
		if body is Prop:
			var hit := HitInfo.new()
			hit.source = _shooter if is_instance_valid(_shooter) else null
			(body as Prop).take_hit(hit)
		Vfx.hit(_world, global_position, -_direction, _element.color(), false, _spec.element)
		Sfx.play_at(Sfx.bank.projectile_impact, global_position, -4.0)
		_burst()
		_finish()
		return
	var target := body as Actor
	if (target.faction == _faction and not _hits_everyone) or target.is_dead or _already_hit.has(target):
		return
	_already_hit.append(target)
	if _spec.explosion_radius > 0.0:
		_finish()
		return
	var hit := Combat.make_hit(_spec.damage, _crit_chance, _shooter if is_instance_valid(_shooter) else null)
	hit.knockback = _direction * _spec.knockback
	hit.status = _spec.status
	hit.element = _spec.element
	hit.is_secondary = _spec.secondary
	target.take_hit(hit)
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_burst()
		_finish()


## A magic shot bursts where it lands, in its element's language (exploding ones have their
## own big blast).
func _burst() -> void:
	if _spec.glow > 0.0 and _spec.explosion_radius <= 0.0:
		Vfx.pop(_world, global_position, _element, clampf(_spec.radius * 2.2, 10.0, 22.0), _direction)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _spec.explosion_radius > 0.0:
		_explode()
	elif _travelled >= _spec.max_distance and _spec.glow > 0.0:
		# Out of range: it breaks up into a few of its bits instead of vanishing.
		_world.spawn_vfx(ImpactVfx.create(global_position, _direction, _element.color(), false, _element if _spec.element else null))
	queue_free()


func _explode() -> void:
	Vfx.explosion(_world, global_position, _spec.explosion_radius, _spec.element)
	var source: Actor = _shooter if is_instance_valid(_shooter) else null
	Combat.hit_props(_world, source, global_position, _spec.explosion_radius)
	for target in _world.get_actors() if _hits_everyone else _world.get_hostiles(_faction):
		var offset := target.global_position - global_position
		if offset.length() <= _spec.explosion_radius + target.radius:
			var hit := Combat.make_hit(_spec.damage, _crit_chance, source)
			hit.knockback = offset.normalized() * _spec.knockback
			hit.status = _spec.status
			hit.element = _spec.element
			hit.is_secondary = _spec.secondary
			target.take_hit(hit)


func _draw() -> void:
	if _spec == null:
		return
	# A streak of its element's bits behind magic shots, on the grid, going down its ramp
	# and dithering out (plain things just fly).
	# Every other position, so it reads as motes left behind, not a line.
	if _spec.glow > 0.0:
		for i in range(_trail.size() - 1, -1, -2):
			var t := float(i + 1) / (_trail.size() + 1)  # 1 = newest
			var local := _trail[i] - global_position
			if not PixelDraw.dither(PixelDraw.cell_of(local), t):
				continue
			var size := 2 if t > 0.6 and _spec.radius >= 6.0 else 1
			PixelDraw.bit(self, VfxElementDef.Bit.SQUARE if _spec.element == null else _element.bit, local, size, _element.shade(1.0 - t * 0.75), -_direction)
	if _sheet:
		PixelDraw.sheet(self, _sheet, int(_age * _sheet.fps) + _phase, Vector2.ZERO, _direction, _element)
		return
	# No sprite: a stepped dot, its edge, its body, a bright heart.
	var r := PixelDraw.snap_length(_spec.radius)
	PixelDraw.disc(self, Vector2.ZERO, r + PixelDraw.PX, _element.edge())
	PixelDraw.disc(self, Vector2.ZERO, r, _element.color())
	PixelDraw.disc(self, Vector2.ZERO, maxf(r * 0.5, PixelDraw.PX), _element.core())
