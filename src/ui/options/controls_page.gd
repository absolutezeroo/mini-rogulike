class_name ControlsPage
extends VBoxContainer
## Options > Controls: what does what on the device in use, read-only. The controls of
## data/ui/input_prompts.tres in two columns, each with its keys and mouse buttons (PromptGlyph
## caps, every binding of the input map), its gamepad buttons in the pad's own names, or how it
## is done by touch. Picking up another device turns the page to it.

const ROW_HEIGHT := 32.0

var _heading: Label
var _note: Label
var _columns: HBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_heading = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	add_child(_heading)
	_note = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	add_child(_note)
	var box := UiSkin.section()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)
	var scroll := UiParts.scroll()
	box.add_child(scroll)
	_columns = HBoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 28)
	scroll.add_child(_columns)


func _ready() -> void:
	InputDevice.changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())


## Fills the page for the device in use.
func refresh() -> void:
	var kind := InputDevice.kind
	match kind:
		InputDevice.Kind.GAMEPAD:
			var pad := InputDevice.pad_glyphs()
			_heading.text = tr("Gamepad: %s") % tr(pad.brand) if pad else tr("Gamepad")
		InputDevice.Kind.KEYBOARD:
			_heading.text = tr("Keyboard and mouse")
		_:
			_heading.text = tr("Touch")
	_note.text = tr("The controls of the device in hand. Pick up another (a key, a gamepad, a touch) and this page follows.")
	UiParts.clear(_columns)
	var rows: Array[Array] = []
	for entry in Prompts.DATA.actions:
		if not entry.listed:
			continue
		if kind == InputDevice.Kind.TOUCH:
			if not entry.touch_text.is_empty():
				rows.append([entry, [] as Array[Dictionary]])
		else:
			var caps := Prompts.glyphs(entry.action, kind)
			if not caps.is_empty():
				rows.append([entry, caps])
	var half := ceili(rows.size() / 2.0)
	for part in [rows.slice(0, half), rows.slice(half)]:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		_columns.add_child(grid)
		for row: Array in part:
			_add_row(grid, row[0], row[1])


## The rows shown (tests): [the control's words, what does it] per row.
func rows_text() -> Array[PackedStringArray]:
	var found: Array[PackedStringArray] = []
	for grid in _columns.get_children():
		var cells := grid.get_children()
		for i in range(0, cells.size() - 1, 2):
			var how := cells[i + 1]
			var words := PackedStringArray()
			if how is Label:
				words.append((how as Label).text)
			else:
				for cap in how.get_children():
					var shown := (cap as PromptGlyph).cap() if cap is PromptGlyph else {}
					if not shown.is_empty():
						words.append(Prompts.DATA.mouse_glyph(shown.button) if shown.shape == Prompts.Shape.MOUSE else str(shown.text))
			found.append(PackedStringArray([(cells[i] as Label).text, " ".join(words)]))
	return found


func _add_row(grid: GridContainer, entry: ActionPromptDef, caps: Array[Dictionary]) -> void:
	var name_label := UiSkin.label(tr(entry.display_name), Fonts.BODY)
	name_label.custom_minimum_size.y = ROW_HEIGHT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	if caps.is_empty():
		var how := UiSkin.label(tr(entry.touch_text), Fonts.BODY, UiSkin.DIM, true)
		how.custom_minimum_size.x = 260
		grid.add_child(how)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	for cap in caps:
		var glyph := PromptGlyph.new()
		glyph.fixed = cap
		row.add_child(glyph)
	grid.add_child(row)
