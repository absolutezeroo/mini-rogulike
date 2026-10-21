class_name ComposedVfx
extends Node2D
## A nova, a wave or a trail built from many pieces of an element's kit (VfxElementDef.piece:
## an ice crystal that grows, holds and shatters; a lick of fire; a rock spike), placed around
## a ring or along a line at the art's own size. Any radius or length is filled with more
## pieces, never by stretching a sheet (docs/vfx.md). The pieces nearest the source start first,
## so it reads as a wave going out; when they break they shed the element's residue (cold mist,
## smoke, dust) that sinks and dithers away. Without a piece in the kit it falls back to a ring.
## Its pieces are on their sheet's layer (VfxLayer): flat ones (storm's crackles) under the
## actors; upright ones (ice crystals, rays, smoke) each sorted with the actors by its base, so
## a hero standing in a Frost Nova stands among the crystals, not under them. The wave's edge
## and the residue lie on the ground, under everyone.

## Seconds for the wave to reach its outer pieces (the main action, in the first quarter).
const SPREAD_TIME := 0.12
const MAX_PIECES := 48

var element: VfxElementDef
var _pieces: Array[Dictionary] = []  # {at, delay, variant, flip}
var _motes: Array[Dictionary] = []  # {from, velocity, born, life}
var _age := 0.0
var _life := 0.6
## The outline of the wave on the ground (rings only).
var _radius := 0.0
## Upright pieces are nodes of their own among the actors (one per piece, sorted by its base).
var _standing := false


## One upright piece, sorted with the actors by its base (the parent draws it).
class StandingPiece extends Node2D:
	var composed: ComposedVfx
	var piece: Dictionary
	var lift := 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		composed.draw_piece(self, piece, Vector2(0, -lift))


## Pieces of `element` filling a disc of `radius` around `at`: an outer ring and, for big
## ones, an inner one. `inner` off: an explosion's edge, one sparse ring around its blast
## sheet. Falls back to a RingVfx when the element has no piece.
static func ring(at: Vector2, radius: float, of_element: VfxElementDef, inner: bool = true) -> Node2D:
	if of_element == null or of_element.piece == null:
		return RingVfx.create(at, radius, of_element.color() if of_element else Color.WHITE, of_element)
	var vfx := ComposedVfx.new()
	vfx.element = of_element
	vfx.position = PixelDraw.snap(at)
	vfx._radius = radius
	var spacing := vfx._spacing()
	# The outer ring closes; a big one gets a sparse inner ring (a field of ice, not a wall
	# hiding the monsters in it).
	var rings: Array[float] = [radius * 0.92]
	if inner and radius > spacing * 2.2:
		rings.append(radius * 0.5)
	for r in rings:
		var density := (1.0 if inner else 0.6) if r == rings[0] else 0.55
		var count := clampi(roundi(TAU * r / spacing * density), 5, MAX_PIECES / rings.size())
		var turn := randf() * TAU
		for i in count:
			var angle := turn + TAU * i / count + randf_range(-0.12, 0.12)
			var where := Vector2.from_angle(angle) * (r + randf_range(-3.0, 3.0))
			vfx._add(where, SPREAD_TIME * r / maxf(radius, 1.0))
	vfx._finish()
	return vfx


## Pieces of `element` along the front half of a circle of `radius` around `at`, facing
## `facing` (Flame Arc: a wall of fire licks sweeping from one side to the other), a sparse
## second row inside. Falls back to a ring when the element has no piece.
static func arc(at: Vector2, radius: float, facing: Vector2, of_element: VfxElementDef, sweep: float = 0.12) -> Node2D:
	if of_element == null or of_element.piece == null:
		return ring(at, radius, of_element)
	var vfx := ComposedVfx.new()
	vfx.element = of_element
	vfx.position = PixelDraw.snap(at)
	var spacing := vfx._spacing()
	var half := deg_to_rad(80.0)
	var start := facing.angle() - half
	for row: float in [0.9, 0.55]:
		var r := radius * row
		var count := clampi(roundi(2.0 * half * r / spacing * (1.0 if row > 0.8 else 0.6)), 3, MAX_PIECES / 2)
		for i in count:
			var t := (i + 0.5) / count
			var angle := start + 2.0 * half * t + randf_range(-0.06, 0.06)
			vfx._add(Vector2.from_angle(angle) * (r + randf_range(-3.0, 3.0)), sweep * t)
	vfx._finish()
	return vfx


