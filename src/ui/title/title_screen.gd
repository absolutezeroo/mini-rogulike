class_name TitleScreen
extends Control
## First screen: play (or today's daily run, see DailyRun), visit the shrine (permanent
## upgrades bought with souls), read the story, see your records. No class to pick: you become
## who you want with what you find in the dungeon. The very first run starts with the story.
## The Daily Descent button says what it is (same dungeon for everyone today, the day's weapon and
## relic, your score); the records sit on a plaque under the buttons; the Shrine button shows a
## badge when an upgrade can be bought.

const GAME_SCENE := "res://src/game/game.tscn"
const STORY_SCENE := "res://src/ui/story/story_screen.tscn"
## The dark text of the theme's orange buttons.
const BUTTON_TEXT := Color(0.16862746, 0.11372549, 0.14117648)

@export var content: ContentDB

@onready var _records: BoxContainer = %Records
@onready var _shrine: ShrinePanel = %ShrinePanel
@onready var _hero: AnimatedSprite2D = %Hero

var _daily_title: Label
var _daily_text: Label
var _shrine_badge: Control
var oath_panel: OathPanel
var daily_dialog: DailyDialog
## The tutorial's title-screen hints (the Tree of Souls, the oaths), over everything.
var hint_box: HintBox


func _ready() -> void:
	get_tree().paused = false
	if content.sounds:
		Sfx.bank = content.sounds
	var first_act := content.dungeon.acts[0] if not content.dungeon.acts.is_empty() else null
	var biome := first_act.main_biome() if first_act else null
	if biome and biome.theme:
		Sfx.play_music(biome.theme.music)
	if content.story:
		(%Title as Label).text = tr(content.story.title)
		(%Subtitle as Label).text = tr(content.story.tagline)
		(%ShrineText as Label).text = tr(content.story.shrine_text)
	_hero.sprite_frames = content.player.frames
	_hero.play(&"idle_right")  # (looking at the Well)
	# The hero on the Well's rim, the souls rising from it (the picture follows the screen's size).
	var backdrop: TitleBackdrop = %Backdrop
	backdrop.resized.connect(_place_scene)
	_place_scene.call_deferred()
	AchievementDef.unlock_reached(content.achievements)  # goals reached by older saves
	_build_daily_button()
	_build_shrine_badge()
	var plaque_style := MenuWindow.strip_style().duplicate() as StyleBoxTexture
	plaque_style.content_margin_left = 16
	plaque_style.content_margin_right = 16
	plaque_style.content_margin_top = 12
	plaque_style.content_margin_bottom = 14
	(%RecordsPlaque as PanelContainer).add_theme_stylebox_override("panel", plaque_style)
	(%RecordsPlaque as PanelContainer).custom_minimum_size.x = 250
	_setup_continue()
	%PlayButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%DifficultyPanel as DifficultyPanel).open(content.difficulties, content.ascensions))
	# Once the tree opened an oath or the Armory: "At the Well's Edge" between the two.
	oath_panel = OathPanel.new()
	add_child(oath_panel)
	oath_panel.started.connect(play)
	hint_box = HintBox.new()
	add_child(hint_box)
	hint_box.dismissed.connect(hint_box.hide_hint)
	(%DifficultyPanel as DifficultyPanel).chosen.connect(func(_difficulty: DifficultyDef) -> void:
		if OathPanel.has_choices(content):
			Sfx.play_ui(Sfx.bank.ui_open)
			oath_panel.open(content)
			show_menu_hint(&"menu_oath")
		else:
			play())
	# The daily run: tapping it explains it first (DailyDialog), then it starts.
	daily_dialog = DailyDialog.new()
	daily_dialog.hide()
	add_child(daily_dialog)
	daily_dialog.accepted.connect(func() -> void:
		Game.daily_requested = true
		play())
	%DailyButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		daily_dialog.open(content, DailyRun.today()))
	%ShrineButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_shrine.open(content.soul_tree)
		show_menu_hint(&"menu_shrine"))
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
		Loader.go(GAME_SCENE)


## The run in progress, if the app was closed during one.
func _setup_continue() -> void:
	var saved := RunSave.read()
	var button: Button = %ContinueButton
	button.visible = not saved.is_empty()
	if saved.is_empty():
		return
	var player: Dictionary = saved.get("player", {})
	button.text = tr("Resume the descent  -  floor %d, level %d") % [int(saved.get("depth", 1)), int(player.get("level", 1))]
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		Game.resume_requested = true
		Loader.go(GAME_SCENE))
	button.grab_focus.call_deferred()


