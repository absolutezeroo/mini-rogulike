class_name CodexPanel
extends Control
## The codex (title screen and pause menu): today's and this week's quests, the bestiary (every
## monster and boss: unknown, seen or slain; tap one for its page, see MonsterPage), the
## achievements with their progress, and the last runs.

enum Tab { QUESTS, BESTIARY, ACHIEVEMENTS, RUNS }

const CARD_SIZE := Vector2(170, 168)
const UNKNOWN_COLOR := Color(0.1, 0.08, 0.12)

var _content: ContentDB
var _tab := Tab.BESTIARY

@onready var _list: Container = %List
@onready var _scroll: ScrollContainer = %Scroll
var _page := MonsterPage.new()
@onready var _summary: Label = %Summary
@onready var _tab_buttons: Array[Button] = [%QuestsTab, %BestiaryTab, %AchievementsTab, %RunsTab]


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	for i in _tab_buttons.size():
		_tab_buttons[i].pressed.connect(show_tab.bind(i))
	_page.visible = false
	_scroll.get_parent().add_child(_page)
	_page.back_requested.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		_close_page())


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
		_tab_buttons[i].disabled = i == tab
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.QUESTS:
			_fill_quests()
		Tab.BESTIARY:
			_fill_bestiary()
		Tab.ACHIEVEMENTS:
			_fill_achievements()
		Tab.RUNS:
			_fill_runs()


# --- Quests ---------------------------------------------------------------------

func _fill_quests() -> void:
	# Quests finished during the last run but not paid yet (an old save, a crash): pay them now.
	QuestBoard.claim_finished(_content.quests)
	_summary.text = "Souls: %d" % Profile.souls
	for period in [QuestDef.Period.DAILY, QuestDef.Period.WEEKLY]:
		var title := "Daily quests" if period == QuestDef.Period.DAILY else "Weekly quests"
		var header := _label("%s   -   new ones in %s" % [title, QuestBoard.time_text(QuestBoard.seconds_left(period))], 20, Palette.GOLD, false)
		header.custom_minimum_size = Vector2(1000, 34)  # a line of its own in the flow
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(header)
		for quest in QuestBoard.current(_content.quests, period):
			_list.add_child(_quest_row(quest))


func _quest_row(quest: Dictionary) -> Control:
	var done := QuestBoard.is_done(quest)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(1000, 56)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.add_child(_label(QuestBoard.text(quest), 18, Palette.HEAL if done else Color.WHITE))
	var bar := StatBar.new()
	bar.custom_minimum_size = Vector2(300, 20)
	bar.fill_color = Palette.HEAL if done else Palette.GOLD
	bar.font_size = 13
	text.add_child(bar)
	bar.set_values(QuestBoard.progress(quest), quest.target, "%d / %d" % [QuestBoard.progress(quest), quest.target])
	row.add_child(text)
	var right := VBoxContainer.new()
	right.add_child(_label("Done!" if done else "", 16, Palette.HEAL, false))
	right.add_child(_label("+%d souls" % quest.reward, 15, Color(0.65, 0.95, 1, 0.9), false))
	row.add_child(right)
	return row


# --- Bestiary -------------------------------------------------------------------

## Every monster of every act, then the bosses.
func bestiary_entries() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = _content.all_monsters()
	for act in _content.dungeon.acts:
		for boss in act.all_bosses():
			if not result.has(boss):
				result.append(boss)
	return result


func _fill_bestiary() -> void:
	var entries := bestiary_entries()
	var rules := _content.bestiary
	# Ranks reached before (an old save, a crash): paid now.
	if rules:
		for monster in entries:
			Bestiary.claim(monster, rules)
	var known := entries.filter(func(m: MonsterDef) -> bool: return Profile.kill_count(m.id) > 0).size()
	var mastered := entries.filter(func(m: MonsterDef) -> bool: return rules != null and Bestiary.is_mastered(m, rules)).size()
	var shiny := entries.filter(func(m: MonsterDef) -> bool: return Profile.has_shiny(m.id)).size()
	_summary.text = "Bestiary: %d / %d slain, %d mastered, %d shiny (*)   -   tap one for its attacks and challenges" % [known, entries.size(), mastered, shiny]
	for monster in entries:
		_list.add_child(_monster_card(monster))


## Its page instead of the list.
func open_monster(monster: MonsterDef) -> void:
	_page.show_monster(monster, _content)
	_scroll.hide()
	_page.show()


func _close_page() -> void:
	if _page.visible:
		_page.hide()
		for child in _page.get_children():
			child.queue_free()
		_scroll.show()


func is_page_open() -> bool:
	return _page.visible


## The back button: a monster's page goes back to the list, the list closes the codex.
func back() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	if _page.visible:
		_close_page()
	else:
		hide()


