class_name StairsSign
extends Node2D
## The sign over a way down (FloorRoute): the next floor's world, then its curse or event in its
## color. Drawn above the actors, so it reads from across the room.

const LIFT := 30.0

var _route: FloorRoute


func _init(route: FloorRoute) -> void:
	_route = route
	z_as_relative = false
	z_index = 9


func _draw() -> void:
	var title := _route.title()
	var twist := _route.twist()
	var title_width := Fonts.local_width(self, title, Fonts.BODY)
	var twist_width := Fonts.local_width(self, twist, Fonts.BODY) if not twist.is_empty() else 0.0
	var width := maxf(title_width, twist_width) + 10.0
	var height := 16.0 + (12.0 if not twist.is_empty() else 0.0)
	var top := -LIFT - height
	# A small wooden board on a post.
	draw_rect(Rect2(0.0, top + height, 2.0, -LIFT + 8.0 - top - height), Color(0.36, 0.22, 0.12))
	draw_rect(Rect2(-width * 0.5, top, width, height), Color(0.24, 0.15, 0.09, 0.92))
	draw_rect(Rect2(-width * 0.5, top, width, height), Color(0.62, 0.42, 0.22), false, 1.0)
	var y := top + 12.0
	Fonts.draw(self, Vector2(0, y), title, Fonts.BODY, Palette.GOLD, 0.5)
	if not twist.is_empty():
		y += 12.0
		Fonts.draw(self, Vector2(0, y), twist, Fonts.BODY, _route.twist_color().lerp(Color.WHITE, 0.25), 0.5)
