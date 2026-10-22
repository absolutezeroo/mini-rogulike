class_name Fragment
extends Node2D
## A fragment of the past lying on a floor (FragmentDef, placed by FragmentPlacer): a scrap, a
## tablet, a letter, glowing in its look's element so it reads from afar on every floor: a rim
## of the element's light round its picture (inside the picture's own dark outline), a ring
## on the floor in the element's color outlined by its dark edge, breathing by an art pixel (the
## dark edge reads on light grass and sand, the color on dark stone), a glow halo (sparser on a
## bright floor), motes rising, a small light. Stepped, on the grid, only the element's ramp
## (docs/vfx.md). Standing by it, Interact reads it (Events.fragment_requested: the Game opens the
## reading panel); once read it is gone from the floor.

## The Interact button offers it from this close.
const READ_DISTANCE := 44.0
## Its glow's radius and its motes (world pixels).
const GLOW_RADIUS := 20.0
const MOTES := 3

var def: FragmentDef
## Whose story it belongs to.
var boss: BossDef
## Read: gone.
var taken := false

var _time := 0.0
var _spot := Interactable.new()
var _light: LightSource
## Its glow's element (its look's; holy's gold without one).
var _element: VfxElementDef
## The ring on the floor, under every actor (VfxLayer.GROUND).
var _floor: Node2D
var _breath := false


func setup(fragment: FragmentDef, owner_boss: BossDef) -> void:
	def = fragment
	boss = owner_boss
	add_to_group(&"fragments")
	var look := fragment.look
	_spot.verb = look.verb if look else "Read"
	_spot.reach = READ_DISTANCE
	_spot.icon = look.icon if look else null
	_spot.icon_tint = look.icon_tint if look else Color.WHITE
	_spot.color = _glow_color(0.0)
	_spot.used.connect(func(_by: Player) -> void: Events.fragment_requested.emit(self))
	add_child(_spot)
	_light = LightSource.new()
	_light.color = _glow_color(0.0)
	_light.level = 7
	add_child(_light)
	_element = look.element if look and look.element else VfxElementDef.named(&"holy")
	_floor = Node2D.new()
	_floor.name = "Ring"
	VfxLayer.apply(_floor, VfxLayer.Layer.GROUND)
	_floor.draw.connect(_draw_floor)
	add_child(_floor)
	var halo := GlowHalo.attach(self, _element, 9.0, Vector2(0, -2))
	if halo:
		halo.show_behind_parent = true  # behind the picture: a halo over its core whitens it


## Read: it leaves the floor.
func take() -> void:
	if taken:
		return
	taken = true
	_spot.enabled = false
	if _light:
		_light.queue_free()
	queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	var breath := sin(_time * 2.6) > 0.0
	if breath != _breath:
		_breath = breath
		_floor.queue_redraw()
	queue_redraw()


## A shade of its element's ramp (0: the core, 1: the edge).
func _glow_color(t: float) -> Color:
	var element := def.look.element if def and def.look else null
	return element.shade(t) if element else VfxElementDef.named(&"holy").shade(t)


## The element its glow is drawn in.
func glow_element() -> VfxElementDef:
	return _element


## The rim round its picture, in the element's light: one art pixel outside the picture's dark
## outline (none for a fragment without a picture).
func rim() -> PackedVector2Array:
	return ItemPickup.rim_of(def.look.icon) if def and def.look and def.look.icon else PackedVector2Array()


## The ring on the floor: the element's color, outlined outside by its dark edge, breathing out
## by an art pixel.
func _draw_floor() -> void:
	var radius := 14.0 + (2.0 if _breath else 0.0)
	PixelDraw.ring(_floor, Vector2(0, 8), radius + PixelDraw.PX, _element.edge(), 1, 1.0, 0.45)
	PixelDraw.ring(_floor, Vector2(0, 8), radius, _element.shade(0.3), 1, 1.0, 0.45)


func _draw() -> void:
	if def == null:
		return
	PixelDraw.disc(self, Vector2(0, 8), 10.0, Color(0, 0, 0, 0.35), 1.0, 0.45)
	# Motes rising from it, each on its own slow loop (whole pixels).
	for i in MOTES:
		var phase := fmod(_time * 0.45 + float(i) / MOTES, 1.0)
		var at := Vector2(sin(i * 2.4 + _time * 1.3) * 7.0, 2.0 - phase * 22.0)
		if phase < 0.85:
			PixelDraw.bit(self, _element.bit, at, 1, _element.shade(phase), Vector2.UP)
	var look := def.look
	if look and look.icon:
		var corner := Vector2(-16, -18 + (-PixelDraw.PX if _breath else 0.0))
		var icon_scale := 32.0 / look.icon.get_width()
		# The element's light round the picture, a step brighter while it breathes in.
		var lit := _element.shade(0.1 if _breath else 0.3)
		for p in rim():
			draw_rect(Rect2(corner + p * icon_scale, Vector2.ONE * icon_scale), lit)
		draw_texture_rect(look.icon, Rect2(corner, Vector2(32, 32)), false, look.icon_tint)
