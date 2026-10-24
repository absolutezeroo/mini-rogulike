class_name AbyssHud
extends HudEventCard
## The Deeps on screen (see Abyss): their name and rule across the screen when the hero lands
## (HudEventCard),
## then at the top the way out's name and the seconds left for the dawn's gift, and an arrow of
## light circling the hero, pointing toward the Dawn Breach while it is out of sight (a phone
## screen is small and the Deeps are dark; by the hero it is never under a thumb or a button). Built in code; the Hud shows it while the hero
## is down there (not while the Threshold has him).

const PANEL_COLOR := Color(0.06, 0.02, 0.03, 0.72)
## The arrow circles the hero this far from him (screen pixels).
const ARROW_RADIUS := 84.0
## The door counts as in sight this far inside the screen's edges (pixels).
const SIGHT_MARGIN := 60.0
## One art pixel of the arrow, in screen pixels (the camera's 1.5 zoom on a 2-unit art pixel).
const ARROW_PX := 3.0

var abyss: Abyss

var _door_label: Label
var _gift_label: Label
var _arrow: Arrow
var _last_second := -1


func _ready() -> void:
	_init_card_hud(Color(0.06, 0.01, 0.02))
	_arrow = Arrow.new()
	_arrow.name = "AbyssArrow"
	_arrow.hud = self
	_arrow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arrow.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_build_door_banner()
	_build_card("AbyssCard")
	hide()


func _build_door_banner() -> void:
	var row := _build_banner("AbyssBanner", PANEL_COLOR)
	_door_label = _label(Fonts.BODY)
	_door_label.name = "AbyssDoorName"
	row.add_child(_door_label)
	_gift_label = _label(Fonts.BODY)
	_gift_label.name = "AbyssGift"
	_gift_label.add_theme_color_override("font_color", Palette.GOLD)
	row.add_child(_gift_label)


## He landed: the name and rule across the screen, the way out's name at the top.
func open(def: AbyssDef) -> void:
	set_banner_color(def.color)
	_door_label.text = tr(def.door_name)
	_door_label.add_theme_color_override("font_color", def.return_veil_color)
	_last_second = -1
	_refresh_gift()
	_show_card(tr(def.display_name), tr("Find the Dawn Breach. The demons will not wait."), def.color)


## The top panel (the tutorial points at it).
func banner() -> Control:
	return _banner


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
	_arrow.refresh()


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
	## What was last drawn: whether it pointed, its angle and its tip (screen pixels).
	var _drawn_pointing := false
	var _drawn_angle := 0.0
	var _drawn_tip := Vector2.INF
	## The chevron's cells for _mask_key (offsets from the grid cell under the tip) and colors:
	## worked out again only when the angle or the tip's place inside its grid cell changes.
	var _mask_key := Vector3.INF
	var _cells := PackedVector2Array()
	var _colors := PackedColorArray()

	## Every frame (AbyssHud._process): drawn again only when it turns, breathes or moves.
	func refresh() -> void:
		var pointing := hud != null and hud.is_pointing()
		var angle := 0.0
		var tip := Vector2.INF
		if pointing:
			angle = _angle()
			tip = _tip(angle)
		if pointing == _drawn_pointing and angle == _drawn_angle and tip == _drawn_tip:
			return
		_drawn_pointing = pointing
		_drawn_angle = angle
		_drawn_tip = tip
		queue_redraw()

	## The nearest of 16 directions toward the door.
	func _angle() -> float:
		return snappedf((hud.door_on_screen() - hud.hero_on_screen()).normalized().angle(), TAU / 16.0)

	## Its point, a pixel out on the beat (twice a second).
	func _tip(angle: float) -> Vector2:
		var beat := 1.0 if fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0) < 0.5 else 0.0
		return hud.hero_on_screen() + Vector2.from_angle(angle) * (ARROW_RADIUS + beat * ARROW_PX)

	func _draw() -> void:
		if hud == null or not hud.is_pointing():
			return
		var angle := _angle()
		var tip := _tip(angle)
		var origin := (tip / ARROW_PX).floor() * ARROW_PX
		var offset := tip - origin
		if Vector3(angle, offset.x, offset.y) != _mask_key:
			_mask_key = Vector3(angle, offset.x, offset.y)
			_build_mask(angle, offset)
		for i in _cells.size():
			draw_rect(Rect2(origin + _cells[i], Vector2.ONE * ARROW_PX), _colors[i])

	## Each screen cell of the art's grid around the tip (`offset`: the tip inside its own cell):
	## in the chevron (a triangle pointing along +x, its middle cut out, turned by `angle`), on its
	## dark rim, or neither.
	func _build_mask(angle: float, offset: Vector2) -> void:
		var holy := VfxElementDef.named(&"holy")
		_cells.clear()
		_colors.clear()
		for dy in range(-15, 16):
			for dx in range(-15, 16):
				var cell := Vector2(dx, dy) * ARROW_PX
				var local := (cell + Vector2.ONE * ARROW_PX * 0.5 - offset).rotated(-angle) / ARROW_PX
				var inside := _inside(local)
				if not inside and not _inside(local + Vector2(1, 0)) and not _inside(local + Vector2(-1, 0)) \
						and not _inside(local + Vector2(0, 1)) and not _inside(local + Vector2(0, -1)):
					continue
				var color := holy.edge()
				if inside:
					color = holy.core() if -local.x < 5.0 else holy.shade(0.25)
				_cells.append(cell)
				_colors.append(color)


	## In the arrowhead (local art pixels, the tip at 0 pointing along +x): a narrow wedge 13
	## pixels long, a swallowtail notch cut from behind.
	static func _inside(local: Vector2) -> bool:
		var depth := -local.x
		var spread := depth * 0.5
		if depth < -0.5 or depth > 13.0 or absf(local.y) > spread + 0.5:
			return false
		return not (depth > 8.5 and absf(local.y) < (depth - 8.5) * 1.1)
