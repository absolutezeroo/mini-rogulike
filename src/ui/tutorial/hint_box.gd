class_name HintBox
extends Control
## A tutorial hint on screen (see Tutorial): a small wooden board at the top, its title in gold,
## what to do, an OK button; when the hint is about a control of the HUD, a ring pulses around
## that control and an arrow points at it.

signal dismissed

const WIDTH := 560.0
const TOP := 12.0
## Lower, when the boss bar takes the top of the screen.
const TOP_UNDER_BOSS_BAR := 84.0
const RING_COLOR := Color(1.0, 0.85, 0.35)

## The control pointed at (screen rect); empty: none.
var target := Rect2()
## Pushed down under the boss bar (the Hud says when).
var lowered := false:
	set(value):
		lowered = value
		_place()

var _board: PanelContainer
var _title: Label
var _text: Label
var _time := 0.0
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = PanelContainer.new()
	var style := UiSkin.panel()
	style.content_margin_left = 20
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_board.add_theme_stylebox_override("panel", style)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_on_board_input)
	add_child(_board)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_board.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	_title = UiSkin.label("", 20, UiSkin.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_text = UiSkin.label("", 16, UiSkin.TEXT, true)
	_text.custom_minimum_size.x = WIDTH - 140.0  # wraps at the board's width from the start
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	var ok := Button.new()
	ok.text = "OK"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(72, 48)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void: dismissed.emit())
	row.add_child(ok)
	hide()


func _ready() -> void:
	resized.connect(_place)


## `at`: the control it is about (screen rect), or an empty rect.
func show_hint(hint: HintDef, at: Rect2) -> void:
	_title.text = hint.title
	_text.text = hint.text
	target = at
	_time = 0.0
	show()
	_place.call_deferred()
	if _tween:
		_tween.kill()
	_board.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_board, "modulate:a", 1.0, 0.2)
	Sfx.play_ui(Sfx.bank.ui_open, -8.0)
	queue_redraw()


func hide_hint() -> void:
	if _tween:
		_tween.kill()
	hide()
	target = Rect2()


func shown_text() -> String:
	return _text.text


func _place() -> void:
	_board.size = Vector2(WIDTH, _board.get_combined_minimum_size().y)
	_board.position = Vector2(roundf((size.x - WIDTH) * 0.5), TOP_UNDER_BOSS_BAR if lowered else TOP)


func _process(delta: float) -> void:
	if visible and target.has_area():
		_time += delta
		queue_redraw()


func _on_board_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		accept_event()
		dismissed.emit()


## The ring around the control and the arrow pointing at it, from the middle of the screen.
func _draw() -> void:
	if not target.has_area():
		return
	var center := target.get_center()
	var radius := maxf(target.size.x, target.size.y) * 0.5 + 10.0
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_arc(center, radius + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.35 + 0.45 * pulse), 4.0)
	draw_arc(center, radius + 14.0 + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.15 * pulse), 2.0)
	var from := (size * 0.5 - center)
	var direction := from.normalized() if from.length() > 1.0 else Vector2.UP
	var tip := center + direction * (radius + 16.0 + pulse * 10.0)
	var side := direction.orthogonal() * 16.0
	var back := tip + direction * 26.0
	var shadow := Vector2(2, 3)
	draw_colored_polygon(PackedVector2Array([tip + shadow, back + side + shadow, back - side + shadow]), Color(0.1, 0.05, 0.03, 0.8))
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), RING_COLOR)
	draw_line(back, back + direction * 22.0, RING_COLOR, 7.0)
