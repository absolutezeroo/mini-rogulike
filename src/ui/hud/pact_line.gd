class_name PactLine
extends VBoxContainer
## Under the minimap, while a pact's fight lasts (PactRoom): the pact's name and its rule's
## state ("Untouched", "18 s left", "Health lost: 12 / 40"), gold while it holds, red once
## broken, green once kept. The banner names the pact when the door seals; a banner and a toast
## say when it breaks (with its cost) and when it is kept. Listens to Events only.

const KEEP_SHOWN := 4.0
const HOLDING := Color(1.0, 0.82, 0.4)

## Where the toasts and the banner go.
var hud: Hud

var _pact: PactRoom
var _name: Label
var _state: Label
var _hide_in := -1.0


func _ready() -> void:
	name = "PactLine"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -420.0
	offset_right = -16.0
	offset_top = 300.0
	offset_bottom = 360.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 0)
	_name = _label(Fonts.BODY)
	_name.name = "PactName"
	_state = _label(Fonts.BODY)
	_state.name = "PactState"
	hide()
	Events.pact_started.connect(_on_started)
	Events.pact_broken.connect(_on_broken)
	Events.pact_ended.connect(_on_ended)
	Events.depth_changed.connect(func(_depth: int) -> void:
		_pact = null
		hide())


## The rule's state as shown (tests).
func state_text() -> String:
	return _state.text if visible else ""


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", Fonts.outline_size(font_size))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	return label


func _on_started(pact: PactRoom) -> void:
	_pact = pact
	_hide_in = -1.0
	_name.text = tr(pact.def.display_name)
	_name.add_theme_color_override("font_color", pact.def.color.lightened(0.2))
	_refresh()
	show()
	if hud:
		hud.show_banner(tr(pact.def.display_name), PactRoom.CRIMSON.lightened(0.35))


func _on_broken(pact: PactRoom) -> void:
	_refresh()
	if hud:
		hud.show_banner(tr("Pact broken"), UiParts.BAD)
		hud.toast(tr("-%d max Health for the rest of the run") % pact.hp_lost)


func _on_ended(pact: PactRoom) -> void:
	_refresh()
	_hide_in = KEEP_SHOWN
	if hud and pact.outcome == PactRoom.Outcome.KEPT:
		hud.show_banner(tr("Pact kept"), Palette.GOLD)
		hud.toast(tr("Pact kept: a relic is yours"))


func _process(delta: float) -> void:
	if not visible:
		return
	if _pact == null or not is_instance_valid(_pact):
		hide()
		return
	_refresh()
	if _hide_in >= 0.0:
		_hide_in -= delta
		if _hide_in < 0.0:
			hide()


func _refresh() -> void:
	if _pact == null or not is_instance_valid(_pact):
		return
	var text := ""
	var color := HOLDING
	match _pact.outcome:
		PactRoom.Outcome.KEPT:
			text = tr("Pact kept")
			color = UiParts.GOOD
		PactRoom.Outcome.BROKEN:
			text = tr("Broken: -%d max Health") % _pact.hp_lost
			color = UiParts.BAD
		_:
			text = _pact.rule.status_text() if _pact.rule else ""
	if _state.text != text:
		_state.text = text
	_state.add_theme_color_override("font_color", color)
