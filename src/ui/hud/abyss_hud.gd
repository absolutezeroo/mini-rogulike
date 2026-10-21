class_name AbyssHud
extends Control
## The Deeps on screen (see Abyss): their name and rule across the screen when the hero lands,
## then at the top the way out's name and the seconds left for the dawn's gift, and an arrow of
## light circling the hero, pointing toward the Dawn Breach while it is out of sight (a phone
## screen is small and the Deeps are dark; by the hero it is never under a thumb or a button). Built in code; the Hud shows it while the hero
## is down there (not while the Threshold has him).

const PANEL_COLOR := Color(0.06, 0.02, 0.03, 0.72)
const CARD_TIME := 2.6
## The arrow circles the hero this far from him (screen pixels).
const ARROW_RADIUS := 84.0
## The door counts as in sight this far inside the screen's edges (pixels).
const SIGHT_MARGIN := 60.0
## One art pixel of the arrow, in screen pixels (the camera's 1.5 zoom on a 2-unit art pixel).
const ARROW_PX := 3.0

var abyss: Abyss

var _banner: PanelContainer
var _door_label: Label
var _gift_label: Label
var _card: VBoxContainer
var _title: Label
var _rule: Label
var _card_tween: Tween
var _card_on := false
var _arrow: Arrow
var _last_second := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_arrow = Arrow.new()
	_arrow.name = "AbyssArrow"
	_arrow.hud = self
	_arrow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arrow.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_build_banner()
	_build_card()
	hide()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "AbyssBanner"
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	_banner.add_theme_stylebox_override("panel", style)
	_banner.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_banner.grow_horizontal = GROW_DIRECTION_BOTH
	_banner.offset_top = 10.0
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_door_label = _label(Fonts.BODY)
	_door_label.name = "AbyssDoorName"
	row.add_child(_door_label)
	_gift_label = _label(Fonts.BODY)
	_gift_label.name = "AbyssGift"
	_gift_label.add_theme_color_override("font_color", Palette.GOLD)
	row.add_child(_gift_label)


func _build_card() -> void:
	_card = VBoxContainer.new()
	_card.name = "AbyssCard"
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_card.grow_horizontal = GROW_DIRECTION_BOTH
	_card.offset_left = -420.0
	_card.offset_right = 420.0
	_card.offset_top = 104.0
	_card.add_theme_constant_override("separation", 2)
	add_child(_card)
	_title = _label(Fonts.HUGE)
	_card.add_child(_title)
	_rule = _label(Fonts.TITLE)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_rule)
	_card.modulate.a = 0.0


func _label(size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.01, 0.02))
	label.add_theme_constant_override("outline_size", Fonts.outline_size(size))
	return label


## He landed: the name and rule across the screen, the way out's name at the top.
func open(def: AbyssDef) -> void:
	(_banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(def.color, 0.8)
	_title.add_theme_color_override("font_color", def.color)
	_title.text = tr(def.display_name)
	_rule.text = tr("Find the Dawn Breach. The demons will not wait.")
	_door_label.text = tr(def.door_name)
	_door_label.add_theme_color_override("font_color", def.return_veil_color)
	_last_second = -1
	_refresh_gift()
	show()
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card_on = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.35)
	_card_tween.tween_interval(CARD_TIME)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	_card_tween.tween_callback(func() -> void: _card_on = false)


func close() -> void:
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card_on = false
	hide()


## The top panel (the tutorial points at it).
func banner() -> Control:
	return _banner


## The name and rule are on screen (hints wait for them).
func is_card_showing() -> bool:
	return visible and _card_on


## Where the door is on screen (the canvas' coordinates), or INF when there is none to point at.
func door_on_screen() -> Vector2:
	if abyss == null or abyss.depths == null or abyss.depths.door == null or not abyss.depths.door.is_inside_tree():
		return Vector2.INF
	return abyss.depths.door.get_global_transform_with_canvas().origin + Vector2(0, -AbyssDoor.HEIGHT * 0.5)


## Where the hero's middle is on screen, or INF.
func hero_on_screen() -> Vector2:
	var hero := abyss.game.player if abyss and abyss.game else null
	if hero == null or not hero.is_inside_tree():
		return Vector2.INF
	return hero.get_global_transform_with_canvas().origin + Vector2(0, -14)


## The arrow is showing (the door is out of sight).
func is_pointing() -> bool:
	var target := door_on_screen()
	if not visible or not _arrow.visible or target == Vector2.INF or hero_on_screen() == Vector2.INF:
		return false
	return not get_viewport_rect().grow(-SIGHT_MARGIN).has_point(target)


func _process(_delta: float) -> void:
	if not visible:
		return
	# Not while the Threshold has him (its own screen shows then).
	var here := abyss != null and abyss.game != null and abyss.holds(abyss.game.player)
	_banner.visible = here
	_arrow.visible = here
	_refresh_gift()
	_arrow.queue_redraw()


func _refresh_gift() -> void:
	if abyss == null or abyss.def == null or abyss.game == null or abyss.game.world == null:
		return
	var left := abyss.def.quick_time_for(abyss.game.world.depth, abyss.game.content.dungeon) - abyss.time_in
	var seconds := ceili(left)
	if seconds == _last_second:
		return
	_last_second = seconds
	_gift_label.visible = left > 0.0
	_gift_label.text = tr("Dawn's gift: %d s") % maxi(seconds, 0)


## The arrow of light circling the hero toward the Dawn Breach while it is out of sight: a
## pointed chevron in holy's ramp, cut in whole art pixels at the nearest of 16 directions (never a
## turned sprite), its dark rim reading on any floor, breathing a pixel in and out.
class Arrow extends Control:
	var hud: AbyssHud

	func _draw() -> void:
		if hud == null or not hud.is_pointing():
			return
		var hero := hud.hero_on_screen()
		var toward := (hud.door_on_screen() - hero).normalized()
		var angle := snappedf(toward.angle(), TAU / 16.0)
		var direction := Vector2.from_angle(angle)
		var beat := 1.0 if fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0) < 0.5 else 0.0
		var tip := hero + direction * (ARROW_RADIUS + beat * ARROW_PX)
		var holy := VfxElementDef.named(&"holy")
		# Each screen cell of the art's grid around the tip: in the chevron (a triangle pointing
		# along +x, its middle cut out, turned by `angle`), on its dark rim, or neither.
		var origin := (tip / ARROW_PX).floor() * ARROW_PX
		for dy in range(-15, 16):
			for dx in range(-15, 16):
				var at := origin + Vector2(dx, dy) * ARROW_PX
				var local := (at + Vector2.ONE * ARROW_PX * 0.5 - tip).rotated(-angle) / ARROW_PX
				var inside := _inside(local)
				if not inside and not _inside(local + Vector2(1, 0)) and not _inside(local + Vector2(-1, 0)) \
						and not _inside(local + Vector2(0, 1)) and not _inside(local + Vector2(0, -1)):
					continue
				var color := holy.edge()
				if inside:
					color = holy.core() if -local.x < 5.0 else holy.shade(0.25)
				draw_rect(Rect2(at, Vector2.ONE * ARROW_PX), color)


	## In the arrowhead (local art pixels, the tip at 0 pointing along +x): a narrow wedge 13
	## pixels long, a swallowtail notch cut from behind.
	static func _inside(local: Vector2) -> bool:
		var depth := -local.x
		var spread := depth * 0.5
		if depth < -0.5 or depth > 13.0 or absf(local.y) > spread + 0.5:
			return false
		return not (depth > 8.5 and absf(local.y) < (depth - 8.5) * 1.1)
