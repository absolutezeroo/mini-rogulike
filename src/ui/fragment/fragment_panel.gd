class_name FragmentPanel
extends Control
## A fragment of the past, read (FragmentDef): in the game's skin (RpgDialog), its title on the
## ribbon, its picture, who wrote it and where, its lines, and whose chronicle keeps it now.
## The game is paused while it is open; a tap anywhere (or Back, or the button) closes it.
## The codex opens the same panel to read a found fragment again. Built in code.

signal closed

const WIDTH := 780.0
## Taps this few frames after it opened are not for it (about a quarter of a second).
const OPEN_GRACE_FRAMES := 15

var _dialog: RpgDialog
var _icon: TextureRect
var _source: Label
var _place: Label
var _lines: VBoxContainer
var _kept: Label
var _close: Button
var _named: Array[Node] = []
var _opened_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## Shows `fragment` (about `boss`; `first_time`: just found, "Kept in the chronicle of ...").
func open(fragment: FragmentDef, boss: BossDef, first_time: bool = false) -> void:
	_dialog.set_title(tr(fragment.title), UiSkin.GOLD)
	var look := fragment.look
	_icon.texture = look.icon if look else null
	_icon.modulate = look.icon_tint if look else Color.WHITE
	_icon.visible = _icon.texture != null
	_source.text = tr(fragment.author)
	_place.text = tr(fragment.place)
	_place.visible = not fragment.place.is_empty()
	UiParts.clear(_lines)
	for line in fragment.lines:
		_lines.add_child(UiSkin.label(tr(line), Fonts.BODY, UiSkin.TEXT, true))
	_kept.visible = boss != null
	if boss:
		var name := tr(boss.display_name)
		_kept.text = tr("A new page for its chronicle: %s.") % name if first_time else tr("From its chronicle: %s.") % name
	_opened_at = Engine.get_process_frames()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The lines shown (tests).
func lines_text() -> PackedStringArray:
	var result := PackedStringArray()
	for label: Label in _lines.get_children():
		result.append(label.text)
	return result


func board_rect() -> Rect2:
	return _dialog.board_rect()


## Any tap, click or key closes it (not in its first moments: the tap that opened it).
func _input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() - _opened_at < OPEN_GRACE_FRAMES:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.is_echo()) or (event is InputEventJoypadButton and event.pressed)
	if press:
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_dialog = RpgDialog.new("", WIDTH)
	_dialog.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_dialog)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_dialog.body.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	top.add_child(words)
	_source = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_source.name = "Source"
	words.add_child(_source)
	_place = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_place.name = "Place"
	words.add_child(_place)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override("separation", 6)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	words.add_child(gap)
	words.add_child(_lines)
	_kept = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	_kept.name = "Kept"
	_dialog.body.add_child(_kept)
	_close = MenuWindow.button(tr("Close"), Fonts.BODY, 48)
	_close.name = "CloseButton"
	_close.custom_minimum_size.x = 200
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	_dialog.body.add_child(_close)
	for node: Node in [_source, _place, _lines, _kept, _close]:
		_named.append(node)
		node.owner = self
		node.unique_name_in_owner = true
