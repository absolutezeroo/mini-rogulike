class_name Projectile
extends Area2D
## A moving shot. Hits the first enemy of its shooter (or several with pierce),
## stops on walls, and optionally explodes.

var _world: World
var _shooter: Actor
var _faction: Actor.Faction
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
	_spec = spec
	_direction = direction.normalized()
	_pierce_left = spec.pierce
	rotation = _direction.angle()
	collision_layer = 0
	collision_mask = Layers.WORLD | (Layers.MONSTERS if _faction == Actor.Faction.PLAYER else Layers.PLAYER)
	var shape := CircleShape2D.new()
	shape.radius = spec.radius
	($CollisionShape2D as CollisionShape2D).shape = shape


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
		# A wall
		Vfx.hit(_world, global_position, -_direction, _spec.color)
		Sfx.play_at(Sfx.bank.projectile_impact, global_position, -4.0)
		_finish()
		return
	var target := body as Actor
	if target.faction == _faction or target.is_dead or _already_hit.has(target):
		return
	_already_hit.append(target)
	if _spec.explosion_radius > 0.0:
		_finish()
		return
	var hit := Combat.make_hit(_spec.damage, _crit_chance, _shooter if is_instance_valid(_shooter) else null)
	hit.knockback = _direction * _spec.knockback
	target.take_hit(hit)
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _spec.explosion_radius > 0.0:
		_explode()
	queue_free()


func _explode() -> void:
	Vfx.explosion(_world, global_position, _spec.explosion_radius)
	var source := _shooter if is_instance_valid(_shooter) else null
	for target in _world.get_hostiles(_faction):
		var offset := target.global_position - global_position
		if offset.length() <= _spec.explosion_radius + target.radius:
			var hit := Combat.make_hit(_spec.damage, _crit_chance, source)
			hit.knockback = offset.normalized() * _spec.knockback
			target.take_hit(hit)


func _draw() -> void:
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
