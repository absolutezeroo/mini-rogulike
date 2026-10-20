class_name TitleScreen
extends Control
## First screen: play (or today's daily run, see DailyRun), visit the shrine (permanent
## upgrades bought with souls), read the story, see your records. No class to pick: you become
## who you want with what you find in the dungeon. The very first run starts with the story.
## The Daily run button says what it is (same dungeon for everyone today, the day's weapon and
## relic, your score); the records sit on a plaque under the buttons; the Shrine button shows a
## badge when an upgrade can be bought.

const GAME_SCENE := "res://src/game/game.tscn"
const STORY_SCENE := "res://src/ui/story/story_screen.tscn"
## The dark text of the theme's orange buttons.
const BUTTON_TEXT := Color(0.16862746, 0.11372549, 0.14117648)

@export var content: ContentDB

@onready var _records: HBoxContainer = %Records
@onready var _shrine: ShrinePanel = %ShrinePanel
@onready var _hero: AnimatedSprite2D = %Hero

var _daily_title: Label
var _daily_text: Label
var _daily_score: Label
var _shrine_badge: Control


func _ready() -> void:
	get_tree().paused = false
	if content.sounds:
		Sfx.bank = content.sounds
	var first_act := content.dungeon.acts[0] if not content.dungeon.acts.is_empty() else null
	var biome := first_act.main_biome() if first_act else null
	if biome and biome.theme:
		Sfx.play_music(biome.theme.music)
	if content.story:
		(%Title as Label).text = content.story.title
		(%Subtitle as Label).text = content.story.tagline
		(%ShrineText as Label).text = content.story.shrine_text
	_hero.sprite_frames = content.player.frames
	_hero.play(&"idle_down")
	var spot: Control = %HeroSpot
	spot.resized.connect(func() -> void: _hero.position.x = spot.size.x * 0.5)
	AchievementDef.unlock_reached(content.achievements)  # goals reached by older saves
	_build_boss_row()
	_build_daily_button()
	_build_shrine_badge()
	(%RecordsPlaque as PanelContainer).add_theme_stylebox_override("panel", MenuWindow.strip_style())
	_setup_continue()
	%PlayButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%DifficultyPanel as DifficultyPanel).open(content.difficulties, content.ascensions))
	(%DifficultyPanel as DifficultyPanel).chosen.connect(func(_difficulty: DifficultyDef) -> void: play())
	%DailyButton.pressed.connect(func() -> void:
		Game.daily_requested = true
		play())
	%ShrineButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_shrine.open(content.upgrades))
	%QuestsButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%CodexPanel as CodexPanel).open(content, CodexPanel.Tab.QUESTS))
	%CodexButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%CodexPanel as CodexPanel).open(content))
	%OptionsButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%OptionsPanel as OptionsPanel).open())
	%StoryButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		tell_story(""))
	Profile.changed.connect(_refresh)
	_refresh()
	(%PlayButton as Button).grab_focus()


func play() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if not Profile.seen_intro and content.story and not content.story.intro_pages.is_empty():
		tell_story(GAME_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


## The run in progress, if the app was closed during one.
func _setup_continue() -> void:
	var saved := RunSave.read()
	var button: Button = %ContinueButton
	button.visible = not saved.is_empty()
	if saved.is_empty():
		return
	var player: Dictionary = saved.get("player", {})
	button.text = "Continue your run  -  floor %d, level %d" % [int(saved.get("depth", 1)), int(player.get("level", 1))]
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		Game.resume_requested = true
		get_tree().change_scene_to_file(GAME_SCENE))
	button.grab_focus.call_deferred()


## The story screen, then `next_scene` (empty = back here).
func tell_story(next_scene: String) -> void:
	StoryScreen.next_scene = next_scene if not next_scene.is_empty() else scene_file_path
	get_tree().change_scene_to_file(STORY_SCENE)


