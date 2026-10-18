class_name ActionButton
extends TouchScreenButton
## Round on-screen button bound to an input action (set `action` in the inspector).
## TouchScreenButton supports multi-touch, so you can move and attack at the same time.

@export var radius := 56.0
## Shown in the middle when there is no icon.
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var color := Color(1, 1, 1):
	set(value):
		color = value
		queue_redraw()

var icon: Texture2D:
	set(value):
		if value != icon:
			icon = value
			queue_redraw()
var icon_tint := Color.WHITE
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
	var size := Vector2(radius, radius) * 2.0
	var base := UiAtlas.large(UiAtlas.ROUND_BUTTON_PRESSED if is_pressed() else UiAtlas.ROUND_BUTTON)
	var tint := color.lerp(Color.WHITE, 0.35)
	tint.a = 0.85
	draw_texture_rect(base, Rect2(-size * 0.5, size), false, tint)

	if icon:
		var icon_size := Vector2(radius, radius) * 1.1
		var offset := Vector2(0, 2) if is_pressed() else Vector2.ZERO
		draw_texture_rect(icon, Rect2(-icon_size * 0.5 + offset, icon_size), false, icon_tint)
	elif not label.is_empty():
		var font := Fonts.MAIN
		var font_size := 16 if radius < 60.0 else 24
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2(-text_size.x * 0.5, font_size * 0.35)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color("3f2631"))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	if cooldown_ratio > 0.01:
		var points := PackedVector2Array([Vector2.ZERO])
		var steps := 32
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * cooldown_ratio * i / steps
			points.append(Vector2.from_angle(angle) * (radius - 4.0))
		draw_colored_polygon(points, Color(0.1, 0.05, 0.08, 0.6))

	if counter >= 0:
		var badge := Vector2(radius * 0.7, -radius * 0.7)
		draw_texture_rect(UiAtlas.small(80), Rect2(badge - Vector2(14, 14), Vector2(28, 28)), false)
		var count_text := str(counter)
		var count_size := Fonts.MAIN.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(Fonts.MAIN, badge + Vector2(-count_size.x * 0.5, 6.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
