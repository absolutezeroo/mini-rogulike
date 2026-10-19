class_name HeatSource
extends Node2D
## Built from a HeatSourceDef: scorching ground, a frozen room, a campfire or an oasis. It marks
## the place and draws it (a pond, decor around); BodyTemperature asks every heat source whether
## it reaches the hero. Campfires and oases may have a CampWatch (no camping by the light).

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
## Water cells of a pond where a ripple shows, and their phase.
var _ripples: Array[Vector3] = []
## The rough ground around a pond: circles [x, y, radius].
var _ground_blobs: Array[Vector3] = []


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
	if def.comfort and def.pond == null:
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
	elif def.pond == null:
		_cracks = _make_cracks(world.rng)
	if def.pond:
		_make_pond(ts)
	if not def.decor.is_empty() and def.decor_count.y > 0:
		_scatter_decor(ts)
	if def.camp_limit > 0.0:
		var watch := CampWatch.new()
		watch.source = self
		add_child(watch)
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
	if def.comfort and def.pond:
		# Along the shore, whatever the pond's size.
		var local := actor.global_position - global_position
		return local.distance_to(local.clamp(area.position, area.end)) <= def.reach
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
	elif def.pond:
		_draw_pond()  # plain water: a flooded hall's pool...
	elif def.ground_shader:
		draw_rect(area, Color.WHITE)
	else:
		_draw_hot_ground()


## The warm circle (so you see where it helps), the pit, the flames.
func _draw_campfire() -> void:
	var glow := def.glow_color
	var breathing := Color(glow, glow.a * (0.6 + 0.15 * sin(_time * 3.0)))
	if def.pond:
		draw_rect(area.grow(def.reach), breathing)
		_draw_pond()
	else:
		draw_circle(Vector2.ZERO, def.reach, breathing)
		draw_arc(Vector2.ZERO, def.reach, 0.0, TAU, 48, Color(glow, glow.a * 2.0), 2.0)
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
	elif def.sprite == null and def.pond == null:
		draw_circle(Vector2.ZERO, 10.0, Color("ff9f1c"))  # nothing to show: a plain fire


## The pond: each cell takes the shore tile matching its place (corner, edge, water), then
## ripples here and there.
func _draw_pond() -> void:
	for blob in _ground_blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z, def.pond_ground.darkened(0.25))
	for blob in _ground_blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z - 3.0, def.pond_ground)
	NineSlice.draw(self, def.pond, Rect2i(Vector2i.ZERO, def.pond.get_size()), area, rect.size, float(world.map.tile_size))
	for ripple in _ripples:
		var t := fposmod(_time * 0.5 + ripple.z, 1.0)
		var center := Vector2(ripple.x, ripple.y)
		draw_set_transform(center, 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 2.0 + 9.0 * t, 0.0, TAU, 16, Color(1, 1, 1, 0.6 * (1.0 - t)), 1.5)
		draw_set_transform(Vector2.ZERO)


## Water nobody walks on: a body on the water layer, cells blocked for the monsters' paths.
func _make_pond(ts: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WATER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = area.size - Vector2(ts, ts) * 0.5  # the shore can be stepped on
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			world.set_cell_blocked(Vector2i(x, y), true)
	# The ground around: circles along the shore, of random sizes, so every oasis has its shape.
	if def.pond_ground.a > 0.0:
		for y in rect.size.y:
			for x in rect.size.x:
				if x != 0 and y != 0 and x != rect.size.x - 1 and y != rect.size.y - 1:
					continue
				var at := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * ts
				var push := (at.normalized() if at != Vector2.ZERO else Vector2.UP) * ts * world.rng.randf_range(0.1, 0.5)
				_ground_blobs.append(Vector3(at.x + push.x, at.y + push.y, ts * world.rng.randf_range(0.75, 1.15)))
	# A few ripples on the inner water.
	for i in world.rng.randi_range(1, 3):
		var cell := Vector2(world.rng.randf_range(1.0, maxf(rect.size.x - 1.0, 1.0)), world.rng.randf_range(1.0, maxf(rect.size.y - 1.0, 1.0)))
		var at := area.position + cell * ts
		_ripples.append(Vector3(at.x, at.y, world.rng.randf()))


## Decor around the spot, on free floor: a random number of random pieces in random places.
func _scatter_decor(ts: float) -> void:
	var layer := DecorLayer.new()
	layer.z_index = 1  # on top of the pond's ground, under whoever walks by
	add_child(layer)
	var count := world.rng.randi_range(def.decor_count.x, def.decor_count.y)
	for i in count * 4:
		if layer.pieces.size() >= count:
			break
		var angle := world.rng.randf() * TAU
		var distance := world.rng.randf_range(0.45, 0.95) * def.reach
		var offset := Vector2.from_angle(angle) * distance
		if def.pond:
			# Along the shore, just outside the water.
			var edge := offset.normalized() * (area.size * 0.5 + Vector2(ts, ts) * 0.6)
			offset = edge + Vector2(world.rng.randf_range(-ts, ts), world.rng.randf_range(-ts, ts)) * 0.5
		var at := global_position + offset
		var cell := world.map.world_to_cell(at)
		if not world.map.is_floor(cell) or rect.has_point(cell) or world.nav.is_blocked(cell):
			continue
		layer.pieces.append([def.decor[world.rng.randi() % def.decor.size()], offset.snapped(Vector2(2, 2))])


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
