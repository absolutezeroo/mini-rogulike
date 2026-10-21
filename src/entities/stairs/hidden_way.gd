class_name HiddenWay
extends Stairs
## The sealed way to the hidden floor (HiddenFloorDef), opened in a boss arena by its key
## (HiddenPassage): a fissure torn in the flagstones, cold light rising out of it, a ring of pale
## runes turning over it. Stepping in emits `reached` like any stairs; its sign names the floor.

const OPEN_TIME := 1.2
const RUNES_COUNT := 7

## Its light (HiddenFloorDef.color). Set before it enters the tree.
var glow := Color(0.62, 0.86, 1.0)
## Seconds since it opened (it tears open over OPEN_TIME).
var _age := 0.0
var _shine: Shine


## The runes and the light over the fissure: drawn above the floor's light (they glow).
class Shine:
	extends Node2D
	var way: HiddenWay

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		way.draw_shine(self)


func _ready() -> void:
	super._ready()
	if _motes is CPUParticles2D:
		(_motes as CPUParticles2D).color = glow.lightened(0.3)
	var light := LightSource.new()
	light.color = glow
	light.level = 11
	add_child(light)
	_shine = Shine.new()
	_shine.way = self
	_shine.z_as_relative = false
	_shine.z_index = LightField.Z + 1
	add_child(_shine)


func _process(delta: float) -> void:
	_age += delta
	super._process(delta)


## The fissure itself, on the floor (lit like the floor).
func _draw() -> void:
	var open := _opening()
	if open <= 0.05:
		return
	PixelDraw.polygon(self, _split(open), Color(0.01, 0.01, 0.03))


func _opening() -> float:
	return clampf(_age / OPEN_TIME, 0.0, 1.0)


## A jagged split in the stone, wider as it opens.
func _split(open: float) -> PackedVector2Array:
	var half := SIZE * 0.6 * open
	return PackedVector2Array([
		Vector2(-half, -2), Vector2(-half * 0.5, -SIZE * 0.24 * open), Vector2(-half * 0.1, -4),
		Vector2(half * 0.35, -SIZE * 0.32 * open), Vector2(half, 1), Vector2(half * 0.4, SIZE * 0.26 * open),
		Vector2(-half * 0.05, 5), Vector2(-half * 0.55, SIZE * 0.22 * open),
	])


## The cold light: a rim on the split, light rising from it, runes turning around it.
func draw_shine(canvas: CanvasItem) -> void:
	var open := _opening()
	var pulse := 0.75 + 0.25 * sin(_time * 2.2)
	# A cold halo on the flagstones around it.
	var solid := Color(glow, 1.0)
	# A cold halo on the flagstones around it: flat stepped discs.
	PixelDraw.disc(canvas, Vector2.ZERO, SIZE * 1.1, Color(solid, 0.12 * open * pulse))
	PixelDraw.disc(canvas, Vector2.ZERO, SIZE * 0.7, Color(solid, 0.1 * open * pulse))
	if open > 0.05:
		var split := _split(open)
		split.append(split[0])
		PixelDraw.polyline(canvas, split, solid.lightened(0.3), 1, pulse)
		# Light rising out of the dark, in a few thin columns (whole art pixels).
		for i in 3:
			var x := (i - 1) * SIZE * 0.22 * open
			var height := PixelDraw.snap_length(SIZE * (0.9 + 0.3 * sin(_time * 1.7 + i * 2.0)) * open)
			canvas.draw_rect(Rect2(PixelDraw.snap(Vector2(x - 2.0, -height)), Vector2(4.0, height)), Color(solid.lightened(0.3), 0.35 * pulse))
	var radius := SIZE * 0.95
	PixelDraw.ring(canvas, Vector2.ZERO, radius, solid.lightened(0.2), 1, open * pulse)
	for i in RUNES_COUNT:
		var angle := -_time * 0.5 + TAU * i / RUNES_COUNT
		var at := Vector2.from_angle(angle) * radius
		var size := 4.0
		var rune := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.6, 0), at + Vector2(0, size), at + Vector2(-size * 0.6, 0)])
		PixelDraw.polygon(canvas, rune, solid.lightened(0.6), open * pulse)
