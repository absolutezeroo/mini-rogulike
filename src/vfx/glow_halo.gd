class_name GlowHalo
extends Node2D
## The glow around an emissive core: the pixel art's "bloom", never a blur (glow_halo.gdshader).
## Two flat bands of added light in the element's darker steps (a stronger one, a fainter one),
## a checker one art pixel wide where they meet, on the world's grid, breathing by a whole pixel (fire, holy, arcane) or
## flickering (storm). It lights the air around a fire's heart, a storm spark, a holy column's
## foot, an arcane glint, a frost crystal's glint.
##
## A glow is one halo plus at most one light on the floor (a LightSource: LightField lights the
## floor around it in steps). `attach` never adds a second light where the effect already has
## one (a shot's Glow, a prop's lamp, VfxLayer.light_up), so nothing is lit twice; the halo itself
## stays within its two rings, right behind its core (never over it), and it is sparser on a
## bright floor (the desert, a lit room) than in the dark, where a glow shows most.

enum Pulse { BREATHE, FLICKER, STILL }

const SHADER := preload("res://assets/shaders/glow_halo.gdshader")
## How much of the glow is left on the brightest floor (1 in the dark).
const BRIGHT_FLOOR := 0.4

## Shared materials (element, size, pulse...): halos alike batch into one draw call.
static var _materials := {}

var element: VfxElementDef
## The core's radius, world units: the inner band reaches about 1.1x it, the outer one 1.7x.
var size := 6.0
var pulse := Pulse.BREATHE
## Under 1: an oval on the floor.
var squash := 1.0


## A halo around `parent`'s core (`offset` from its origin), in `element`'s darker steps; with
## `light_level` > 0 also a light on the floor in its color, unless `parent` already has one.
## Nothing for an element that doesn't shine (blood, earth, steel, shadow).
static func attach(parent: Node2D, of_element: VfxElementDef, core_size: float, offset: Vector2 = Vector2.ZERO, how: Pulse = Pulse.BREATHE, light_level: int = 0) -> GlowHalo:
	if of_element == null or not of_element.emissive:
		return null
	var halo := GlowHalo.new()
	halo.element = of_element
	halo.size = core_size
	halo.pulse = how
	halo.position = offset
	parent.add_child(halo)
	if light_level > 0:
		light(parent, of_element.color(), light_level)
	return halo


## A light in `color` on `parent` (moving with it), unless it already has one: one light per glow.
static func light(parent: Node2D, color: Color, level: int) -> LightSource:
	for child in parent.get_children():
		if child is LightSource:
			return child as LightSource
	var source := LightSource.new()
	source.color = color
	source.level = level
	source.relative = true
	source.moves = true
	parent.add_child(source)
	return source


func _ready() -> void:
	show_behind_parent = true  # right behind its core, never over it
	var field := get_tree().get_first_node_in_group(LightField.GROUP) as LightField
	var dark := 1.0 - (field.ambient_level if field else LightField.MAX_LEVEL) / float(LightField.MAX_LEVEL)
	material = _material_for(element, size, pulse, squash, lerpf(BRIGHT_FLOOR, 1.0, dark))


## How far it reaches, world units.
func reach() -> float:
	return PixelDraw.snap_length(size * 1.7) + PixelDraw.PX


func _draw() -> void:
	var r := reach() + PixelDraw.PX
	draw_rect(Rect2(-r, -r * squash, r * 2.0, r * 2.0 * squash), Color.WHITE)


static func _material_for(of_element: VfxElementDef, core_size: float, how: Pulse, oval: float, strength: float) -> ShaderMaterial:
	strength = snappedf(strength, 0.1)
	var key := "%s/%d/%d/%.2f/%.1f/%s" % [of_element.id, roundi(core_size), how, oval, strength, Settings.fewer_effects]
	if _materials.has(key):
		return _materials[key]
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("inner", PixelDraw.snap_length(core_size * 1.1))
	look.set_shader_parameter("outer", PixelDraw.snap_length(core_size * 1.7))
	look.set_shader_parameter("inner_color", of_element.shade(0.7))
	look.set_shader_parameter("outer_color", of_element.edge())
	# Fewer effects: the inner band only.
	look.set_shader_parameter("outer_density", 0.0 if Settings.fewer_effects else 0.22)
	look.set_shader_parameter("pulse", how)
	look.set_shader_parameter("squash", oval)
	look.set_shader_parameter("strength", strength)
	_materials[key] = look
	return look
