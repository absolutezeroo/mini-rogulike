class_name MonsterOverlay
extends Node2D
## What is drawn around a monster besides its body: under it (elite aura, shields, the red
## warning of an attack or a cast), or over it (elite name, health bar). Two of these per monster,
## one behind the body (UNDER) and one in front (OVER), so the Monster script stays about behaviour.

enum Layer { UNDER, OVER }

const HP_BAR_WIDTH := 26.0

var layer := Layer.UNDER
var monster: Monster
## The attack warning (UNDER only).
var _telegraph: TelegraphView


static func create(owner: Monster, overlay_layer: Layer) -> MonsterOverlay:
	var overlay := MonsterOverlay.new()
	overlay.monster = owner
	overlay.layer = overlay_layer
	overlay.name = "Under" if overlay_layer == Layer.UNDER else "Over"
	overlay.show_behind_parent = overlay_layer == Layer.UNDER
	if overlay_layer == Layer.UNDER:
		overlay._telegraph = TelegraphView.new()
		overlay.add_child(overlay._telegraph)
	return overlay


func _process(_delta: float) -> void:
	queue_redraw()
	if _telegraph:
		_update_telegraph()


func _draw() -> void:
	if monster.is_dead or monster.is_falling:
		return
	if layer == Layer.UNDER:
		if monster.elite:
			_draw_elite_aura()
		for monster_trait in monster.def.traits:
			monster_trait.draw_under(monster, self)
	else:
		if monster.elite:
			_draw_elite_name()
		# Bosses have a big bar in the HUD instead.
		if monster.hp < monster.get_max_hp() and not monster.is_boss():
			var top_left := monster.head_position() - monster.global_position + Vector2(-HP_BAR_WIDTH * 0.5, -6.0)
			draw_rect(Rect2(top_left - Vector2.ONE, Vector2(HP_BAR_WIDTH + 2.0, 6.0)), Palette.INK)
			draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH * monster.hp / monster.get_max_hp(), 4.0)), Palette.BLOOD)


## Red warning (TelegraphView): the area of a skill being cast, the cone of a melee swing, the
## line of a shot, filling up until it lands.
func _update_telegraph() -> void:
	var telegraph := monster.telegraph
	if telegraph <= 0.0 or monster.is_dead or monster.is_falling:
		_telegraph.visible = false
		return
	var weapon := monster.get_weapon()
	var skill := monster.casting_skill()
	var angle := monster.facing.angle()
	if skill:
		if skill.telegraph_radius > 0.0:
			_telegraph.show_shape(TelegraphView.Shape.CIRCLE, skill.telegraph_radius, 0.0, telegraph)
		else:
			_telegraph.visible = false
	elif weapon and weapon.kind == WeaponDef.Kind.MELEE:
		var reach := monster.radius + weapon.reach
		if weapon.arc_degrees >= 359.0:
			_telegraph.show_shape(TelegraphView.Shape.CIRCLE, reach, 0.0, telegraph)
		else:
			_telegraph.show_shape(TelegraphView.Shape.CONE, reach, angle, telegraph, deg_to_rad(weapon.arc_degrees) * 0.5)
	else:
		var length := (weapon.reach if weapon else 200.0) * 0.6
		_telegraph.show_shape(TelegraphView.Shape.LINE, length, angle, telegraph, 0.0, 8.0)


## Pulsing ring of the affix color at the elite's feet.
func _draw_elite_aura() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var color := monster.elite.color
	var feet := monster.radius * 0.7 + 1.0
	draw_set_transform(Vector2(0, feet - 1.0), 0.0, Vector2(1.0, 0.45))
	color.a = 0.25 + 0.2 * pulse
	draw_circle(Vector2.ZERO, monster.radius + 6.0 + 2.0 * pulse, color)
	color.a = 0.8
	draw_arc(Vector2.ZERO, monster.radius + 6.0 + 2.0 * pulse, 0.0, TAU, 24, color, 2.0)
	draw_set_transform(Vector2.ZERO)


func _draw_elite_name() -> void:
	var font := Fonts.MAIN
	var font_size := 12
	var text := monster.display_name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := monster.head_position() - monster.global_position + Vector2(-text_size.x * 0.5, -12.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, monster.elite.color.lightened(0.3))
