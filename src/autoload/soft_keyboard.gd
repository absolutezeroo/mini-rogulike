extends CanvasLayer
## Typing on a phone (autoload "SoftKeyboard"): while the phone's own keyboard is up over any text
## field (LineEdit, TextEdit), the field is shown in a bar of its own, readable, in the part of the
## screen the keyboard leaves free; the rest of the game is hidden behind it.
##
## Why. Godot's Android activity is `adjustResize`: the keyboard shrinks the game's window to the
## strip above it (2340x1080 becomes about 2340x480 on a phone held sideways). PixelGrid would read
## a 480-line screen and scale the whole UI down (x0.67 instead of x1.5), and the dialogs laid out
## for 720 lines would squeeze into it: the words typed came out a few pixels tall. So PixelGrid
## asks is_keyboard_resize() and keeps the scale it had before the keyboard; the dialog no longer
## fits the strip, so this bar takes its place until the keyboard goes: the field's name (the
## dialog's title), its hint, the words as typed with the caret, at BODY size, and OK (which puts
## the keyboard away and gives the dialog back). Where the window is not resized (the keyboard
## drawn over the game), the bar sits above the keyboard's height instead.
##
## The field keeps the focus all along (the keyboard types into it): the bar only mirrors it, and
## its backdrop takes the taps, so nothing under it steals the focus. Desktop (no virtual keyboard)
## never shows it. A field can name itself (TITLE_META), give a hint (HINT_META, else its
## placeholder) and a length limit (MAX_META, else a LineEdit's max_length).

## The bar was shown or put away.
signal changed(up: bool)

## Above every menu (10), the hints, the feedback note (120).
const LAYER := 126
## A window this much shorter (same width) while a field is being typed in: the keyboard's doing.
const SHRUNK := 0.92
## The bar's margin from the strip's edges, and the gap between its lines (UI units).
const MARGIN := 16
const GAP := 8
const OK_SIZE := Vector2(200, 52)
## Behind the bar: the game, almost hidden.
const BACKDROP := Color(0.03, 0.02, 0.05, 0.94)
## The caret drawn in the mirrored words.
const CARET := "|"
## Metadata a field may carry: its name over the bar, a hint under it, its length limit.
const TITLE_META := &"entry_title"
const HINT_META := &"entry_hint"
const MAX_META := &"entry_max_length"

## Tests: a phone's keyboard this many screen pixels tall (0: hidden); -1 uses the real one
## (none on a computer).
var fake_height := -1

var _field: Control
var _up := false
var _screen: Control
var _box: Control
var _title: Label
var _counter: Label
var _hint: Label
var _words: Label


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_screen.hide()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().root.size_changed.connect(_update)
	set_process(false)


## This device types with a keyboard drawn on its screen (a phone, a tablet; or a test's fake).
func has_virtual_keyboard() -> bool:
	if fake_height >= 0:
		return true
	return DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.is_touchscreen_available()


## The keyboard's height in screen pixels (0 when it is hidden).
func keyboard_height() -> int:
	if fake_height >= 0:
		return fake_height
	if not has_virtual_keyboard():
		return 0
	return DisplayServer.virtual_keyboard_get_height()


## A text field has the focus (where the keyboard types).
func typing_field() -> Control:
	var owner_now := get_viewport().gui_get_focus_owner()
	if owner_now is LineEdit and (owner_now as LineEdit).editable:
		return owner_now
	if owner_now is TextEdit and (owner_now as TextEdit).editable:
		return owner_now
	return null


## The window went from `settled` (its size without a keyboard) to `size` because the phone's
## keyboard opened: same width, shorter, while a field is typed in. PixelGrid keeps its scale then.
## Also when the phone turned with the keyboard up: the settled size turned a quarter (its height
## now the width) and shorter than that. The game is held sideways (sensor landscape), so a turn is
## usually a half one (the same size, the first case); this one covers a device or a build that
## lets it stand upright, which would otherwise be read as a new, small screen until the keyboard
## goes. A change of width any other way (a foldable unfolding) is a real new window.
func is_keyboard_resize(size: Vector2i, settled: Vector2i) -> bool:
	if not has_virtual_keyboard() or typing_field() == null:
		return false
	if settled.x <= 0 or settled.y <= 0:
		return false
	if size.x == settled.x and size.y < settled.y * SHRUNK:
		return true
	return settled.x != settled.y and size.x == settled.y and size.y < settled.x * SHRUNK


## The bar is showing.
func is_up() -> bool:
	return _up


## The bar's board (tests check where it is and how big its words are).
func board() -> Control:
	return _box


## The label with the words as typed.
func words_label() -> Label:
	return _words


