class_name CurseCard
extends Control
## Shown on black when the hero arrives on a cursed floor (CurseDef): the Well's sigil forms out
## of drifting souls, then the curse's name, its story line and its rule appear. Any tap or key
## skips it.

signal finished

const FADE_TIME := 0.35
const HOLD_TIME := 3.4
const SOULS := 28

var curse: CurseDef

var _time := 0.0
var _skip := false
var _color := Color.WHITE

@onready var _header: Label = %Header
@onready var _title: Label = %Title
@onready var _lore: Label = %Lore
@onready var _rule: Label = %Rule


func _ready() -> void:
	hide()


## Shows the card for `cursed` and returns when it is gone (await it).
func play(cursed: CurseDef) -> void:
	curse = cursed
	_color = cursed.color
	_title.text = cursed.display_name
	_title.add_theme_color_override("font_color", _color)
	_lore.text = cursed.lore
	_rule.text = cursed.description
	for label: Label in [_header, _title, _lore, _rule]:
		label.modulate.a = 0.0
	_time = 0.0
	_skip = false
	modulate.a = 1.0
	show()
	Sfx.play_ui(Sfx.bank.boss_roar, -8.0)
	var reveal := create_tween()
	reveal.tween_interval(0.35)
	reveal.tween_property(_header, "modulate:a", 1.0, 0.4)
	reveal.tween_callback(_strike)
	reveal.tween_property(_title, "modulate:a", 1.0, 0.25)
	reveal.tween_property(_lore, "modulate:a", 1.0, 0.5)
	reveal.tween_property(_rule, "modulate:a", 1.0, 0.4)
	while _time < HOLD_TIME and not _skip:
		await get_tree().process_frame
	reveal.kill()
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade_out.finished
	hide()
	finished.emit()


## The curse lands: a jolt, a flash of its color.
func _strike() -> void:
	Sfx.play_ui(Sfx.bank.soul)
	Settings.vibrate(0.25)
	var punch := create_tween()
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * 1.35
	punch.tween_property(_title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## A violet haze, souls spiralling in, and the sigil turning in the curse's color.
func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.3)
	var grow := clampf(_time / 0.9, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	# Haze.
	for i in 6:
		var radius := size.y * (0.18 + i * 0.09) * (0.6 + 0.4 * grow)
		draw_circle(center, radius, Color(0.35, 0.12, 0.45, 0.07 * (6 - i) / 6.0))
	# Souls drawn into the sigil.
	for i in SOULS:
		var seed := float(i) * 12.9898
		var phase := fposmod(_time * 0.45 + fposmod(sin(seed) * 437.5, 1.0), 1.0)
		var distance := (1.0 - phase) * size.y * 0.45 + 30.0
		var angle := seed + phase * 5.0 + _time * 0.6
		var at := (center + Vector2.from_angle(angle) * distance).snapped(Vector2(3, 3))
		var alpha := sin(phase * PI) * 0.8
		draw_rect(Rect2(at, Vector2(4, 4)), Color(_color.lightened(0.4), alpha))
	# The sigil: two rings turning opposite ways, with runes, and an eye of the curse's color.
	var ring := 110.0 * grow
	if ring < 2.0:
		return
	var glow := Color(_color, 0.15 + 0.15 * pulse)
	draw_circle(center, ring * 1.15, glow)
	draw_arc(center, ring, 0.0, TAU, 64, Color(_color, 0.9), 4.0)
	draw_arc(center, ring * 0.72, 0.0, TAU, 48, Color(_color, 0.7), 3.0)
	for i in 12:
		var angle := _time * 0.5 + TAU * i / 12.0
		var at := center + Vector2.from_angle(angle) * ring * 0.86
		var rune := Rect2(at - Vector2(5, 5), Vector2(10, 10))
		draw_rect(rune, Color(_color.lightened(0.3), 0.85), i % 3 == 0)
	for i in 3:
		var angle := -_time * 0.8 + TAU * i / 3.0
		var a := center + Vector2.from_angle(angle) * ring * 0.72
		var b := center + Vector2.from_angle(angle + TAU / 3.0) * ring * 0.72
		draw_line(a, b, Color(_color, 0.6), 3.0)
	draw_circle(center, 14.0 + 4.0 * pulse, Color(_color.lightened(0.5), 0.95))
	draw_circle(center, 6.0, Color(0.05, 0.02, 0.08, 1.0))


func _input(event: InputEvent) -> void:
	if not visible or _time < 0.8:
		return
	var tapped := (event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed()
	if tapped:
		_skip = true
		get_viewport().set_input_as_handled()
