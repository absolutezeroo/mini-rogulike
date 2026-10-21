class_name CodexPanel
extends Control
## The codex (title screen and pause menu), in the game's skin (RpgWindow): four tabs in the
## header. Quests: today's and this week's goals and the souls they pay. Bestiary: every monster
## and boss, act by act (CodexCard: unknown, seen or slain, your hunter rank); tap one for its
## page (MonsterPage). Achievements: goals across all runs, with progress. Runs: the last runs and
## the fastest wins. Each tab opens with a line saying what it is for. Built in code.

enum Tab { QUESTS, BESTIARY, ACHIEVEMENTS, RUNS }

const TAB_NAMES := ["Quests", "Bestiary", "Achievements", "Runs"]  # i18n
## What each tab is for, under its summary.
const TAB_HELP := [
	"Quests change every day and every week. Everything you do in any run counts toward them, and a finished quest pays its souls at once. Souls are kept between runs: spend them at the Shrine on lasting upgrades.",  # i18n
	"Every monster you meet goes in here. Slay more of a kind to raise your hunter rank with it: each rank pays souls, and Mastered also gives +%d%% damage against that kind for good. Tap a monster for its attacks and challenges.",  # i18n
	"Big goals across all your runs. Reaching one pays its souls at once.",  # i18n
	"Your last runs, newest first. Gold is lost when a run ends; souls are kept.",  # i18n
]

var _content: ContentDB
var _tab := Tab.BESTIARY

var _window: RpgWindow
var _tab_buttons: Array[Button] = []
var _souls: Label
var _intro: VBoxContainer
var _summary: Label
var _help: Label
var _records: Label
var _list_box: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _page: MonsterPage
var _cards: Array[CodexCard] = []
var _named: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build()


## `tab` -1: the one shown last time.
func open(content: ContentDB, tab: int = -1) -> void:
	_content = content
	show()
	show_tab(_tab if tab < 0 else tab)


func show_tab(tab: int) -> void:
	_tab = tab as Tab
	Sfx.play_ui(Sfx.bank.ui_click)
	_close_page()
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == tab)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	_records.hide()
	_list.add_theme_constant_override("separation", 8)
	match _tab:
		Tab.QUESTS:
			_fill_quests()
		Tab.BESTIARY:
			_fill_bestiary()
		Tab.ACHIEVEMENTS:
			_fill_achievements()
		Tab.RUNS:
			_fill_runs()
	var help: String = tr(TAB_HELP[_tab])
	if _tab == Tab.BESTIARY:
		help = help % roundi((_content.bestiary.mastery_damage if _content.bestiary else 0.1) * 100.0)
	_help.text = help
	_souls.text = tr("Souls %d") % Profile.souls
	_scroll.scroll_vertical = 0


# --- Quests ---------------------------------------------------------------------

func _fill_quests() -> void:
	# Quests finished during the last run but not paid yet (an old save, a crash): pay them now.
	QuestBoard.claim_finished(_content.quests)
	var done := 0
	var total := 0
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	_list.add_child(columns)
	for period in [QuestDef.Period.DAILY, QuestDef.Period.WEEKLY]:
		var daily: bool = period == QuestDef.Period.DAILY
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		columns.add_child(column)
		column.add_child(UiSkin.label(tr("Daily quests") if daily else tr("Weekly quests"), 20, UiSkin.GOLD))
		var left := QuestBoard.time_text(QuestBoard.seconds_left(period))
		var when := tr("New ones in %s. Counts every run today.") if daily else tr("New ones in %s. Counts every run this week (from Monday).")
		column.add_child(UiSkin.label(when % left, 15, UiSkin.DIM, true))
		for quest in QuestBoard.current(_content.quests, period):
			column.add_child(CodexRows.quest_row(quest))
			total += 1
			done += 1 if QuestBoard.is_done(quest) else 0
	_summary.text = tr("Quests done: %d of %d") % [done, total]


# --- Bestiary -------------------------------------------------------------------