## OK: the words are typed; the keyboard goes and the dialog comes back.
func finish() -> void:
	var field := _field
	if field and is_instance_valid(field):
		field.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_update()


func _build() -> void:
	_screen = Control.new()
	_screen.name = "TextEntry"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var dim := ColorRect.new()
	dim.color = BACKDROP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # (a tap on the game under it would take the field's focus)
	_screen.add_child(dim)
	_box = PanelContainer.new()
	_box.name = "Board"
	_box.add_theme_stylebox_override("panel", UiSkin.panel())
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	_box.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	column.add_child(head)
	_title = _label(UiSkin.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_counter = _label(UiSkin.DIM)
	head.add_child(_counter)
	_hint = _label(UiSkin.DIM)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hint)
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", UiSkin.inset())
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(inset)
	_words = _label(UiSkin.TEXT)
	_words.name = "Words"
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_words.clip_text = true
	_words.custom_minimum_size.y = _words.get_line_height()
	inset.add_child(_words)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	var ok := UiParts.button(tr("OK"), finish, OK_SIZE, Fonts.BODY)
	ok.name = "OkButton"
	ok.focus_mode = Control.FOCUS_NONE  # (taking the focus would close the keyboard before OK is read)
	row.add_child(ok)


func _label(color: Color) -> Label:
	var label := UiSkin.label("", Fonts.BODY, color)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (given translated, or the player's words)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_focus_changed(_node: Control) -> void:
	_update()


func _process(_delta: float) -> void:
	_update()


## Shows or hides the bar, places it in the strip the keyboard leaves, and mirrors the field.
func _update() -> void:
	var field := typing_field() if has_virtual_keyboard() else null
	set_process(field != null)
	if field != _field:
		_watch(field)
	var covered := _covered_height()
	var up := field != null and field.is_visible_in_tree() and covered >= 0.0
	if up:
		_box.offset_left = MARGIN
		_box.offset_top = MARGIN
		_box.offset_right = -MARGIN
		_box.offset_bottom = -MARGIN - covered
		_mirror()
	if up != _up:
		_up = up
		_screen.visible = up
		changed.emit(up)


## How much of the canvas's bottom the keyboard hides, in UI units: 0 when the window was shrunk
## to the strip above it, its height when it is drawn over the game; -1 when it is not up.
func _covered_height() -> float:
	var root := get_tree().root
	var settled := PixelGrid.settled_size()
	if is_keyboard_resize(root.size, settled):
		return 0.0
	var height := keyboard_height()
	if height <= 0 or root.size.y <= 0:
		return -1.0
	var visible_height := get_viewport().get_visible_rect().size.y
	return minf(float(height) * visible_height / float(root.size.y), visible_height * 0.8)


func _watch(field: Control) -> void:
	_field = field
	if field == null:
		return
	_title.text = str(field.get_meta(TITLE_META)) if field.has_meta(TITLE_META) else _dialog_title(field)
	_title.visible = not _title.text.is_empty()
	var hint := ""
	if field.has_meta(HINT_META):
		hint = str(field.get_meta(HINT_META))
	elif field is LineEdit:
		hint = (field as LineEdit).placeholder_text
	elif field is TextEdit:
		hint = (field as TextEdit).placeholder_text
	_hint.text = hint
	_hint.visible = not hint.is_empty()


## The title of the dialog holding `field` (RpgDialog's ribbon), or nothing.
func _dialog_title(field: Control) -> String:
	var node := field.get_parent()
	while node:
		if node is RpgDialog and (node as RpgDialog).title_label:
			return (node as RpgDialog).title_label.text
		node = node.get_parent()
	return ""


## The words as typed, the caret where it is, the last lines kept in sight.
func _mirror() -> void:
	var text := ""
	var caret := 0
	var limit := 0
	if _field is LineEdit:
		var edit := _field as LineEdit
		text = edit.text
		if edit.secret:
			text = edit.secret_character.repeat(text.length())
		caret = edit.caret_column
		limit = edit.max_length
	elif _field is TextEdit:
		var area := _field as TextEdit
		text = area.text
		var line := area.get_caret_line()
		for i in line:
			caret += area.get_line(i).length() + 1
		caret += area.get_caret_column()
	if _field.has_meta(MAX_META):
		limit = int(_field.get_meta(MAX_META))
	caret = clampi(caret, 0, text.length())
	var shown := text.left(caret) + CARET + text.substr(caret)
	if _words.text != shown:
		_words.text = shown
	_counter.text = "%d / %d" % [text.length(), limit] if limit > 0 else ""
	_counter.visible = limit > 0
	var room := maxi(1, floori(_words.size.y / maxf(1.0, _words.get_line_height())))
	_words.lines_skipped = maxi(0, _words.get_line_count() - room)