func _monster_card(monster: MonsterDef) -> Control:
	var kills := Profile.kill_count(monster.id)
	var known := kills > 0
	var rank := Bestiary.rank_of(monster, _content.bestiary) if _content.bestiary else (1 if known else -1)
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = rank == Bestiary.UNSEEN
	card.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		open_monster(monster))
	var inside := VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)
	var picture := TextureRect.new()
	picture.texture = portrait(monster)
	picture.custom_minimum_size = Vector2(72, 72)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.modulate = Color.WHITE if rank >= Bestiary.SEEN else UNKNOWN_COLOR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(picture)
	var name_label := _label(monster.display_name if rank >= Bestiary.SEEN else "???", 16, Palette.DANGER if monster is BossDef else Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inside.add_child(name_label)
	var info_text := "Not met yet"
	if rank == Bestiary.SEEN:
		info_text = "Seen, never slain"
	elif rank > 0:
		info_text = "%s\n%d slain" % [Bestiary.rank_name(rank, _content.bestiary), kills]
	var info := _label(info_text, 15, Palette.HEAL if _content.bestiary and Bestiary.is_mastered(monster, _content.bestiary) else Color(1, 1, 1, 0.7))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_constant_override("outline_size", 4)
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	inside.add_child(info)
	if Profile.has_shiny(monster.id):
		# A badge in the corner (it never gets cut off like text at the end of a line).
		var shiny := _label("Shiny", 14, Color(1.0, 0.6, 0.95))
		shiny.add_theme_constant_override("outline_size", 4)
		shiny.add_theme_color_override("font_outline_color", Color.BLACK)
		shiny.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shiny.position = Vector2(8, 4)
		card.add_child(shiny)
	return card


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
	var done := _content.achievements.filter(func(a: AchievementDef) -> bool: return a.is_unlocked()).size()
	_summary.text = "Achievements: %d / %d" % [done, _content.achievements.size()]
	for achievement in _content.achievements:
		_list.add_child(_achievement_row(achievement))


func _achievement_row(achievement: AchievementDef) -> Control:
	var unlocked := achievement.is_unlocked()
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 64)
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = achievement.icon
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.4)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label(achievement.display_name, 18, Palette.GOLD if unlocked else Color.WHITE))
	text.add_child(_label(achievement.description, 15, Color(1, 1, 1, 0.7)))
	row.add_child(text)
	var status := "Done" if unlocked else "%d / %d" % [achievement.progress(), achievement.target]
	var right := VBoxContainer.new()
	right.add_child(_label(status, 16, Palette.HEAL if unlocked else Color.WHITE, false))
	right.add_child(_label("+%d souls" % achievement.reward_souls, 13, Color(0.65, 0.95, 1, 0.8), false))
	row.add_child(right)
	return row


# --- Runs -----------------------------------------------------------------------

func _fill_runs() -> void:
	_summary.text = "Runs: %d     Victories: %d     Deepest floor: %d" % [Profile.runs, Profile.victories, Profile.best_depth]
	var records := _records_text()
	if not records.is_empty():
		_list.add_child(_label(records, 16, Palette.GOLD))
	if Profile.history.is_empty():
		_list.add_child(_label("No run finished yet. Go down the Well!", 18, Color(1, 1, 1, 0.7)))
	for entry: Dictionary in Profile.history:
		_list.add_child(_run_row(entry))


func _run_row(entry: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 0)
	row.add_theme_constant_override("separation", 0)
	var date := Time.get_datetime_string_from_unix_time(int(entry.get("time", 0)), true).left(16)
	var won := bool(entry.get("won", false))
	var title := "%s  -  %s  -  depth %d" % [date, entry.get("difficulty", "?"), int(entry.get("depth", 1))]
	row.add_child(_label(title, 16, Palette.GOLD if won else Color.WHITE))
	var end := "Victory!" if won and str(entry.get("cause", "")).is_empty() else "Slain by %s" % entry.get("cause", "?")
	if won and not str(entry.get("cause", "")).is_empty():
		end = "Won, then slain by %s" % entry.get("cause")
	var line := "%s   -   level %d, %d kills, %d bosses, %s, +%d souls" % [
		end, int(entry.get("level", 1)), int(entry.get("kills", 0)), int(entry.get("bosses", 0)),
		entry.get("weapon", "?"), int(entry.get("souls", 0))]
	if entry.has("duration"):
		line = "%s   -   %s" % [TimeText.of(int(entry.duration) / 1000.0), line]
	row.add_child(_label(line, 13, Color(1, 1, 1, 0.7)))
	return row


## "Fastest wins: Normal 32:10.45   Nightmare +3 51:02.10" (empty before the first win).
func _records_text() -> String:
	var parts: PackedStringArray = []
	for key: String in Profile.best_times:
		parts.append("%s %s" % [_record_name(key), TimeText.of(Profile.best_time(key))])
	return ("Fastest wins:   " + "    ".join(parts)) if not parts.is_empty() else ""


## A record's difficulty, as the title screen names it ("Nightmare +3").
func _record_name(key: String) -> String:
	var parts := key.split("/a")
	var difficulty := _content.get_difficulty(StringName(parts[0])) if _content else null
	var name := difficulty.display_name if difficulty else parts[0].capitalize()
	return name + (" +%s" % parts[1] if parts.size() > 1 else "")


## `trim`: long text ends with "..." (and the label can shrink to nothing: not for short values).
func _label(text: String, size: int, color: Color, trim := true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if trim:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
