class_name ThresholdHud
extends Control
## The trial of the Threshold on screen (see Threshold): its name and rule across the screen when
## the hero arrives, then at the top a big countdown and the spectres slain so far. The countdown
## turns red and beats in its last seconds. Built in code; the Hud shows it while the trial is on.

## Seconds left when the countdown turns red.
const URGENT := 10.0
const PANEL_COLOR := Color(0.03, 0.04, 0.1, 0.72)
const CARD_TIME := 2.6

var threshold: Threshold

var _counters: PanelContainer
var _kills_label: Label
var _time_label: Label
var _card: VBoxContainer
var _title: Label
var _rule: Label
var _card_tween: Tween
## The name and rule are up (from the start of their fade in to the end of their fade out).
var _card_on := false
var _last_second := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_counters()
	_build_card()
	hide()


func _build_counters() -> void:
	_counters = PanelContainer.new()
	_counters.name = "ThresholdCounters"
	_counters.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	_counters.add_theme_stylebox_override("panel", style)
	_counters.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_counters.grow_horizontal = GROW_DIRECTION_BOTH
	_counters.offset_top = 10.0
	add_child(_counters)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_counters.add_child(row)
	_kills_label = _label(30, 6)
	_kills_label.name = "ThresholdKills"
	row.add_child(_kills_label)
	_time_label = _label(46, 8)
	_time_label.name = "ThresholdTime"
	_time_label.custom_minimum_size.x = 110.0
	row.add_child(_time_label)


func _build_card() -> void:
	_card = VBoxContainer.new()
	_card.name = "ThresholdCard"
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_card.grow_horizontal = GROW_DIRECTION_BOTH
	_card.offset_left = -420.0
	_card.offset_right = 420.0
	_card.offset_top = 104.0
	_card.add_theme_constant_override("separation", 2)
	add_child(_card)
	_title = _label(52, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_title)
	_rule = _label(26, 6)
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_rule)
	_card.modulate.a = 0.0


func _label(size: int, outline: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.06))
	label.add_theme_constant_override("outline_size", outline)
	return label


## The trial begins: its name and rule across the screen, the counters at the top.
func open(trial: ThresholdDef, needed: int) -> void:
	var color := trial.color
	(_counters.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(color, 0.8)
	_kills_label.add_theme_color_override("font_color", color)
	_title.add_theme_color_override("font_color", color)
	_title.text = tr(trial.display_name)
	var rule := tr("Slay %d spectre before the knell") if needed == 1 else tr("Slay %d spectres before the knell")
	_rule.text = rule % needed
	_last_second = -1
	set_progress(0, needed)
	_refresh_time()
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


## The countdown and kills panel ("ThresholdCounters").
func counters() -> Control:
	return _counters


func set_progress(kills: int, needed: int) -> void:
	_kills_label.text = tr("Slain %d / %d") % [kills, needed]
	if kills > 0:
		_kills_label.pivot_offset = _kills_label.size * 0.5
		_kills_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_kills_label, "scale", Vector2.ONE, 0.2)


func close() -> void:
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card_on = false
	hide()


## The name and rule are on screen (hints wait for them).
func is_card_showing() -> bool:
	return visible and _card_on


func _process(_delta: float) -> void:
	if visible:
		_refresh_time()


func _refresh_time() -> void:
	if threshold == null:
		return
	var seconds := ceili(threshold.time_left)
	if seconds == _last_second:
		return
	_last_second = seconds
	_time_label.text = tr("%d s") % seconds
	var urgent := threshold.time_left <= URGENT
	_time_label.add_theme_color_override("font_color", Palette.DANGER if urgent else Color(0.95, 0.97, 1.0))
	if urgent and threshold.is_fighting() and seconds > 0:
		# Each second of the last ten beats.
		_time_label.pivot_offset = _time_label.size * 0.5
		_time_label.scale = Vector2.ONE * 1.3
		create_tween().tween_property(_time_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
