class_name StatusFx
extends Node2D
## What a body's statuses look like (StatusLookDef, data/vfx/status_looks.tres): small flames
## licking up a burning monster, embers, poison bubbles, frost falling from a slowed one, a burst
## and a sound when a status takes hold. Drawn by hand (no nodes per particle), over the body, only
## while something is on it or a particle still lives. Actor owns one.

const LOOKS: StatusLookSet = preload("res://data/vfx/status_looks.tres")
## Particles at most per body (a pack on fire stays cheap).
const MAX_PARTICLES := 24

class Bit:
	var look: StatusLookDef
	var kind := 0  # 0 sheet particle, 1 mote, 2 burst
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var age := 0.0
	var life := 0.5
	var size := 1.0

var actor: Actor
var _bits: Array[Bit] = []
var _active: Array[StringName] = []
var _spawn := {}  # status -> [particle timer, mote timer]
var _time := 0.0


func _init(owner_actor: Actor) -> void:
	actor = owner_actor
	z_index = 2
	set_physics_process(false)


func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_time += delta
	var now := actor.statuses.active_ids() if not actor.is_dead else ([] as Array[StringName])
	for status in now:
		var look := LOOKS.look(status)
		if look == null:
			continue
		if not _active.has(status):
			_start(look)
		_feed(look, delta)
	_active = now
	for bit in _bits.duplicate():
		bit.age += delta
		bit.position += bit.velocity * delta
		if bit.kind == 1 and bit.look.mote == StatusLookDef.Mote.EMBER:
			bit.velocity.x += sin(_time * 9.0 + bit.size * 7.0) * 30.0 * delta
		if bit.age >= bit.life:
			_bits.erase(bit)
	visible = not _bits.is_empty() or not _active.is_empty()
	if not visible:
		set_process(false)  # asleep until a status lands again (wake())
	queue_redraw()


## A status is on the body: show it.
func wake() -> void:
	if not is_processing():
		set_process(true)


## The body's middle and its size, in this node's space (the feet are at the actor's origin).
func _body() -> Rect2:
	var height := actor.head_height if actor.frames else actor.radius * 2.0
	var width := actor.radius * 1.6
	var feet := actor.radius * 0.7
	return Rect2(Vector2(-width * 0.5, feet - height), Vector2(width, height))


func _start(look: StatusLookDef) -> void:
	_spawn[look.status] = [0.0, 0.0]
	if look.burst and _bits.size() < MAX_PARTICLES:
		var bit := Bit.new()
		bit.look = look
		bit.kind = 2
		bit.position = _body().get_center()
		bit.life = look.burst_time
		_bits.append(bit)
	if look.sound and actor.world:
		Sfx.play_at(look.sound, actor.global_position, look.sound_db)


func _feed(look: StatusLookDef, delta: float) -> void:
	var timers: Array = _spawn.get(look.status, [0.0, 0.0])
	var body := _body()
	if look.particle and look.particle_rate > 0.0:
		timers[0] -= delta
		while timers[0] <= 0.0:
			timers[0] += 1.0 / look.particle_rate
			if _bits.size() >= MAX_PARTICLES:
				break
			var bit := Bit.new()
			bit.look = look
			bit.position = Vector2(randf_range(body.position.x, body.end.x), randf_range(body.position.y + body.size.y * 0.25, body.end.y))
			if look.particle_rise < 0.0:
				bit.position.y = randf_range(body.position.y - 4.0, body.position.y + body.size.y * 0.4)
			bit.velocity = Vector2(randf_range(-4.0, 4.0), -look.particle_rise)
			bit.life = look.particle_life * randf_range(0.8, 1.2)
			bit.size = look.particle_scale * randf_range(0.75, 1.1)
			_bits.append(bit)
	if look.mote != StatusLookDef.Mote.NONE and look.mote_rate > 0.0:
		timers[1] -= delta
		while timers[1] <= 0.0:
			timers[1] += 1.0 / look.mote_rate
			if _bits.size() >= MAX_PARTICLES:
				break
			var mote := Bit.new()
			mote.look = look
			mote.kind = 1
			mote.position = Vector2(randf_range(body.position.x, body.end.x), randf_range(body.position.y + body.size.y * 0.3, body.end.y))
			var ember := look.mote == StatusLookDef.Mote.EMBER
			mote.velocity = Vector2(randf_range(-6.0, 6.0), -randf_range(28.0, 46.0) if ember else -randf_range(10.0, 18.0))
			mote.life = randf_range(0.5, 0.9) if ember else randf_range(0.5, 0.8)
			mote.size = randf_range(1.0, 2.0) if ember else randf_range(1.5, 3.0)
			_bits.append(mote)
	_spawn[look.status] = timers


func _draw() -> void:
	# A soft glow on the body while a status lasts.
	if not _active.is_empty():
		var body := _body()
		for status in _active:
			var look := LOOKS.look(status)
			if look and look.glow.a > 0.0:
				var pulse := 0.8 + 0.2 * sin(_time * 11.0)
				for ring in 3:
					draw_circle(body.get_center() + Vector2(0, body.size.y * 0.15), body.size.x * (0.45 + ring * 0.2), Color(look.glow, look.glow.a * pulse / (ring + 1)))
	for bit in _bits:
		var t := clampf(bit.age / bit.life, 0.0, 0.999)
		match bit.kind:
			0:
				_draw_frame(bit.look.particle, bit.look.particle_frames, t, bit.position, bit.size, Color(bit.look.particle_tint, 1.0 - maxf(t - 0.7, 0.0) / 0.3))
			2:
				_draw_frame(bit.look.burst, bit.look.burst_frames, t, bit.position, bit.look.burst_scale, bit.look.burst_tint)
			1:
				var color := bit.look.mote_color
				if bit.look.mote == StatusLookDef.Mote.EMBER:
					color = color.lerp(Color(0.8, 0.15, 0.05), t)
					color.a = 1.0 - t
					draw_rect(Rect2(bit.position.round(), Vector2.ONE * roundf(bit.size)), color)
				else:
					# A bubble: a ring that pops at the end.
					color.a = 0.85 * (1.0 - maxf(t - 0.8, 0.0) / 0.2)
					var radius := bit.size * (1.6 if t > 0.85 else 1.0)
					draw_arc(bit.position.round(), radius, 0.0, TAU, 10, color, 1.0)


func _draw_frame(sheet: Texture2D, frames: int, t: float, at: Vector2, scale: float, tint: Color) -> void:
	if sheet == null:
		return
	var width := sheet.get_width() / maxi(frames, 1)
	var frame := mini(int(t * frames), frames - 1)
	var source := Rect2(frame * width, 0, width, sheet.get_height())
	var size := Vector2(width, sheet.get_height()) * scale
	draw_texture_rect_region(sheet, Rect2((at - size * 0.5).round(), size), source, tint)