## Every monster and boss, act by act (each act's monsters, then its bosses).
func bestiary_entries() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for act in _content.dungeon.acts:
		for monster: MonsterDef in act.monsters + act.all_bosses():
			if monster and not result.has(monster):
				result.append(monster)
	return result


## The bestiary's cards, in the order of bestiary_entries() (empty on other tabs).
func bestiary_cards() -> Array[CodexCard]:
	return _cards


func _fill_bestiary() -> void:
	var entries := bestiary_entries()
	var rules := _content.bestiary
	# Ranks reached before (an old save, a crash): paid now.
	if rules:
		for monster in entries:
			Bestiary.claim(monster, rules)
	var slain := entries.filter(func(m: MonsterDef) -> bool: return Profile.kill_count(m.id) > 0).size()
	var mastered := entries.filter(func(m: MonsterDef) -> bool: return Bestiary.is_mastered(m, rules)).size()
	var shiny := entries.filter(func(m: MonsterDef) -> bool: return Profile.has_shiny(m.id)).size()
	_summary.text = tr("Slain: %d of %d kinds     Mastered: %d     Celestial found: %d") % [slain, entries.size(), mastered, shiny]
	_list.add_theme_constant_override("separation", 6)
	var placed := {}
	var acts := _content.dungeon.acts
	for i in acts.size():
		var act := acts[i]
		var kinds: Array[MonsterDef] = []
		for monster: MonsterDef in act.monsters + act.all_bosses():
			if monster and not placed.has(monster):
				placed[monster] = true
				kinds.append(monster)
		if kinds.is_empty():
			continue
		var first := _content.dungeon.first_depth(i)
		var known := kinds.filter(func(m: MonsterDef) -> bool: return Profile.kill_count(m.id) > 0).size()
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 14)
		heading.add_child(UiSkin.label("%s  -  %s" % [tr(act.subtitle), tr(act.title)], 19, UiSkin.GOLD))
		var floors := tr("floor %d") % first if act.floors <= 1 else tr("floors %d to %d") % [first, first + act.floors - 1]
		var where := UiSkin.label(tr("%s     %d of %d slain") % [floors, known, kinds.size()], 15, UiSkin.DIM)
		where.size_flags_vertical = Control.SIZE_SHRINK_END
		heading.add_child(where)
		_list.add_child(heading)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_list.add_child(flow)
		for monster in kinds:
			var card := CodexCard.new(monster, rules)
			card.pressed.connect(func() -> void:
				Sfx.play_ui(Sfx.bank.ui_open)
				open_monster(monster))
			flow.add_child(card)
			_cards.append(card)
		if i < acts.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size.y = 6
			_list.add_child(gap)


## Its page instead of the list.
func open_monster(monster: MonsterDef) -> void:
	_page.show_monster(monster, _content)
	_list_box.hide()
	_intro.hide()
	_page.show()


func _close_page() -> void:
	if _page.visible:
		_page.hide()
		_page.clear()
		_list_box.show()
		_intro.show()


func is_page_open() -> bool:
	return _page.visible


## The back button: a monster's page goes back to the list, the list closes the codex.
func back() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	if _page.visible:
		_close_page()
	else:
		hide()


## The first idle frame facing down (bosses: their portrait).
static func portrait(monster: MonsterDef) -> Texture2D:
	if monster is BossDef and (monster as BossDef).portrait:
		return (monster as BossDef).portrait
	if monster.frames:
		for anim in [&"idle_down", &"walk_down", &"idle"]:
			if monster.frames.has_animation(anim) and monster.frames.get_frame_count(anim) > 0:
				return monster.frames.get_frame_texture(anim, 0)
	return monster.icon


# --- Achievements ---------------------------------------------------------------

func _fill_achievements() -> void:
	var list := _content.achievements
	var unlocked := list.filter(func(a: AchievementDef) -> bool: return a.is_unlocked())
	var earned := 0
	for achievement: AchievementDef in unlocked:
		earned += achievement.reward_souls
	_summary.text = tr("Achievements: %d of %d     Souls earned from them: %d") % [unlocked.size(), list.size(), earned]
	# The ones under way first (closest to done), then the ones done.
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool:
		return _closeness(a) > _closeness(b))
	for achievement: AchievementDef in sorted:
		_list.add_child(CodexRows.achievement_row(achievement))


