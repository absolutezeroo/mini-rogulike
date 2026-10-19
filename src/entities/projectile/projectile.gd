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

const TRAIL_LENGTH := 6


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
	rotation = _direction.angle()
	collision_layer = 0
	var shape := CircleShape2D.new()
	shape.radius = spec.radius
	($CollisionShape2D as CollisionShape2D).shape = shape
	# Magic shots light up the dark in their color (not a boss's whole ring: too many lights);
	# plain things (shurikens, arrows) don't shine at all.
	var glow := $Glow as PointLight2D
	glow.enabled = spec.glow > 0.0 and (spec.count <= 3 or spec.explosion_radius > 0.0)
	glow.color = spec.color
	glow.energy = 0.75 * spec.glow
	if spec.glow > 0.0:
		var halo := ProjectileHalo.new()
		halo.color = spec.color
		halo.size = maxf(spec.radius, 5.0) * (1.4 if spec.texture else 1.0)
		add_child(halo)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
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
		Vfx.hit(_world, global_position, -_direction, _spec.color)
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
	target.take_hit(hit)
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_burst()
		_finish()


## A magic shot bursts where it lands (exploding ones have their own big blast).
func _burst() -> void:
	if _spec.glow > 0.0 and _spec.explosion_radius <= 0.0:
		Vfx.pop(_world, global_position, _spec.color, clampf(_spec.radius * 2.2, 10.0, 22.0))


func _finish() -> void:
	if _done:
		return
	_done = true
	if _spec.explosion_radius > 0.0:
		_explode()
	queue_free()


func _explode() -> void:
	Vfx.explosion(_world, global_position, _spec.explosion_radius, _spec.color if _spec.glow > 0.0 else Color(1.0, 0.45, 0.15))
	var source: Actor = _shooter if is_instance_valid(_shooter) else null
	Combat.hit_props(_world, source, global_position, _spec.explosion_radius)
	for target in _world.get_actors() if _hits_everyone else _world.get_hostiles(_faction):
		var offset := target.global_position - global_position
		if offset.length() <= _spec.explosion_radius + target.radius:
			var hit := Combat.make_hit(_spec.damage, _crit_chance, source)
			hit.knockback = offset.normalized() * _spec.knockback
			hit.status = _spec.status
			target.take_hit(hit)


func _draw() -> void:
	if _spec and _spec.texture:
		_draw_sprite()
		return
	var r := _spec.radius if _spec else 5.0
	var color := _spec.color if _spec else Color.WHITE
	# Fading trail of squares behind the shot (pixel style).
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		var trail_color := color
		trail_color.a = 0.5 * t
		var half := r * (0.4 + 0.5 * t)
		var local := (_trail[i] - global_position).rotated(-rotation)
		draw_rect(Rect2(local - Vector2(half, half), Vector2(half, half) * 2.0), trail_color)
	# Glow, core and bright center.
	var glow := color
	glow.a = 0.3
	draw_circle(Vector2.ZERO, r * 1.8, glow)
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2.ZERO, r * 0.5, color.lightened(0.7))


## Sprite projectiles: frames side by side (square), animated, pointing along the flight direction.
func _draw_sprite() -> void:
	var texture := _spec.texture
	var height := texture.get_height()
	var frame_count := texture.get_width() / height if texture.get_width() % height == 0 else 1
	var frame_width := texture.get_width() / frame_count
	var frame := int(_travelled / 40.0) % frame_count
	var size := Vector2(frame_width, height) * 2.0
	var source := Rect2(frame * frame_width, 0, frame_width, height)
	# A glowing streak behind magic shots, thinning out (plain things just fly).
	for i in (_trail.size() if _spec.glow > 0.0 else 0):
		var t := float(i + 1) / (_trail.size() + 1)
		var local := (_trail[i] - global_position).rotated(-rotation)
		draw_circle(local, size.y * (0.12 + 0.22 * t), Color(_spec.color, 0.35 * t))
	var glow := _spec.color
	glow.a = 0.3
	draw_circle(Vector2(-size.x * 0.25, 0), size.y * 0.35, glow)
	draw_texture_rect_region(texture, Rect2(-size * 0.5, size), source, Color.WHITE)