## Pieces of `element` along the line from `from` to `to` (a dash leaving ice behind it),
## starting one after the other over `duration` seconds.
static func line(from: Vector2, to: Vector2, of_element: VfxElementDef, duration: float = 0.15) -> Node2D:
	if of_element == null or of_element.piece == null:
		return null
	var vfx := ComposedVfx.new()
	vfx.element = of_element
	vfx.position = PixelDraw.snap(from)
	var length := from.distance_to(to)
	var count := clampi(roundi(length / (vfx._spacing() * 0.8)), 1, MAX_PIECES)
	var side := (to - from).normalized().orthogonal()
	for i in count:
		var t := (i + 0.5) / count
		var where := (to - from) * t + side * randf_range(-6.0, 6.0)
		vfx._add(where, duration * t)
	vfx._finish()
	return vfx


## Distance between two pieces: a little more than one piece is wide.
func _spacing() -> float:
	return element.piece.frame_size().x * element.piece.texel * 0.95


func _add(where: Vector2, delay: float) -> void:
	_pieces.append({ at = PixelDraw.snap(where), delay = delay, variant = randi() % maxi(element.piece.variants, 1), flip = randf() < 0.5 })


func _finish() -> void:
	# The farther (upper) pieces first, so the nearer ones stand in front.
	_pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at.y < b.at.y)
	var layer := element.piece.layer
	VfxLayer.apply(self, layer)
	VfxLayer.light_up(self, element, maxf(_radius, 32.0))
	if layer == VfxLayer.Layer.STANDING:
		# Among the actors (World.spawn_vfx), its own drawing (the edge, the residue) flat under
		# them; each piece a node of its own at its base, sorted with them.
		_standing = true
		z_index = VfxLayer.GROUND_Z
		var lift := roundf(element.piece.base_offset() / PixelDraw.PX) * PixelDraw.PX
		for piece in _pieces:
			var node := StandingPiece.new()
			node.composed = self
			node.piece = piece
			node.lift = lift
			node.position = piece.at + Vector2(0, lift)
			VfxLayer.apply(node, VfxLayer.Layer.STANDING)
			add_child(node)
	var longest := 0.0
	for piece in _pieces:
		longest = maxf(longest, piece.delay)
	_life = longest + element.piece.duration() + 0.4


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	# Each piece sheds a little residue as it breaks (its last third).
	if element.residue.a > 0.0:
		var breaking := element.piece.duration() * 0.66
		for piece in _pieces:
			var since: float = _age - piece.delay - breaking
			if since >= 0.0 and since < delta and _motes.size() < MAX_PIECES * 3:
				for i in 2:
					_motes.append({ from = piece.at + Vector2(randf_range(-6.0, 6.0), randf_range(-10.0, 0.0)), velocity = Vector2(randf_range(-14.0, 14.0), randf_range(4.0, 16.0)), born = _age, life = randf_range(0.25, 0.4) })
	queue_redraw()


## Piece `piece` as it is now, drawn on `canvas` at `at`.
func draw_piece(canvas: CanvasItem, piece: Dictionary, at: Vector2) -> void:
	var sheet := element.piece
	var local: float = _age - piece.delay
	if local < 0.0:
		return
	# A piece's own last frames are its dissipation (fragments, a few chips).
	var frame := int(local * sheet.fps)
	if frame >= sheet.frame_count():
		return
	PixelDraw.sheet(canvas, sheet, frame, at, Vector2.RIGHT, element, Color.WHITE, piece.flip, piece.variant)


func _draw() -> void:
	# The wave's edge on the ground: a thin stepped ring in the dark step, gone once out.
	if _radius > 0.0 and _age < SPREAD_TIME * 2.0:
		var t := _age / (SPREAD_TIME * 2.0)
		PixelDraw.ring(self, Vector2.ZERO, _radius * minf(0.4 + t, 1.0), element.shade(0.75), 1, 1.0 - t)
	if not _standing:
		for piece in _pieces:
			draw_piece(self, piece, piece.at)
	for mote in _motes:
		var t: float = (_age - mote.born) / mote.life
		if t >= 1.0:
			continue
		var at: Vector2 = mote.from + mote.velocity * (_age - mote.born)
		if PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - t):
			PixelDraw.pixel(self, at, Color(element.residue, 1.0) if t < 0.5 else element.shade(0.75))
