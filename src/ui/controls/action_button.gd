class_name ActionButton
extends TouchScreenButton
## Round on-screen button bound to an input action (set `action` in the inspector).
## TouchScreenButton supports multi-touch, so you can move and attack at the same time.

@export var radius := 56.0
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var color := Color(1, 1, 1):
	set(value):
		color = value
		queue_redraw()

## 0 = ready, 1 = just used. Draws a dark pie over the button.
var cooldown_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, cooldown_ratio):
			cooldown_ratio = value
			queue_redraw()
## Small number in the corner (e.g. how many potions are left). Hidden when < 0.
var counter := -1:
	set(value):
		if value != counter:
			counter = value
			queue_redraw()


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape = circle
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)


func _draw() -> void:
	var fill := color
	fill.a = 0.45 if is_pressed() else 0.25
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.9), 3.0)

	if cooldown_ratio > 0.01:
		var points := PackedVector2Array([Vector2.ZERO])
		var steps := 32
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * cooldown_ratio * i / steps
			points.append(Vector2.from_angle(angle) * radius)
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))

	var font := ThemeDB.fallback_font
	var font_size := roundi(radius * 0.45)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	if counter >= 0:
		var badge := Vector2(radius * 0.7, -radius * 0.7)
		draw_circle(badge, 14.0, Color(0.1, 0.1, 0.15))
		var count_text := str(counter)
		var count_size := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, badge + Vector2(-count_size.x * 0.5, 6.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
