class_name Stairs
extends Area2D
## Stairs to the next floor. Emits `reached` when the player steps on them, or `blocked` while
## their seal holds (StairsSeal: slay enough of the floor's monsters first). Sealed, they lie
## dark under a slowly turning violet seal; it shatters into light when the seal breaks.

signal reached
## The player stepped on them while sealed.
signal blocked

const SIZE := 32.0
const MOTES: PackedScene = preload("res://src/vfx/particles/stairs_motes.tscn")
## How long the seal takes to shatter.
const BREAK_TIME := 0.7
const RUNES := 6

## Set by the World from the floor's theme. Falls back to a drawn shape.
var texture: Texture2D
var _time := 0.0
var _seal: StairsSeal
## Counts up from 0 when the seal breaks (-1: not breaking).
var _breaking := -1.0
var _motes: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.6
	($CollisionShape2D as CollisionShape2D).shape = shape
	body_entered.connect(_on_body_entered)
	_motes = MOTES.instantiate() as Node2D
	add_child(_motes)
	_motes.visible = not is_sealed()


## The floor's seal: closed until it breaks.
func bind_seal(seal: StairsSeal) -> void:
	_seal = seal
	seal.broken.connect(_on_seal_broken)
	if _motes:
		_motes.visible = not is_sealed()
	queue_redraw()


func is_sealed() -> bool:
	return _seal != null and _seal.is_sealed()


func _process(delta: float) -> void:
	_time += delta
	if _breaking >= 0.0:
		_breaking += delta
		if _breaking >= BREAK_TIME:
			_breaking = -1.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or (body as Player).is_dead:
		return
	if is_sealed():
		blocked.emit()
	else:
		reached.emit()


func _on_seal_broken() -> void:
	_breaking = 0.0
	_motes.visible = true


func _draw() -> void:
	var half := SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	var sealed := is_sealed()
	var shade := Color(0.45, 0.4, 0.55) if sealed else Color.WHITE
	if texture:
		draw_texture_rect(texture, rect, false, shade)
	else:
		draw_rect(rect, Color(0.02, 0.02, 0.04))
	if sealed:
		_draw_seal(1.0, 0.0)
		return
	if _breaking >= 0.0:
		var t := _breaking / BREAK_TIME
		_draw_seal(1.0 - t, t)
	# Pulsing golden frame so the exit is easy to spot.
	var glow := Palette.GOLD
	glow.a = 0.5 + 0.4 * sin(_time * 3.0)
	draw_rect(rect.grow(2.0), glow, false, 2.0)


## A violet ring of runes turning over the stairs, a bar across them. `fade` 1 = whole;
## `burst` 0..1 throws the runes outward as it shatters.
func _draw_seal(fade: float, burst: float) -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 2.5)
	var color := Palette.SEAL
	var radius := SIZE * 0.72 + burst * SIZE
	color.a = 0.9 * fade * pulse
	draw_circle(Vector2.ZERO, radius * 1.15, Color(color, 0.16 * fade * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.5, true)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 24, Color(color, color.a * 0.5), 1.0, true)
	for i in RUNES:
		var angle := _time * 0.6 + TAU * i / RUNES
		var at := Vector2.from_angle(angle) * radius
		var size := 3.5 + burst * 3.0
		var rune := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 0.7, 0), at + Vector2(0, size), at + Vector2(-size * 0.7, 0)])
		draw_colored_polygon(rune, Color(1.0, 0.9, 1.0, fade * pulse))
	if burst <= 0.0:
		# The bar across the way down.
		var bar := Color(color, 0.7 * fade)
		draw_line(Vector2(-SIZE * 0.42, -SIZE * 0.42), Vector2(SIZE * 0.42, SIZE * 0.42), bar, 3.0, true)
		draw_line(Vector2(SIZE * 0.42, -SIZE * 0.42), Vector2(-SIZE * 0.42, SIZE * 0.42), bar, 3.0, true)
	else:
		draw_circle(Vector2.ZERO, SIZE * 0.5 * (1.0 - burst), Color(1, 0.95, 0.8, 0.6 * (1.0 - burst)))
