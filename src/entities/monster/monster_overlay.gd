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
	if overlay_layer == Layer.OVER:
		overlay.z_index = LightField.Z + 1  # names and health bars stay readable in the dark
	if overlay_layer == Layer.UNDER:
		overlay._telegraph = TelegraphView.new()
		overlay._telegraph.z_index = LightField.Z + 1  # a warning must show even in the dark
		overlay.add_child(overlay._telegraph)
	return overlay


func _process(delta: float) -> void:
	# Off screen nothing needs drawing (the telegraph still follows what the monster does).
	if monster.world and monster.world.view_rect().has_point(monster.global_position):
		queue_redraw()
	if _telegraph:
		_update_telegraph()
	# A shimmering rank (Shiny) sheds sparkles now and then.
	if layer == Layer.OVER and monster.rank and monster.rank.shimmer and not monster.is_dead and randf() < delta * 2.5:
		var at := monster.global_position + Vector2(randf_range(-1.0, 1.0) * monster.radius, -randf() * monster.head_height)
		Vfx.sparkles(monster.world, at, monster.rank.color)


func _draw() -> void:
	if monster.is_dead or monster.is_falling:
		return
	if layer == Layer.UNDER:
		if monster.rank:
			_draw_elite_aura()
		for monster_trait in monster.def.traits:
			monster_trait.draw_under(monster, self)
	else:
		if monster.ward > 0:
			monster.draw_ward(self)
		if monster.rank and not monster.is_boss():
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


## Pulsing rings of the rank's color at its feet (more rings for rarer ranks), and for the
## rarest a slow crown of rays.
func _draw_elite_aura() -> void:
	var time := Time.get_ticks_msec() * 0.001
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var color := monster.rank_color()
	var feet := monster.radius * 0.7 + 1.0
	draw_set_transform(Vector2(0, feet - 1.0), 0.0, Vector2(1.0, 0.45))
	color.a = 0.25 + 0.2 * pulse
	draw_circle(Vector2.ZERO, monster.radius + 6.0 + 2.0 * pulse, color)
	for ring in maxi(monster.rank.aura_rings, 1):
		var size := monster.radius + 6.0 + 2.0 * pulse + ring * 6.0
		draw_arc(Vector2.ZERO, size, 0.0, TAU, 28, Color(color, 0.8 - ring * 0.2), 2.0)
	if monster.rank.aura_rings >= 3:
		for i in 8:
			var angle := time * 0.8 + TAU * i / 8.0
			var inner := Vector2.from_angle(angle) * (monster.radius + 8.0)
			var outer := Vector2.from_angle(angle) * (monster.radius + 22.0 + 4.0 * pulse)
			draw_line(inner, outer, Color(color, 0.5), 2.0)
	draw_set_transform(Vector2.ZERO)


func _draw_elite_name() -> void:
	var font := Fonts.MAIN
	var font_size := 12
	var text := monster.display_name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := monster.head_position() - monster.global_position + Vector2(-text_size.x * 0.5, -12.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, monster.rank_color().lightened(0.3))
	# An Epic or Legendary: its affixes on a small line above.
	if monster.rank.show_in_name and monster.affixes.size() > 0:
		var line := monster.affix_names()
		var line_size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var line_at := at + Vector2((text_size.x - line_size.x) * 0.5, -12.0)
		draw_string_outline(font, line_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(0, 0, 0, 0.8))
		draw_string(font, line_at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
