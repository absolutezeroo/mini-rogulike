class_name PseudonymDialog
extends RpgDialog
## "Name your soul": the explicit choice to publish one's scores online, and the pseudonym shown
## on the leaderboards (Leaderboards, PlayerName). Nothing reaches the server before this choice
## (docs/privacy-ops.md): it says plainly what is published and to whom, and offers "Don't
## publish" and "Publish my scores", side by side and the same size. Asked the first time the
## Leaderboards page opens or the Dawn Knell's official toll begins (Leaderboards.needs_name()),
## and from the Options (Change, or the page's button). Typing takes a keyboard (on a phone, its
## own); with a gamepad the name can be kept as it is.
## Reachable as %NameEdit, %NameError, %ConfirmButton (publish), %DeclineButton, %PolicyButton,
## %PolicyPanel.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload

## Closed, whatever was chosen (published under a name, or not).
signal finished

const WIDTH := 700.0

var policy: PrivacyPolicyPanel

var _edit: LineEdit
var _error: Label


func _init() -> void:
	super._init(TranslationServer.tr("Name your soul"), WIDTH, 0.8)
	hide()


func _ready() -> void:
	_build()
	policy = PrivacyPolicyPanel.new()
	add_child(policy)
	_own(policy, "PolicyPanel")


## Shows it with the current name.
func open() -> void:
	_edit.text = Leaderboards.display_name()
	_edit.max_length = Leaderboards.config.name_max
	_error.text = ""
	show()
	if not InputDevice.uses_buttons():
		_edit.grab_focus.call_deferred()


func _build() -> void:
	var lore := UiSkin.label(tr("The Well keeps the names of those who go down. Under which will yours be read?"), Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lore)
	var question := UiSkin.label(tr("Publish your scores online?"), Fonts.BODY, UiSkin.GOLD, true)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(question)
	var config := Leaderboards.config
	body.add_child(UiSkin.label(tr("If you publish, your Dawn Knell scores, a summary of each run and this pseudonym are sent to the game's online service (Talo) and shown to every player. Nothing is sent before you choose. You can stop at any time in Options > Privacy."), Fonts.BODY, UiSkin.TEXT, true))
	var rules := tr("Pseudonym: %d to %d letters, digits, spaces and - _ . ' Never your real name.") % [config.name_min, config.name_max]
	body.add_child(UiSkin.label(rules, Fonts.BODY, UiSkin.DIM, true))
	_edit = LineEdit.new()
	_edit.set_meta(SoftKeyboard.HINT_META, rules)  # (over the phone's keyboard: SoftKeyboard)
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
	var link := UiParts.button(tr("Privacy policy"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		policy.open(), Vector2(260, 44), Fonts.BODY)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(link)
	_own(link, "PolicyButton")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)
	var decline := UiParts.button(tr("Don't publish"), _decline, Vector2(0, 56), Fonts.BODY)
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(decline)
	_own(decline, "DeclineButton")
	var confirm := UiParts.button(tr("Publish my scores"), _confirm, Vector2(0, 56), Fonts.BODY)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(confirm)
	_own(confirm, "ConfirmButton")
	MenuNavScript.set_first(self, link)


## Publish: the name set (a refused one says why and the dialog stays), sending turned on.
func _confirm() -> void:
	var text := PlayerName.tidy(_edit.text)
	var problem := PlayerName.problem(text, Leaderboards.config)
	if problem != PlayerName.Problem.NONE:
		_error.text = PlayerName.explain(problem, Leaderboards.config)
		Sfx.play_ui(Sfx.bank.ui_close)
		return
	Leaderboards.set_shown(true)
	Leaderboards.set_pseudonym(text)
	_close()


## Don't publish: nothing is ever sent nor read (until turned on in the Options).
func _decline() -> void:
	Leaderboards.set_shown(false)
	_close()


## Back: the policy first; otherwise like Don't publish the first time (an answer: not asked
## again), and the choice kept as it was afterwards.
func cancel() -> void:
	if policy and policy.visible:
		policy.close()
		return
	if not Leaderboards.name_chosen:
		Leaderboards.set_shown(false)
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
