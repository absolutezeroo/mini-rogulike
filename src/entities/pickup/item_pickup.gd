class_name ItemPickup
extends Area2D
## An item lying on the floor. Walking over it picks it up.

const PICKUP_RADIUS := 14.0

var item: ItemDef
## Dropped items wait until the player walks away before they can be picked up again.
var _armed := true
var _taken := false
var _time := 0.0


func setup(item_def: ItemDef, armed: bool = true) -> void:
	item = item_def
	_armed = armed
	_time = randf() * TAU
	collision_layer = Layers.PICKUPS
	collision_mask = Layers.PLAYER
	var shape := CircleShape2D.new()
	shape.radius = PICKUP_RADIUS
	($CollisionShape2D as CollisionShape2D).shape = shape


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not _armed or not body is Player:
		return
	var player := body as Player
	if not player.is_dead and player.pick_up(item):
		_taken = true
		queue_free()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_armed = true


func _draw() -> void:
	if item == null:
		return
	var bob := Vector2(0, sin(_time * 3.0) * 2.0)
	var glow := item.color
	glow.a = 0.25 + 0.1 * sin(_time * 4.0)
	draw_circle(bob, 11.0, glow)
	draw_circle(bob, 8.0, Color(0.08, 0.08, 0.12))
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(item.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, bob + Vector2(-size.x * 0.5, 5.0), item.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, item.color)
