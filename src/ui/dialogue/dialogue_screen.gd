class_name DialogueScreen
extends Control
## A conversation over the screen (the Vigil-Keeper at the shrine): the screen dimmed a little,
## a DialogueBox (PAGED) low in the middle, a tap anywhere, Enter or A going on page by page,
## Back (Escape, B, the phone's back button: the screen's own back()) closing it at once. When the
## last page is read on, it closes. A menu for keys and gamepads (MenuNav): what was focused
## under it gets the focus back. Built in code.

signal closed

const WIDTH := 980.0
## Room left under the box (the screen's bottom edge).
const BOTTOM := 36.0

var box: DialogueBox

var _dim: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(MenuNav.GROUP)
	hide()
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.03, 0.02, 0.05, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	box = DialogueBox.new(DialogueBox.Mode.PAGED, WIDTH)
	box.name = "DialogueBox"
	box.add_theme_stylebox_override("panel", UiSkin.panel())
	box.focus_mode = Control.FOCUS_ALL
	box.finished.connect(close)
	add_child(box)
	resized.connect(_place)
	box.resized.connect(_place)


## Says `spoken` (one or more lines, Dialogues.Spoken) over the screen.
func open(spoken: Array[Dialogues.Spoken]) -> void:
	show()
	box.say(spoken)
	_place.call_deferred()
	if InputDevice.uses_buttons():
		box.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


func _place() -> void:
	var width := minf(WIDTH, size.x - 48.0)
	box.custom_minimum_size.x = width
	box.size = Vector2(width, box.get_combined_minimum_size().y)
	box.position = Vector2(roundf((size.x - width) * 0.5), roundf(size.y - box.size.y - BOTTOM))


func _on_dim_input(event: InputEvent) -> void:
	var tapped := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped:
		box.tap()
		_dim.accept_event()
