class_name ActionButton
extends TouchScreenButton
## Round on-screen button bound to an input action (set `action` in the inspector).
## TouchScreenButton supports multi-touch, so you can move and attack at the same time.

@export var radius := 56.0
## Shown in the middle when there is no icon.
@export var label := "":
	set(value):
		if value != label:
			label = value
			queue_redraw()
@export var color := Color(1, 1, 1):
	set(value):
		if value != color:
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
## The attack button's charge (0: none): steps lighting up around its rim, clockwise from the
## top, in `charge_color`; `charge_full` makes them beat in `charge_core`.
var charge_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, charge_ratio):
			charge_ratio = value
			queue_redraw()
var charge_full := false:
	set(value):
		if value != charge_full:
			charge_full = value
			queue_redraw()
var charge_color := Color.WHITE
var charge_core := Color.WHITE
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


const BASE: Texture2D = preload("res://assets/ui/sphere/backgroundwood.png")
const BASE_PRESSED: Texture2D = preload("res://assets/ui/sphere/backgroundiron.png")


func _draw() -> void:
	var size := Vector2(radius, radius) * 2.0
	var tint := color.lerp(Color.WHITE, 0.55)
	tint.a = 0.9
	draw_texture_rect(BASE_PRESSED if is_pressed() else BASE, Rect2(-size * 0.5, size), false, tint)

	if icon:
		# Pixel icons: scale by a whole number so pixels stay square.
		var icon_scale := maxf(1.0, floorf(radius * 1.1 / maxf(icon.get_width(), icon.get_height())))
		var icon_size := icon.get_size() * icon_scale
		var offset := Vector2(0, 2) if is_pressed() else Vector2.ZERO
		draw_texture_rect(icon, Rect2(-icon_size * 0.5 + offset, icon_size), false, icon_tint)
	elif not label.is_empty():
		var font_size := Fonts.BODY if radius < 60.0 else Fonts.TITLE
		Fonts.draw(self, Vector2(0, font_size / 3.0), label, font_size, Color.WHITE, 0.5, Color("2b1d24"))

	if cooldown_ratio > 0.01:
		var points := PackedVector2Array([Vector2.ZERO])
		var steps := 32
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * cooldown_ratio * i / steps
			points.append(Vector2.from_angle(angle) * (radius - 6.0))
		draw_colored_polygon(points, Color(0.08, 0.04, 0.06, 0.65))

	if charge_ratio > 0.0 or charge_full:
		_draw_charge()

	if counter >= 0:
		var badge := Vector2(radius * 0.7, -radius * 0.7)
		draw_circle(badge, 14.0, Color("2b1d24"))
		draw_circle(badge, 14.0, Color("e9a85a"), false, 2.0)
		var count_text := str(counter)
		Fonts.draw(self, badge + Vector2(0, 6), count_text, Fonts.BODY, Color.WHITE, 0.5, Color.TRANSPARENT)


## The charge gauge on the rim: twelve steps of square pixels (the art's blocks, no smooth arc),
## lit one after another; full, all of them beat (under three times a second).
func _draw_charge() -> void:
	const STEPS := 12
	const BLOCK := 6.0
	var lit := STEPS if charge_full else floori(charge_ratio * STEPS)
	var beat := charge_full and fmod(Time.get_ticks_msec() * 0.001 * 2.5, 1.0) < 0.5
	var rim := radius - BLOCK * 0.5
	for step in STEPS:
		for k in 3:
			var turn := (step + (k + 0.5) / 3.5) / STEPS
			var at := Vector2(sin(turn * TAU), -cos(turn * TAU)) * rim
			at = (at / BLOCK).floor() * BLOCK
			var color := Color("1a1218", 0.8)
			if step < lit:
				color = charge_core if beat else charge_color
			draw_rect(Rect2(at, Vector2(BLOCK, BLOCK)), color)
	if charge_full:
		queue_redraw()  # it beats