static func _closeness(achievement: AchievementDef) -> float:
	if achievement.is_unlocked():
		return -1.0
	return float(achievement.progress()) / maxf(achievement.target, 1.0)


# --- Runs -----------------------------------------------------------------------

func _fill_runs() -> void:
	_summary.text = tr("Runs: %d     Wins: %d     Deepest floor: %d") % [Profile.runs, Profile.victories, Profile.best_depth]
	var records := _records_text()
	_records.text = records
	_records.visible = not records.is_empty()
	if Profile.history.is_empty():
		_list.add_child(UiSkin.label(tr("No run finished yet. Go down the Well!"), 18, UiSkin.DIM))
	for entry: Dictionary in Profile.history:
		_list.add_child(CodexRows.run_row(entry, _content))


## "Fastest wins:  Normal 32:10.45   Nightmare +3 51:02.10" (empty before the first win).
func _records_text() -> String:
	var parts: PackedStringArray = []
	for key: String in Profile.best_times:
		parts.append("%s %s" % [_record_name(key), TimeText.of(Profile.best_time(key))])
	return (tr("Fastest wins:   %s") % "     ".join(parts)) if not parts.is_empty() else ""


## A record's difficulty, as the title screen names it ("Nightmare +3").
func _record_name(key: String) -> String:
	var parts := key.split("/a")
	var difficulty := _content.get_difficulty(StringName(parts[0])) if _content else null
	var name := tr(difficulty.display_name) if difficulty else parts[0].capitalize()
	return name + (" +%s" % parts[1] if parts.size() > 1 else "")


# --- Building ---------------------------------------------------------------------

func _build() -> void:
	_window = RpgWindow.new(tr("Codex"))
	_window.close_requested.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	add_child(_window)
	# The tabs, left of the header (the window's own row: Close stays on the right).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var header := _window.header_right.get_parent()
	header.add_child(tabs)
	header.move_child(tabs, 0)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = tr(TAB_NAMES[i])
		button.name = "%sTab" % TAB_NAMES[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void:
			if _tab != i or _page.visible:
				show_tab(i)
			else:
				button.set_pressed_no_signal(true))
		tabs.add_child(button)
		_tab_buttons.append(button)
		_own(button)
	_souls = UiSkin.label("", 22, CodexRows.SOUL)
	_souls.name = "Souls"
	_souls.tooltip_text = tr("Souls are kept between runs. Spend them at the Shrine.")
	_window.header_right.add_child(_souls)
	_own(_souls)

	# What the tab shows, in a line and a sentence.
	_intro = VBoxContainer.new()
	_intro.add_theme_constant_override("separation", 2)
	_window.body.add_child(_intro)
	_summary = UiSkin.label("", 19, UiSkin.GOLD)
	_summary.name = "Summary"
	_intro.add_child(_summary)
	_own(_summary)
	_help = UiSkin.label("", 15, UiSkin.TEXT, true)
	_help.name = "Help"
	_intro.add_child(_help)
	_own(_help)
	_records = UiSkin.label("", 17, UiSkin.GOLD)
	_records.name = "Records"
	_intro.add_child(_records)

	# The list, in a dark inset, scrolled with a finger.
	_list_box = UiSkin.section()
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.body.add_child(_list_box)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(_scroll)
	_own(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_own(_list)
	TouchScroll.attach(_scroll)

	_page = MonsterPage.new()
	_page.name = "MonsterPage"
	_page.visible = false
	_page.back_requested.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		_close_page())
	_window.body.add_child(_page)
	_own(_page)
	for node in _named:
		node.owner = self
		node.unique_name_in_owner = true


## Reachable as %Name from the panel (tests, other scripts), once built.
func _own(node: Node) -> void:
	_named.append(node)
