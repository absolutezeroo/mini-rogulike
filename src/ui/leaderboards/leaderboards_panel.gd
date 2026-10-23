class_name LeaderboardsPanel
extends Control
## The Leaderboards page, "The Roll of Souls" (design/progression.md "Online leaderboards"), from
## the title screen and the Dawn Knell's end screen. A MenuWindow: a tab per shown board
## (LeaderboardDef.shown: the Dawn Knell for now) and its periods (today, yesterday), the top of
## the board on the left, the player's place and those around it on the right with the board's
## rule, and the states between: loading, nothing yet, no network (Retry), no leaderboards in
## this build. It only asks Leaderboards (load_board()); it never sends anything itself. The first
## time, it asks whether to publish one's scores, and under which pseudonym (PseudonymDialog);
## not published, the boards aren't even read (the header's button asks again).
## Reachable as %BoardTabs, %TodayTab, %YesterdayTab, %TopList, %Status, %RetryButton, %MinePanel,
## %MineText, %AroundList, %NameText, %ChangeNameButton, %CloseButton, %NameDialog.

signal closed

## The right column's width.
const SIDE_WIDTH := 430.0
## Rank, name, score columns.
const RANK_WIDTH := 64.0
const SCORE_WIDTH := 150.0
## The first three ranks' colors (gold, silver, bronze).
const PODIUM: Array[Color] = [Color(1.0, 0.82, 0.4), Color(0.82, 0.86, 0.92), Color(0.86, 0.58, 0.36)]
## The player's own line.
const MINE_COLOR := Color(0.65, 0.95, 1.0)

var name_dialog: PseudonymDialog

var _window: MenuWindow
var _board: LeaderboardDef
## 0: the current period (today), 1: the one before.
var _back := 0
## Each load's number: an answer for an older one is dropped.
var _load_id := 0
var _tabs: HBoxContainer
var _period_tabs: Array[Button] = []
var _board_tabs := {}
var _top_title: Label
var _top_list: VBoxContainer
var _top_scroll: ScrollContainer
var _top_heading: Control
var _status: Label
var _retry: Button
var _mine_text: Label
var _around: VBoxContainer
var _rules: Label
var _name_text: Label
var _change_name: Button
var _mine_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	name_dialog = PseudonymDialog.new()
	name_dialog.finished.connect(func() -> void:
		_show_name()
		refresh())
	add_child(name_dialog)
	MenuWindow.expose(name_dialog, "NameDialog", self)
	Leaderboards.changed.connect(func() -> void:
		if visible:
			_show_name())


## Shows the page on `board_id` (empty: the first shown board), today's.
func open(board_id: StringName = &"") -> void:
	var boards := Leaderboards.config.shown_boards()
	_board = Leaderboards.config.board(board_id) if board_id != &"" else null
	if _board == null and not boards.is_empty():
		_board = boards[0]
	_back = 0
	_show_tabs()
	_show_name()
	show()
	if Leaderboards.needs_name():
		name_dialog.open()
	refresh()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## Back (Escape, B, the phone's): the name dialog first, then the page. False if nothing was open.
func back() -> bool:
	if not visible:
		return false
	if name_dialog.visible:
		name_dialog.cancel()  # (its policy page first)
	else:
		close()
	return true


## Loads the board again (and sends what waits first).
func refresh() -> void:
	_show_online(Leaderboards.is_available())
	if _board == null or not Leaderboards.is_available():
		_show_state(tr("Online leaderboards are not available in this version of the game."), false)
		_show_mine(null)
		return
	if not Leaderboards.shown:
		# Not chosen to publish: the server isn't contacted at all, not even to read.
		_show_state(tr("You chose not to publish your scores, so the online leaderboards are not loaded either. Publish them to see the boards."), false)
		_show_mine(null)
		return
	_load_id += 1
	var my_load := _load_id
	_show_state(tr("Loading..."), false)
	_show_mine(null, true)
	var view := await Leaderboards.load_board(_board, _back)
	if my_load != _load_id or not is_inside_tree():
		return
	show_view(view)


