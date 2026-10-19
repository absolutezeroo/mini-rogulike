class_name CodexPanel
extends Control
## The codex (title screen): the bestiary (every monster and boss, slain or still unknown),
## the achievements with their progress, and the last runs.

enum Tab { BESTIARY, ACHIEVEMENTS, RUNS }

const CARD_SIZE := Vector2(170, 168)
const UNKNOWN_COLOR := Color(0.1, 0.08, 0.12)

var _content: ContentDB
var _tab := Tab.BESTIARY

@onready var _list: Container = %List
@onready var _summary: Label = %Summary
@onready var _tab_buttons: Array[Button] = [%BestiaryTab, %AchievementsTab, %RunsTab]


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	for i in _tab_buttons.size():
		_tab_buttons[i].pressed.connect(show_tab.bind(i))


func open(content: ContentDB) -> void:
	_content = content
	show()
	show_tab(_tab)


func show_tab(tab: int) -> void:
	_tab = tab as Tab
	Sfx.play_ui(Sfx.bank.ui_click)
	for i in _tab_buttons.size():
		_tab_buttons[i].disabled = i == tab
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.BESTIARY:
			_fill_bestiary()
		Tab.ACHIEVEMENTS:
			_fill_achievements()
		Tab.RUNS:
			_fill_runs()


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
	var known := entries.filter(func(m: MonsterDef) -> bool: return Profile.kill_count(m.id) > 0).size()
	_summary.text = "Bestiary: %d / %d discovered" % [known, entries.size()]
	for monster in entries:
		_list.add_child(_monster_card(monster))


func _monster_card(monster: MonsterDef) -> Control:
	var kills := Profile.kill_count(monster.id)
	var known := kills > 0
	var card := VBoxContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var picture := TextureRect.new()
	picture.texture = portrait(monster)
	picture.custom_minimum_size = Vector2(72, 72)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.modulate = Color.WHITE if known else UNKNOWN_COLOR
	card.add_child(picture)
	var name_label := _label(monster.display_name if known else "???", 16, Color("ff6b6b") if monster is BossDef else Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var info := _label("Slain: %d" % kills if known else "Not met yet", 13, Color(1, 1, 1, 0.65))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(info)
	if known and not monster.description.is_empty():
		card.tooltip_text = monster.description
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
	text.add_child(_label(achievement.display_name, 18, Color("ffd166") if unlocked else Color.WHITE))
	text.add_child(_label(achievement.description, 13, Color(1, 1, 1, 0.7)))
	row.add_child(text)
	var status := "Done" if unlocked else "%d / %d" % [achievement.progress(), achievement.target]
	var right := VBoxContainer.new()
	right.add_child(_label(status, 16, Color("6ee787") if unlocked else Color.WHITE, false))
	right.add_child(_label("+%d souls" % achievement.reward_souls, 13, Color(0.65, 0.95, 1, 0.8), false))
	row.add_child(right)
	return row


# --- Runs -----------------------------------------------------------------------

func _fill_runs() -> void:
	_summary.text = "Runs: %d     Victories: %d     Deepest floor: %d" % [Profile.runs, Profile.victories, Profile.best_depth]
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
	row.add_child(_label(title, 16, Color("ffd166") if won else Color.WHITE))
	var end := "Victory!" if won and str(entry.get("cause", "")).is_empty() else "Slain by %s" % entry.get("cause", "?")
	if won and not str(entry.get("cause", "")).is_empty():
		end = "Won, then slain by %s" % entry.get("cause")
	row.add_child(_label("%s   -   level %d, %d kills, %d bosses, %s, +%d souls" % [
		end, int(entry.get("level", 1)), int(entry.get("kills", 0)), int(entry.get("bosses", 0)),
		entry.get("weapon", "?"), int(entry.get("souls", 0))], 13, Color(1, 1, 1, 0.7)))
	return row


## `trim`: long text ends with "..." (and the label can shrink to nothing: not for short values).
func _label(text: String, size: int, color: Color, trim := true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if trim:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