## The story screen, then `next_scene` (empty = back here).
func tell_story(next_scene: String) -> void:
	StoryScreen.next_scene = next_scene if not next_scene.is_empty() else scene_file_path
	get_tree().change_scene_to_file(STORY_SCENE)


## The hero and the souls where the Well is drawn.
func _place_scene() -> void:
	var backdrop: TitleBackdrop = %Backdrop
	_hero.position = backdrop.hero_spot()
	var wisps: CPUParticles2D = %Wisps
	wisps.position = backdrop.well_center() + Vector2(0, -backdrop.size.y * 0.3)
	wisps.emission_rect_extents = Vector2(backdrop.well_radius().x * 0.8, backdrop.size.y * 0.3)


## The Daily Descent button's three lines: name, what it is, your score.
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
	_daily_title = _button_label(24)
	_daily_text = _button_label(14)
	for label in [_daily_title, _daily_text]:
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
	_shrine_badge = MenuWindow.badge(tr("Souls to offer"), 14, MenuWindow.SOULS)
	# Its right edge just past the button's, over the top edge (it grows to the left).
	_shrine_badge.anchor_left = 1.0
	_shrine_badge.anchor_right = 1.0
	_shrine_badge.offset_left = 10.0
	_shrine_badge.offset_right = 10.0
	_shrine_badge.offset_top = -12.0
	_shrine_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.add_child(_shrine_badge)


## "Daily Descent" (practice once played today), the same dungeon for everyone with the day's
## weapon and relic, and the score: today's (or "your first try counts"), best, streak.
func _refresh_daily() -> void:
	var day := DailyRun.today()
	var played := Profile.daily_played(day)
	_daily_title.text = tr("The Dawn Knell")
	_daily_text.text = tr("Tolled today: %d points") % Profile.daily_score if played else tr("The bell tolls: one descent, the same for all")


func _refresh() -> void:
	_refresh_daily()
	_shrine_badge.visible = content.soul_tree != null and content.soul_tree.nodes.any(func(n: SoulNodeDef) -> bool: return Profile.can_buy_node(n))
	if _shrine_badge.visible and hint_box and not hint_box.visible and not _shrine.visible:
		show_menu_hint.call_deferred(&"menu_souls")
	for child in _records.get_children():
		_records.remove_child(child)
		child.queue_free()
	var difficulty := content.get_difficulty(Profile.difficulty)
	_record(tr("%d souls") % Profile.souls, tr("to spend"), MenuWindow.SOULS)
	_record(tr("Runs"), str(Profile.runs))
	_record(tr("Victories"), str(Profile.victories))
	_record(tr("Deepest floor"), str(Profile.best_depth))
	_record(tr("Difficulty"), tr(difficulty.display_name) if difficulty else tr("Keeper"),
		difficulty.color if difficulty else UiSkin.TEXT)


## One record on the plaque: a word, and its value on the right.
func _record(first: String, second: String, color: Color = UiSkin.TEXT) -> void:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 18)
	var is_souls := color == MenuWindow.SOULS
	var word := UiSkin.label(first, 18 if is_souls else 15, color if is_souls else UiSkin.DIM)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(word)
	var value := UiSkin.label(second, 15, UiSkin.DIM if is_souls else color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pair.add_child(value)
	_records.add_child(pair)


## A tutorial hint of the title screen, once ever (and only with the hints on in the options).
## Returns whether it showed.
func show_menu_hint(id: StringName) -> bool:
	if not Settings.tutorial_hints or Profile.has_seen_hint(id) or content.tutorial == null:
		return false
	var hint := content.tutorial.hint(id)
	if hint == null:
		return false
	var at := Rect2()
	if hint.target != &"" and has_node("%" + String(hint.target)):
		at = (get_node("%" + String(hint.target)) as Control).get_global_rect()
	hint_box.show_hint(hint, at)
	Profile.mark_hint(id)
	return true


## The phone's back button: closes what is open, or leaves the game.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if hint_box and hint_box.visible:
		hint_box.hide_hint()
		return
	var options: OptionsPanel = %OptionsPanel
	if options.visible:
		options.close()
	elif _shrine.visible:
		_shrine.close()
	elif oath_panel and oath_panel.visible:
		oath_panel.hide()
	elif daily_dialog and daily_dialog.visible:
		daily_dialog.hide()
	elif (%CodexPanel as Control).visible:
		(%CodexPanel as CodexPanel).back()
	elif (%DifficultyPanel as Control).visible:
		(%DifficultyPanel as Control).hide()
	else:
		get_tree().quit()
