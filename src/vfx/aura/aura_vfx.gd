class_name AuraVfx
extends Node2D
## An aura worn (AuraDef, docs/vfx.md "Auras"), drawn round a body standing on its feet: this
## node sits at the feet, behind the body's sprites (VfxLayer.on_body; on the title, behind the
## hero's sprite), and holds three things.
##  - The glow on the ground (`ground`, aura_ground.gdshader): on the GROUND layer in a floor
##    (under every body and every telegraph), lit by a light of its own in a dim room.
##  - The halo behind the body (glow_halo.gdshader: two flat bands of added light, a tall oval),
##    seen round his sides and over his head, never over him.
##  - The motes, drawn here by hand as whole art pixels on the grid, at 12 frames a second (no
##    redraw in between), rising or sinking around him, behind him.
## Fewer effects (Settings.fewer_effects): the ground glow alone, still. For the look only:
## nothing here touches the game.

const GROUND_SHADER: Shader = preload("res://assets/shaders/aura_ground.gdshader")
## Out of a floor (wear_on_sprite): the same drawing, blended as a picture.
const GROUND_UI_SHADER: Shader = preload("res://assets/shaders/aura_ground_ui.gdshader")
const HALO_SHADER: Shader = preload("res://assets/shaders/glow_halo.gdshader")
## The motes move at the hand-animated pace.
const MOTE_FPS := 12.0

var def: AuraDef
## Feet to the top of the head, and the body's width, world units (the hero's: 30 and 12).
var body_height := 30.0
var body_width := 12.0
## Its glow on the floor.
var ground: Node2D
var _halo: Node2D
var _still := false
## Out of a floor (wear_on_sprite): drawn as a picture (GROUND_UI_SHADER).
var _on_sprite := false
## Per mote: x, height above the feet, age, life (seconds).
var _motes := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## Art pixel size where it is drawn (2 world units; more on a scaled title sprite).
var _pixel := PixelDraw.PX


## An aura of `aura` for a body `height` tall and `width` wide; null for no aura.
static func make(aura: AuraDef, height: float = 30.0, width: float = 12.0) -> AuraVfx:
	if aura == null:
		return null
	var vfx := AuraVfx.new()
	vfx.def = aura
	vfx.body_height = height
	vfx.body_width = width
	vfx.name = "Aura"
	return vfx


## Worn by `body`, an actor in a floor: at its feet (`feet`, from its origin), the halo and the
## motes behind its sprites, the glow on the floor under every body, with its own light.
func wear_on(body: Node2D, feet: Vector2) -> void:
	position = feet
	VfxLayer.on_body(body, self, true)
	if ground:
		VfxLayer.apply(ground, VfxLayer.Layer.GROUND)
		# (Its light in the first of its colors that shines: the demonic's embers, not its blood.)
		var shining := def.element if def.element.emissive else def.mote_element
		if def.light_reach > 0.0 and def.emissive and shining:
			VfxLayer.light_up(ground, shining, def.light_reach)


## Worn by a sprite out of a floor (the hero on the title, the Wardrobe's preview): beside it
## in its parent, just behind it, at its feet (`feet`, in the sprite's own art pixels), scaled
## as a floor would be under that sprite (one world unit = half an art pixel).
func wear_on_sprite(sprite: Node2D, feet: Vector2) -> void:
	_on_sprite = true
	scale = sprite.scale / PixelDraw.PX
	position = sprite.position + feet * sprite.scale
	sprite.get_parent().add_child(self)
	sprite.get_parent().move_child(self, sprite.get_index())
	z_index = sprite.z_index


func _ready() -> void:
	_still = Settings.fewer_effects
	_rng.seed = hash(def.id) if def else 0
	_pixel = PixelDraw.PX * absf(global_scale.x) if is_inside_tree() else PixelDraw.PX
	_build_ground()
	if _still or def.motes <= 0:
		set_process(false)  # (nothing moves but the ground glow, in its shader)
	if not _still:
		_build_halo()
		_seed_motes()