## Fills the page with `view` (Leaderboards.load_board()'s).
func show_view(view: Leaderboards.View) -> void:
	if view.status == BoardBackend.Status.OFFLINE or view.status == BoardBackend.Status.REJECTED:
		_show_state(tr("The leaderboards can't be reached right now. Check your connection, then try again."), true)
		_show_mine(view)
		return
	if view.status != BoardBackend.Status.OK:
		_show_state(tr("Online leaderboards are not available in this version of the game."), false)
		_show_mine(null)
		return
	UiParts.clear(_top_list)
	_top_title.text = tr("The first %d") % Leaderboards.config.top_count
	if view.top.is_empty():
		_show_state(tr("No one is on this board yet.") if _back == 0 else tr("No one was on this board."), false)
	else:
		_status.hide()
		_retry.hide()
		_top_scroll.show()
		_top_heading.show()
		for entry in view.top:
			_top_list.add_child(_row(entry, view.mine != null and entry.alias_id == view.mine.alias_id))
	_show_mine(view)


func _show_state(text: String, can_retry: bool) -> void:
	_status.text = text
	_status.show()
	_retry.visible = can_retry
	_top_scroll.hide()
	_top_heading.hide()
	UiParts.clear(_top_list)


## The right column: the player's place, those around it, or why there is none.
func _show_mine(view: Leaderboards.View, loading := false) -> void:
	UiParts.clear(_around)
	_rules.text = tr(_board.rule) if _board else ""
	if not Leaderboards.shown:
		_mine_text.text = tr("Your scores are not published (Options > Privacy).")
		return
	if loading or view == null:
		_mine_text.text = ""
		return
	if view.status != BoardBackend.Status.OK:
		# Not reached: only what waits is known.
		_mine_text.text = tr("Your score of %s waits to be sent: it goes as soon as the network is back.") % _board.format_score(view.waiting) if view.waiting >= 0.0 else ""
		return
	var text := ""
	if view.mine:
		text = tr("Rank %d - %s") % [view.mine.rank, _board.format_score(view.mine.score)] if view.mine.rank > 0 \
			else tr("Your score: %s (past the first %d)") % [_board.format_score(view.mine.score), Leaderboards.config.top_count * Leaderboards.config.rank_scan_pages]
	elif view.waiting >= 0.0:
		text = tr("Your score of %s waits to be sent: it goes as soon as the network is back.") % _board.format_score(view.waiting)
	else:
		text = tr("You have no score on this board yet.") if _back == 0 else tr("You had no score on this board.")
	if view.mine and view.waiting >= 0.0:
		text += "\n" + tr("A better score waits to be sent.")
	_mine_text.text = text
	if view.mine and view.mine.rank > Leaderboards.config.top_count:
		for entry in view.around:
			_around.add_child(_row(entry, entry.alias_id == view.mine.alias_id))


## A build without a server: no name, no periods, no place to show; only why.
func _show_online(on: bool) -> void:
	_name_text.visible = on
	_change_name.visible = on
	_mine_panel.visible = on
	for tab in _period_tabs:
		tab.visible = on and _board != null and _board.period != LeaderboardDef.Period.ALL_TIME


func _show_name() -> void:
	if _name_text:
		_name_text.text = tr("You appear as %s") % Leaderboards.display_name() if Leaderboards.shown else tr("You don't appear in the leaderboards")
		_change_name.text = tr("Change name") if Leaderboards.shown else tr("Publish my scores")


## The tabs: one per shown board, and the board's two periods (none for an all-time board).
func _show_tabs() -> void:
	for board_id: StringName in _board_tabs:
		(_board_tabs[board_id] as Button).set_pressed_no_signal(_board != null and _board.id == board_id)
	var has_periods := _board != null and _board.period != LeaderboardDef.Period.ALL_TIME
	var weekly := _board != null and _board.period == LeaderboardDef.Period.WEEKLY
	_period_tabs[0].text = tr("This week") if weekly else tr("Today")
	_period_tabs[1].text = tr("Last week") if weekly else tr("Yesterday")
	for i in _period_tabs.size():
		_period_tabs[i].visible = has_periods
		_period_tabs[i].set_pressed_no_signal(i == _back)


func _pick_board(board: LeaderboardDef) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_board = board
	_back = 0
	_show_tabs()
	refresh()


