class_name TitleScreen
extends Control
## First screen: play (or today's daily run, see DailyRun), visit the shrine (permanent
## upgrades bought with souls), read the story, see your records. No class to pick: you become who you want with what you find in the dungeon.
## The very first run starts with the story.

const GAME_SCENE := "res://src/game/game.tscn"
const STORY_SCENE := "res://src/ui/story/story_screen.tscn"

@export var content: ContentDB

@onready var _records: Label = %Records
@onready var _shrine: ShrinePanel = %ShrinePanel
@onready var _hero: AnimatedSprite2D = %Hero


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
	button.text = "Continue  -  depth %d, level %d" % [int(saved.get("depth", 1)), int(player.get("level", 1))]
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
		var label := Label.new()
		label.text = "%s\n%s" % [act.subtitle, act.title]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		column.add_child(label)
		row.add_child(column)


## "Daily run - Bow + Multishot" and the record: today's score or "new!", best, streak.
func _refresh_daily() -> void:
	var day := DailyRun.today()
	var played := Profile.daily_played(day)
	var line := "Today: %d points" % Profile.daily_score if played else "Not played today"
	if Profile.daily_best > 0:
		line += "   Best %d" % Profile.daily_best
	if Profile.daily_streak > 1 and (played or Profile.daily_day == day - 1):
		line += "   %d days in a row" % Profile.daily_streak
	(%DailyButton as Button).text = "Daily run%s  -  %s\n%s" % [" (practice)" if played else "", DailyRun.describe(content, day), line]


func _refresh() -> void:
	_refresh_daily()
	var difficulty := content.get_difficulty(Profile.difficulty)
	_records.text = "Souls: %d     Runs: %d     Victories: %d     Deepest floor: %d     Difficulty: %s" % [
		Profile.souls, Profile.runs, Profile.victories, Profile.best_depth,
		difficulty.display_name if difficulty else "Normal"]


## The phone's back button: closes what is open, or leaves the game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var options: OptionsPanel = %OptionsPanel
	if options.visible:
		options.close()
	elif _shrine.visible:
		_shrine.hide()
	elif (%CodexPanel as Control).visible:
		(%CodexPanel as Control).hide()
	elif (%DifficultyPanel as Control).visible:
		(%DifficultyPanel as Control).hide()
	else:
		get_tree().quit()
