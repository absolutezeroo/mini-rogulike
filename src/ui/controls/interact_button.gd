class_name InteractButton
extends ActionButton
## The contextual Interact button (input action "interact"): it shows only while the hero stands
## by something to use (Interactable: the merchant, the forge, an encounter, a pact's stele),
## with that thing's picture and what tapping does under it ("Trade", "Pray"...).

## What tapping does, translated (under the button).
var caption := "":
	set(value):
		if value != caption:
			caption = value
			queue_redraw()

var _tween: Tween


func _init() -> void:
	action = "interact"
	radius = 44.0
	visible = false


## Shows it for `target` (null: hides it). It pops in, so the eye catches it.
func show_for(target: Interactable) -> void:
	if target == null:
		if _tween:
			_tween.kill()
		hide()
		return
	icon = target.icon
	icon_tint = target.icon_tint
	color = target.color
	caption = tr(target.verb)
	label = caption.left(1)
	if visible:
		return
	show()
	if _tween:
		_tween.kill()
	scale = Vector2.ONE * 0.6
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _draw() -> void:
	super._draw()
	if caption.is_empty():
		return
	# The verb on a dark plaque under the button.
	var font := Fonts.MAIN
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var plaque := Rect2(Vector2(-text_size.x * 0.5 - 10.0, radius + 4.0), Vector2(text_size.x + 20.0, 28.0))
	draw_rect(plaque, Color(0.1, 0.06, 0.07, 0.85))
	draw_rect(plaque, Color(color, 0.9), false, 2.0)
	var at := Vector2(-text_size.x * 0.5, plaque.position.y + 21.0)
	draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
	draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
