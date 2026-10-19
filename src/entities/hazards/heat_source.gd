class_name HeatSource
extends Node2D
## Built from a HeatSourceDef: scorching ground, a frozen room, or a campfire. It only marks the
## place and draws it; BodyTemperature asks every heat source whether it reaches the hero.

const EMBERS := 7

var def: HeatSourceDef
var world: World
## Covered ground, around the node (heat zones).
var area := Rect2()
## The cells it covers.
var rect := Rect2i()

var _time := 0.0
var _sound_timer := 0.0
var _cracks: Array[PackedVector2Array] = []


func setup(source_def: HeatSourceDef, floor_world: World, cells: Rect2i) -> void:
	def = source_def
	world = floor_world
	rect = cells
	var ts := float(world.map.tile_size)
	position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * ts
	area = Rect2(-Vector2(rect.size) * ts * 0.5, Vector2(rect.size) * ts)
	z_index = -2 if def.comfort else -9
	_time = world.rng.randf() * 10.0
	add_to_group("heat_sources")
	if def.comfort:
		# The fire is its own light: don't let the lights burn it out.
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
	elif def.ground_shader:
		var look := ShaderMaterial.new()
		look.shader = def.ground_shader
		var world_area := Rect2(position + area.position, area.size)
		look.set_shader_parameter("area", Vector4(world_area.position.x, world_area.position.y, world_area.size.x, world_area.size.y))
		look.set_shader_parameter("edge", ts)
		material = look
	else:
		_cracks = _make_cracks(world.rng)
	if def.particles:
		var particles := def.particles.instantiate() as CPUParticles2D
		particles.emission_rect_extents = area.size * 0.5
		particles.amount = clampi(roundi(area.get_area() / 2200.0), 12, 160)
		particles.z_as_relative = false
		particles.z_index = 5
		add_child(particles)
	if def.light_color.a > 0.0:
		var light := FlickerLight.new()
		light.texture = preload("res://assets/fx/light.png")
		light.color = Color(def.light_color, 1.0)
		light.base_energy = def.light_color.a
		light.flicker = 0.18
		light.texture_scale = def.light_radius / 128.0
		light.position = Vector2(0, -6)
		add_child(light)


## True if `actor` feels it.
func reaches(actor: Actor) -> bool:
	if def.comfort:
		return actor.global_position.distance_to(global_position) <= def.reach
	return area.has_point(actor.global_position - global_position)


func _process(delta: float) -> void:
	_time += delta
	if def.ground_shader == null:
		queue_redraw()  # the shader animates by itself
	if def.sound:
		_sound_timer -= delta
		if _sound_timer <= 0.0:
			_sound_timer = randf_range(1.5, 3.0)
			if world.player and world.player.global_position.distance_to(global_position) < 300.0:
				Sfx.play_at(def.sound, global_position, -10.0, randf_range(0.85, 1.15))


func _draw() -> void:
	if def.comfort:
		_draw_campfire()
	elif def.ground_shader:
		draw_rect(area, Color.WHITE)
	else:
		_draw_hot_ground()


## The warm circle (so you see where it helps), the pit, the flames.
func _draw_campfire() -> void:
	var glow := def.glow_color
	draw_circle(Vector2.ZERO, def.reach, Color(glow, glow.a * (0.6 + 0.15 * sin(_time * 3.0))))
	draw_arc(Vector2.ZERO, def.reach, 0.0, TAU, 48, Color(glow, glow.a * 2.0), 2.0)
	if def.pool_color.a > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 24.0, def.pool_color.darkened(0.45))
		draw_circle(Vector2.ZERO, 20.0, def.pool_color)
		# Ripples spreading out from the middle.
		for i in 3:
			var t := fposmod(_time * 0.6 + i / 3.0, 1.0)
			draw_arc(Vector2.ZERO, 3.0 + 15.0 * t, 0.0, TAU, 24, Color(def.pool_color.lightened(0.6), 0.8 * (1.0 - t)), 2.0)
		draw_set_transform(Vector2.ZERO)
	if def.sprite:
		var size := def.sprite.get_size() * 2.0
		draw_texture_rect(def.sprite, Rect2(-size * 0.5, size), false)
	if def.flames:
		var frame_size := def.flames.get_height()
		var frames := mini(maxi(def.flames.get_width() / frame_size, 1), def.flame_frames)
		var copies := def.flame_copies
		for i in copies:
			# Side by side and out of step; the middle one a bit higher.
			var frame := int(_time * 9.0 + i * 1.7) % frames
			var middle := (copies - 1) * 0.5
			var offset := Vector2((i - middle) * 10.0, (-14.0 - (6.0 if absf(i - middle) < 0.6 else 0.0)) if copies > 1 else 0.0)
			var size := Vector2.ONE * frame_size * def.flame_scale
			draw_texture_rect_region(def.flames, Rect2(offset - size * 0.5, size),
				Rect2(frame * frame_size, 0, frame_size, frame_size))
	elif def.sprite == null and def.pool_color.a <= 0.0:
		draw_circle(Vector2.ZERO, 10.0, Color("ff9f1c"))  # nothing to show: a plain fire


## Glowing cracked ground, pulsing, with embers rising from it.
func _draw_hot_ground() -> void:
	var glow := def.glow_color
	var pulse := 0.75 + 0.25 * sin(_time * 2.4)
	draw_rect(area, Color(glow, glow.a * pulse))
	draw_rect(area.grow(-6.0), Color(glow, glow.a * 0.6 * pulse))
	var crack_color := Color(glow.lightened(0.5), 0.55 + 0.35 * pulse)
	for crack in _cracks:
		draw_polyline(crack, crack_color, 2.0)
	for i in EMBERS:
		var x := area.position.x + fposmod(i * 37.0 + 11.0, area.size.x)
		var rise := fposmod(_time * (18.0 + i * 3.0) + i * 23.0, 40.0)
		var at := Vector2(x + sin(_time * 2.0 + i) * 4.0, area.end.y - 8.0 - rise - fposmod(i * 29.0, area.size.y - 16.0))
		draw_rect(Rect2(at.snapped(Vector2(2, 2)), Vector2(2, 2)), Color(1.0, 0.75, 0.3, 1.0 - rise / 40.0))


func _make_cracks(rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var cracks: Array[PackedVector2Array] = []
	for i in 4:
		var line := PackedVector2Array()
		var point := Vector2(rng.randf_range(area.position.x + 6, area.end.x - 6), rng.randf_range(area.position.y + 6, area.end.y - 6))
		line.append(point)
		for step in 4:
			point += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 12.0)
			point = point.clamp(area.position + Vector2(4, 4), area.end - Vector2(4, 4))
			line.append(point.snapped(Vector2(2, 2)))
		cracks.append(line)
	return cracks