## The goal of a run: one boss per act.
func _build_boss_row() -> void:
	var row: HBoxContainer = %Bosses
	for act in content.dungeon.acts:
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		# The act's bosses: one of them guards it in each run.
		var faces := HBoxContainer.new()
		faces.alignment = BoxContainer.ALIGNMENT_CENTER
		for boss in act.all_bosses():
			var portrait := TextureRect.new()
			portrait.texture = boss.portrait
			portrait.custom_minimum_size = Vector2(64, 64)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			faces.add_child(portrait)
		column.add_child(faces)
		var label := UiSkin.label("%s\n%s" % [act.subtitle, act.title], 14, UiSkin.TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		row.add_child(column)
	var goal := UiSkin.label("A run: go down through the acts and beat the boss at the end of each (one of these).", 14, UiSkin.DIM)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.get_parent().add_child(goal)
	row.get_parent().move_child(goal, row.get_index() + 1)


## The Daily run button's three lines: name, what it is, your score.
func _build_daily_button() -> void:
	var button: Button = %DailyButton
	button.text = ""
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)
	_daily_title = _button_label(18)
	_daily_text = _button_label(14)
	_daily_score = _button_label(14)
	for label in [_daily_title, _daily_text, _daily_score]:
		column.add_child(label)


func _button_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BUTTON_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # never wider than the button
	return label


## A small plaque on the Shrine button's corner when an upgrade can be bought.
func _build_shrine_badge() -> void:
	var button: Button = %ShrineButton
	_shrine_badge = MenuWindow.badge("Upgrade ready", 14, MenuWindow.SOULS)
	# Its right edge just past the button's, over the top edge (it grows to the left).
	_shrine_badge.anchor_left = 1.0
	_shrine_badge.anchor_right = 1.0
	_shrine_badge.offset_left = 10.0
	_shrine_badge.offset_right = 10.0
	_shrine_badge.offset_top = -24.0
	_shrine_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.add_child(_shrine_badge)


## "Daily run" (practice once played today), the same dungeon for everyone with the day's
## weapon and relic, and the score: today's (or "your first try counts"), best, streak.
func _refresh_daily() -> void:
	var day := DailyRun.today()
	var played := Profile.daily_played(day)
	_daily_title.text = "Daily run: practice (today's try is done)" if played else "Daily run: same dungeon for everyone today"
	_daily_text.text = "Everyone starts with %s" % DailyRun.describe(content, day)
	var parts := PackedStringArray()
	parts.append("Today: %d points" % Profile.daily_score if played else "Your first try today is the one that counts")
	if Profile.daily_best > 0:
		parts.append("Best %d" % Profile.daily_best)
	if Profile.daily_streak > 1 and (played or Profile.daily_day == day - 1):
		parts.append("%d days in a row" % Profile.daily_streak)
	_daily_score.text = "  -  ".join(parts)


func _refresh() -> void:
	_refresh_daily()
	_shrine_badge.visible = content.upgrades.any(func(u: UpgradeDef) -> bool: return Profile.can_buy(u))
	for child in _records.get_children():
		_records.remove_child(child)
		child.queue_free()
	var difficulty := content.get_difficulty(Profile.difficulty)
	_record("%d souls" % Profile.souls, "to spend at the Shrine", MenuWindow.SOULS)
	_record("Runs", str(Profile.runs))
	_record("Victories", str(Profile.victories))
	_record("Deepest floor", str(Profile.best_depth))
	_record("Difficulty", difficulty.display_name if difficulty else "Normal",
		difficulty.color if difficulty else UiSkin.TEXT)


## One record on the plaque: a word and its value.
func _record(first: String, second: String, color: Color = UiSkin.TEXT) -> void:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	var is_souls := color == MenuWindow.SOULS
	pair.add_child(UiSkin.label(first, 16, color if is_souls else UiSkin.DIM))
	pair.add_child(UiSkin.label(second, 16, UiSkin.DIM if is_souls else color))
	_records.add_child(pair)


## The phone's back button: closes what is open, or leaves the game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var options: OptionsPanel = %OptionsPanel
	if options.visible:
		options.close()
	elif _shrine.visible:
		_shrine.close()
	elif (%CodexPanel as Control).visible:
		(%CodexPanel as CodexPanel).back()
	elif (%DifficultyPanel as Control).visible:
		(%DifficultyPanel as Control).hide()
	else:
		get_tree().quit()
