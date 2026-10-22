class_name Fragment
extends Node2D
## A fragment of the past lying on a floor (FragmentDef, placed by FragmentPlacer): a scrap, a
## tablet, a letter, in a soft glow of its look's element (stepped and breathing, motes rising,
## a small light) so it reads from afar. Standing by it, Interact reads it (Events.
## fragment_requested: the Game opens the reading panel); once read it is gone from the floor.

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
	queue_redraw()


## A shade of its element's ramp (0: the core, 1: the edge); gold without one.
func _glow_color(t: float) -> Color:
	var element := def.look.element if def and def.look else null
	return element.shade(t) if element else Color(1.0, 0.82, 0.4)


func _draw() -> void:
	if def == null:
		return
	PixelDraw.disc(self, Vector2(0, 8), 10.0, Color(0, 0, 0, 0.35), 1.0, 0.45)
	# A breathing glow in two steps of its ramp, dithered at the rim (docs/vfx.md: no smooth fade).
	var breath := sin(_time * 2.6) > 0.0
	PixelDraw.disc(self, Vector2(0, 0), GLOW_RADIUS, Color(_glow_color(0.8), 0.3 if breath else 0.2), 0.55)
	PixelDraw.disc(self, Vector2(0, 0), GLOW_RADIUS * 0.55, Color(_glow_color(0.4), 0.35 if breath else 0.26), 0.7)
	# A thin ring on the floor, in its core color: something lies here, seen from afar.
	PixelDraw.ring(self, Vector2(0, 8), 14.0, _glow_color(0.1), 1, 0.85 if breath else 0.6, 0.45)
	# Motes rising from it, each on its own slow loop (whole pixels).
	var element := def.look.element if def.look else null
	for i in MOTES:
		var phase := fmod(_time * 0.45 + float(i) / MOTES, 1.0)
		var at := Vector2(sin(i * 2.4 + _time * 1.3) * 7.0, 2.0 - phase * 22.0)
		if phase < 0.85:
			PixelDraw.bit(self, element.bit if element else VfxElementDef.Bit.SQUARE, at, 1, _glow_color(phase), Vector2.UP)
	var look := def.look
	if look and look.icon:
		var bob := -1.0 if breath else 0.0
		draw_texture_rect(look.icon, Rect2(Vector2(-16, -18 + bob), Vector2(32, 32)), false, look.icon_tint)
