class_name PseudonymDialog
extends RpgDialog
## "Name your soul": the pseudonym shown on the online leaderboards (Leaderboards, PlayerName),
## and "Show me in the leaderboards". Asked the first time the Leaderboards page opens or the
## Dawn Knell's official toll begins (Leaderboards.needs_name()), and from the Options. Typing
## takes a keyboard (on a phone, its own); with a gamepad the name can be kept as it is.
## Reachable as %NameEdit, %NameError, %ShowMeCheck, %ConfirmButton, %BackButton.

## Closed, whatever was chosen (the name set, kept, or the player hidden).
signal finished

const WIDTH := 640.0

var _edit: LineEdit
var _error: Label
var _show_me: CheckButton


func _init() -> void:
	super._init(TranslationServer.tr("Name your soul"), WIDTH, 0.8)
	hide()


func _ready() -> void:
	_build()


## Shows it with the current name.
func open() -> void:
	_edit.text = Leaderboards.display_name()
	_edit.max_length = Leaderboards.config.name_max
	_error.text = ""
	_show_me.set_pressed_no_signal(Leaderboards.shown)
	_edit.editable = Leaderboards.shown
	show()
	if not InputDevice.uses_buttons():
		_edit.grab_focus.call_deferred()


func _build() -> void:
	var lore := UiSkin.label(tr("The Well keeps the names of those who go down. Under which will yours be read?"), Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lore)
	var config := Leaderboards.config
	body.add_child(UiSkin.label(tr("Shown to every player on the leaderboards: %d to %d letters, digits, spaces and - _ . ' No email, nothing else about you is sent.") % [config.name_min, config.name_max], Fonts.BODY, UiSkin.TEXT, true))
	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(0, 52)
	_edit.add_theme_font_size_override("font_size", Fonts.BODY)
	_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_edit.text_submitted.connect(func(_text: String) -> void: _confirm())
	_edit.text_changed.connect(func(_text: String) -> void: _error.text = "")
	body.add_child(_edit)
	_own(_edit, "NameEdit")
	_error = UiSkin.label("", Fonts.BODY, MenuWindow.BAD, true)
	body.add_child(_error)
	_own(_error, "NameError")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiSkin.label(tr("Show me in the leaderboards"), Fonts.BODY, UiSkin.TEXT, true))
	words.add_child(UiSkin.label(tr("Off: none of your scores is ever sent."), Fonts.BODY, UiSkin.DIM, true))
	row.add_child(words)
	_show_me = CheckButton.new()
	_show_me.custom_minimum_size = Vector2(MenuWindow.SWITCH_SIZE.x + 8, 40)
	_show_me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuWindow.style_switch(_show_me)
	_show_me.toggled.connect(func(on: bool) -> void:
		_edit.editable = on
		Sfx.play_ui(Sfx.bank.ui_click))
	row.add_child(_show_me)
	_own(_show_me, "ShowMeCheck")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)
	var confirm := UiParts.button(tr("Confirm"), _confirm, Vector2(0, 56), Fonts.BODY)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(confirm)
	_own(confirm, "ConfirmButton")
	var back := UiParts.button(tr("Back"), cancel, Vector2(160, 56), Fonts.BODY)
	buttons.add_child(back)
	_own(back, "BackButton")
	MenuNav.set_first(self, confirm)


## The name set (or the player hidden): closes. A refused name says why and stays open.
func _confirm() -> void:
	if not _show_me.button_pressed:
		Leaderboards.set_shown(false)
		_close()
		return
	if not Leaderboards.shown:
		Leaderboards.set_shown(true)
	var text := PlayerName.tidy(_edit.text)
	if text == Leaderboards.display_name() and Leaderboards.pseudonym.is_empty():
		Leaderboards.keep_default_name()
		_close()
		return
	var problem := Leaderboards.set_pseudonym(text)
	if problem != PlayerName.Problem.NONE:
		_error.text = PlayerName.explain(problem, Leaderboards.config)
		Sfx.play_ui(Sfx.bank.ui_close)
		return
	_close()


## Back: the name stays as it was (the default one is kept: not asked again).
func cancel() -> void:
	if not Leaderboards.name_chosen:
		Leaderboards.keep_default_name()
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	finished.emit()


func _close() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	hide()
	finished.emit()


func _own(node: Node, node_name: String) -> void:
	node.name = node_name
	node.owner = self
	node.unique_name_in_owner = true