func _build_ground() -> void:
	ground = Node2D.new()
	ground.name = "Ground"
	ground.show_behind_parent = true  # (in a floor, wear_on puts it on the GROUND layer)
	var look := ShaderMaterial.new()
	look.shader = GROUND_UI_SHADER if _on_sprite else GROUND_SHADER
	var accent := def.accent if def.accent else def.element
	var sparks := def.mote_element if def.mote_element else def.element
	look.set_shader_parameter("bright", def.element.shade(def.bright_shade))
	look.set_shader_parameter("glow", def.element.shade(def.glow_shade))
	look.set_shader_parameter("dim", def.element.shade(def.dim_shade))
	look.set_shader_parameter("deep", accent.shade(def.deep_shade))
	look.set_shader_parameter("spark", sparks.shade(def.spark_shade))
	look.set_shader_parameter("pattern", def.ground)
	look.set_shader_parameter("radius", def.radius * _scale())
	look.set_shader_parameter("squash", def.squash)
	look.set_shader_parameter("density", def.density)
	look.set_shader_parameter("breath", def.breath)
	look.set_shader_parameter("emissive", def.emissive)
	look.set_shader_parameter("still", _still)
	look.set_shader_parameter("pixel", _pixel)
	ground.material = look
	var reach := def.radius + 4.0 * PixelDraw.PX
	ground.draw.connect(func() -> void:
		ground.draw_rect(Rect2(-reach, -reach * def.squash, reach * 2.0, reach * 2.0 * def.squash), Color.WHITE))
	add_child(ground)


func _build_halo() -> void:
	if def.halo_outer <= 0.0:
		return
	_halo = Node2D.new()
	_halo.name = "Halo"
	_halo.position = Vector2(0, -body_height * 0.5)
	var look := ShaderMaterial.new()
	look.shader = HALO_SHADER
	var element := def.element
	look.set_shader_parameter("inner", PixelDraw.snap_length(def.halo_inner) * _scale())
	look.set_shader_parameter("outer", PixelDraw.snap_length(def.halo_outer) * _scale())
	look.set_shader_parameter("inner_color", element.shade(def.halo_inner_shade))
	look.set_shader_parameter("outer_color", element.shade(def.halo_outer_shade))
	look.set_shader_parameter("inner_density", def.halo_inner_density)
	look.set_shader_parameter("outer_density", def.halo_outer_density)
	look.set_shader_parameter("pulse", 1 if def.halo_flicker else 0)
	look.set_shader_parameter("squash", def.halo_squash)
	look.set_shader_parameter("pixel", _pixel)
	_halo.material = look
	var reach := def.halo_outer + 2.0 * PixelDraw.PX
	_halo.draw.connect(func() -> void:
		_halo.draw_rect(Rect2(-reach, -reach * def.halo_squash, reach * 2.0, reach * 2.0 * def.halo_squash), Color.WHITE))
	add_child(_halo)


## The motes, already under way when it shows (not all born at once).
func _seed_motes() -> void:
	_motes.resize(def.motes * 4)
	for i in def.motes:
		_spawn(i, _rng.randf() * def.mote_life)


func _spawn(i: int, age: float) -> void:
	var half := body_width * 0.5 + 2.0 * PixelDraw.PX
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	_motes[i * 4] = side * _rng.randf_range(body_width * 0.25, half)
	_motes[i * 4 + 1] = _rng.randf_range(0.0, body_height * 0.3) if def.mote_motion == AuraDef.Motes.RISE else _rng.randf_range(body_height * 0.6, body_height)
	_motes[i * 4 + 2] = age
	_motes[i * 4 + 3] = def.mote_life * _rng.randf_range(0.7, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	for i in def.motes:
		_motes[i * 4 + 2] += delta
		if _motes[i * 4 + 2] >= _motes[i * 4 + 3]:
			_spawn(i, 0.0)
	# A new frame of the motes at 12 a second only (docs/performance.md: redraw on change).
	if _clock >= 1.0 / MOTE_FPS:
		_clock = fmod(_clock, 1.0 / MOTE_FPS)
		queue_redraw()


func _draw() -> void:
	if _still:
		return
	var element := def.mote_element if def.mote_element else def.element
	var px := PixelDraw.PX
	for i in def.motes:
		var age := _motes[i * 4 + 2]
		var life := _motes[i * 4 + 3]
		var t := age / life
		var climb := def.mote_speed * age * (1.0 if def.mote_motion == AuraDef.Motes.RISE else -1.0)
		var height := clampf(_motes[i * 4 + 1] + climb, 0.0, body_height * 1.2)
		var sway := sin(age * 3.0 + float(i)) * def.mote_sway
		var at := Vector2(_motes[i * 4] + sway, -height)
		# Bright as it is born, a darker step as it goes, dithered out at the end (whole pixels).
		var shades := def.mote_shades
		var step := mini(floori(t * shades.size()), shades.size() - 1)
		var color := element.shade(shades[step]) if not shades.is_empty() else element.core()
		var cell := Vector2i(floori(at.x / px), floori(at.y / px))
		if t > 0.8 and (cell.x + cell.y + floori(age * MOTE_FPS)) % 2 == 0:
			continue
		draw_rect(Rect2(Vector2(cell) * px, Vector2(px, px)), color)


## The share of an art pixel's size here (1 in a floor; the sprite's scale is undone on the title).
func _scale() -> float:
	return _pixel / PixelDraw.PX
