class_name ActCard
extends Control
## Title card shown on black when an act begins: "Act II", its name and a line of story.
## Any tap or key skips it.

signal finished

const FADE_TIME := 0.4
const HOLD_TIME := 2.4

var _skip := false
var _gate := TapGate.new()

@onready var _subtitle: Label = %Subtitle
@onready var _title: Label = %Title
@onready var _lore: Label = %Lore


func _ready() -> void:
	hide()


## Shows the card for `act` and returns when it is gone (await it).
func play(act: ActDef) -> void:
	_subtitle.text = tr(act.subtitle)
	_title.text = tr(act.title)
	_lore.text = tr(act.lore)
	_skip = false
	modulate.a = 0.0
	show()
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	await fade_in.finished
	var time := 0.0
	while time < HOLD_TIME and not _skip:
		await get_tree().process_frame
		time += get_process_delta_time()
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade_out.finished
	hide()
	finished.emit()


## Any tap, click, key or button skips it (TapGate: never the wheel, one finger once).
func _input(event: InputEvent) -> void:
	var read := _gate.read(event, visible)
	if read == TapGate.IGNORE:
		return
	get_viewport().set_input_as_handled()
	if read == TapGate.TAKE:
		_skip = true
