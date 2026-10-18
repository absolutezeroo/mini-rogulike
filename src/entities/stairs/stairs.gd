class_name Stairs
extends Area2D
## Stairs to the next floor. Emits `reached` when the player steps on them.

signal reached

const SIZE := 30.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.6
	($CollisionShape2D as CollisionShape2D).shape = shape
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).is_dead:
		reached.emit()


func _draw() -> void:
	var half := SIZE * 0.5
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color(0.02, 0.02, 0.04))
	for i in 4:
		var step := Rect2(-half + 3.0 + i * 3.0, -half + 3.0 + i * 6.0, SIZE - 6.0 - i * 6.0, 4.0)
		draw_rect(step, Color(0.55, 0.5, 0.45).darkened(i * 0.2))
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color("ffd166"), false, 2.0)
