class_name GameOverPanel
extends Control
## End of a run, in the game's skin (RpgDialog): death, or victory over the last boss (then you
## may keep going: endless mode). How it ended (a line of the story), the run's numbers (time,
## depth, kills...), the souls it earned and what souls are for, then what to do next.

signal restart_requested
signal continue_requested
signal title_requested

const DEATH_COLOR := Color(1, 0.88, 0.82)
const VICTORY_COLOR := Color(1, 0.86, 0.45)
const WIDTH := 880.0

var _dialog: RpgDialog
var _summary: Label
var _columns: HBoxContainer
var _stats: GridContainer
var _souls_earned: Label
var _souls_total: Label
var _continue_note: Label
var _continue_button: Button
var _restart_button: Button
var _named: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## The whole end of a run. `rows`: [label, value] pairs (RunState.summary_rows()). `title`:
## instead of the usual one (an ending's, chosen at the bottom of the Well).
func show_end(victory: bool, story: String, rows: Array, souls_earned: int, souls_total: int, title: String = "") -> void:
	if title.is_empty():
		title = tr("Victory Achieved") if victory else tr("The Well claims you")
	_show(title, VICTORY_COLOR if victory else DEATH_COLOR, story, victory)
	UiParts.clear(_stats)
	for row: Array in rows:
		_stats.add_child(UiSkin.label(str(row[0]), Fonts.BODY, UiSkin.DIM))
		var value := UiSkin.label(str(row[1]), Fonts.BODY, UiSkin.GOLD if str(row[1]).contains(tr("New record!")) else UiSkin.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(value)
	_souls_earned.text = tr("+%d souls") % souls_earned
	_souls_total.text = tr("You now have %d souls.") % souls_total
	_columns.show()


## Just a text (older callers): death.
func show_result(summary: String) -> void:
	_show(tr("The Well claims you"), DEATH_COLOR, summary, false)
	_columns.hide()


## Just a text (older callers): victory.
func show_victory(summary: String) -> void:
	_show(tr("Victory Achieved"), VICTORY_COLOR, summary, true)
	_columns.hide()


## Every word on the screen, top to bottom (tests).
func shown_text() -> String:
	var parts := PackedStringArray()
	var stack: Array[Node] = [_dialog]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node is Label and (node as Label).is_visible_in_tree():
			parts.append((node as Label).text)
		elif node is Button and (node as Button).is_visible_in_tree():
			parts.append((node as Button).text)
		stack.append_array(node.get_children())
	return "\n".join(parts)


func _show(title: String, color: Color, summary: String, can_continue: bool) -> void:
	_dialog.set_title(title, color)
	_summary.text = summary
	_summary.visible = not summary.is_empty()
	_continue_button.visible = can_continue
	_continue_note.visible = can_continue
	_restart_button.text = tr("New run") if can_continue else tr("Try again")
	show()


func _build() -> void:
	_dialog = RpgDialog.new(tr("The Well claims you"), WIDTH, 0.82)
	add_child(_dialog)
	_dialog.title_label.name = "Title"
	_own(_dialog.title_label)
	_summary = UiParts.text("", Fonts.BODY, UiSkin.TEXT, WIDTH - 60)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.name = "Summary"
	_own(_summary)
	_dialog.body.add_child(_summary)

	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 14)
	_dialog.body.add_child(_columns)
	var run: Dictionary = RpgWindow.section(tr("This run"))
	(run.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(run.box)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 20)
	_stats.add_theme_constant_override("v_separation", 2)
	_stats.name = "Stats"
	_own(_stats)
	run.column.add_child(_stats)
	var souls: Dictionary = RpgWindow.section(tr("Souls"))
	(souls.box as Control).custom_minimum_size.x = 400
	_columns.add_child(souls.box)
	_souls_earned = UiSkin.label("", Fonts.TITLE, UiSkin.GOLD)
	_souls_earned.name = "SoulsEarned"
	_own(_souls_earned)
	souls.column.add_child(_souls_earned)
	_souls_total = UiSkin.label("", Fonts.BODY, UiSkin.TEXT)
	souls.column.add_child(_souls_total)
	souls.column.add_child(UiParts.text(tr("Souls are kept between runs. Spend them at the Shrine (title screen) on upgrades that make every next run stronger."), Fonts.BODY, UiSkin.DIM, 360))
	souls.column.add_child(UiParts.text(tr("Gold was only for this run."), Fonts.BODY, UiSkin.DIM, 360))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	_dialog.body.add_child(buttons)
	_continue_button = UiParts.button(tr("Keep going (endless)"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		hide()
		continue_requested.emit(), Vector2(260, 58), Fonts.BODY)
	_continue_button.name = "ContinueButton"
	_own(_continue_button)
	buttons.add_child(_continue_button)
	_restart_button = UiParts.button(tr("Try again"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		restart_requested.emit(), Vector2(240, 58), Fonts.BODY)
	_restart_button.name = "RestartButton"
	_own(_restart_button)
	buttons.add_child(_restart_button)
	var title_button := UiParts.button(tr("Title screen"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		title_requested.emit(), Vector2(240, 58), Fonts.BODY)
	title_button.name = "TitleButton"
	_own(title_button)
	buttons.add_child(title_button)
	_continue_note = UiParts.text(tr("Keep going: endless floors, harder and harder. Your win is already counted."), Fonts.BODY, UiSkin.DIM, WIDTH - 60)
	_continue_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_continue_note)
	for node in _named:
		node.owner = self
		node.unique_name_in_owner = true


## Reachable as %Name from the panel (tests, other scripts), once built.
func _own(node: Node) -> void:
	_named.append(node)
