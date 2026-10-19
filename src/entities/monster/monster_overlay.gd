class_name MonsterOverlay
extends Node2D
## What is drawn around a monster besides its body: under it (elite aura, shields, the red
## warning of an attack or a cast), or over it (elite name, health bar). Two of these per monster,
## one behind the body (UNDER) and one in front (OVER), so the Monster script stays about behaviour.

enum Layer { UNDER, OVER }

const HP_BAR_WIDTH := 26.0

var layer := Layer.UNDER
var monster: Monster


static func create(owner: Monster, overlay_layer: Layer) -> MonsterOverlay:
	var overlay := MonsterOverlay.new()
	overlay.monster = owner
	overlay.layer = overlay_layer
	overlay.name = "Under" if overlay_layer == Layer.UNDER else "Over"
	overlay.show_behind_parent = overlay_layer == Layer.UNDER
	return overlay


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if monster.is_dead or monster.is_falling:
		return
	if layer == Layer.UNDER:
		if monster.elite:
			_draw_elite_aura()
		for monster_trait in monster.def.traits:
			monster_trait.draw_under(monster, self)
		if monster.telegraph > 0.0:
			_draw_telegraph()
	else:
		if monster.elite:
			_draw_elite_name()
		# Bosses have a big bar in the HUD instead.
		if monster.hp < monster.get_max_hp() and not monster.is_boss():
			var top_left := monster.head_position() - monster.global_position + Vector2(-HP_BAR_WIDTH * 0.5, -6.0)
			draw_rect(Rect2(top_left - Vector2.ONE, Vector2(HP_BAR_WIDTH + 2.0, 6.0)), Color("3f2631"))
			draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH * monster.hp / monster.get_max_hp(), 4.0)), Color("e84537"))


## Red warning: the area of a skill being cast, the cone of a melee swing, the line of a shot.
func _draw_telegraph() -> void:
	var telegraph := monster.telegraph
	var weapon := monster.get_weapon()
	var warning := Color(1.0, 0.2, 0.2, 0.15 + 0.35 * telegraph)
	var skill := monster.casting_skill()
	if skill:
		# Casting: circle showing the area (if any), filling up until it goes off.
		if skill.telegraph_radius > 0.0:
			draw_circle(Vector2.ZERO, skill.telegraph_radius, Color(1.0, 0.2, 0.2, 0.12))
			if skill.telegraph_radius * telegraph > 1.0:
				draw_circle(Vector2.ZERO, skill.telegraph_radius * telegraph, warning)
			draw_arc(Vector2.ZERO, skill.telegraph_radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.7), 2.0)
		return
	if weapon and weapon.kind == WeaponDef.Kind.MELEE:
		# Red cone showing where the hit will land.
		var reach := (monster.radius + weapon.reach) * telegraph
		if reach < 2.0:
			return
		if weapon.arc_degrees >= 359.0:
			draw_circle(Vector2.ZERO, reach, warning)
			return
		var half := deg_to_rad(weapon.arc_degrees) * 0.5
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			points.append(Vector2.from_angle(monster.facing.angle() - half + half * 2.0 * i / 12.0) * reach)
		draw_colored_polygon(points, warning)
	else:
		# Aiming line for ranged attacks.
		var length := (weapon.reach if weapon else 200.0) * 0.6
		draw_line(Vector2.ZERO, monster.facing * length, warning, 2.0 + 3.0 * telegraph)


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