func _pick_period(back: int) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_back = back
	_show_tabs()
	refresh()


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = MenuWindow.new(tr("The Roll of Souls"))
	_window.close_requested.connect(close)
	add_child(_window)
	MenuWindow.expose(_window.close_button, "CloseButton", self)
	_name_text = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_name_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_text.clip_text = true
	_name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window.header_left.add_child(_name_text)
	MenuWindow.expose(_name_text, "NameText", self)
	var change := MenuWindow.button(tr("Change name"), Fonts.BODY, 48)
	_change_name = change
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	change.set_meta(MenuNav.NOT_FIRST, true)
	change.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		name_dialog.open())
	_window.header_left.add_child(change)
	MenuWindow.expose(change, "ChangeNameButton", self)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	_window.body.add_child(_tabs)
	MenuWindow.expose(_tabs, "BoardTabs", self)
	for board in Leaderboards.config.shown_boards():
		var tab := _tab(tr(board.display_name), "Board_%s" % board.id)
		tab.add_to_group(MenuNav.TABS)
		tab.pressed.connect(_pick_board.bind(board))
		_board_tabs[board.id] = tab
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	_tabs.add_child(gap)
	for back in 2:
		var period := _tab(tr("Today"), "TodayTab" if back == 0 else "YesterdayTab")
		period.custom_minimum_size.x = 150
		period.pressed.connect(_pick_period.bind(back))
		_period_tabs.append(period)
	_tabs.add_child(PromptGlyph.make(&"menu_tabs"))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)

	var top: Dictionary = RpgWindow.section(tr("The first %d") % Leaderboards.config.top_count)
	(top.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(top.box)
	_top_title = top.title
	var column: VBoxContainer = top.column
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_heading = _heading_row()
	column.add_child(_top_heading)
	_top_scroll = UiParts.scroll()
	_top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_top_scroll)
	_top_list = VBoxContainer.new()
	_top_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_list.add_theme_constant_override("separation", 2)
	_top_scroll.add_child(_top_list)
	MenuWindow.expose(_top_list, "TopList", self)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_status)
	MenuWindow.expose(_status, "Status", self)
	_retry = MenuWindow.button(tr("Try again"), Fonts.BODY, 52)
	_retry.custom_minimum_size.x = 220
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		refresh())
	column.add_child(_retry)
	MenuWindow.expose(_retry, "RetryButton", self)

	var side_scroll := UiParts.scroll()
	side_scroll.custom_minimum_size.x = SIDE_WIDTH
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side_scroll.add_child(side)
	var mine: Dictionary = RpgWindow.section(tr("Your place"))
	side.add_child(mine.box)
	_mine_panel = mine.box
	MenuWindow.expose(mine.box, "MinePanel", self)
	_mine_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	(mine.column as VBoxContainer).add_child(_mine_text)
	MenuWindow.expose(_mine_text, "MineText", self)
	_around = VBoxContainer.new()
	_around.add_theme_constant_override("separation", 2)
	(mine.column as VBoxContainer).add_child(_around)
	MenuWindow.expose(_around, "AroundList", self)
	var rules: Dictionary = RpgWindow.section(tr("Rules"))
	side.add_child(rules.box)
	_rules = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	(rules.column as VBoxContainer).add_child(_rules)
	(rules.column as VBoxContainer).add_child(UiSkin.label(tr("Scores no hero could make are removed."), Fonts.BODY, UiSkin.DIM, true))


func _tab(text: String, node_name: String) -> Button:
	var button := MenuWindow.button(text, Fonts.BODY, 44)
	button.toggle_mode = true
	button.custom_minimum_size.x = 160
	_tabs.add_child(button)
	MenuWindow.expose(button, node_name, self)
	return button


## Rank, Name, Score over the list.
func _heading_row() -> HBoxContainer:
	var row := _columns_row(tr("Rank"), tr("Name"), tr("Score"), UiSkin.GOLD)
	return row


## A line of the board; the player's own stands out.
func _row(entry: BoardBackend.Entry, mine: bool) -> Control:
	var color := MINE_COLOR if mine else (PODIUM[entry.rank - 1] if entry.rank >= 1 and entry.rank <= PODIUM.size() else UiSkin.TEXT)
	var row := _columns_row(str(entry.rank) if entry.rank > 0 else "-", PlayerName.readable(entry.name, Leaderboards.config), _board.format_score(entry.score), color)
	if not mine:
		return row
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.65, 0.95, 1.0, 0.14)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	box.add_theme_stylebox_override("panel", style)
	box.add_child(row)
	return box


func _columns_row(rank: String, who: String, score: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rank_label := UiSkin.label(rank, Fonts.BODY, color)
	rank_label.custom_minimum_size.x = RANK_WIDTH
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rank_label)
	var name_label := UiSkin.label(who, Fonts.BODY, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (a player's name)
	row.add_child(name_label)
	var score_label := UiSkin.label(score, Fonts.BODY, color)
	score_label.custom_minimum_size.x = SCORE_WIDTH
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_label)
	return row
