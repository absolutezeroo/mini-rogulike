class_name ShrineKeeper
extends Button
## Who keeps vigil at the shrine, standing by the Well on the title screen (NarrativeDef.
## shrine_speaker: the Vigil-Keeper): her body from her sheet at a whole scale, breathing on her
## two idle frames, her name under her, and a speech bubble over her head while she has something
## she never said (Dialogues.has_new). A button: a tap, a click, or the focus and Enter / A open
## her words (TitleScreen.talk_to_keeper()). Built in code.

## Screen pixels per art pixel (the hero beside her is drawn at x4 too).
const SCALE := 4.0
const CELL := 16.0
## Seconds per idle frame.
const BREATH := 0.7
const BUBBLE: Texture2D = preload("res://assets/ui/emotes/emote20.png")

var speaker: SpeakerDef
## Something new to say: the bubble shows.
var has_news := false:
	set(value):
		has_news = value
		queue_redraw()

var _time := 0.0
var _name: Label


func _init(who: SpeakerDef = null) -> void:
	speaker = who
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(150, 118)
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_name = UiSkin.label(tr(speaker.display_name) if speaker else "", Fonts.BODY, speaker.color if speaker else UiSkin.GOLD)
	_name.name = "KeeperName"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_name.offset_top = -26
	add_child(_name)
	tooltip_text = tr(speaker.title) if speaker else ""


## Where her feet stand, inside the button (her figure is drawn up from there).
func feet() -> Vector2:
	return Vector2(size.x * 0.5, size.y - 28.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if speaker == null or speaker.figure == null:
		return
	var frame := int(_time / BREATH) % 2
	var rows := int(speaker.figure.get_height() / CELL)
	var cell := Rect2(0.0, CELL * (frame % maxi(rows, 1)), CELL, CELL)
	var drawn := Vector2(CELL, CELL) * SCALE
	var at := (feet() - Vector2(drawn.x * 0.5, drawn.y)).floor()
	draw_texture_rect_region(speaker.figure, Rect2(at, drawn), cell)
	if has_news:
		var bob := 0.0 if fmod(_time, 1.2) < 0.6 else -SCALE * 0.5
		var bubble := BUBBLE.get_size() * 2.0
		draw_texture_rect(BUBBLE, Rect2((at + Vector2(drawn.x * 0.62, -bubble.y * 0.55 + bob)).floor(), bubble), false)
