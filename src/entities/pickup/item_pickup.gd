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
	add_to_group("pickups")
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
	var bob := Vector2(0, sin(_time * 3.0) * 2.0 - 4.0)
	# Shadow on the ground, then a soft glow in the item's color.
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var rarity := (item as EquipmentDef).rarity if item is EquipmentDef else ItemRarity.COMMON
	var glow := item.rarity_color() if rarity > ItemRarity.COMMON or item is RuneDef else item.color
	glow.a = 0.18 + 0.08 * sin(_time * 4.0) + 0.08 * rarity
	draw_circle(bob, 14.0 + 2.0 * rarity, glow)
	if rarity >= ItemRarity.RARE:
		# A beam of light: rare and epic items are seen from afar.
		var beam := item.rarity_color()
		beam.a = 0.22 + 0.1 * sin(_time * 5.0)
		draw_rect(Rect2(-3, -70, 6, 70), beam)
		draw_rect(Rect2(-1, -90, 2, 90), Color(beam, beam.a * 1.5))
	if item.icon:
		# Small item sprites at 2x like the rest of the art; bigger UI-style icons at 1x.
		var icon_scale := Actor.SPRITE_SCALE if maxf(item.icon.get_width(), item.icon.get_height()) <= 18.0 else 1.0
		var size := item.icon.get_size() * icon_scale
		draw_texture_rect(item.icon, Rect2(bob - size * 0.5, size), false, item.icon_tint)
	else:
		var font := Fonts.MAIN
		var text_size := font.get_string_size(item.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, bob + Vector2(-text_size.x * 0.5, 6.0), item.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, item.color)
