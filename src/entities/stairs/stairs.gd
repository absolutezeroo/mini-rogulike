class_name Stairs
extends Area2D
## Stairs to the next floor. Emits `reached` when the player steps on them.

signal reached

const SIZE := 32.0
const MOTES: PackedScene = preload("res://src/vfx/particles/stairs_motes.tscn")

## Set by the World from the floor's theme. Falls back to a drawn shape.
var texture: Texture2D
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.6
	($CollisionShape2D as CollisionShape2D).shape = shape
	body_entered.connect(_on_body_entered)
	add_child(MOTES.instantiate())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).is_dead:
		reached.emit()


func _draw() -> void:
	var half := SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	if texture:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, Color(0.02, 0.02, 0.04))
	# Pulsing golden frame so the exit is easy to spot.
	var glow := Palette.GOLD
	glow.a = 0.5 + 0.4 * sin(_time * 3.0)
	draw_rect(rect.grow(2.0), glow, false, 2.0)
